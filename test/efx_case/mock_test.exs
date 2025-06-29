defmodule EfxCase.MockTest do
  use ExUnit.Case

  alias EfxCase.EfxExample
  alias EfxCase.Mock

  describe "make/1" do
    test "creates a new mock" do
      mock = make()

      assert_all_unmocked(mock)

      funs = Enum.map(mock.mocked_funs, fn f -> f.name end)
      assert :get in funs
    end
  end

  describe "add_fun/5" do
    test "adds a function the first time" do
      {:ok, mock} = make() |> add_mock()
      assert Mock.get_fun(mock, :get, 0)
    end

    test "adds a function the second time" do
      {:ok, mock} =
        make() |> add_mock(expected_calls: 3) |> elem(1) |> add_mock(expected_calls: 2)

      assert Mock.get_fun(mock, :get, 0)
    end

    test "returns error if fun arity doesn't match" do
      assert {:error, :function_not_in_mock} = make() |> add_mock(arity: 2)
    end

    test "returns error if fun name doesn't match" do
      assert {:error, :function_not_in_mock} = make() |> add_mock(name: :blub)
    end
  end

  describe "get_fun/3" do
    test "returns a function that was added" do
      {:ok, mock} = make() |> add_mock()
      {:ok, %{impl: fun}} = Mock.get_fun(mock, :get, 0)
      assert fun.() == []
    end

    test "throws if no mocks where found" do
      mock = make()
      assert {:error, :not_found} = Mock.get_fun(mock, :foo, 0)
    end

    test "throws if calls where exhausted" do
      {:ok, mock} = make() |> add_mock(name: :get, expected_calls: 0)
      assert {:error, :exhausted} = Mock.get_fun(mock, :get, 0)
    end

    test "throws if function is unmocked" do
      mock = make()
      assert {:error, :unmocked} = Mock.get_fun(mock, :get, 0)
    end
  end

  describe "get_unsatisfied/1" do
    test "returns unsatisfied funs" do
      {:ok, mock} = make() |> add_mock(expected_calls: 1)
      funs = Mock.get_unsatisfied(mock) |> Enum.map(fn f -> f.name end)
      assert :get in funs
    end

    test "doesn't return fun once satisfied" do
      mock = make() |> add_mock(expected_calls: 1) |> elem(1) |> Mock.inc_called(:get, 0)
      funs = Mock.get_unsatisfied(mock) |> Enum.map(fn f -> f.name end)
      refute :get in funs
    end
  end

  describe "inc_called/1" do
    test "increases calls" do
      mock = make() |> add_mock(expected_calls: 1) |> elem(1) |> Mock.inc_called(:get, 0)
      funs = Mock.get_unsatisfied(mock) |> Enum.map(fn f -> f.name end)
      refute :get in funs
    end
  end

  defp make(), do: Mock.make(EfxExample)

  defp assert_all_unmocked(mock) do
    assert Enum.all?(mock.mocked_funs, fn f -> f.impl == :unmocked end)
  end

  defp add_mock(mock, opts \\ []) do
    name = Keyword.get(opts, :name, :get)
    arity = Keyword.get(opts, :arity, 0)
    impl = Keyword.get(opts, :impl, fn -> [] end)
    expected_calls = Keyword.get(opts, :expected_calls)
    Mock.add_fun(mock, name, arity, impl, expected_calls)
  end
end
