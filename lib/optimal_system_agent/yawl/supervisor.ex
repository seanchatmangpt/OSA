defmodule OptimalSystemAgent.Yawl.Supervisor do
  @moduledoc """
  Supervisor for the YAWL integration subsystem.

  Currently supervises:
    * `OptimalSystemAgent.Yawl.Client` — GenServer HTTP client for the YAWL engine.

  Uses `:one_for_one` strategy: a crash in the client is isolated and the
  supervisor restarts it without affecting other extensions.
  """

  use Supervisor

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    children = [{OptimalSystemAgent.Yawl.Client, []}]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
