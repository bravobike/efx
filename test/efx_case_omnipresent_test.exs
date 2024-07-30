defmodule EfxCaseOmnipresentTest do
  use ExUnit.Case

  alias EfxCase.EfxOmnipresentExample

  describe "without binding effects" do
    test "omnipresent binding is executed" do
      assert EfxOmnipresentExample.get() == [42]
      assert EfxOmnipresentExample.another_get() == ["foo"]
    end
  end
end
