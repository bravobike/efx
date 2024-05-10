defmodule EfxCase do
  @doc """
  Module for testing with effects.

  Mocking follows these principles:

  - By default, an effects module is not mocked.
  - An effects module is always mocked or not mocked at all.
    We cannot mock single functions (except the explicit use of :default)
  - A function is either mocked without a specified number of calls
    or with a specified number of calls. If a function has multiple
    expects, they are mocked in given order, until they satisfied their
    expected number of calls.
  - The number of expected calls is always veryified.

  ## Mocking effects

  To mock effects one simply has to use this module and write
  expect functions. Lets say we have the following effects
  implementation:

      defmodule MyModule do
        use Common.Effects 
    
        @spec get() :: list()
        defeffect get() do
           ...
        end
      end
    
  The following shows code that mocks the effect:

      defmodule SomeTest do
        use Common.EffectsCase
    
        test "test something" do
          expect(MyModule, :get, fn -> [1,2,3] end)
          ...
        end
      end

  Instead of returning the value of the default implementation,
  `MyModule.get/0` returns `[1,2,3]`.

  ## Mocking with an expected number of calls

  We can also define an expected number of calls. The expected
  number of calls is always verified - a test run will fail if
  it is not satisfied, as well as exceeded.

  We can define a number of expected calls as follows:


      defmodule SomeTest do
        use Common.EffectsCase
    
        test "test something" do
          expect(MyModule, :get, 2, fn -> [1,2,3] end)
          ...
        end
      end

  In this case, we verify that the mocked function `get/0` is called
  exactly twice.

  ## Mocking globally

  The effects mocking uses process dictionariesto find the right mock
  through-out the supervision-tree.
  As long as calling processes have the testing process that defines
  the expects as an ancestor, mocking works. If we cannot ensure that,
  we can set mocking to global. However, then the tests must be set
  to async to not interfere:

      defmodule SomeTest do
        use Common.EffectsCase, async: false
    
        test "test something" do
          expect(MyModule, :get, fn -> [1,2,3] end)
          ...
        end
      end


  ## Mocking with multiple expects for the same function

  We can chain expects for the same functions. They then
  get executed until their number of expected calls is satisfied:

      defmodule SomeTest do
        use Common.EffectsCase
    
        test "test something" do
          expect(MyModule, :get, 1, fn -> [1,2,3] end)
          expect(MyModule, :get, 2, fn -> [] end)
          expect(MyModule, :get, fn -> [1,2] end)
          ...
        end
      end

  In this example the first mock of `get/0` gets called one time,
  then the second expect is used to mock the call two more times
  and the last get, specified without an expected number of calls,
  is used for the rest of the execution.

  ## Setup for many tests

  If we want to setup the same mocks for multiple tests we can do
  this as follows:

      defmodule SomeTest do
        use Common.EffectsCase

        setup_effects(MyModule,
           :get, fn -> [1,2,3] end
        )
    
        test "test something" do
          # test with mocked get
          ...
        end
      end


  ## Explicitly defaulting one function in tests

  While it is best practice to mock all function of a module or none,
  we can also default certain functions explicitly:

      defmodule MyModule do
        use Common.Effects 
    
        @spec get() :: list()
        defeffect get() do
           ...
        end
    
        @spec put(any()) :: :ok
        defeffect put(any()) do
           ...
        end
      end
    

      defmodule SomeTest do
        use Common.EffectsCase
    
        test "test something" do
          expect(MyModule, :get, fn -> [1,2,3] end)
          expect(MyModule, :put, :default)
          ...
        end
      end

  While entirely leaving out `put/1` would result in an error
  (when called), we can tell the effects library to use it's
  default implementation. Note that defaulting can be combined
  with an expected number of calls.
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
            MockState.clean_globals()
          end
        end)
      end

      defp expect(effects_behaviour, key, num \\ nil, fun) do
        pid =
          if unquote(async?) do
            self()
          else
            :global
          end

        EfxCase.expect(pid, effects_behaviour, key, num, fun)
      end

      import EfxCase, only: [setup_effects: 2]
    end
  end

  defmacro setup_effects(effects_behaviour, stubs \\ []) do
    quote do
      setup do
        Enum.each(unquote(stubs), fn {k, v} ->
          expect(unquote(effects_behaviour), k, v)
        end)
      end
    end
  end

  def expect(pid, effects_behaviour, key, num \\ nil, fun) do
    {:arity, arity} = Function.info(fun, :arity)
    MockState.add_fun(pid, effects_behaviour, key, arity, fun, num)
  end
end
