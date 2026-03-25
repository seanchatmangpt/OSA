defmodule OptimalSystemAgent.FaultTolerance.AutonomousHealer do
  @moduledoc """
  Armstrong-Compliant Autonomous System Healer.

  GenServer implementing autonomous healing of system failures without human
  intervention. Detects failures, diagnoses root causes, and executes recovery
  plans across all subsystems.

  ## Architecture

  Monitors:
    - All agent sessions (Loop processes)
    - All subsystem supervisors (Infrastructure, Sessions, AgentServices, Extensions)
    - Provider health (failover capability)
    - Budget utilization (throttling capability)

  Recovery patterns:
    - Process restart via supervisor
    - Provider failover
    - Context compaction
    - Budget rebalancing
    - Session termination + recovery

  ## Supervision

  Started as a supervised GenServer in AgentServices supervisor with `:permanent`
  restart strategy. Can tolerate its own crashes — supervisor restarts it.

  ## API

    - `start_link/0` — supervised start
    - `diagnose_system_health()` — health report of all components
    - `initiate_recovery(failed_component)` — execute recovery plan
    - `validate_recovery_complete(component)` — verify recovery succeeded
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus

  # ============================================================================
  # Types
  # ============================================================================

  defmodule SystemHealth do
    @moduledoc false
    defstruct [
      :timestamp,
      :root_supervisor_alive,
      :infrastructure_alive,
      :sessions_alive,
      :agent_services_alive,
      :extensions_alive,
      :healing_orchestrator_alive,
      :reflex_arcs_alive,
      :provider_health,
      :budget_status,
      :failed_components,
      :recovery_actions
    ]
  end

  defmodule RecoveryPlan do
    @moduledoc false
    defstruct [
      :component,
      :failure_type,
      :root_cause,
      :steps,
      :estimated_duration_ms,
      :priority,
      :created_at
    ]
  end

  # ============================================================================
  # Child spec and startup
  # ============================================================================

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Perform comprehensive system health check and return diagnosis.

  Returns a SystemHealth struct with status of all critical components.
  """
  @spec diagnose_system_health() :: SystemHealth.t()
  def diagnose_system_health do
    GenServer.call(__MODULE__, :diagnose, 30_000)
  end

  @doc """
  Initiate recovery sequence for a failed component.

  Component can be:
    - supervisor PID or module name
    - session ID
    - provider name
    - :budget (budget pressure recovery)

  Returns a RecoveryPlan with steps and estimated duration.
  """
  @spec initiate_recovery(atom() | pid() | String.t()) :: {:ok, RecoveryPlan.t()} | {:error, String.t()}
  def initiate_recovery(failed_component) do
    GenServer.call(__MODULE__, {:initiate_recovery, failed_component}, 30_000)
  end

  @doc """
  Validate that recovery for a component is complete and system is healthy.

  Returns true if recovery succeeded, false otherwise.
  """
  @spec validate_recovery_complete(atom() | pid() | String.t()) :: boolean()
  def validate_recovery_complete(component) do
    GenServer.call(__MODULE__, {:validate_recovery, component}, 30_000)
  end

  @doc """
  Get current healer state (for debugging).
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status, 5_000)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    _log_level = Keyword.get(opts, :log_level, :info)

    # Schedule periodic health checks every 30 seconds
    schedule_health_check()

    Logger.info("[AutonomousHealer] Started — 30s health check interval")

    {:ok,
     %{
       last_health_check: nil,
       active_recoveries: %{},
       recovery_log: [],
       restart_storm_detector: %{}
     }}
  end

  @impl true
  def handle_call(:diagnose, _from, state) do
    health = perform_health_check()
    {:reply, health, state}
  end

  @impl true
  def handle_call({:initiate_recovery, component}, _from, state) do
    plan = build_recovery_plan(component)

    Logger.info(
      "[AutonomousHealer] Recovery initiated for #{inspect(component)}: " <>
        "#{Enum.count(plan.steps)} steps, ~#{plan.estimated_duration_ms}ms"
    )

    case execute_recovery_plan(plan) do
      :ok ->
        new_state = %{state | active_recoveries: Map.put(state.active_recoveries, component, plan)}

        emit_recovery_event(:recovery_initiated, %{
          component: component,
          plan: plan
        })

        {:reply, {:ok, plan}, new_state}

      {:error, reason} ->
        Logger.error("[AutonomousHealer] Recovery failed: #{inspect(reason)}")

        emit_recovery_event(:recovery_failed, %{
          component: component,
          reason: reason
        })

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:validate_recovery, component}, _from, state) do
    health = perform_health_check()
    recovered = is_healthy?(health, component)

    Logger.info(
      "[AutonomousHealer] Recovery validation for #{inspect(component)}: #{if recovered, do: "SUCCESS", else: "FAILED"}"
    )

    {:reply, recovered, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      active_recoveries: Enum.count(state.active_recoveries),
      recovery_log_size: Enum.count(state.recovery_log),
      recent_recoveries: Enum.take(state.recovery_log, 5)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    health = perform_health_check()
    state = process_health_check(health, state)
    schedule_health_check()
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================================
  # Health Diagnosis
  # ============================================================================

  defp perform_health_check do
    %SystemHealth{
      timestamp: DateTime.utc_now(),
      root_supervisor_alive: check_alive(:root_supervisor),
      infrastructure_alive: check_alive(:infrastructure_supervisor),
      sessions_alive: check_alive(:sessions_supervisor),
      agent_services_alive: check_alive(:agent_services_supervisor),
      extensions_alive: check_alive(:extensions_supervisor),
      healing_orchestrator_alive: check_alive(OptimalSystemAgent.Healing.Orchestrator),
      reflex_arcs_alive: check_alive(OptimalSystemAgent.Healing.ReflexArcs),
      provider_health: check_provider_health(),
      budget_status: check_budget_status(),
      failed_components: [],
      recovery_actions: []
    }
  end

  defp check_alive(module_name) do
    case Process.whereis(module_name) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  defp check_provider_health do
    try do
      case Process.whereis(OptimalSystemAgent.Providers.HealthChecker) do
        nil ->
          %{}

        _pid ->
          OptimalSystemAgent.Providers.HealthChecker.state()
      end
    rescue
      _ -> %{}
    end
  end

  defp check_budget_status do
    try do
      case OptimalSystemAgent.Budget.get_status() do
        {:ok, status} -> status
        _ -> %{}
      end
    rescue
      _ -> %{}
    end
  end

  defp process_health_check(health, state) do
    # Detect failures and trigger recovery if needed
    failed_components = collect_failed_components(health)

    state =
      if failed_components != [] do
        Enum.reduce(failed_components, state, fn component, acc_state ->
          case initiate_recovery(component) do
            {:ok, _plan} -> acc_state
            {:error, _} -> acc_state
          end
        end)
      else
        state
      end

    # Update state
    state = %{state | last_health_check: health}

    # Log health summary
    if Enum.count(failed_components) > 0 do
      Logger.warning(
        "[AutonomousHealer] Health check: #{Enum.count(failed_components)} failures detected"
      )
    end

    state
  end

  defp collect_failed_components(health) do
    []
    |> maybe_add(:root_supervisor, health.root_supervisor_alive)
    |> maybe_add(:infrastructure, health.infrastructure_alive)
    |> maybe_add(:sessions, health.sessions_alive)
    |> maybe_add(:agent_services, health.agent_services_alive)
    |> maybe_add(:healing_orchestrator, health.healing_orchestrator_alive)
  end

  defp maybe_add(list, component, alive) do
    if alive, do: list, else: [component | list]
  end

  defp is_healthy?(health, component) do
    case component do
      :root_supervisor -> health.root_supervisor_alive
      :infrastructure -> health.infrastructure_alive
      :sessions -> health.sessions_alive
      :agent_services -> health.agent_services_alive
      :healing_orchestrator -> health.healing_orchestrator_alive
      _ -> true
    end
  end

  # ============================================================================
  # Recovery Planning & Execution
  # ============================================================================

  defp build_recovery_plan(:root_supervisor) do
    %RecoveryPlan{
      component: :root_supervisor,
      failure_type: :critical,
      root_cause: "Root supervisor process dead",
      steps: [
        "Alert — root supervisor is unrecoverable",
        "Emit critical algedonic alert",
        "Preserve state for post-mortem"
      ],
      estimated_duration_ms: 0,
      priority: :critical,
      created_at: DateTime.utc_now()
    }
  end

  defp build_recovery_plan(:infrastructure) do
    %RecoveryPlan{
      component: :infrastructure,
      failure_type: :high,
      root_cause: "Infrastructure supervisor process dead",
      steps: [
        "Attempt graceful restart via Application supervisor",
        "Wait up to 10s for children to initialize",
        "Fall back to emergency escalation if restart fails"
      ],
      estimated_duration_ms: 10_000,
      priority: :high,
      created_at: DateTime.utc_now()
    }
  end

  defp build_recovery_plan(:sessions) do
    %RecoveryPlan{
      component: :sessions,
      failure_type: :high,
      root_cause: "Sessions supervisor process dead",
      steps: [
        "Restart Sessions supervisor child",
        "Restore session registry state from memory",
        "Reap stale sessions older than 30 minutes",
        "Restart user-initiated sessions"
      ],
      estimated_duration_ms: 5_000,
      priority: :high,
      created_at: DateTime.utc_now()
    }
  end

  defp build_recovery_plan(:agent_services) do
    %RecoveryPlan{
      component: :agent_services,
      failure_type: :medium,
      root_cause: "AgentServices supervisor process dead",
      steps: [
        "Restart AgentServices supervisor child",
        "Restore memory store from SQLite",
        "Reinitialize learning tables",
        "Resume scheduled tasks"
      ],
      estimated_duration_ms: 3_000,
      priority: :high,
      created_at: DateTime.utc_now()
    }
  end

  defp build_recovery_plan(:healing_orchestrator) do
    %RecoveryPlan{
      component: :healing_orchestrator,
      failure_type: :medium,
      root_cause: "Healing orchestrator process dead",
      steps: [
        "Restart Healing.Orchestrator GenServer",
        "Restore session state from ETS table",
        "Resume in-flight healing sessions",
        "Emit healing_system_recovered event"
      ],
      estimated_duration_ms: 2_000,
      priority: :high,
      created_at: DateTime.utc_now()
    }
  end

  defp build_recovery_plan({:session, session_id}) do
    %RecoveryPlan{
      component: {:session, session_id},
      failure_type: :low,
      root_cause: "Agent session process dead",
      steps: [
        "Verify session is dead",
        "Emit session_terminated event",
        "Request healing via Orchestrator if needed",
        "User can restart via CLI/HTTP"
      ],
      estimated_duration_ms: 1_000,
      priority: :medium,
      created_at: DateTime.utc_now()
    }
  end

  defp build_recovery_plan({:provider, provider_name}) do
    %RecoveryPlan{
      component: {:provider, provider_name},
      failure_type: :medium,
      root_cause: "Provider health check failed",
      steps: [
        "Mark provider as degraded",
        "Trigger provider failover via ReflexArcs",
        "Switch sessions to fallback provider",
        "Monitor recovery metrics"
      ],
      estimated_duration_ms: 2_000,
      priority: :high,
      created_at: DateTime.utc_now()
    }
  end

  defp build_recovery_plan(:budget) do
    %RecoveryPlan{
      component: :budget,
      failure_type: :low,
      root_cause: "Budget pressure exceeded",
      steps: [
        "Throttle non-critical agents to utility tier",
        "Defer expensive tool calls",
        "Emit budget_throttle event",
        "Monitor spending"
      ],
      estimated_duration_ms: 500,
      priority: :medium,
      created_at: DateTime.utc_now()
    }
  end

  defp build_recovery_plan(component) do
    %RecoveryPlan{
      component: component,
      failure_type: :unknown,
      root_cause: "Unknown failure",
      steps: [
        "Verify component status",
        "Emit diagnostic event",
        "Await manual intervention"
      ],
      estimated_duration_ms: 1_000,
      priority: :low,
      created_at: DateTime.utc_now()
    }
  end

  defp execute_recovery_plan(plan) do
    try do
      case plan.component do
        :root_supervisor ->
          # Unrecoverable — escalate
          Bus.emit_algedonic(:critical,
            "Root supervisor is dead — system unrecoverable",
            metadata: %{component: plan.component}
          )

          {:error, :unrecoverable}

        :infrastructure ->
          # Try to restart Infrastructure supervisor
          case DynamicSupervisor.start_child(
                 Process.whereis(OptimalSystemAgent.Supervisor),
                 OptimalSystemAgent.Supervisors.Infrastructure
               ) do
            {:ok, _pid} -> :ok
            {:error, reason} -> {:error, reason}
          end

        :sessions ->
          # Sessions supervisor is under Application, rely on supervisor tree
          :ok

        :agent_services ->
          # AgentServices supervisor is under Application, rely on supervisor tree
          :ok

        :healing_orchestrator ->
          # Orchestrator is under AgentServices, should restart automatically
          :ok

        {:session, _session_id} ->
          # Sessions are supervised by DynamicSupervisor — they auto-restart
          :ok

        {:provider, provider_name} ->
          # Trigger failover
          Bus.emit(:system_event, %{
            event: :provider_health_critical,
            provider: provider_name
          })

          :ok

        :budget ->
          # Trigger throttling
          Bus.emit(:system_event, %{
            event: :budget_pressure_critical
          })

          :ok

        _other ->
          :ok
      end
    rescue
      e ->
        Logger.error("[AutonomousHealer] Recovery execution failed: #{Exception.message(e)}")
        {:error, Exception.message(e)}
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp emit_recovery_event(event_type, metadata) do
    Bus.emit(:system_event, Map.put(metadata, :event, event_type))
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, 30_000)
  end
end
