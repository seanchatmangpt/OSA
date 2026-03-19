defmodule OptimalSystemAgent.Supervisors.AgentServices do
  @moduledoc """
  Subsystem supervisor for agent intelligence processes.

  Stripped to the minimal set needed for message/chat: memory, tasks,
  budget, progress, hooks, compactor, cortex, and scheduler.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      OptimalSystemAgent.Memory.Store,
      OptimalSystemAgent.Memory.Learning,
      OptimalSystemAgent.Agent.Memory.Episodic,
      OptimalSystemAgent.Agent.Tasks,
      OptimalSystemAgent.Budget,
      OptimalSystemAgent.Agent.Progress,
      OptimalSystemAgent.Agent.Hooks,
      OptimalSystemAgent.Agent.Scheduler,
      OptimalSystemAgent.Agent.Compactor,
      OptimalSystemAgent.Signal.Persistence
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
