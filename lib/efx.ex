defmodule Efx do
  @moduledoc """
    Testing with side-effects is often hard. Various solutions exist to work around
  the difficulties, e.g. mocking. This library offers a very easy way to achieve 
  testable code by mocking. Instead of mocking we talk about binding effects to another implementation.
  `Efx` offers a declarative way to mark effectful functions and bind them in tests. 

  Efx allows async testing even in with child-processes in tests, since it uses process-dictionaries
  to store bindings and find them in the super vision tree.

  ## Rationale 

  Efx is a small library that does one thing and one thing only very well: Make code
  that contains side effects testable. 

  Existing mock libraries often set up mocks in non declarative ways: configs need 
  to be adapted & mock need to be initialized. In source code there are intrusive 
  instructions to set up mockable code. `Efx` is very unintrusive in both, source
  code and test code. It offers a convenient and declarative syntax. Instead of 
  mocking we talk about binding effects.

  Efx follows the following principles:

  - Implementing and binding effects should be as simple and declarative as possible.
  - Modules contain groups of effects that can only be bound as a set.
  - We want to run as much tests async as possible. Thus, we traverse 
    the supervision tree to find rebound effects in the ancest test processes,
    in an isolated manner.
  - Effects by default execute their default implemenation in tests, and thus, must be explicitly bound.
  - Effects can only be bound in tests, but not in production. In production always the default implementation is executed.
  - We want zero performance overhead in production.


  ## Usage

  ### Defining Effects

  An effect is a function that executes side effects and thus is
  hard to test or even untestable. With the effects abstraction we
  can define mockable effect-functions comfortably.

  Since effects are used on a module level utilizing the use-macro,
  all effect-functions defined inside build a group. We can later
  either bind all or none of this functions.

  This module provides macros for implementing effects that are expanded into a
  mockable behaviour, e.g.


  ```elixir
  defmodule MyEffect do
    use Efx

    @spec read_numbers(String.t()) :: integer()
    defeffect read_numbers(id) do
      ... 
    end

    @spec write_numbers(String.t(), integer()) :: :ok
    defeffect write_numbers(id, numbers) do
      ...
    end
  end
  ```


    The above example generates a behaviour with the callbacks

  ```elixir
        @callback read_numbers(String.t()) :: integer()
        @callback write_numbers(String.t(), integer()) :: :ok
  ```

  By using the `defeffect`-macro, we define an effect-function as well as provide 
  a default-implementation in its body. For more detail see the moduledoc in the
  `Efx`-module.


  ### Binding Effects in Tests

  To bind effects one simply has to use `EfxCase`-Module and call bind functions. Lets say we have the following effects implementation:

  ```elixir
  defmodule MyModule do
    use Efx 

    @spec get() :: list()
    defeffect get() do
       ...
    end
  end
  ```
    
  The following shows code that binds the effect to a different implementation in tests:

  ```elixir
  defmodule SomeTest do
    use EfxCase

    test "test something" do
      bind(MyModule, :get, fn -> [1,2,3] end)
      ...
    end
  end
  ```

  Instead of returning the value of the default implementation, `MyModule.get/0` returns `[1,2,3]`.

  For more details see the `EfxCase`-module.

  """

  defmacro __using__(opts) do
    caller = __CALLER__.module
    config_root = Keyword.get(opts, :config_root, :effects)
    config_key = Keyword.get(opts, :config_key, caller)

    Module.register_attribute(caller, :effects, accumulate: true)
    Module.register_attribute(caller, :effect_impls, accumulate: true)

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

    effect_impls =
      Module.get_attribute(caller, :effect_impls, [])
      |> Enum.map(fn {_, _, impl} -> impl end)

    specs = Module.get_attribute(caller, :spec, [])

    Module.delete_attribute(caller, :effects)
    Module.delete_attribute(caller, :effect_impls)

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
    end) ++
      effect_impls
  end

  defmacro defeffect(fun, do_block) do
    {name, ctx, args} = fun
    module = __CALLER__.module

    # we do this to not get warnings for wildcard params in functions
    alt_args = Macro.generate_arguments(Enum.count(args), module)
    alt_fun = {name, ctx, alt_args}

    Module.put_attribute(module, :effects, {name, Enum.count(args)})
    impl_name = :"__#{name}"
    impl_fun = {impl_name, ctx, args}

    impl =
      quote do
        def unquote(impl_fun) do
          unquote(Keyword.get(do_block, :do))
        end
      end

    # we store the implementations here to put them all together in the end
    # to avoid warnings about non grouped definitions of the same function
    arity = Enum.count(args)

    already_exists? = already_exists?(module, name, arity)

    Module.put_attribute(module, :effect_impls, {name, Enum.count(args), impl})

    if Mix.env() == :test do
      unless already_exists? do
        quote do
          @impl unquote(module)
          def unquote(alt_fun) do
            if EfxCase.MockState.mocked?(unquote(module)) do
              EfxCase.MockState.call(unquote(module), unquote(name), unquote(alt_args))
            else
              Kernel.apply(__MODULE__, unquote(impl_name), unquote(alt_args))
            end
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

  @spec already_exists?(module(), atom(), arity()) :: boolean()
  def already_exists?(module, name, arity) do
    Enum.any?(
      Module.get_attribute(module, :effect_impls),
      fn {other_name, other_arity, _} ->
        name == other_name && arity == other_arity
      end
    )
  end
end
