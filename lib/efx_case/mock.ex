defmodule EfxCase.Mock do
  @moduledoc !"""
             Internal logic of a mocked behaviour. This module is meant
             to make handling a mock, counting the calls, finding the
             right mocked function, calling the mocked function, etc... more
             convenient.

             A mock consists of the following:

             - a list of mocked functions
             """
  use TypedStruct
  alias __MODULE__

  defmodule MockedFun do
    @moduledoc !"""
               Internal logic of a mocked function. 

               A mocked functions consists of the following:

               - the name or identifier of the function
               - the arity of the function
               - the implementation/replacement of the function. Besides an
                 anonymous function this can be :unmocked or :default.
                 :unmocked says there is no replacement yet and error when called 
                 :default refers to the default implementation
               - a number of expected calls
               - a counter showing how the mocked functions has been called
               """
    use TypedStruct

    typedstruct do
      field(:name, atom())
      field(:arity, arity())
      field(:impl, fun() | :unmocked | :default)
      field(:num_expected_calls, non_neg_integer() | nil)
      field(:num_calls, non_neg_integer(), default: 0)
    end

    @spec satisfied?(MockedFun.t()) :: boolean()
    def satisfied?(mocked_fun) do
      is_nil(mocked_fun.num_expected_calls) ||
        mocked_fun.num_expected_calls == mocked_fun.num_calls
    end

    @spec limit_reached?(MockedFun.t()) :: boolean()
    def limit_reached?(mocked_fun) do
      mocked_fun.num_expected_calls &&
        mocked_fun.num_expected_calls == mocked_fun.num_calls
    end
  end

  typedstruct do
    field(:mocked_funs, list(MockedFun.t()))
  end

  @spec make(module()) :: Mock.t()
  def make(module) do
    effects =
      module.__effects__()
      |> Enum.flat_map(fn {effect, arities, _} ->
        Enum.map(arities, fn arity ->
          %MockedFun{name: effect, arity: arity, impl: :unmocked}
        end)
      end)

    %Mock{mocked_funs: effects}
  end

  @spec add_fun(Mock.t(), atom(), arity(), fun() | :default | :unmocked, non_neg_integer() | nil) ::
          {:ok, Mock.t()} | {:error, :function_not_in_mock}
  def add_fun(mock, name, arity, impl, exptected_calls \\ nil) do
    if member?(mock, name, arity) do
      mock = delete_when_unmocked(mock, name, arity)

      new_mocked_funs =
        mock.mocked_funs ++
          [%MockedFun{name: name, arity: arity, impl: impl, num_expected_calls: exptected_calls}]

      {:ok, %Mock{mock | mocked_funs: new_mocked_funs}}
    else
      {:error, :function_not_in_mock}
    end
  end

  @spec get_fun(Mock.t(), atom(), arity()) ::
          {:ok, MockedFun.t()} | {:error, :unmocked} | {:error, :exhausted} | {:error, :not_found}
  def get_fun(mock, name, arity) do
    get_next_mocked_fun(mock.mocked_funs, name, arity)
  end

  @spec get_unsatisfied(Mock.t()) :: list(MockedFun.t())
  def get_unsatisfied(mock) do
    Enum.reject(mock.mocked_funs, &MockedFun.satisfied?/1)
  end

  @spec inc_called(Mock.t(), atom(), arity()) :: Mock.t()
  def inc_called(mock, name, arity) do
    {:done, funs} =
      Enum.reduce(mock.mocked_funs, {:continue, []}, fn
        fun, {:continue, funs} ->
          if fun.name == name && fun.arity == arity && !MockedFun.limit_reached?(fun) do
            new_fun = %MockedFun{fun | num_calls: fun.num_calls + 1}
            {:done, [new_fun | funs]}
          else
            {:continue, [fun | funs]}
          end

        fun, {:done, funs} ->
          {:done, [fun | funs]}
      end)

    %Mock{mock | mocked_funs: Enum.reverse(funs)}
  end

  @spec get_next_mocked_fun(list(MockedFun.t()), atom(), arity()) ::
          {:ok, MockedFun.t()} | {:error, :unmocked} | {:error, :exhausted} | {:error, :not_found}
  defp get_next_mocked_fun(funs, name, arity) do
    Enum.find(funs, fn f -> f.name == name && f.arity == arity && !MockedFun.limit_reached?(f) end)
    |> case do
      nil -> {:error, exhausted_or_not_found(funs, name, arity)}
      %MockedFun{impl: :unmocked} -> {:error, :unmocked}
      fun -> {:ok, fun}
    end
  end

  @spec delete_when_unmocked(Mock.t(), atom(), non_neg_integer()) :: Mock.t()
  defp delete_when_unmocked(mock, name, arity) do
    %Mock{
      mock
      | mocked_funs:
          Enum.reject(mock.mocked_funs, fn f ->
            f.name == name && f.impl == :unmocked && arity == f.arity
          end)
    }
  end

  @spec exhausted_or_not_found(list(MockedFun.t()), atom(), arity()) :: :exhausted | :not_found
  defp exhausted_or_not_found(funs, name, arity) do
    if Enum.find(funs, fn f -> f.name == name && f.arity == arity end) do
      :exhausted
    else
      :not_found
    end
  end

  @spec member?(Mock.t(), atom(), arity()) :: boolean()
  defp member?(mock, name, arity) do
    Enum.any?(mock.mocked_funs, fn f ->
      f.name == name && arity == f.arity
    end)
  end
end
