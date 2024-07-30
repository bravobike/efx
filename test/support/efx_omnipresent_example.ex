defmodule EfxCase.EfxOmnipresentExample do
  use Efx

  @spec get() :: list()
  defeffect get(), do: [1, 2, 3, 4, 5]

  @spec another_get() :: list()
  defeffect another_get() do
    ["hello", "world"]
  end
end
