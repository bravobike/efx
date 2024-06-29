defmodule EfxCaseGlobalTest do
  use ExUnit.Case
  use EfxCase, async: false

  alias EfxCase.EfxExample

  describe "without binding effect" do
    test "defaults are executed" do
      assert EfxExample.get() == [1, 2, 3, 4, 5]
      assert EfxExample.append_get(6) == [1, 2, 3, 4, 5, 6]
    end
  end

  describe "binding effects" do
    test "works as expected" do
      bind(EfxExample, :get, fn -> [] end)
      bind(EfxExample, :append_get, fn arg -> [arg] end)

      assert EfxExample.get() == []
      assert EfxExample.append_get(1) == [1]
    end

    test "works when one function is bound and the other isn't called" do
      bind(EfxExample, :get, fn -> [] end)
      assert EfxExample.get() == []
    end

    test "works with expected number of calls" do
      bind(EfxExample, :get, fn -> [] end, calls: 1)
      assert EfxExample.get() == []
    end

    test "works with expected number of calls part two" do
      bind(EfxExample, :get, fn -> [] end, calls: 2)
      assert EfxExample.get() == []
      assert EfxExample.get() == []
    end

    test "allows binding one effect and defaulting the other" do
      bind(EfxExample, :get, fn -> [] end)
      bind(EfxExample, :append_get, {:default, 1})

      assert EfxExample.get() == []
      assert EfxExample.append_get(6) == [1, 2, 3, 4, 5, 6]
    end

    test "works in child processes" do
      bind(EfxExample, :get, fn -> [] end)
      bind(EfxExample, :append_get, {:default, 1})

      task =
        Task.async(fn ->
          assert EfxExample.get() == []
          assert EfxExample.append_get(6) == [1, 2, 3, 4, 5, 6]
        end)

      Task.await(task)
    end

    test "does work in non child processes" do
      bind(EfxExample, :get, fn -> [] end)

      assert [] = TestAgent.get()
    end
  end

  describe "style" do
    test "zero-artity may be defined without parens" do
      assert EfxExample.without_parens() == :ok
    end
  end
end
