defmodule EfxCaseOmnipresent2Test do
  use EfxCase
  use ExUnit.Case

  alias EfxCase.EfxExample
  alias EfxCase.EfxOmnipresentExample

  describe "without binding effects" do
    test "omnipresent binding is executed" do
      assert EfxOmnipresentExample.get() == [42]
      assert EfxOmnipresentExample.another_get() == ["foo"]
    end
  end

  describe "omnipresent effects can be overridden" do
    test "by normal bindings" do
      bind(EfxOmnipresentExample, :get, fn -> [2] end)
      bind(EfxOmnipresentExample, :another_get, fn -> ["bar"] end)
      assert EfxOmnipresentExample.get() == [2]
      assert EfxOmnipresentExample.another_get() == ["bar"]
    end
  end

  describe "with other local bindings" do
    test "omnipresence still works" do
      bind(EfxExample, :get, fn -> [] end)
      bind(EfxExample, :append_get, fn arg -> [arg] end)

      assert EfxExample.get() == []
      assert EfxExample.append_get(1) == [1]

      assert EfxOmnipresentExample.get() == [42]
      assert EfxOmnipresentExample.another_get() == ["foo"]
    end
  end
end
