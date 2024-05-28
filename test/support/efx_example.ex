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

  # we use this to check that we don't get a warning
  # about the wildcard param at comepile time.
  @spec fun_with_wildcard(any()) :: list()
  defeffect fun_with_wildcard(_arg) do
    [1, 2, 3, 4, 5]
  end

  # we use this to see if functions with multiple
  # implementations work properly at compile time
  @spec multi_fun(any()) :: list()
  defeffect multi_fun([] = list) do
    list
  end

  defeffect multi_fun(string) do
    string
  end
end
