# Efx

![Tests](https://github.com/bravobike/efx/actions/workflows/main.yaml/badge.svg)
[![Hex version badge](https://img.shields.io/hexpm/v/efx.svg)](https://hex.pm/packages/efx)

Testing with side-effects is often hard. Various solutions exist to work around
the difficulties, e.g. mocking. This library offers a very easy way to achieve 
testable code by mocking. Instead of mocking we talk about binding effects to another implementation.
`Efx` offers a declarative way to mark effectful functions and bind them in tests. 

Efx allows async testing even in with child-processes, since it uses process-dictionaries
to store bindings and find them in the super vision tree (see this [test-case](https://github.com/bravobike/efx/blob/improve-doc-example/test/efx_case_test.exs#L52)).

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

We can rewrite the module using Efx as follows:


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
a default-implementation in its body. For more detail see the moduledoc in the
`Efx`-module.

The above code is now easily testable since we can rebind the effect-functions with ease:

```elixir
defmodule MyModuleTest do

  use EfxCase

  describe "read_data/0" do
    test "works as expected with empty file" do
      bind(MyModule, :read_data, fn -> "" end)

      # test code here
      ...
    end

    test "works as expected with proper contents" do
      bind(MyModule, :read_data, fn -> "some expected file content" end)

      # test code here
      ...
    end

  end

end
```

Instead of returning the value of the default implementation, `MyModule.read_data/0` returns test data that is needed for the test case.

For more details see the `EfxCase`-module.



## License
Copyright © 2024 Bravobike GmbH and Contributors

This project is licensed under the Apache 2.0 license.
