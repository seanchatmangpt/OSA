defmodule OptimalSystemAgent.Yawl.EventStream do
  @moduledoc """
  GenServer that subscribes to the YAWL SSE event stream per case and emits
  `:telemetry` events using Weaver-generated semconv constants.

  ## Telemetry events emitted

  | Event | Measurements | Metadata keys |
  |-------|-------------|---------------|
  | `[:osa, :yawl, :case, :started]` | `%{}` | case_id, spec_uri, instance_id, event_type |
  | `[:osa, :yawl, :case, :completed]` | `%{}` | case_id, event_type |
  | `[:osa, :yawl, :task, :execution]` | `%{token_consumed, token_produced}` | case_id, task_id, event_type, work_item_id |

  All metadata keys are atoms matching `OpenTelemetry.SemConv.Incubating.YawlAttributes`
  function names (e.g. `:"yawl.case.id"`) so consumers can attach them directly to OTEL spans.

  ## Trace correlation

  `case_id` is hashed (SHA-256 first 16 bytes → 32 hex chars) to derive a stable W3C
  `trace_id`. The mapping is stored in the ETS table `:osa_yawl_trace_ids`:

      {case_id :: String.t(), trace_id :: String.t()}

  Agent work item handlers look up `trace_id` to parent their spans under the YAWL case trace.
  """

  use GenServer
  require Logger

  alias OpenTelemetry.SemConv.Incubating.YawlAttributes, as: Attrs

  @ets_table :osa_yawl_trace_ids
  @stream_path "/api/process-mining/events/stream"
  @stream_timeout 300_000

  # ──────────────────────────────────────────────────────────────────────────
  # Public API
  # ──────────────────────────────────────────────────────────────────────────

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Subscribe to the SSE event stream for the given case. Idempotent — calling
  multiple times for the same case_id is safe.
  """
  @spec subscribe(String.t()) :: :ok
  def subscribe(case_id) when is_binary(case_id) do
    GenServer.cast(__MODULE__, {:subscribe, case_id})
  end

  @doc """
  Look up the W3C trace_id derived from a YAWL case_id. Returns `nil` if not known.
  """
  @spec lookup_trace_id(String.t()) :: String.t() | nil
  def lookup_trace_id(case_id) when is_binary(case_id) do
    case :ets.lookup(@ets_table, case_id) do
      [{^case_id, trace_id}] -> trace_id
      [] -> nil
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # GenServer Callbacks
  # ──────────────────────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    table =
      case :ets.whereis(@ets_table) do
        :undefined ->
          :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])

        tid ->
          tid
      end

    {:ok, %{table: table, tasks: %{}}}
  end

  @impl true
  def handle_cast({:subscribe, case_id}, state) do
    if Map.has_key?(state.tasks, case_id) do
      {:noreply, state}
    else
      trace_id = derive_trace_id(case_id)
      :ets.insert(@ets_table, {case_id, trace_id})

      task = Task.Supervisor.async_nolink(
        OptimalSystemAgent.TaskSupervisor,
        fn -> stream_case(case_id) end
      )

      Logger.debug("[EventStream] Subscribed to case #{case_id} → trace_id=#{trace_id}")
      {:noreply, put_in(state, [:tasks, case_id], task)}
    end
  end

  # Task completed normally
  @impl true
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # Task crashed
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.debug("[EventStream] Stream task exited: #{inspect(reason)}")
    {:noreply, state}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # SSE Streaming (runs in Task)
  # ──────────────────────────────────────────────────────────────────────────

  defp stream_case(case_id) do
    base_url = Application.get_env(:optimal_system_agent, :yawl_url, "http://localhost:8080")
    url = "#{base_url}#{@stream_path}?caseId=#{URI.encode(case_id)}"

    case Req.get(url, receive_timeout: @stream_timeout, into: &handle_sse_chunk/2) do
      {:ok, _} ->
        Logger.debug("[EventStream] SSE stream for #{case_id} completed normally")

      {:error, reason} ->
        Logger.warning("[EventStream] SSE stream failed for #{case_id}: #{inspect(reason)}")
    end
  end

  defp handle_sse_chunk({:data, data}, acc) do
    data
    |> String.split("\n\n")
    |> Enum.each(&parse_and_emit_sse_event/1)

    {:cont, acc}
  end

  defp handle_sse_chunk(_chunk, acc), do: {:cont, acc}

  # ──────────────────────────────────────────────────────────────────────────
  # SSE Event Parsing
  # ──────────────────────────────────────────────────────────────────────────

  defp parse_and_emit_sse_event(raw) when is_binary(raw) do
    lines = String.split(raw, "\n")

    data_line =
      Enum.find_value(lines, fn line ->
        case String.split(line, ":", parts: 2) do
          ["data", json] -> String.trim(json)
          _ -> nil
        end
      end)

    if data_line do
      case Jason.decode(data_line) do
        {:ok, event} -> dispatch_event(event)
        {:error, _} -> :ignore
      end
    end
  end

  defp parse_and_emit_sse_event(_), do: :ignore

  # ──────────────────────────────────────────────────────────────────────────
  # Telemetry Dispatch (Weaver-generated constants)
  # ──────────────────────────────────────────────────────────────────────────

  defp dispatch_event(
         %{"eventType" => "INSTANCE_CREATED", "caseID" => case_id} = event
       ) do
    :telemetry.execute(
      [:osa, :yawl, :case, :started],
      %{},
      %{
        Attrs.yawl_case_id() => case_id,
        Attrs.yawl_spec_uri() => Map.get(event, "specificationID", ""),
        Attrs.yawl_instance_id() => Map.get(event, "instanceId", ""),
        Attrs.yawl_event_type() => Attrs.yawl_event_type_values().instance_created
      }
    )
  end

  defp dispatch_event(
         %{"eventType" => event_type, "caseID" => case_id, "taskId" => task_id} = event
       )
       when event_type in ["TASK_STARTED", "TASK_COMPLETED", "TASK_FAILED"] do
    {consumed, produced} =
      case event_type do
        "TASK_STARTED" -> {1, 0}
        "TASK_COMPLETED" -> {0, 1}
        "TASK_FAILED" -> {0, 0}
      end

    event_type_atom =
      case event_type do
        "TASK_STARTED" -> Attrs.yawl_event_type_values().task_started
        "TASK_COMPLETED" -> Attrs.yawl_event_type_values().task_completed
        "TASK_FAILED" -> Attrs.yawl_event_type_values().task_failed
      end

    work_item_id =
      event
      |> Map.get("details", %{})
      |> then(fn
        d when is_map(d) -> Map.get(d, "workItemId", "")
        _ -> ""
      end)

    :telemetry.execute(
      [:osa, :yawl, :task, :execution],
      %{token_consumed: consumed, token_produced: produced},
      %{
        Attrs.yawl_case_id() => case_id,
        Attrs.yawl_task_id() => task_id,
        Attrs.yawl_event_type() => event_type_atom,
        Attrs.yawl_work_item_id() => work_item_id
      }
    )
  end

  defp dispatch_event(
         %{"eventType" => event_type, "caseID" => case_id} = _event
       )
       when event_type in ["INSTANCE_COMPLETED", "INSTANCE_CANCELLED"] do
    event_type_atom =
      if event_type == "INSTANCE_COMPLETED",
        do: Attrs.yawl_event_type_values().instance_completed,
        else: Attrs.yawl_event_type_values().instance_cancelled

    :telemetry.execute(
      [:osa, :yawl, :case, :completed],
      %{},
      %{
        Attrs.yawl_case_id() => case_id,
        Attrs.yawl_event_type() => event_type_atom
      }
    )
  end

  defp dispatch_event(_event), do: :ignore

  # ──────────────────────────────────────────────────────────────────────────
  # Trace ID Derivation
  # ──────────────────────────────────────────────────────────────────────────

  # Deterministically derives a W3C 128-bit trace_id (32 hex chars) from a YAWL
  # case_id by taking the first 16 bytes of SHA-256(case_id).
  defp derive_trace_id(case_id) do
    :crypto.hash(:sha256, case_id)
    |> binary_part(0, 16)
    |> Base.encode16(case: :lower)
  end
end
