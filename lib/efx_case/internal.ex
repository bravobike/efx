defmodule EfxCase.Internal do
  alias EfxCase.MockState

  def verify_mocks(pid) do
    verify_mocks!(pid)
    :ok
  rescue
    e -> {:error, e}
  end

  def verify_mocks!(pid) do
    MockState.verify_called!(pid)
  end

  def init(pid) do
    Process.put(:mock_pid, pid)
  end

  def special_fun_from_opts(opts, arity) do
    cond do
      Keyword.has_key?(opts, :const) ->
        EfxCase.FunUtil.constantly(arity, Keyword.fetch!(opts, :const))

      Keyword.has_key?(opts, :default) && Keyword.fetch!(opts, :default) ->
        {:default, arity}

      true ->
        raise "You have to at least pass :default or :const when calling bind without a function."
    end
  end
end
