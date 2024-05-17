defmodule Efx do
  @moduledoc """
  A module to be `use`d to define effects.

  An effect is a function that executes side effects and thus is
  hard to test or even untestable. With the effects abstraction we
  can define mockable effect-functions comfortably.

  Since effects are used on a module level utilizing the use-macro,
  all effect-functions defined inside build a group. We can later
  either bind all or none of this functions.

  This module provides macros for implementing effects that are expanded into a
  mockable behaviour, e.g.

      defmodule MyEffect do
        use Efx

        @spec read_numbers(String.t()) :: integer()
        defeffect read_numbers(id) do
          :default_implementation
        end

        @spec write_numbers(String.t(), integer()) :: :ok
        defeffect read_numbers(id, numbers) do
          :default_implementation
        end
      end

  The above example generates a behaviour with the callbacks

      @callback read_numbers(String.t()) :: integer()
      @callback write_numbers(String.t(), integer()) :: :ok

  This module is meant to be used in conjuction with the mocking test helpers
  found in `Efx.EffectsCase`.
  """

  defmacro __using__(opts) do
    caller = __CALLER__.module
    config_root = Keyword.get(opts, :config_root, :effects)
    config_key = Keyword.get(opts, :config_key, caller)

    Module.register_attribute(caller, :effects, accumulate: true)

    quote do
      import Efx

      @before_compile unquote(__MODULE__)
      @behaviour __MODULE__

      def __config_root(), do: unquote(config_root)
      def __config_key(), do: unquote(config_key)

      def __effects__(), do: @effects
    end
  end

  defmacro __before_compile__(_) do
    caller = __CALLER__.module
    effects = Module.get_attribute(caller, :effects, [])
    specs = Module.get_attribute(caller, :spec, [])

    # the following code searches for the effects, collected in
    # the module attribute `@effects`, finds the specs for the
    # effect functions and implements callbacks for them.
    # Raises if there are no specs founds.
    Enum.map(effects, fn {effect, arity} ->
      Enum.find(specs, fn {:spec, spec, _} ->
        spec_arity(spec) == arity && spec_name(spec) == effect
      end)
      |> case do
        {:spec, spec, _} ->
          quote do
            @callback unquote(spec)
          end

        nil ->
          raise "No spec for effect found: #{effect}"
      end
    end)
  end

  defmacro defeffect(fun, do_block) do
    {name, _, args} = fun
    module = __CALLER__.module

    Module.put_attribute(module, :effects, {name, Enum.count(args)})

    if Mix.env() == :test do
      quote do
        @impl unquote(module)
        def unquote(fun) do
          if EfxCase.MockState.mocked?(unquote(module)) do
            EfxCase.MockState.call(unquote(module), unquote(name), unquote(args))
          else
            unquote(Keyword.get(do_block, :do))
          end
        end
      end
    else
      quote do
        @impl unquote(module)
        def unquote(fun) do
          unquote(Keyword.get(do_block, :do))
        end
      end
    end
  end

  @spec spec_name({any(), any(), list()}) :: name :: atom()
  defp spec_name({_, _, a}), do: List.first(a) |> elem(0)

  @spec spec_arity(tuple()) :: arity()
  defp spec_arity({:"::", _, [{_, _, args} | _]}), do: Enum.count(args)
end
