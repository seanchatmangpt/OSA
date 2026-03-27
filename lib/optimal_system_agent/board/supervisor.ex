defmodule OptimalSystemAgent.Board.Supervisor do
  @moduledoc """
  Board Intelligence supervision tree.

  Restart strategy: :rest_for_one

  Ordering of children matters:
    1. Auth        — key loading and crypto operations
    2. BriefingGenerator — queries Oxigraph, generates briefing text
    3. HealingBridge     — bridges conformance deviations to healing agents
    4. Delivery    — encrypts and pushes briefings to board chair
    5. ConwayLittleMonitor — Conway + Little's Law structural monitoring
    6. DecisionRecorder   — records board chair decisions, closes the Conway feedback loop

  With :rest_for_one: if Auth crashes, BriefingGenerator, HealingBridge, and
  Delivery are also restarted (they depend on Auth for encryption). A crash in
  BriefingGenerator restarts HealingBridge and Delivery but not Auth. A crash
  in Delivery only restarts Delivery.

  CRITICAL: This supervisor starts at application boot and CANNOT be stopped
  via any HTTP endpoint or admin command. It is rooted in the main application
  supervisor as a :permanent child. No mix task, no HTTP handler, no IEx
  command should be able to stop this supervisor.

  The board chair is the only human who can ever decrypt a briefing. The system
  holds only the public key. There is no admin backdoor.
  """

  use Supervisor

  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Board.Supervisor] Starting — single-principal board intelligence tree")

    # Auth is a pure stateless module (no GenServer process needed).
    # It is called directly by BriefingGenerator and Delivery for crypto operations.
    # The remaining three children are OTP processes supervised with :rest_for_one:
    #   - BriefingGenerator crash → HealingBridge and Delivery restart too
    #   - HealingBridge crash → Delivery restarts too
    #   - Delivery crash → only Delivery restarts
    children = [
      # permanent: briefing generation must always be available
      %{
        id: OptimalSystemAgent.Board.BriefingGenerator,
        start: {OptimalSystemAgent.Board.BriefingGenerator, :start_link, [[]]},
        restart: :permanent,
        type: :worker
      },

      # permanent: healing bridge must always be available
      %{
        id: OptimalSystemAgent.Board.HealingBridge,
        start: {OptimalSystemAgent.Board.HealingBridge, :start_link, [[]]},
        restart: :permanent,
        type: :worker
      },

      # permanent: push delivery must always be available
      %{
        id: OptimalSystemAgent.Board.Delivery,
        start: {OptimalSystemAgent.Board.Delivery, :start_link, [[]]},
        restart: :permanent,
        type: :worker
      },

      # permanent: Conway's Law + Little's Law monitor must always be available
      %{
        id: OptimalSystemAgent.Board.ConwayLittleMonitor,
        start: {OptimalSystemAgent.Board.ConwayLittleMonitor, :start_link, [[]]},
        restart: :permanent,
        type: :worker
      },

      # permanent: board chair decision recorder — closes the Conway feedback loop
      %{
        id: OptimalSystemAgent.Board.DecisionRecorder,
        start: {OptimalSystemAgent.Board.DecisionRecorder, :start_link, [[]]},
        restart: :permanent,
        type: :worker
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
