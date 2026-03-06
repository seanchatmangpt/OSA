defmodule OptimalSystemAgent.Tools.Builtins.ScheduleTask do
  @moduledoc """
  Agent self-scheduling — add a one-off or recurring cron job from within a running agent.

  Lets an agent say "re-run me in 6 hours" or "check this every Monday" without
  requiring a human to edit CRONS.json manually. The job is persisted immediately
  so it survives restarts.

  Supports two modes:
    - "once"      — run at a fixed datetime (ISO 8601 or relative like "+2h", "+30m")
    - "recurring" — standard 5-field cron expression ("0 9 * * 1" = every Monday at 09:00)

  Job type is always "agent" — the task text is sent through the normal agent loop.
  """
  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  alias OptimalSystemAgent.Agent.Scheduler

  @impl true
  def name, do: "schedule_task"

  @impl true
  def description do
    "Schedule an agent task to run later. " <>
      "Use 'once' mode with a relative time like '+2h' or '+30m', or 'recurring' mode with a cron expression."
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "task" => %{
          "type" => "string",
          "description" => "The natural-language task to run through the agent loop."
        },
        "mode" => %{
          "type" => "string",
          "enum" => ["once", "recurring"],
          "description" => "'once' for a one-off run, 'recurring' for a repeating cron schedule."
        },
        "when" => %{
          "type" => "string",
          "description" =>
            "For 'once': relative time like '+2h', '+30m', '+1d', or ISO datetime. " <>
              "For 'recurring': 5-field cron expression like '0 9 * * 1' (Mon 09:00)."
        },
        "label" => %{
          "type" => "string",
          "description" => "Optional human-readable label for the job."
        }
      },
      "required" => ["task", "mode", "when"]
    }
  end

  @impl true
  def execute(%{"task" => task, "mode" => mode, "when" => when_str} = args) do
    label = Map.get(args, "label", task |> String.slice(0, 60))

    case build_job(task, mode, when_str, label) do
      {:ok, job} ->
        case Scheduler.add_job(job) do
          {:ok, persisted} ->
            id = persisted["id"] || "?"
            Logger.info("[ScheduleTask] Job #{id} scheduled: #{label}")
            {:ok, "Scheduled: \"#{label}\" (id: #{id}, mode: #{mode}, when: #{when_str})"}

          {:error, reason} ->
            {:error, "Failed to schedule job: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(_args), do: {:error, "Missing required fields: task, mode, when"}

  # ── Job construction ──────────────────────────────────────────────────

  defp build_job(task, "recurring", cron_expr, label) do
    job = %{
      "type" => "agent",
      "task" => task,
      "schedule" => cron_expr,
      "label" => label,
      "enabled" => true
    }

    {:ok, job}
  end

  defp build_job(task, "once", when_str, label) do
    case parse_once_time(when_str) do
      {:ok, dt} ->
        # Convert to a cron expression that fires exactly at this datetime (best-effort for minute precision).
        cron_expr =
          "#{dt.minute} #{dt.hour} #{dt.day} #{dt.month} *"

        job = %{
          "type" => "agent",
          "task" => task,
          "schedule" => cron_expr,
          "label" => label,
          "enabled" => true,
          "run_once" => true,
          "run_at" => DateTime.to_iso8601(dt)
        }

        {:ok, job}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_job(_task, mode, _when, _label),
    do: {:error, "Unknown mode '#{mode}'. Use 'once' or 'recurring'."}

  # ── Time parsing ──────────────────────────────────────────────────────

  defp parse_once_time("+" <> rest) do
    case parse_relative(rest) do
      {:ok, seconds} -> {:ok, DateTime.add(DateTime.utc_now(), seconds, :second)}
      err -> err
    end
  end

  defp parse_once_time(iso_str) do
    case DateTime.from_iso8601(iso_str) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> {:error, "Cannot parse time '#{iso_str}'. Use '+2h', '+30m', '+1d', or ISO 8601."}
    end
  end

  defp parse_relative(str) do
    cond do
      String.ends_with?(str, "m") ->
        case Integer.parse(String.trim_trailing(str, "m")) do
          {n, ""} -> {:ok, n * 60}
          _ -> {:error, "Invalid relative time: +#{str}"}
        end

      String.ends_with?(str, "h") ->
        case Integer.parse(String.trim_trailing(str, "h")) do
          {n, ""} -> {:ok, n * 3600}
          _ -> {:error, "Invalid relative time: +#{str}"}
        end

      String.ends_with?(str, "d") ->
        case Integer.parse(String.trim_trailing(str, "d")) do
          {n, ""} -> {:ok, n * 86_400}
          _ -> {:error, "Invalid relative time: +#{str}"}
        end

      true ->
        {:error, "Unknown unit in '#{str}'. Use m (minutes), h (hours), or d (days)."}
    end
  end
end
