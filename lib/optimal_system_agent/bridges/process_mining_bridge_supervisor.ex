defmodule OptimalSystemAgent.Bridges.ProcessMiningBridgeSupervisor do
  @moduledoc """
  Supervisor for the Process Mining Bridge.

  Armstrong Fault Tolerance: every worker has a supervisor. The bridge GenServer
  is supervised with :permanent restart strategy — if it crashes, it restarts
  cleanly with fresh state. No orphan processes.

  Strategy: :one_for_one — the bridge is the only child.
  Max restarts: 5 within 60 seconds. If the bridge crashes more than 5 times
  in a minute, something is fundamentally wrong and the supervisor gives up
  (escalates to parent supervisor).
  """

  use Supervisor

  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[ProcessMiningBridgeSupervisor] Starting — process mining bridge supervision tree")

    children = [
      %{
        id: OptimalSystemAgent.Bridges.ProcessMiningBridge,
        start: {OptimalSystemAgent.Bridges.ProcessMiningBridge, :start_link, [[]]},
        restart: :permanent,
        type: :worker
      }
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 5, max_seconds: 60)
  end
end
