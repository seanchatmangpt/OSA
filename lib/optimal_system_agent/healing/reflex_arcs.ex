defmodule OptimalSystemAgent.Healing.ReflexArcs do
  @moduledoc """
  Autonomic Nervous System -- fast, pre-programmed automatic responses to common
  failure patterns. Like the human autonomic nervous system, these reflex arcs
  fire without reasoning: no LLM call, no deliberation, just instant reaction.

  ## Reflex Arcs

  1. **Provider Failover** -- 3 consecutive provider failures triggers automatic
     failover to the next available provider in the fallback chain.

  2. **Context Pressure Relief** -- context utilization exceeding 85% triggers
     immediate compaction via `Agent.Compactor.maybe_compact/1`.

  3. **Budget Throttle** -- daily spend exceeding 80% of budget downgrades all
     non-critical agents to utility tier.

  4. **Doom Loop Break** -- doom loop detection kills the stuck session and
     creates a new session with modified context.

  5. **Stale Session Reaper** -- every 60 seconds, reaps sessions idle for
     more than 30 minutes.

  ## Integration

  Subscribes to the OSA event bus for `:system_event` and `:tool_result` events.
  Each reflex is idempotent and has a configurable cooldown to prevent firing
  twice within its cooldown window.

  ## Events Emitted

  All reflex arcs emit `:system_event` events with the `source` field set to
  `"healing.reflex_arcs"` and a `:reflex` key identifying the arc.

      {:reflex, :provider_failover, %{from: old_provider, to: new_provider}}
      {:reflex, :context_relief, %{session_id: sid, utilization: pct}}
      {:reflex, :budget_throttle, %{spend: amount, budget: budget}}
      {:reflex, :doom_loop_break, %{session_id: sid, tool: tool_name}}
      {:reflex, :session_reaped, %{session_id: sid, idle_minutes: min}}

  ## Innovation 5 -- Autonomic Nervous System (Vision 2030)
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus
  alias OptimalSystemAgent.Providers.HealthChecker
  alias OptimalSystemAgent.Agent.Compactor

  # -- Cooldowns (milliseconds) --
  @provider_failover_cooldown 30_000
  @context_relief_cooldown 15_000
  @budget_throttle_cooldown 60_000
  @doom_loop_break_cooldown 10_000
  @session_reaper_interval 60_000
  @stale_session_threshold_ms 30 * 60 * 1_000

  # -- Thresholds --
  @provider_failure_threshold 3
  @budget_pressure_threshold 0.80

  # -- Critical agents that should never be throttled --
  @critical_agents ~w(health-monitor healing)

  # -- State --

  defstruct reflex_log: [],
            cooldowns: %{},
            provider_failures: %{}

  # -- Child spec --

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  # -- Client API --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Return the reflex log -- list of recent reflex arc firings."
  @spec log() :: [map()]
  def log do
    GenServer.call(__MODULE__, :log, 15000)
  end

  @doc "Return current state including cooldowns and provider failure counts."
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status, 15000)
  end

  @doc "Manually trigger a session reaper sweep (useful in tests)."
  @spec reap_sessions() :: :ok
  def reap_sessions do
    GenServer.cast(__MODULE__, :reap_sessions)
  end

  # -- GenServer Callbacks --

  @impl true
  def init(_opts) do
    # Subscribe to system events for budget warnings and doom loop detection
    Bus.register_handler(:system_event, &handle_system_event/1)
    Bus.register_handler(:tool_result, &handle_tool_result/1)

    # Start the stale session reaper timer
    schedule_reaper()

    Logger.info("[Healing.ReflexArcs] Started -- 5 reflex arcs armed")

    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:log, _from, state) do
    {:reply, state.reflex_log, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      reflex_log: state.reflex_log,
      cooldowns: state.cooldowns,
      provider_failures: state.provider_failures
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:reap_sessions, state) do
    state = run_session_reaper(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:doom_loop_break, session_id, tool_name}, state) do
    state = maybe_fire_reflex(state, :doom_loop_break, @doom_loop_break_cooldown, fn ->
      execute_doom_loop_break(session_id, tool_name)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:check_budget_pressure, state) do
    state = maybe_fire_reflex(state, :budget_throttle, @budget_throttle_cooldown, fn ->
      execute_budget_throttle()
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:check_provider_health, state) do
    state = check_provider_failures(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:context_pressure, session_id, utilization}, state) do
    state = maybe_fire_reflex(state, :context_relief, @context_relief_cooldown, fn ->
      execute_context_relief(session_id, utilization)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:reap_sessions, state) do
    state = run_session_reaper(state)
    schedule_reaper()
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # -- Event Bus Handlers --

  # These are called from Bus handler tasks -- they must be self-contained and
  # never block. They send a cast to this GenServer to do the actual work.

  defp handle_system_event(payload) do
    event = Map.get(payload, :event) || Map.get(payload, :data, %{}) |> Map.get(:event)

    case event do
      :doom_loop_detected ->
        session_id = payload[:session_id] || payload[:data][:session_id]
        tool_name = payload[:tool_name] || payload[:data][:tool_name]

        if session_id do
          GenServer.cast(__MODULE__, {:doom_loop_break, session_id, tool_name})
        end

      :budget_warning ->
        handle_budget_event(payload)

      :budget_exceeded ->
        handle_budget_event(payload)

      :cost_recorded ->
        # Check budget pressure on every cost recording
        GenServer.cast(__MODULE__, :check_budget_pressure)

      _ ->
        :ok
    end
  end

  defp handle_tool_result(_payload) do
    # Tool results can contribute to provider failure tracking.
    # The HealthChecker already records failures; we poll its state.
    GenServer.cast(__MODULE__, :check_provider_health)
  end

  defp handle_budget_event(payload) do
    type = payload[:type] || payload[:data][:type]

    if type == :daily do
      GenServer.cast(__MODULE__, :check_budget_pressure)
    end
  end

  # -- Reflex Arc Implementations --

  # ---------------------------------------------------------------------------
  # Reflex Arc 1: Provider Failover
  # ---------------------------------------------------------------------------

  defp check_provider_failures(state) do
    try do
      health_state = HealthChecker.state()
      current_provider = Application.get_env(:optimal_system_agent, :default_provider)

      Enum.reduce(health_state, state, fn {provider, entry}, acc_state ->
        failures = Map.get(entry, :consecutive_failures, 0)
        circuit = Map.get(entry, :circuit, :closed)

        # Track failures
        acc_state = put_in(
          acc_state.provider_failures,
          [provider],
          failures
        )

        # Check if current default provider has tripped the threshold
        if provider == current_provider and
             failures >= @provider_failure_threshold and
             circuit == :open do
          maybe_fire_reflex(acc_state, :provider_failover, @provider_failover_cooldown, fn ->
            execute_provider_failover(provider)
          end)
        else
          acc_state
        end
      end)
    rescue
      e ->
        Logger.warning("[Healing.ReflexArcs] Provider health check failed: #{Exception.message(e)}")
        state
    end
  end

  defp execute_provider_failover(failed_provider) do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    :otel_tracer.with_span(tracer, "healing.reflex_provider_failover", %{
      "failed_provider" => to_string(failed_provider)
    }, fn span_ctx ->
      fallback_chain =
        Application.get_env(:optimal_system_agent, :fallback_chain, [])

      # Find the next available provider after the failed one
      new_provider =
        fallback_chain
        |> Enum.drop_while(&(&1 != failed_provider))
        |> Enum.drop(1)
        |> Enum.find(&HealthChecker.is_available?/1)

      if new_provider do
        Logger.warning(
          "[ReflexArc] Provider failover: #{failed_provider} -> #{new_provider} " <>
            "(#{@provider_failure_threshold} consecutive failures)"
        )

        :otel_span.set_attributes(span_ctx, %{"new_provider" => to_string(new_provider)})

        Bus.emit(:system_event, %{
          event: :reflex,
          reflex: :provider_failover,
          from: failed_provider,
          to: new_provider
        },
        source: "healing.reflex_arcs")

        %{from: failed_provider, to: new_provider}
      else
        Logger.warning(
          "[ReflexArc] Provider failover triggered for #{failed_provider} but no fallback available"
        )

        :otel_span.set_attributes(span_ctx, %{"status" => "no_fallback_available"})
        nil
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Reflex Arc 2: Context Pressure Relief
  # ---------------------------------------------------------------------------

  defp execute_context_relief(session_id, utilization) do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    :otel_tracer.with_span(tracer, "healing.reflex_context_relief", %{
      "session_id" => session_id,
      "utilization_pct" => Float.round(utilization * 100, 1)
    }, fn span_ctx ->
      Logger.info(
        "[ReflexArc] Context pressure relief triggered for session #{session_id} " <>
          "(utilization: #{Float.round(utilization * 100, 1)}%)"
      )

      try do
        # Try to get session messages and compact them
        case Registry.lookup(OptimalSystemAgent.SessionRegistry, session_id) do
          [{pid, _}] ->
            if function_export?(pid, :messages, 0) do
              messages = GenServer.call(pid, :messages, 5_000)

              if is_list(messages) and length(messages) > 0 do
                Compactor.maybe_compact(messages)

                Logger.info(
                  "[ReflexArc] Context compaction completed for session #{session_id}"
                )

                :otel_span.set_attributes(span_ctx, %{"compaction_status" => "completed"})
              end
            else
              Logger.debug(
                "[ReflexArc] Session #{session_id} does not expose messages/0, " <>
                  "emitting event for downstream handling"
              )

              :otel_span.set_attributes(span_ctx, %{"compaction_status" => "emitted_event"})
            end

          [] ->
            Logger.debug(
              "[ReflexArc] Session #{session_id} not found in registry, " <>
                "emitting event for downstream handling"
            )

            :otel_span.set_attributes(span_ctx, %{"compaction_status" => "session_not_found"})
        end
      rescue
        e ->
          Logger.warning(
            "[ReflexArc] Context relief failed for session #{session_id}: " <>
              "#{Exception.message(e)}"
          )

          :otel_span.set_attributes(span_ctx, %{"error" => Exception.message(e)})
      end

      Bus.emit(:system_event, %{
        event: :reflex,
        reflex: :context_relief,
        session_id: session_id,
        utilization: Float.round(utilization * 100, 1)
      },
      source: "healing.reflex_arcs")

      %{session_id: session_id, utilization: Float.round(utilization * 100, 1)}
    end)
  end

  # ---------------------------------------------------------------------------
  # Reflex Arc 3: Budget Throttle
  # ---------------------------------------------------------------------------

  defp execute_budget_throttle do
    try do
      case OptimalSystemAgent.Budget.check_budget() do
        {:ok, %{daily_remaining: _remaining}} ->
          case OptimalSystemAgent.Budget.get_status() do
            {:ok, status} ->
              daily_spent = Map.get(status, :daily_spent, 0.0)
              daily_limit = Map.get(status, :daily_limit, 50.0)
              utilization = daily_spent / daily_limit

              if utilization >= @budget_pressure_threshold do
                Logger.warning(
                  "[ReflexArc] Budget throttle triggered: " <>
                    "$#{Float.round(daily_spent, 2)} / $#{daily_limit} " <>
                    "(#{Float.round(utilization * 100, 1)}%)"
                )

                # Switch non-critical agents to utility tier
                throttle_non_critical_agents()

                Bus.emit(:system_event, %{
                  event: :reflex,
                  reflex: :budget_throttle,
                  spend: daily_spent,
                  budget: daily_limit,
                  utilization: Float.round(utilization * 100, 1)
                },
                source: "healing.reflex_arcs")

                %{spend: daily_spent, budget: daily_limit}
              else
                nil
              end

            _ ->
              nil
          end

        {:over_limit, _period} ->
          # Already over limit -- throttle everything
          Logger.warning("[ReflexArc] Budget already over limit, throttling all agents")
          throttle_non_critical_agents()

          Bus.emit_algedonic(:high,
            "Budget over limit -- all non-critical agents throttled to utility tier",
            metadata: %{source: "healing.reflex_arcs"})

          nil
      end
    rescue
      e ->
        Logger.warning("[ReflexArc] Budget throttle check failed: #{Exception.message(e)}")
        nil
    end
  end

  defp throttle_non_critical_agents do
    # Notify the agent registry and team hierarchy about throttling.
    # The actual tier switching is handled by the team supervisor / agent loop.
    Bus.emit(:system_event, %{
      event: :agent_tier_override,
      target_tier: :utility,
      excluded_agents: @critical_agents,
      reason: :budget_throttle
    },
    source: "healing.reflex_arcs")

    Logger.info(
      "[ReflexArc] Non-critical agents throttled to utility tier " <>
        "(excluded: #{Enum.join(@critical_agents, ", ")})"
    )
  end

  # ---------------------------------------------------------------------------
  # Reflex Arc 4: Doom Loop Break
  # ---------------------------------------------------------------------------

  defp execute_doom_loop_break(session_id, tool_name) do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    :otel_tracer.with_span(tracer, "healing.reflex_doom_loop_break", %{
      "session_id" => session_id,
      "tool_name" => tool_name || "unknown"
    }, fn span_ctx ->
      Logger.warning(
        "[ReflexArc] Doom loop break triggered for session #{session_id} " <>
          "(tool: #{tool_name || "unknown"})"
      )

      try do
        # Step 1: Kill the stuck session
        case Registry.lookup(OptimalSystemAgent.SessionRegistry, session_id) do
          [{pid, _}] ->
            if Process.alive?(pid) do
              Logger.info("[ReflexArc] Terminating stuck session #{session_id} (pid: #{inspect(pid)})")

              :otel_span.set_attributes(span_ctx, %{"session_terminated" => true})

              # Graceful stop with reason so supervisor doesn't immediately restart
              GenServer.stop(pid, :doom_loop_break)

              Logger.info("[ReflexArc] Session #{session_id} terminated")
            end

          [] ->
            Logger.debug("[ReflexArc] Session #{session_id} already gone, creating fresh session")
            :otel_span.set_attributes(span_ctx, %{"session_already_gone" => true})
        end

        # Step 2: Create a new session with modified context
        create_recovery_session(session_id, tool_name)
      rescue
        e ->
          Logger.error(
            "[ReflexArc] Doom loop break failed for #{session_id}: #{Exception.message(e)}"
          )

          :otel_span.set_attributes(span_ctx, %{"error" => Exception.message(e)})
      end

      Bus.emit(:system_event, %{
        event: :reflex,
        reflex: :doom_loop_break,
        session_id: session_id,
        tool: tool_name || "unknown"
      },
      source: "healing.reflex_arcs")

      %{session_id: session_id, tool: tool_name || "unknown"}
    end)
  end

  defp create_recovery_session(original_session_id, tool_name) do
    # Generate a new session ID linked to the original
    new_session_id = "#{original_session_id}_recovery_#{:erlang.unique_integer([:positive])}"

    Logger.info(
      "[ReflexArc] Creating recovery session #{new_session_id} " <>
        "from failed session #{original_session_id}"
    )

    # The recovery context is injected via an event so the channel/session
    # layer can pick it up and create the session with the right context.
    Bus.emit(:system_event, %{
      event: :session_recovery_requested,
      original_session_id: original_session_id,
      new_session_id: new_session_id,
      tool_name: tool_name,
      recovery_context:
        "Previous attempt in session #{original_session_id} failed due to " <>
          "a doom loop on tool '#{tool_name || "unknown"}'. " <>
          "Try a different approach -- avoid repeating the same tool call pattern."
    },
    source: "healing.reflex_arcs",
    session_id: new_session_id)

    new_session_id
  end

  # ---------------------------------------------------------------------------
  # Reflex Arc 5: Stale Session Reaper
  # ---------------------------------------------------------------------------

  defp run_session_reaper(state) do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    :otel_tracer.with_span(tracer, "healing.reflex_session_reaper", %{}, fn span_ctx ->
      now = System.monotonic_time(:millisecond)

      try do
        sessions = Registry.select(OptimalSystemAgent.SessionRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

        {final_state, reaped_count} =
          Enum.reduce(sessions, {state, 0}, fn session_id, {acc_state, count} ->
            case Registry.lookup(OptimalSystemAgent.SessionRegistry, session_id) do
              [{pid, _}] ->
                idle_ms = session_idle_time(pid, now)

                if idle_ms > @stale_session_threshold_ms do
                  idle_minutes = Float.round(idle_ms / 60_000, 1)

                  Logger.info(
                    "[ReflexArc] Reaping stale session #{session_id} " <>
                      "(idle: #{idle_minutes} minutes)"
                  )

                  if Process.alive?(pid) do
                    GenServer.stop(pid, :stale_session_reaped)
                  end

                  # Emit reaped event
                  Bus.emit(:system_event, %{
                    event: :reflex,
                    reflex: :session_reaped,
                    session_id: session_id,
                    idle_minutes: idle_minutes
                  },
                  source: "healing.reflex_arcs")

                  # Log the reflex
                  entry = %{
                    reflex: :session_reaped,
                    session_id: session_id,
                    idle_minutes: idle_minutes,
                    fired_at: DateTime.utc_now()
                  }

                  acc_state = log_reflex(acc_state, entry)
                  {acc_state, count + 1}
                else
                  {acc_state, count}
                end

              [] ->
                {acc_state, count}
            end
          end)

        if reaped_count > 0 do
          Logger.info("[ReflexArc] Session reaper: #{reaped_count} sessions reaped")
          :otel_span.set_attributes(span_ctx, %{"sessions_reaped" => reaped_count})
        end

        final_state
      rescue
        e ->
          Logger.warning("[ReflexArc] Session reaper sweep failed: #{Exception.message(e)}")
          :otel_span.set_attributes(span_ctx, %{"error" => Exception.message(e)})
          state
      end
    end)
  end

  # Estimate idle time by querying the session's last activity.
  # Falls back to 0 (never idle) if the session doesn't support idle queries.
  defp session_idle_time(pid, _now) do
    try do
      case GenServer.call(pid, :idle_time_ms, 2_000) do
        ms when is_integer(ms) -> ms
        _ -> 0
      end
    catch
      :exit, _ ->
        # Session doesn't implement idle_time_ms -- assume active
        0
    end
  end

  # -- Cooldown & Logging Helpers --

  defp maybe_fire_reflex(state, reflex_name, cooldown_ms, executor_fn) do
    now = System.monotonic_time(:millisecond)
    last_fired = Map.get(state.cooldowns, reflex_name, 0)

    if now - last_fired >= cooldown_ms do
      result = executor_fn.()

      if result != nil do
        entry = %{
          reflex: reflex_name,
          result: result,
          fired_at: DateTime.utc_now()
        }

        state
        |> log_reflex(entry)
        |> put_in([:cooldowns, reflex_name], now)
      else
        state
      end
    else
      # Still in cooldown
      remaining_s = Float.round((cooldown_ms - (now - last_fired)) / 1_000, 1)
      Logger.debug(
        "[ReflexArc] #{reflex_name} skipped -- cooldown active (#{remaining_s}s remaining)"
      )

      state
    end
  end

  defp log_reflex(state, entry) do
    # Keep last 100 reflex log entries
    updated_log = Enum.take([entry | state.reflex_log], 100)
    %{state | reflex_log: updated_log}
  end

  defp schedule_reaper do
    Process.send_after(self(), :reap_sessions, @session_reaper_interval)
  end

  # Helper to safely check if a process exports a function without calling it
  defp function_export?(pid, fun, arity) do
    case Process.info(pid, :registered_name) do
      {:registered_name, name} when is_atom(name) ->
        function_exported?(name, fun, arity)

      _ ->
        false
    end
  end
end
