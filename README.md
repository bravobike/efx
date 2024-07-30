# Efx

![Tests](https://github.com/bravobike/efx/actions/workflows/main.yaml/badge.svg)
[![Hex version badge](https://img.shields.io/hexpm/v/efx.svg)](https://hex.pm/packages/efx)


Testing with side-effects is often hard. Various solutions exist to work around
the difficulties, e.g. mocking. This library offers a very easy way to achieve
testable code by mocking. Instead of mocking we talk about binding effects to another implementation.
`Efx` offers a declarative way to mark effectful functions and bind them in tests.

Efx allows async testing even in with child-processes, since it uses process-dictionaries
to store bindings and find them in the supervision-tree (see this [test-case](https://github.com/bravobike/efx/blob/ffe213db51d1b55cf81dd492170d9785284f54c4/test/efx_case_test.exs#L52)).

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

### Setup

To use `Efx` in your project, add this to your dependencies in `mix.ex`:

```elixir
{:efx, "~> 0.2.2"}
```

If you want to have proper formatting of the `Efx.defeffect/2` macro, you can add
the following line to your `.formatter.ex`:

```elixir
[
  ...,
  import_deps: [:efx]
]
```

### Example

Given the following code:

```elixir
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
```

In this example, it's quite complicated to test deserialization and serialization since
we have to prepare and place the file correctly for each test.

We can rewrite the module using `Efx` as follows:


```elixir
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
```

By using the `defeffect`-macro, we define an effect-function as well as provide
a default-implementation in its body. It is mandatory for each of the effect-functions to have a matching spec.

The above code is now easily testable since we can rebind the effect-functions with ease:

```elixir
defmodule MyModuleTest do

  use EfxCase

  describe "read_data/0" do
    test "works as expected with empty file" do
      bind(MyModule, :read_file!, fn -> "" end)
      bind(MyModule, :write_file!, fn _ -> :ok end)

      # test code here
      ...
    end

    test "works as expected with proper contents" do
      bind(MyModule, :read_file!, fn -> "some expected file content" end)
      bind(MyModule, :write_file!, fn _ -> :ok end)

      # test code here
      ...
    end

  end

end
```

Instead of returning the value of the default implementation, `MyModule.read_file!/0` returns test data that is needed for the test case. `MyModule.write_file!` does nothing.

For more details, see the `EfxCase`-module.

Note that Efx generates and implements a behavior. Thus, it is recommended, to move side effects to a dedicated submodule, to not accidentally interfere with existing behaviors.
That said, we create the following module:


```elixir
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
```

and straight forward use it in the original module:

```elixir
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
```

That way, we achieve a clear separation between effectful and pure code.

## OTP Version 25 required

The ancestor-key in process dictionaries is relativly new to Erlang. It was introduced with OTP 25 and, thus, this is the minimal required OTP-version.

## License
Copyright © 2024 Bravobike GmbH and Contributors

This project is licensed under the Apache 2.0 license.
