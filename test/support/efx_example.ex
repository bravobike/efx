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
  defeffect multi_fun([]) do
    :empty_list
  end

  defeffect multi_fun(other) do
    other
  end

  # we use this to see if functions with guards
  # work properly at compile time
  @spec guarded_fun(any()) :: any()
  defeffect guarded_fun(a) when a in [:a, :b] do
    :a_or_b
  end

  @spec guarded_fun(any()) :: any()
  defeffect guarded_fun(a) do
    a
  end

  # we use this to see if one liners work without getting 
  # deformed by formatter

  @spec one_liner(any()) :: any()
  defeffect one_liner(a), do: a

  @spec without_parens :: atom
  defeffect without_parens do
    :ok
  end
end
