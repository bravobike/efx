defmodule EfxCase.EfxExample do
  use Efx

  @spec get() :: list()
  defeffect get() do
    [1, 2, 3, 4, 5]
  end
end
