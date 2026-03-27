defmodule OptimalSystemAgent.Yawl.Supervisor do
  @moduledoc """
  Supervisor for the YAWL integration subsystem.

  Supervises:
    * `OptimalSystemAgent.Yawl.Client` — GenServer HTTP client for the YAWL engine.
    * `OptimalSystemAgent.Yawl.EventStream` — SSE consumer emitting OTEL telemetry.

  Uses `:one_for_one` strategy: a crash in either child is isolated and the
  supervisor restarts it without affecting other extensions.
  """

  use Supervisor

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    children = [
      {OptimalSystemAgent.Yawl.Client, []},
      {OptimalSystemAgent.Yawl.EventStream, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
