defmodule EfxCase.MockState do
  @moduledoc """
  This module implements a global mutable state needed for mocking.

  Mocking works by adding the pid of the mock-owning process to it's
  dictionary and accessing this pid using a lookup with `ProcessTree`.

  The pid then can be used to lookup information of the mock, e.g. which
  function is mocked with replacement or how often a function was
  called to verify. This module is the global lookup.

  We need a global lookup in which we can manipulate data to count mock
  invocations as well as store mocks as global when a test is flagged as
  async.
  """
  alias EfxCase.Mock
  alias EfxCase.Mock.MockedFun
  alias ExUnit.Assertions

  require ExUnit.Assertions

  use Agent

  @typedoc """
  Defines the scopes of a binding.

  A scope is one of the following
  - pid: the binding is bound to a pid
  - global: the binding is bound globally, defined with `async: true`
  - omnipresent: the binding is omnipresent, that is, defined at test bootstrap
  """
  @type scope_t :: pid() | :global | :omnipresent

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec add_fun(scope_t(), module(), atom(), arity(), fun(), non_neg_integer() | nil) :: :ok
  def add_fun(pid, behaviour, fun_identifier, arity, fun, num_expected_calls) do
    result =
      Agent.get_and_update(__MODULE__, fn state ->
        pid_state = get_or_init_state(state, pid)

        get_or_init_mock(pid_state, behaviour)
        |> Mock.add_fun(fun_identifier, arity, fun, num_expected_calls)
        |> case do
          {:ok, new_mock} ->
            new_pid_state = Map.put(pid_state, behaviour, new_mock)
            {:ok, Map.put(state, pid, new_pid_state)}

          {:error, :function_not_in_mock} = err ->
            {err, state}
        end
      end)

    if result == {:error, :function_not_in_mock} do
      Assertions.flunk("Not matching function found for #{behaviour}: #{fun_identifier}/#{arity}")
    end

    :ok
  end

  @spec call(module(), atom(), list(any())) :: function_return :: any()
  def call(behaviour, fun_identifier, args) do
    ProcessTree.get(:mock_pid)
    |> call(behaviour, fun_identifier, args)
  end

  @spec call(scope_t() | nil, module(), atom(), list(any())) :: function_return :: any()
  def call(pid, behaviour, fun_identifier, args) do
    arity = Enum.count(args)

    fun =
      Agent.get_and_update(__MODULE__, fn state ->
        with {:ok, mock, scope_state, scope} <- get_from_agent_state(state, pid, behaviour),
             {:ok, foo} <- Mock.get_fun(mock, fun_identifier, arity) do
          new_mock = Mock.inc_called(mock, fun_identifier, arity)
          new_pid_state = Map.put(scope_state, behaviour, new_mock)
          {{:ok, foo.impl}, Map.put(state, scope, new_pid_state)}
        else
          {:error, _} = err ->
            {err, state}
        end
      end)

    case fun do
      {:ok, :default} ->
        Kernel.apply(behaviour, :"__#{fun_identifier}", args)

      {:ok, fun} ->
        Kernel.apply(fun, args)

      {:error, :not_found} ->
        Assertions.flunk(
          "no binding found for #{inspect(behaviour)}.#{Atom.to_string(fun_identifier)}/#{arity} in scope #{inspect(pid)}"
        )

      {:error, :unmocked} ->
        Assertions.flunk(
          "no binding found for #{inspect(behaviour)}.#{Atom.to_string(fun_identifier)}/#{arity} in scope #{inspect(pid)}"
        )

      {:error, :exhausted} ->
        Assertions.flunk(
          "The number of expected calls is exceeded for #{inspect(behaviour)}.#{Atom.to_string(fun_identifier)}/#{arity} in scope #{inspect(pid)}"
        )
    end
  end

  @spec mocked?(module()) :: boolean()
  def mocked?(behaviour) do
    ProcessTree.get(:mock_pid)
    |> mocked?(behaviour)
  end

  @spec mocked?(scope_t(), module()) :: boolean()
  def mocked?(pid, behaviour) do
    mocks = get_from_agent(pid) || %{}

    if pid == :omnipresent do
      Map.has_key?(mocks, behaviour)
    else
      Map.has_key?(mocks, behaviour) || mocked?(:omnipresent, behaviour)
    end
  end

  @spec verify_called!() :: no_return() | nil | :ok
  def verify_called!() do
    ProcessTree.get(:mock_pid)
    |> verify_called!()
  end

  @spec verify_called!(scope_t()) :: no_return() | nil | :ok
  def verify_called!(pid) do
    mocks = get_from_agent(pid)

    if mocks do
      Enum.each(mocks, fn {behaviour, mock} ->
        unsatisfied = Mock.get_unsatisfied(mock)

        unless Enum.empty?(unsatisfied) do
          Assertions.flunk(
            "expectations for #{inspect(behaviour)} were not met: \n #{parse(unsatisfied)}"
          )
        end
      end)
    end
  end

  @spec clean_after_test() :: :ok
  def clean_after_test() do
    pid = self()
    Agent.update(__MODULE__, &(Map.delete(&1, :global) |> Map.delete(pid)))
  end

  @spec get_or_init_state(map(), scope_t()) :: map()
  defp get_or_init_state(state, pid) do
    Map.get(state, pid, %{})
  end

  @spec get_or_init_mock(map(), module()) :: Mock.t()
  defp get_or_init_mock(state, behaviour) do
    Map.get(state, behaviour, Mock.make(behaviour))
  end

  @spec get_from_agent(scope_t()) :: map() | nil
  defp get_from_agent(pid) do
    Agent.get(__MODULE__, &Map.get(&1, pid)) || Agent.get(__MODULE__, &Map.get(&1, :global)) ||
      Agent.get(__MODULE__, &Map.get(&1, :omnipresent))
  end

  @spec get_from_agent_state(map(), scope_t(), module()) ::
          {:ok, Mock.t(), map(), scope_t()} | {:error, :not_found}
  defp get_from_agent_state(state, pid, behaviour) do
    case get_in(state, [pid, behaviour]) do
      nil ->
        cond do
          pid == :omnipresent -> {:error, :not_found}
          pid == :global -> get_from_agent_state(state, :omnipresent, behaviour)
          true -> get_from_agent_state(state, :global, behaviour)
        end

      v ->
        {:ok, v, Map.get(state, pid), pid}
    end
  end

  @spec parse(list(MockedFun.t())) :: String.t()
  def parse(mocked_funs) do
    Enum.map_join(mocked_funs, "\n", fn mocked_fun ->
      "- Function #{mocked_fun.name}/#{mocked_fun.arity} was expected to be called #{mocked_fun.num_expected_calls} times but was called #{mocked_fun.num_calls} times."
    end)
  end
end
