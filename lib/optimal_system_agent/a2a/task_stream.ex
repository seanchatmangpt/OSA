defmodule OptimalSystemAgent.A2A.TaskStream do
  @moduledoc """
  A2A task streaming via Server-Sent Events (SSE).

  Provides real-time task progress updates for A2A operations.
  Clients subscribe to task-specific SSE streams and receive
  state transitions as they occur.

  ## Task Lifecycle

  1. `created` -- Task received, processing starting
  2. `running` -- Agent loop executing
  3. `tool_call` -- Agent is calling a tool
  4. `tool_result` -- Tool call completed
  5. `completed` -- Task finished successfully
  6. `failed` -- Task failed with error

  ## Integration

  Task updates are published via `Phoenix.PubSub` on the
  `a2a:task:TASK_ID` topic (where TASK_ID is the actual task ID).
  The SSE endpoint subscribes and forwards events to the HTTP client.

  Bus events are emitted for each state transition so other
  OSA subsystems can react to A2A task progress.
  """

  @topic_prefix "a2a:task:"

  # ── Public API ────────────────────────────────────────────────────────

  @doc "Subscribe the calling process to task updates for a specific task."
  @spec subscribe(String.t()) :: :ok | {:error, term()}
  def subscribe(task_id) do
    Phoenix.PubSub.subscribe(OptimalSystemAgent.PubSub, topic(task_id))
  end

  @doc "Unsubscribe from task updates."
  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(task_id) do
    Phoenix.PubSub.unsubscribe(OptimalSystemAgent.PubSub, topic(task_id))
  end

  @doc "Publish a task state update."
  @spec publish(String.t(), String.t(), map()) :: :ok
  def publish(task_id, status, metadata \\ %{}) when is_binary(task_id) and is_binary(status) do
    start_time = System.monotonic_time(:microsecond)

    event = %{
      task_id: task_id,
      status: status,
      metadata: metadata,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Phoenix.PubSub.broadcast(OptimalSystemAgent.PubSub, topic(task_id), {:a2a_task_event, event})

    # Also broadcast on the global A2A topic for subscribers that track all tasks
    Phoenix.PubSub.broadcast(
      OptimalSystemAgent.PubSub,
      "a2a:tasks",
      {:a2a_task_event, event}
    )

    # Emit telemetry event for observability
    duration = System.monotonic_time(:microsecond) - start_time
    :telemetry.execute(
      [:osa, :a2a, :task_stream],
      %{duration: duration},
      %{task_id: task_id, status: status, metadata: metadata}
    )

    # Emit Bus event for cross-subsystem notification
    emit_bus_event(task_id, status, metadata)
  end

  @doc "Subscribe to all A2A task events."
  @spec subscribe_all() :: :ok | {:error, term()}
  def subscribe_all do
    Phoenix.PubSub.subscribe(OptimalSystemAgent.PubSub, "a2a:tasks")
  end

  @doc "Unsubscribe from all A2A task events."
  @spec unsubscribe_all() :: :ok
  def unsubscribe_all do
    Phoenix.PubSub.unsubscribe(OptimalSystemAgent.PubSub, "a2a:tasks")
  end

  @doc """
  Plug-compatible SSE stream for a specific task.

  Sends chunked SSE response with task state updates.
  Automatically unsubscribes when the task completes or fails.
  """
  @spec stream(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def stream(conn, task_id) do
    subscribe(task_id)

    conn =
      conn
      |> Plug.Conn.put_resp_content_type("text/event-stream")
      |> Plug.Conn.put_resp_header("cache-control", "no-cache")
      |> Plug.Conn.put_resp_header("connection", "keep-alive")
      |> Plug.Conn.put_resp_header("x-accel-buffering", "no")
      |> Plug.Conn.send_chunked(200)

    {:ok, conn} = Plug.Conn.chunk(conn, sse_event("connected", %{task_id: task_id}))
    sse_loop(conn, task_id)
  end

  @doc """
  Plug-compatible SSE stream for all A2A tasks.

  Receives events from all active tasks.
  """
  @spec stream_all(Plug.Conn.t()) :: Plug.Conn.t()
  def stream_all(conn) do
    subscribe_all()

    conn =
      conn
      |> Plug.Conn.put_resp_content_type("text/event-stream")
      |> Plug.Conn.put_resp_header("cache-control", "no-cache")
      |> Plug.Conn.put_resp_header("connection", "keep-alive")
      |> Plug.Conn.put_resp_header("x-accel-buffering", "no")
      |> Plug.Conn.send_chunked(200)

    {:ok, conn} = Plug.Conn.chunk(conn, sse_event("connected", %{scope: "all_tasks"}))
    sse_loop_all(conn)
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp topic(task_id), do: @topic_prefix <> task_id

  defp sse_loop(conn, task_id) do
    # WvdA Soundness: bounded receive with 120s timeout to prevent indefinite blocking
    receive do
      {:a2a_task_event, %{task_id: ^task_id, status: status} = event} ->
        case Plug.Conn.chunk(conn, sse_event(status, event)) do
          {:ok, conn} when status in ["completed", "failed"] ->
            # Terminal state -- close the stream
            conn

          {:ok, conn} ->
            sse_loop(conn, task_id)

          {:error, _} ->
            unsubscribe(task_id)
            conn
        end
    after
      120_000 ->
        # Hard timeout after 120 seconds of inactivity; escalate to keepalive or close
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} ->
            sse_loop(conn, task_id)

          {:error, _} ->
            unsubscribe(task_id)
            conn
        end
    end
  end

  defp sse_loop_all(conn) do
    receive do
      {:a2a_task_event, event} ->
        data = Jason.encode!(event)

        case Plug.Conn.chunk(conn, "event: #{event.status}\ndata: #{data}\n\n") do
          {:ok, conn} ->
            sse_loop_all(conn)

          {:error, _} ->
            unsubscribe_all()
            conn
        end
    after
      30_000 ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} ->
            sse_loop_all(conn)

          {:error, _} ->
            unsubscribe_all()
            conn
        end
    end
  end

  defp sse_event(event_type, data) do
    encoded = Jason.encode!(data)
    "event: #{event_type}\ndata: #{encoded}\n\n"
  end

  defp emit_bus_event(task_id, status, metadata) do
    try do
      OptimalSystemAgent.Events.Bus.emit(:system_event, %{
        subsystem: :a2a,
        event: :task_update,
        task_id: task_id,
        status: status,
        metadata: metadata
      })
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end
end
