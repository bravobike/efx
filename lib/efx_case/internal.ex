defmodule EfxCase.Internal do
  alias EfxCase.MockState

  def verify_mocks(pid) do
    verify_mocks!(pid)
    :ok
  rescue
    e -> {:error, e}
  end

  def verify_mocks!(pid) do
    MockState.verify_called!(pid)
  end

  def init(pid) do
    Process.put(:mock_pid, pid)
  end
end
