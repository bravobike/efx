defmodule Efx.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  if Mix.env() == :test do
    defp children, do: [EfxCase.MockState]
  else
    defp children, do: []
  end
end
