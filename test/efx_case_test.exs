defmodule EfxCaseTest do
  use EfxCase
  use ExUnit.Case

  alias EfxCase.EfxExample
  alias ExUnit.AssertionError

  describe "binding a non existing function" do
    test "raises but is handled gracefully" do
      assert_raise(AssertionError, fn ->
        bind(EfxExample, :i_dont_exist, fn -> "missigno" end)
      end)
    end
  end

  describe "calling an unbound function" do
    test "raises but is handled gracefully" do
      assert_raise(AssertionError, fn ->
        bind(EfxExample, :get, fn -> [] end)
        assert EfxExample.append_get(1) == [1]
      end)
    end
  end

  describe "without binding effect" do
    test "defaults are executed" do
      assert EfxExample.get() == [1, 2, 3, 4, 5]
      assert EfxExample.append_get(6) == [1, 2, 3, 4, 5, 6]
    end

    test "guarded funs work properly" do
      assert EfxExample.guarded_fun(:a) == :a_or_b
      assert EfxExample.guarded_fun(:c) == :c
    end

    test "multi funs work properly" do
      assert EfxExample.multi_fun([]) == :empty_list
      assert EfxExample.multi_fun(:c) == :c
    end

    test "delegateeffect works properly" do
      assert EfxExample.to_atom("hello") == :hello
      assert EfxExample.to_schmatom("hello") == :hello
    end
  end

  describe "binding effects" do
    test "works as expected" do
      bind(EfxExample, :get, fn -> [] end)
      bind(EfxExample, :append_get, fn arg -> [arg] end)

      assert EfxExample.get() == []
      assert EfxExample.append_get(1) == [1]
    end

    test "works as expected with captures" do
      bind(&EfxExample.get/0, fn -> [] end, calls: 1)
      bind(&EfxExample.append_get/1, fn arg -> [arg] end)

      assert EfxExample.get() == []
      assert EfxExample.append_get(1) == [1]
    end

    test "works when one function is bound and the other isn't called" do
      bind(EfxExample, :get, fn -> [] end)
      assert EfxExample.get() == []
    end

    test "on multi funs" do
      bind(EfxExample, :multi_fun, fn arg -> arg end)
      assert EfxExample.multi_fun(:a) == :a
    end

    test "on guarded funs" do
      bind(EfxExample, :guarded_fun, fn arg -> arg end)
      assert EfxExample.guarded_fun(:a) == :a
    end

    test "works with expected number of calls" do
      bind(EfxExample, :get, fn -> [] end, calls: 1)
      assert EfxExample.get() == []
    end

    test "works with const" do
      bind(&EfxExample.get/0, const: [])
      assert EfxExample.get() == []
    end

    test "works with const and calls" do
      bind(&EfxExample.get/0, const: [], calls: 1)
      assert EfxExample.get() == []
    end

    test "works with expected number of calls with captures" do
      bind(&EfxExample.get/0, fn -> [] end, calls: 1)
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

    test "allows binding one effect and defaulting the other with capture notation" do
      bind(&EfxExample.get/0, const: [])
      bind(&EfxExample.append_get/1, default: true)
      assert EfxExample.get() == []
      assert EfxExample.append_get(6) == [1, 2, 3, 4, 5, 6]
    end

    test "works for delegates" do
      bind(EfxExample, :to_atom, fn _ -> :my_atom end)
      bind(EfxExample, :to_schmatom, fn _ -> :my_schmatom end)

      assert EfxExample.to_atom("hello") == :my_atom
      assert EfxExample.to_schmatom("hello") == :my_schmatom
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

    test "doesn't work in non child processes" do
      bind(EfxExample, :get, fn -> [] end)

      assert [1, 2, 3, 4, 5] = TestAgent.get()
    end
  end

  describe "with_clean_bindings/1" do
    test "cleans bindings withing a test" do
      bind(EfxExample, :get, fn -> [] end)
      assert EfxExample.get() == []

      with_clean_bindings(fn ->
        bind(EfxExample, :get, fn -> 1 end)
        assert EfxExample.get() == 1
      end)
    end
  end

  describe "effects with default args" do
    test "can be called without binding as expected" do
      assert EfxExample.with_default_args() == "Hello user 123"
      assert EfxExample.with_default_args("Rick") == "Hello Rick"
      assert EfxExample.with_default_args("Rick", "Bye") == "Bye Rick"
    end

    test "can be bound with exhaustive arity as expected" do
      bind(EfxExample, :with_default_args, fn a, b -> b <> "-" <> a end)
      assert EfxExample.with_default_args("Rick", "Bye") == "Bye-Rick"
    end

    test "can be bound in defaulted version as expected" do
      bind(EfxExample, :with_default_args, fn -> "Bye Rick" end)
      bind(EfxExample, :with_default_args, fn _a -> "Bye Schlick" end)
      bind(EfxExample, :with_default_args, fn _a, _b -> "Bye Morty" end)

      assert EfxExample.with_default_args() == "Bye Rick"
      assert EfxExample.with_default_args("bla") == "Bye Schlick"
      assert EfxExample.with_default_args("bla", "blub") == "Bye Morty"
    end
  end
end
