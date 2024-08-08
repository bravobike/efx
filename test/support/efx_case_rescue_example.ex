defmodule EfxCase.EfxCaseRescueExample do
  use Efx

  @spec with_rescue() :: String.t()
  defeffect with_rescue() do
    raise "oh noes"
  rescue
    error -> error.message
  end

  @spec with_catch() :: String.t()
  defeffect with_catch() do
    throw("catch me")
  catch
    message -> message
  end
end
