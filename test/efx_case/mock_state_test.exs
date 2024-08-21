defmodule EfxCase.MockStateTest do
  use ExUnit.Case

  alias EfxCase.EfxExample
  alias EfxCase.MockState

  describe "add_fun/6" do
    test "works as expected" do
      add_fun()
      assert [] == call()
    end
  end

  describe "call/4" do
    test "calls a mock" do
      add_fun()
      assert [] == call()
    end

    test "calls chained expects" do
      add_fun(num_expected_calls: 1)
      add_fun(num_expected_calls: 1, fun: fn -> ["foo"] end)
      add_fun(fun: fn -> ["bar"] end)
      assert [] == call()
      assert ["foo"] == call()
      assert ["bar"] == call()
    end
  end

  describe "mocked?/1" do
    test "returns if a behaviour is mocked" do
      refute MockState.mocked?(self(), EfxExample)
      add_fun()
      assert MockState.mocked?(self(), EfxExample)
    end
  end

  describe "verified_called!/1" do
    test "doesn't raise if everything is satisfied" do
      add_fun()
      MockState.verify_called!(self())
    end

    test "raises if if unsatisfied" do
      assert_raise(ExUnit.AssertionError, fn ->
        add_fun(num_expected_calls: 1)
        MockState.verify_called!(self())
      end)
    end
  end

  describe "clean after test/0" do
    test "cleans globals as expected" do
      add_fun(pid: :global)
      assert MockState.mocked?(:global, EfxExample)
      MockState.clean_after_test()
      refute MockState.mocked?(:global, EfxExample)
    end
  end

  defp add_fun(opts \\ []) do
    name = Keyword.get(opts, :name, :get)
    arity = Keyword.get(opts, :arity, 0)
    fun = Keyword.get(opts, :fun, fn -> [] end)
    pid = Keyword.get(opts, :pid, self())
    num_expected_calls = Keyword.get(opts, :num_expected_calls)
    MockState.add_fun(pid, EfxExample, name, arity, fun, num_expected_calls)
  end

  defp call(opts \\ []) do
    name = Keyword.get(opts, :name, :get)
    args = Keyword.get(opts, :args, [])
    MockState.call(self(), EfxExample, name, args)
  end
end
