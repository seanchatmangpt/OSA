defmodule OptimalSystemAgent.Tracing.Context do
  @moduledoc """
  OpenTelemetry trace context management for concurrent operations.

  Provides primitives to capture, propagate, and restore OTEL trace context
  (trace_id, span_id) across process boundaries via the Elixir process dictionary.

  Used by swarm coordinators to thread trace context through Task.async() spawns,
  enabling child spans to link back to parent spans in the OTEL trace tree.

  ## Process Dictionary Keys

  Context is stored in the process dictionary using these keys:
    - `:otel_trace_id` — 16-byte binary or string UUID of the trace
    - `:otel_span_id` — 8-byte binary or string of the current span
    - `:otel_parent_span_id` — 8-byte binary (parent, for linking)

  ## Usage (Swarm Coordinator)

  ```elixir
  # Parent (swarm pattern function)
  parent_ctx = OptimalSystemAgent.Tracing.Context.capture()

  # Spawn child task
  task = Task.Supervisor.async_nolink(OptimalSystemAgent.TaskSupervisor, fn ->
    # Restore parent context in child
    OptimalSystemAgent.Tracing.Context.restore(parent_ctx)

    # Child's work here will see parent trace_id + span_id
    {:ok, result} = Orchestrator.run_subagent(config)
    result
  end)

  # Wait for result
  result = Task.await(task)
  ```

  ## Implementation Notes

  - Capture is lightweight (copy process dict keys, no allocation)
  - Restore is idempotent (overwrites existing context)
  - Context is per-process (not shared/mutated)
  - Safe for Task.async/Task.Supervisor (each Task gets its own copy)
  """

  require Logger

  @typedoc "Captured trace context from process dictionary"
  @type context :: %{
    trace_id: binary() | nil,
    span_id: binary() | nil,
    parent_span_id: binary() | nil
  }

  @doc """
  Capture the current process's OTEL trace context.

  Reads :otel_trace_id, :otel_span_id, :otel_parent_span_id from the process
  dictionary. Returns a map with all three keys (any may be nil if not set).

  Returns `%{trace_id: nil, span_id: nil, parent_span_id: nil}` if no context
  is set (no active trace).

  ## Example

      ctx = OptimalSystemAgent.Tracing.Context.capture()
      # => %{trace_id: "4bf92f3577b34da6...", span_id: "00f067aa0ba...", parent_span_id: nil}
  """
  @spec capture() :: context()
  def capture do
    %{
      trace_id: Process.get(:otel_trace_id),
      span_id: Process.get(:otel_span_id),
      parent_span_id: Process.get(:otel_parent_span_id)
    }
  end

  @doc """
  Restore a captured trace context into the current process.

  Writes trace_id, span_id, parent_span_id to the process dictionary.
  Idempotent — can be called multiple times safely.

  Context keys with nil values are skipped (don't overwrite existing keys).

  ## Example

      ctx = %{
        trace_id: "4bf92f3577b34da6...",
        span_id: "00f067aa0ba...",
        parent_span_id: nil
      }
      :ok = OptimalSystemAgent.Tracing.Context.restore(ctx)
  """
  @spec restore(context() | map()) :: :ok
  def restore(ctx) when is_map(ctx) do
    if ctx.trace_id do
      Process.put(:otel_trace_id, ctx.trace_id)
    end

    if ctx.span_id do
      Process.put(:otel_span_id, ctx.span_id)
    end

    if ctx.parent_span_id do
      Process.put(:otel_parent_span_id, ctx.parent_span_id)
    end

    :ok
  end

  @doc """
  Clear the current process's OTEL trace context.

  Removes all three keys from the process dictionary.
  """
  @spec clear() :: :ok
  def clear do
    Process.delete(:otel_trace_id)
    Process.delete(:otel_span_id)
    Process.delete(:otel_parent_span_id)
    :ok
  end

  @doc """
  Get the current trace_id, or generate a new one if none exists.

  Returns a 16-byte binary UUID string (OpenTelemetry format).
  If no trace_id is set in process dictionary, generates one with
  `System.unique_integer()` and a random suffix (not cryptographically strong,
  suitable for tracing only).

  This is useful for coordinator functions that need to start a new trace
  (e.g., top-level swarm pattern entry points).

  ## Example

      trace_id = OptimalSystemAgent.Tracing.Context.get_or_generate_trace_id()
      # => "4bf92f3577b34da6a3ce929d0e0e4736"
  """
  @spec get_or_generate_trace_id() :: binary()
  def get_or_generate_trace_id do
    case Process.get(:otel_trace_id) do
      nil ->
        # Generate new trace_id (32 hex chars, 128 bits)
        # Format: {random_bits}_{timestamp}_{counter}
        unique = System.unique_integer([:positive, :monotonic])
        timestamp = System.os_time(:millisecond)
        random = :rand.uniform(0xFFFFFFFF)

        trace_id =
          (:erlang.integer_to_binary(unique, 16) <>
             :erlang.integer_to_binary(timestamp, 16) <>
             :erlang.integer_to_binary(random, 16))
          |> String.downcase()

        # Pad to 32 hex chars (16 bytes)
        padded_id = String.pad_leading(trace_id, 32, "0") |> String.slice(0..31)

        Process.put(:otel_trace_id, padded_id)
        padded_id

      existing ->
        existing
    end
  end

  @doc """
  Generate a new span_id for a child operation.

  Returns an 8-byte binary UUID string in hex (OpenTelemetry format).
  Uses `System.unique_integer()` + timestamp for uniqueness.

  Does NOT modify the process dictionary — the span_id is returned for
  manual registration if needed.

  ## Example

      span_id = OptimalSystemAgent.Tracing.Context.generate_span_id()
      # => "00f067aa0ba902b7"
  """
  @spec generate_span_id() :: binary()
  def generate_span_id do
    unique = System.unique_integer([:positive, :monotonic])
    timestamp = System.os_time(:nanosecond)

    span_id =
      (:erlang.integer_to_binary(unique, 16) <>
         :erlang.integer_to_binary(timestamp, 16))
      |> String.downcase()

    # Pad to 16 hex chars (8 bytes)
    String.pad_leading(span_id, 16, "0") |> String.slice(0..15)
  end

  @doc """
  Create a child context by promoting the current span_id to parent_span_id
  and generating a new span_id.

  Used by swarm coordinators to create a new child span that links back to the
  current span as its parent.

  Returns the updated context (does NOT modify the process dictionary).

  ## Example

      # Parent context
      ctx = %{trace_id: "4bf...", span_id: "00f...", parent_span_id: nil}

      # Create child context with new span_id
      child_ctx = OptimalSystemAgent.Tracing.Context.create_child_context(ctx)
      # => %{
      #   trace_id: "4bf..." (same),
      #   span_id: "9z1..." (new),
      #   parent_span_id: "00f..." (promoted from parent)
      # }
  """
  @spec create_child_context(context() | map()) :: context()
  def create_child_context(parent_ctx) when is_map(parent_ctx) do
    %{
      trace_id: parent_ctx.trace_id,
      span_id: generate_span_id(),
      parent_span_id: parent_ctx.span_id
    }
  end

  @doc """
  Format context for logging.

  Returns a string like "trace=4bf...7da6 span=00f...b7" suitable for log lines.
  Truncates IDs to first 8 hex chars for readability.

  If trace_id is nil, returns "trace=none".
  """
  @spec format_for_logging(context() | map()) :: binary()
  def format_for_logging(%{trace_id: trace_id, span_id: span_id})
      when is_binary(trace_id) and is_binary(span_id) do
    trace_short = String.slice(trace_id, 0..7)
    span_short = String.slice(span_id, 0..7)
    "trace=#{trace_short} span=#{span_short}"
  end

  def format_for_logging(_), do: "trace=none"
end
