defmodule EfxCase.EfxExample do
  use Efx

  @spec get() :: list()
  defeffect get() do
    [1, 2, 3, 4, 5]
  end

  @spec append_get(any()) :: list()
  defeffect append_get(arg) do
    [1, 2, 3, 4, 5] ++ [arg]
  end
end
