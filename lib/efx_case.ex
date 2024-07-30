defmodule EfxCase do
  @moduledoc """
  Module for testing with effects.

  Binding effects in tests follows these principles:

  - By default, all effects of a module are bound to the default implementation.
  - We either bind all effect functions of a module or none.
    We cannot bind single functions (except the explicit use of :default).
    If we rebind only one effect and the other is called, we raise.
  - A function is either bound without or with a specified number of expected calls.
    If a function has multiple binds, they are called in the given order, until they satisfied their
    expected number of calls.
  - The number of expected calls is always verified.

  ## Binding effects

  To bind effects, one simply has to use this module and call
  the bind macro. Let's say we have the following effects implementation:

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

  We can now rebind the code in tests for different test scenarios.

      defmodule MyModuleTest do
        use EfxCase

        test "works as expected with empty file" do
          bind(MyModule, :read_file!, fn -> "" end)

          # test code here
          ...
        end
      end

  Instead of returning the value of the default implementation, `MyModule.read_file!/0` returns an empty string now, representing an empty file.

  Once we bind one effect of a module, all effect-function of that module need to be bound. If an unbound effect-function is called, an error is raised.

  ## Binding with an expected Number of Calls

  We can additionally define an expected number of calls. The expected
  number of calls is always verified - a test run will fail if
  it is not satisfied, as well as exceeded.

  We can define a number of expected calls as follows:

      test "works as expected with empty file" do
        bind(MyModule, :read_file!, fn -> "" end, calls: 1)

        # test code here
        ...
      end

  In this case, we verify that the bound function `get/0` is called
  exactly twice.

  We can also use multiple binding with the call option set. Then, they
  are executed until the number of bindings is satisfied, followed by the next
  binding:


      test "works as expected with empty file and then some data" do
        bind(MyModule, :read_file!, fn -> "" end, calls: 1)
        bind(MyModule, :read_file!, fn -> "some meaningful data" end, calls: 1)

        # test code here
        ...
      end

  In the above example, the test only succeeds if there are 2 calls to the effect-function.
  The first call returns an empty string, while the second returns `"some meaningful data"`.

  ## Binding globally

  Effect binding uses process dictionaries to find the right binding
  by traversing the supervision-tree towards the root.
  As long as calling processes have the testing process that defines
  the binding as an ancestor, binding works. If we cannot ensure that,
  we can set binding to global. However, then tests must be explicitly set
  to async to not interfere:

      defmodule MyModuleTest do
        use EfxCase, async: false

        test "async test works as expected" do
          bind(MyModule, :read_file!, fn -> "" end)

          # test code here
          ...
        end
      end

  ## Setup for many Tests

  If we want to set up the same binding for multiple tests, we can do
  this as follows:

      defmodule MyModuleTest do
        use EfxCase, async: false

        setup_effects(MyModule,
           read_file!: fn -> "some meaningful data" end
        )

        test "works with meaningful data" do
          # test code here
          ...
        end

        test "another test works with meaningful data" do
          # test code here
          ...
        end
      end


  ## Setup for all tests at once

  `EfxCase` offers the possiblity to bind effects for all tests in your
  test-suite once. To do so, we add a call to `ExCase.omnipresent/2` to our
  `test_helper.exs` and have it executed before tests:


      ExUnit.start()

      TestAgent.start_link()

      EfxCase.omnipresent(
        MyModule,
        read_file!: fn -> "some meaningful data",
        write_file!: fn _contents -> :ok end
      )


  We can still override the omnipresent binding selectivly in tests.

  ## Explicitly defaulting one Function in Tests

  While it is best practice to bind all function of a module or none,
  we can also default certain functions explicitly:


      defmodule MyModuleTest do
        use EfxCase, async: false

        test "works with meaningful data" do
          bind(MyModule, :read_file!, fn -> "some meaningful data" end)
          bind(MyModule, :write_file!, {:default, 1})

          # test code here
          ...
        end
      end

  While entirely leaving out `write_file!/1` would result in an error
  (when called), we can tell `Efx` to use it's
  default implementation. Note that when default, we have to provide the arity of the function.
  It can be combined with an expected number of calls.
  """

  require Logger

  alias EfxCase.MockState
  alias EfxCase.Internal

  defmacro __using__(opts) do
    async? = Keyword.get(opts, :async, true)

    quote do
      use ExUnit.Case, async: unquote(async?)

      setup do
        pid =
          if unquote(async?) do
            self()
          else
            :global
          end

        Internal.init(pid)

        on_exit(fn ->
          Internal.verify_mocks!(pid)

          unless unquote(async?) do
            MockState.clean_after_test()
          end
        end)
      end

      defp bind(effects_behaviour, key, fun, opts \\ []) do
        num = Keyword.get(opts, :calls)

        pid =
          if unquote(async?) do
            self()
          else
            :global
          end

        EfxCase.bind(pid, effects_behaviour, key, num, fun)
      end

      import EfxCase, only: [setup_effects: 2]
    end
  end

  defmacro setup_effects(effects_behaviour, stubs \\ []) do
    quote do
      setup do
        Enum.each(unquote(stubs), fn {k, v} ->
          bind(unquote(effects_behaviour), k, v)
        end)
      end
    end
  end

  def bind(pid, effects_behaviour, key, num \\ nil, fun) do
    {fun, arity} =
      case fun do
        {:default, _} = f ->
          f

        _ ->
          {:arity, arity} = Function.info(fun, :arity)
          {fun, arity}
      end

    MockState.add_fun(pid, effects_behaviour, key, arity, fun, num)
  end

  def omnipresent(effects_behaviour, stubs \\ []) do
    Enum.each(stubs, fn {k, v} ->
      bind(:omnipresent, effects_behaviour, k, v)
    end)
  end
end
