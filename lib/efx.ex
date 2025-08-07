defmodule Efx do
  @moduledoc """

  Testing with side-effects is often hard. Various solutions exist to work around
  the difficulties, e.g. mocking. This library offers a very easy way to achieve
  testable code by mocking. Instead of mocking we talk about binding effects to another implementation.
  `Efx` offers a declarative way to mark effectful functions and bind them in tests.

  Efx allows async testing even in with child-processes, since it uses process-dictionaries
  to store bindings and find them in the supervision-tree (see this [test-case](https://github.com/bravobike/efx/blob/improve-doc-example/test/efx_case_test.exs#L52)).

  ## Rationale

  Efx is a small library that does one thing and one thing only very well: Make code
  that contains side effects testable.

  Existing mock libraries often set up mocks in non-declarative ways: configs need
  to be adapted & mock need to be initialized. In source code there are intrusive
  instructions to set up mockable code. `Efx` is very unintrusive in both, source
  code and test code. It offers a convenient and declarative syntax. Instead of
  mocking we talk about binding effects.

  Efx follows the following principles:

  - Implementing and binding effects should be as simple and declarative as possible.
  - Modules contain groups of effects that can only be bound as a set.
  - We want to run as many tests async as possible. Thus, we traverse
  the supervision tree to find rebound effects in the spawning test processes,
  in an isolated manner.
  - Effects by default execute their default implementation in tests, and thus, must be explicitly bound.
  - Effects can only be bound in tests, but not in production. In production, the default implementation is always executed.
  - We want zero performance overhead in production.


  ## Usage

  ### Example

  Given the following code:

      defmodule MyModule do

        def read_data() do
          File.read!("file.txt")
          |> deserialize()
        end

        def write_data(data) do
          serialized_data = data |> serialize()
          File.write!("file.txt", deserialized_data)
        end

        defp deserialize(raw) do
          ...
        end

        defp serialize(data) do
          ...
        end

      end

  In this example, it's quite complicated to test deserialization and serialization since
  we have to prepare and place the file correctly for each test.

  We can rewrite the module using `Efx` as follows:


      defmodule MyModule do

        use Efx

        def read_data() do
          read_file!()
          |> deserialize()
        end

        def write_data(data) do
          data
          |> serialize()
          |> write_file!()
        end

        @spec read_file!() :: binary()
        defeffect read_file!() do
          File.read!("file.txt")
        end

        @spec write_file!(binary()) :: :ok
        defeffect write_file!(raw) do
          File.write!("file.txt", raw)
        end

        ...

      end

  By using the `defeffect`-macro, we define an effect-function as well as provide
  a default-implementation in its body. It is mandatory for each of the effect-functions to have a matching spec.

  The above code is now easily testable since we can rebind the effect-functions with ease:

      defmodule MyModuleTest do

        use EfxCase

        describe "read_data/0" do
          test "works as expected with empty file" do
            bind(&MyModule.read_file!/0, fn -> "" end)
            bind(&MyModule.write_file!/1, fn _ -> :ok end)

            # test code here
            ...
          end

          test "works as expected with proper contents" do
            bind(&MyModule.read_file!/0, fn -> "some expected file content" end)
            bind(&MyModule.write_file!/1, fn _ -> :ok end)

            # test code here
            ...
          end

        end

      end

  Instead of returning the value of the default implementation, `MyModule.read_file!/0` returns test data that is needed for the test case. `MyModule.write_file!` does nothing.

  For more details, see the `EfxCase`-module.

  ### Caution: Efx generates a behaviour

  Note that Efx generates and implements a behavior. Thus, it is recommended, to move side effects to a dedicated submodule, to not accidentally interfere with existing behaviors.
  That said, we create the following module:

      defmodule MyModule.Effects do

        use Efx

        @spec read_file!() :: binary()
        defeffect read_file!() do
          File.read!("file.txt")
        end

        @spec write_file!(binary()) :: :ok
        defeffect write_file!(raw) do
          File.write!("file.txt", raw)
        end

      end

  and straight forward use it in the original module:

      defmodule MyModule do

        alias MyModule.Effects

        def read_data() do
          Effects.read_file!()
          |> deserialize()
        end

        def write_data(data) do
          data
          |> serialize()
          |> Effects.write_file!()
        end

      ...
      end

  That way, we achieve a clear separation between effectful and pure code.

  ### Delegate Effects

  The same way we use `Kernel.defdelegate/2` we can implement effect functions that just delegate to another function like so: 

      @spec to_atom(String.t()) :: atom()
      delegateeffect to_atom(str), to: String

  `delegateeffect` follows the same syntax as `Kernel.defdelegate/2`.
  Functions defined using `defdelegate` are bindable in tests like they were created using `defeffect`.

  """

  defmacro __using__(opts) do
    caller = __CALLER__.module
    config_root = Keyword.get(opts, :config_root, :effects)
    config_key = Keyword.get(opts, :config_key, caller)

    Module.register_attribute(caller, :effects, accumulate: true)

    quote do
      import Efx

      @before_compile unquote(__MODULE__)

      def __config_root(), do: unquote(config_root)
      def __config_key(), do: unquote(config_key)

      def __effects__(), do: @effects
    end
  end

  defmacro __before_compile__(_) do
    caller = __CALLER__.module
    effects = Module.get_attribute(caller, :effects, [])

    effect_impls =
      effects
      |> Enum.map(fn {_, _, impl} -> impl end)
      |> Enum.reverse()

    specs = Module.get_attribute(caller, :spec, [])

    Module.delete_attribute(caller, :effects)

    # the following code searches for the effects, collected in
    # the module attribute `@effects`, finds the specs for the
    # effect functions and implements callbacks for them.
    # Raises if there are no specs founds.
    Enum.flat_map(effects, fn {effect, arities, _impl} ->
      Enum.map(arities, fn arity ->
        Enum.find(specs, fn {:spec, spec, _} ->
          spec_arity(spec) == arity && spec_name(spec) == effect
        end)
        |> case do
          {:spec, spec, _} ->
            quote do
              @callback unquote(spec)
            end

          nil ->
            raise "No spec for effect found: #{effect}/#{arity}"
        end
      end)
    end) ++
      effect_impls
  end

  defmacro defeffect(fun, do_block) do
    {name, _ctx, _args} = extract_fun(fun)
    module = __CALLER__.module

    alternative_fun_header = make_alternative_fun_header(fun, module)

    impl_fun = make_implementation_fun_header(fun)

    impl =
      quote do
        def unquote_splicing([impl_fun, do_block])
      end

    real_impl =
      quote do
        def unquote_splicing([fun, do_block])
      end

    generate_effect(module, name, alternative_fun_header, impl_fun, impl, real_impl)
  end

  defmacro delegateeffect(fun, opts) do
    {name, _ctx, args} = fun
    args = ensure_list(args)
    module = __CALLER__.module

    alternative_fun_header = make_alternative_fun_header(fun, module)
    impl_fun = make_implementation_fun_header(fun)

    to = Keyword.fetch!(opts, :to)
    as = Keyword.get(opts, :as, name)

    impl =
      quote do
        def unquote(impl_fun) do
          Kernel.apply(unquote(to), unquote(as), unquote(args))
        end
      end

    real_impl =
      quote do
        defdelegate(unquote_splicing([fun, opts]))
      end

    generate_effect(module, name, alternative_fun_header, impl_fun, impl, real_impl)
  end

  defp make_alternative_fun_header(fun, module) do
    {name, ctx, args} = extract_fun(fun)
    args = ensure_list(args)
    # we do this to not get warnings for wildcard params in functions
    alt_args = make_alt_args(args, module)
    {name, ctx, alt_args}
  end

  defp make_alt_args(args, module) do
    Macro.generate_arguments(Enum.count(args), module)
    |> Enum.zip(args)
    |> Enum.map(fn {alt_arg, arg} ->
      case arg do
        {:\\, context, [_original_arg, default]} -> {:\\, context, [alt_arg, default]}
        _ -> alt_arg
      end
    end)
  end

  defp make_implementation_fun_header(fun) do
    {name, _ctx, _args} = extract_fun(fun)
    impl_name = :"__#{name}"
    substitute_name(fun, impl_name)
  end

  defp generate_effect(
         module,
         name,
         alternative_fun_header,
         implementation_fun_header,
         impl,
         real_fun
       ) do
    {_name, _ctx, alt_args_with_defaults} = extract_fun(alternative_fun_header)
    alt_args = remove_defaults(alt_args_with_defaults)
    {implementation_name, _ctx, _alt_args} = extract_fun(implementation_fun_header)

    # we store the implementations here to put them all together in the end
    # to avoid warnings about non grouped definitions of the same function
    arity = Enum.count(alt_args)

    already_exists? = already_exists?(module, name, arity)

    register_effect(module, name, alt_args_with_defaults, impl)

    if in_test?() do
      unless already_exists? do
        # we generate a function that checks if the function is mocked and
        # if not we call the default implementation we moved to an alternative
        # implementation function
        num_alt_args = Enum.count(alt_args)
        num_alt_args_with_defaults = Enum.count(alt_args_with_defaults)

        for i <- num_alt_args..num_alt_args_with_defaults do
          num_to_cutoff = i - num_alt_args
          fun_header = cutoff_defaults_from_fun_header(alternative_fun_header, num_to_cutoff)
          args = cutoff_defaults_from_args(alt_args_with_defaults, num_to_cutoff)

          quote do
            def unquote(fun_header) do
              if EfxCase.MockState.mocked?(unquote(module)) do
                EfxCase.MockState.call(unquote(module), unquote(name), unquote(args))
              else
                Kernel.apply(__MODULE__, unquote(implementation_name), unquote(args))
              end
            end
          end
        end
      end
    else
      real_fun
    end
  end

  defp cutoff_defaults_from_fun_header(fun_header, num_to_cutoff) do
    {name, context, args} = fun_header

    new_args =
      cutoff_defaults_from_args(args, num_to_cutoff)
      |> undefault()

    {name, context, new_args}
  end

  defp cutoff_defaults_from_args(args, num_to_cutoff) do
    if num_to_cutoff == 0 do
      args
      |> undefault()
    else
      new_args = remove_next_default(args)
      cutoff_defaults_from_args(new_args, num_to_cutoff - 1)
    end
  end

  defp remove_next_default(args) do
    default =
      Enum.find(args, fn
        {:\\, _, _} -> true
        _ -> false
      end)

    List.delete(args, default)
  end

  defp undefault(args) do
    Enum.map(args, fn
      {:\\, _, [name, _]} -> name
      c -> c
    end)
  end

  defp register_effect(module, name, args, impl) do
    num_non_defaulted_args = count_non_defaulted_args(args)
    arity = Enum.count(args)

    Module.put_attribute(module, :effects, {name, num_non_defaulted_args..arity, impl})
  end

  defp count_non_defaulted_args(args) do
    Enum.filter(args, fn
      {:\\, _, _} -> false
      _ -> true
    end)
    |> Enum.count()
  end

  defp remove_defaults(args) do
    Enum.filter(args, fn
      {:\\, _, _} -> false
      _arg -> true
    end)
  end

  defp extract_fun({:when, _ctx, [fun, _when_condition]}), do: fun
  defp extract_fun(fun), do: fun

  defp substitute_name({:when, ctx, [fun, condition]}, new_name),
    do: {:when, ctx, [substitute_name(fun, new_name), condition]}

  defp substitute_name({_name, ctx, args}, new_name), do: {new_name, ctx, args}

  @spec spec_name({any(), any(), list()}) :: name :: atom()
  defp spec_name({_, _, a}) do
    a = ensure_list(a)
    List.first(a) |> elem(0)
  end

  @spec spec_arity(tuple()) :: arity()
  defp spec_arity({:"::", _, [{_, _, args} | _]}) do
    args = ensure_list(args)
    Enum.count(args)
  end

  @spec already_exists?(module(), atom(), arity()) :: boolean()
  def already_exists?(module, name, arity) do
    Enum.any?(
      Module.get_attribute(module, :effects),
      fn {other_name, other_arity, _} ->
        name == other_name && arity in other_arity
      end
    )
  end

  @spec ensure_list(list() | nil) :: list()
  defp ensure_list(nil), do: []
  defp ensure_list(list), do: list

  defp in_test?() do
    Code.ensure_loaded?(Mix) && Mix.env() == :test
  end
end
