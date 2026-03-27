defmodule OptimalSystemAgent.Yawl.EventStream do
  @moduledoc """
  GenServer that subscribes to the YAWL SSE event stream per case and emits
  proper OpenTelemetry spans visible in Jaeger.

  ## OTEL spans emitted

  | Span name              | Trigger                        | Key attributes |
  |------------------------|--------------------------------|----------------|
  | `yawl.case`            | INSTANCE_CREATED → end on INSTANCE_COMPLETED/CANCELLED | yawl.case.id, yawl.spec.uri, yawl.instance.id |
  | `yawl.task.execution`  | TASK_STARTED / TASK_COMPLETED / TASK_FAILED | yawl.case.id, yawl.task.id, yawl.token.consumed, yawl.token.produced, yawl.work_item.id |

  Both span types are stored in the `:telemetry_spans` ETS table so tests and
  dashboards can assert on them without needing a live Jaeger instance.

  ## Trace correlation

  `case_id` is hashed (SHA-256 first 16 bytes → 32 hex chars) to derive a stable W3C
  `trace_id`. The mapping is stored in the ETS table `:osa_yawl_trace_ids`:

      {case_id :: String.t(), trace_id :: String.t()}

  Agent work item handlers look up `trace_id` to parent their spans under the YAWL case trace.

  ## Armstrong compliance

  No try/rescue around span or ETS calls. If `:telemetry_spans` or
  `:osa_yawl_trace_ids` do not exist the process crashes — the supervisor
  restarts EventStream, `init/1` recreates the tables, and the system returns
  to a correct state.
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Observability.Telemetry
  alias OpenTelemetry.SemConv.Incubating.SpanNames

  @ets_table :osa_yawl_trace_ids
  # ETS table that tracks active yawl.case span contexts keyed by case_id
  @case_spans_table :osa_yawl_case_spans
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

  Requires: Application running (ETS table initialized by supervisor).
  Will crash if EventStream GenServer not started — this is intentional (Armstrong).
  Use `@tag :requires_application` in tests that call this.
  """
  @spec lookup_trace_id(String.t()) :: String.t() | nil
  def lookup_trace_id(case_id) when is_binary(case_id) do
    case :ets.lookup(@ets_table, case_id) do
      [{^case_id, trace_id}] -> trace_id
      [] -> nil
    end
  end

  @doc """
  Emit a `yawl.case` OTEL span for a case start event and return the span context.

  Called internally by `dispatch_event/1` when an INSTANCE_CREATED event arrives.
  Exposed as a public function so tests can call it directly to assert on span
  structure without needing a live YAWL SSE stream.

  Stores the span context in `:osa_yawl_case_spans` ETS so `emit_case_end_span/2`
  can retrieve it when INSTANCE_COMPLETED or INSTANCE_CANCELLED arrives.
  """
  @spec emit_case_start_span(String.t(), String.t()) :: {:ok, map} | {:error, term}
  def emit_case_start_span(case_id, spec_uri, instance_id \\ "") do
    attrs = %{
      "yawl.case.id" => case_id,
      "yawl.spec.uri" => spec_uri,
      "yawl.instance.id" => instance_id
    }

    result = Telemetry.start_span(SpanNames.yawl_case(), attrs)

    case result do
      {:ok, span_ctx} ->
        # Store span context so the completion event can end it
        :ets.insert(@case_spans_table, {case_id, span_ctx})
        {:ok, span_ctx}

      error ->
        error
    end
  end

  @doc """
  End an active `yawl.case` span.

  Called internally when INSTANCE_COMPLETED or INSTANCE_CANCELLED arrives.
  `status` is `:ok` for normal completion and `:error` for cancellation.
  """
  @spec emit_case_end_span(map, :ok | :error) :: :ok
  def emit_case_end_span(span_ctx, status) do
    Telemetry.end_span(span_ctx, status)
  end

  @doc """
  Emit a `yawl.task.execution` OTEL span for a task lifecycle event and return
  the completed span context.

  `event_type` is one of `"TASK_STARTED"`, `"TASK_COMPLETED"`, `"TASK_FAILED"`.
  `token_consumed` and `token_produced` follow Petri net token semantics.
  """
  @spec emit_task_span(String.t(), String.t(), String.t(), integer, integer, String.t()) ::
          {:ok, map} | {:error, term}
  def emit_task_span(case_id, task_id, event_type, token_consumed, token_produced, work_item_id) do
    attrs = %{
      "yawl.case.id" => case_id,
      "yawl.task.id" => task_id,
      "yawl.event.type" => event_type,
      "yawl.token.consumed" => token_consumed,
      "yawl.token.produced" => token_produced,
      "yawl.work_item.id" => work_item_id
    }

    case Telemetry.start_span(SpanNames.yawl_task_execution(), attrs) do
      {:ok, span_ctx} ->
        # Task spans are point-in-time events — end immediately after creation
        status = if event_type == "TASK_FAILED", do: :error, else: :ok
        Telemetry.end_span(span_ctx, status)
        {:ok, span_ctx}

      error ->
        error
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

    _case_spans_table =
      case :ets.whereis(@case_spans_table) do
        :undefined ->
          :ets.new(@case_spans_table, [:named_table, :public, :set, read_concurrency: true])

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
  # OTEL Span Dispatch (replaces :telemetry.execute calls)
  # ──────────────────────────────────────────────────────────────────────────

  # INSTANCE_CREATED → open a yawl.case span, store it for later completion
  defp dispatch_event(
         %{"eventType" => "INSTANCE_CREATED", "caseID" => case_id} = event
       ) do
    spec_uri = Map.get(event, "specificationID", "")
    instance_id = Map.get(event, "instanceId", "")

    emit_case_start_span(case_id, spec_uri, instance_id)
  end

  # TASK_STARTED / TASK_COMPLETED / TASK_FAILED → yawl.task.execution span (point-in-time)
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

    work_item_id =
      event
      |> Map.get("details", %{})
      |> then(fn
        d when is_map(d) -> Map.get(d, "workItemId", "")
        _ -> ""
      end)

    emit_task_span(case_id, task_id, event_type, consumed, produced, work_item_id)
  end

  # INSTANCE_COMPLETED / INSTANCE_CANCELLED → close the yawl.case span
  defp dispatch_event(
         %{"eventType" => event_type, "caseID" => case_id} = _event
       )
       when event_type in ["INSTANCE_COMPLETED", "INSTANCE_CANCELLED"] do
    status = if event_type == "INSTANCE_COMPLETED", do: :ok, else: :error

    case :ets.lookup(@case_spans_table, case_id) do
      [{^case_id, span_ctx}] ->
        emit_case_end_span(span_ctx, status)
        :ets.delete(@case_spans_table, case_id)

      [] ->
        # No open span for this case — log and continue (case may have started before
        # EventStream was subscribed, or SSE stream delivered INSTANCE_COMPLETED first)
        Logger.debug("[EventStream] No open span for case #{case_id} on #{event_type}")
    end
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
