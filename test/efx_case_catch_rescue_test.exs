defmodule EfxCaseCatchRescueTest do
  use ExUnit.Case
  use EfxCase

  alias EfxCase.EfxCaseRescueExample

  describe "without binding effect" do
    test "catches are executed" do
      assert EfxCaseRescueExample.with_catch() == "catch me"
    end

    test "resuces are executed" do
      assert EfxCaseRescueExample.with_rescue() == "oh noes"
    end
  end
end
