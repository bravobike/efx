defmodule EfxCase.FunUtil do
  for arity <- 0..20 do
    args = for i <- 0..arity, i != 0, do: Macro.var(:"_arg#{i}", nil)
    def unquote(:"constantly_#{arity}")(ret), do: fn unquote_splicing(args) -> ret end
  end

  def constantly(arity, ret) do
    Kernel.apply(EfxCase.FunUtil, :"constantly_#{arity}", [ret])
  end
end
