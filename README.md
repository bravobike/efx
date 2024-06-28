# Efx

![Tests](https://github.com/bravobike/efx/actions/workflows/main.yaml/badge.svg)
[![Hex version badge](https://img.shields.io/hexpm/v/efx.svg)](https://hex.pm/packages/efx)

Testing with side-effects is often hard. Various solutions exist to work around
the difficulties, e.g. mocking. This library offers a very easy way to achieve 
testable code by mocking. Instead of mocking we talk about binding effects to another implementation.
`Efx` offers a declarative way to mark effectful functions and bind them in tests. 

Efx allows async testing even in with child-processes, since it uses process-dictionaries
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

To define effects we insert the use-Macro provided by the `Efx`-Module as follows:


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

By using the `defeffect`-macro, we define an effect-function as well as provide 
a default-implementation in its body. For more detail see the moduledoc in the
`Efx`-module.


### Binding Effects in Tests

To bind effects one simply has to use `EfxCase`-Module and call bind functions. Lets say we have the following effects
implementation:

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



## License
Copyright © 2024 Bravobike GmbH and Contributors

This project is licensed under the Apache 2.0 license.
