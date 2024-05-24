defmodule Efx.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  defp children, do: [EfxCase.MockState]
end
