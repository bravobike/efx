defmodule TestAgent do
  use Agent

  def start_link() do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, fn _ -> EfxCase.EfxExample.get() end)
  end
end
