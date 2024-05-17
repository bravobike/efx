defmodule EfxCase.MockState do
  @moduledoc """
  This module implements a global mutable state needed for mocking.

  Mocking works by adding the pid of the mock-owning process to it's
  dictionary and accessing this pid using a lookup with `ProcessTree`.

  The pid then can be used to lookup information of the mock, e.g. which
  function is mocked with with replacement or how often a function was
  called to verify. This module is the global lookup.

  We need a global lookup in which we can manipulate data to count mock
  invokations as well as store mocks as global when a test is flagged as
  async.
  """
  alias EfxCase.Mock
  alias EfxCase.Mock.MockedFun
  use Agent

  @type pid_t :: pid() | :global

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec add_fun(module(), atom(), arity(), fun(), non_neg_integer() | nil) :: :ok
  def add_fun(behaviour, fun_identifier, arity, fun, num_expected_calls) do
    (ProcessTree.get(:mock_pid) || :global)
    |> add_fun(behaviour, fun_identifier, arity, fun, num_expected_calls)
  end

  @spec add_fun(pid_t(), module(), atom(), arity(), fun(), non_neg_integer() | nil) :: :ok
  def add_fun(pid, behaviour, fun_identifier, arity, fun, num_expected_calls) do
    Agent.update(__MODULE__, fn state ->
      pid_state = get_or_init_state(state, pid)

      new_mock =
        get_or_init_mock(pid_state, behaviour)
        |> Mock.add_fun(fun_identifier, arity, fun, num_expected_calls)
        |> case do
          {:ok, mock} ->
            mock

          {:error, :function_not_in_mock} ->
            raise "Not matching function found for #{behaviour}: #{fun_identifier}/#{arity}"
        end

      new_pid_state = Map.put(pid_state, behaviour, new_mock)

      Map.put(state, pid, new_pid_state)
    end)
  end

  @spec call(module(), atom(), list(any())) :: function_return :: any()
  def call(behaviour, fun_identifier, args) do
    (ProcessTree.get(:mock_pid) || :global)
    |> call(behaviour, fun_identifier, args)
  end

  @spec call(pid_t(), module(), atom(), list(any())) :: function_return :: any()
  def call(pid, behaviour, fun_identifier, args) do
    fun =
      Agent.get_and_update(__MODULE__, fn state ->
        with {:ok, pid_state} <- get_from_agent_state(state, pid),
             {:ok, mock} <- get_from_pid_state(pid_state, behaviour) do
          ret = Mock.get_fun(mock, fun_identifier, Enum.count(args))
          new_mock = Mock.inc_called(mock, fun_identifier, Enum.count(args))
          new_pid_state = Map.put(pid_state, behaviour, new_mock)
          {ret, Map.put(state, pid, new_pid_state)}
        else
          {:error, _} -> raise "no mock found for #{inspect(behaviour)} in pid #{inspect(pid)}"
        end
      end)

    case fun do
      :default ->
        Kernel.apply(behaviour, :"__#{fun_identifier}", args)

      fun ->
        Kernel.apply(fun, args)
    end
  end

  @spec mocked?(module()) :: boolean()
  def mocked?(behaviour) do
    ProcessTree.get(:mock_pid)
    |> mocked?(behaviour)
  end

  @spec mocked?(pid_t(), module()) :: boolean()
  def mocked?(pid, behaviour) do
    mocks = get_from_agent(pid) || %{}
    Map.has_key?(mocks, behaviour)
  end

  @spec verify_called!() :: no_return() | nil | :ok
  def verify_called!() do
    ProcessTree.get(:mock_pid)
    |> verify_called!()
  end

  @spec verify_called!(pid_t()) :: no_return() | nil | :ok
  def verify_called!(pid) do
    mocks = get_from_agent(pid)

    if mocks do
      Enum.each(mocks, fn {behaviour, mock} ->
        unsatisfied = Mock.get_unsatisfied(mock)

        unless Enum.empty?(unsatisfied) do
          raise "expectations for #{inspect(behaviour)} were not meat: \n #{parse(unsatisfied)}"
        end
      end)
    end
  end

  @spec clean_globals() :: :ok
  def clean_globals() do
    Agent.update(__MODULE__, &Map.delete(&1, :global))
  end

  @spec get_or_init_state(map(), pid_t()) :: map()
  defp get_or_init_state(state, pid) do
    Map.get(state, pid, %{})
  end

  @spec get_or_init_mock(map(), module()) :: Mock.t()
  defp get_or_init_mock(state, behaviour) do
    Map.get(state, behaviour, Mock.make(behaviour))
  end

  @spec get_from_agent(pid_t()) :: map() | nil
  defp get_from_agent(pid) do
    Agent.get(__MODULE__, &Map.get(&1, pid)) || Agent.get(__MODULE__, &Map.get(&1, :global))
  end

  @spec get_from_agent_state(map(), pid() | :global) ::
          {:ok, Mock.t()} | {:error, :not_in_pid_lookup}
  defp get_from_agent_state(state, pid) do
    case Map.get(state, pid, Map.get(state, :global)) do
      nil -> {:error, :not_in_pid_lookup}
      something -> {:ok, something}
    end
  end

  @spec get_from_agent_state(map(), pid() | :global) :: {:ok, map()} | {:error, :not_in_pid_state}
  defp get_from_pid_state(state, behaviour) do
    case Map.get(state, behaviour) do
      nil -> {:error, :not_in_pid_state}
      something -> {:ok, something}
    end
  end

  @spec parse(list(MockedFun.t())) :: String.t()
  def parse(mocked_funs) do
    Enum.map_join(mocked_funs, "\n", fn mocked_fun ->
      "- Function #{mocked_fun.name}/#{mocked_fun.arity} was expected to be called #{mocked_fun.num_expected_calls} times but was called #{mocked_fun.num_calls} times."
    end)
  end
end
