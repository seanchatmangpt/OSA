defmodule OptimalSystemAgent.Agent.AutonomyWiring do
  @moduledoc """
  Wires bus events to autonomous actions at startup.

  Closes 3 gaps that left the system emitting events nobody acted on:

  Gap 1 — Bus→Trigger bridge
    TRIGGERS.json triggers have an `event` field but the Scheduler never
    subscribed to the bus. This handler routes matching system_events to
    `Scheduler.fire_trigger/2` so internal events can activate triggers
    without going through an HTTP webhook.

  Gap 2 — ProactiveMonitor dead-letter fix
    ProactiveMonitor emits :proactive_alerts but nothing dispatched an agent
    to act on them. This handler dispatches a Loop.process_message for the
    highest-priority alert so the system can self-heal.

  Gap 3 — Learning skill candidate auto-creation
    Learning.Engine emits :learning_skill_candidates when a pattern repeats
    5+ times. This handler calls Orchestrator.create_skill/4 for each
    candidate so OSA can grow its own tool library at runtime.
  """
  require Logger

  alias OptimalSystemAgent.Events.Bus
  alias OptimalSystemAgent.Agent.{Loop, Scheduler}
  alias OptimalSystemAgent.Agent.Orchestrator

  @doc "Register all autonomy bus bridges. Called once from Application.start/2."
  def setup do
    wire_trigger_bridge()
    wire_proactive_alerts()
    wire_skill_generation()
    Logger.info("[AutonomyWiring] 3 bus bridges active (triggers, proactive alerts, skill generation)")
    :ok
  end

  # ── Gap 1: Bus → Trigger bridge ──────────────────────────────────────

  defp wire_trigger_bridge do
    Bus.register_handler(:system_event, fn payload ->
      with %{event: event} when is_atom(event) <- payload do
        event_str = to_string(event)

        try do
          triggers = Scheduler.list_triggers()

          Enum.each(triggers, fn t ->
            if t["event"] == event_str and t["enabled"] != false do
              Scheduler.fire_trigger(t["id"], payload)
            end
          end)
        catch
          :exit, _ -> :ok
        end
      end

      :ok
    end)
  end

  # ── Gap 2: ProactiveMonitor alert dispatch ────────────────────────────

  defp wire_proactive_alerts do
    Bus.register_handler(:system_event, fn payload ->
      case payload do
        %{event: :proactive_alerts, alerts: [first | _rest]} ->
          message = Map.get(first, :message) || Map.get(first, "message") || inspect(first)
          session_id = "proactive_#{:erlang.unique_integer([:positive])}"
          task = "Proactive system alert: #{message}. Investigate and fix if possible."

          Task.start(fn ->
            Loop.process_message(session_id, task, [])
          end)

        _ ->
          :ok
      end

      :ok
    end)
  end

  # ── Gap 3: Learning skill candidate auto-creation ────────────────────

  defp wire_skill_generation do
    Bus.register_handler(:system_event, fn payload ->
      case payload do
        %{event: :learning_skill_candidates, candidates: candidates}
        when is_list(candidates) and candidates != [] ->
          Enum.each(candidates, fn pattern_key ->
            name =
              pattern_key
              |> String.replace(~r/[^a-z0-9_]/, "_")
              |> String.trim("_")
              |> String.slice(0, 40)

            desc = "Auto-generated skill for frequent pattern: #{pattern_key}"
            instructions = "Handle tasks matching the pattern: #{pattern_key}"

            Task.start(fn ->
              case Orchestrator.create_skill(name, desc, instructions, ["file_read", "memory_save"]) do
                {:ok, path} ->
                  Logger.info("[AutonomyWiring] Auto-created skill #{name} at #{path}")

                {:error, reason} ->
                  Logger.warning("[AutonomyWiring] Skill creation failed for #{name}: #{inspect(reason)}")
              end
            end)
          end)

        _ ->
          :ok
      end

      :ok
    end)
  end
end
