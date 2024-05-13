# Efx

![Tests](https://github.com/smoes/validixir/actions/workflows/main.yaml/badge.svg)

Testing with side-effects is often hard. Various solutions exists to work around
the difficulties, e.g. mocking. This library offers a very easy way to achieve 
testable code by mocking. It offers a declarative way to mark effectful functions
and rebind them in tests. 

## Rationale 

Efx is a small library that does one thing and one thing only very well: Make code
that contains side effects testable. It offers a convenient and declarative syntax.
Efx follows the following principles:

- Modules contain groups of effects that can all be rebound or neither in tests
- Mocking effects should be as simple as possible without going into technical detail.
- We want to run as much tests async as possible. Thus, we traverse 
  the supervision tree to find rebound effects in the ancest test processes,
  in an isolated manner.
- Effects are not mocked by default in tests, thus, must be explicitly mocked.
- Effects can only be rebound in tests, but not in production.
- We want zero performance overhead in production.


## Setup

## Usage

### Defining effects

To define effects we insert the use-Macro provided by the `Efx`-Module as follows:


    defmodule MyEffect do
      use Efx

      @spec read_numbers(String.t()) :: integer()
      defeffect read_numbers(id) do
        ... 
      end

      @spec write_numbers(String.t(), integer()) :: :ok
      defeffect read_numbers(id, numbers) do
        ...
      end
    end

By using the `deffect`-macro, we define an effect-function as well as provide 
a default-implementation in its body. For more detail see the moduledoc in the
`Efx`-module.


### Rebinding (or mocking) effects in tests

To mock effects one simply has to use `EfxCase`-Module and write
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

For more details see the `EfxCase`-module.



