defmodule EfxCaseOmnipresent2Test do
  use EfxCase
  use ExUnit.Case

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
end
