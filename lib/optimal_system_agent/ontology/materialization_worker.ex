defmodule OptimalSystemAgent.Ontology.MaterializationWorker do
  @moduledoc """
  Materialization Worker — executes one CONSTRUCT level refresh in a supervised Task.

  This module is called exclusively by `MaterializationScheduler` via
  `Task.Supervisor.start_child/2`. Each invocation is a single-shot, temporary
  process: run the CONSTRUCT, emit an OTEL span, return result, then exit.

  ## Armstrong Let-It-Crash

  On any error, the worker raises (crashes). The Task.Supervisor logs the crash
  and the scheduler reschedules at the next normal interval. There is no silent
  catch here — failures are visible in supervisor logs.

  ## OTEL Span

  Emits span `materialization.worker.refresh` with attributes:
    - `level` — atom as string (e.g. "l0")
    - `triple_count` — integer count of materialized triples
    - `duration_ms` — wall-clock duration of the CONSTRUCT operation
    - `status` — "ok" or "error"
  """

  require Logger
  require OpenTelemetry.Tracer

  alias OptimalSystemAgent.Ontology.InferenceChain
  alias OpenTelemetry.Tracer

  @worker_timeout_ms 30_000

  @doc """
  Execute one CONSTRUCT level refresh.

  Calls `InferenceChain.run_level/1` with a 30-second timeout guard,
  emits an OTEL span with results, and returns `{:ok, triple_count}`.

  On failure, raises — letting the Task crash and the supervisor log it.
  The scheduler will retry at the next scheduled interval.

  ## Parameters

    - `level` — one of `:l0 | :l1 | :l2 | :l3`

  ## Returns

    - `{:ok, non_neg_integer()}` on success

  ## Raises

    - Raises on `{:error, _}` result so the Task crashes visibly
  """
  @spec run(:l0 | :l1 | :l2 | :l3) :: {:ok, non_neg_integer()}
  def run(level) when level in [:l0, :l1, :l2, :l3] do
    level_str = to_string(level)
    start_ms = System.monotonic_time(:millisecond)

    Logger.info("[MaterializationWorker] Starting refresh level=#{level_str}")

    # Enforce 30-second wall-clock timeout via Task wrapping
    task = Task.async(fn -> InferenceChain.run_level(level) end)

    result =
      case Task.yield(task, @worker_timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, inner_result} -> inner_result
        nil -> {:error, :worker_timeout}
      end

    duration_ms = System.monotonic_time(:millisecond) - start_ms

    case result do
      {:ok, triple_count} ->
        Tracer.with_span("materialization.worker.refresh", %{
          "level" => level_str,
          "triple_count" => triple_count,
          "duration_ms" => duration_ms,
          "status" => "ok"
        }) do
          Tracer.set_attributes(%{
            "level" => level_str,
            "triple_count" => triple_count,
            "duration_ms" => duration_ms,
            "status" => "ok"
          })
          :ok
        end

        Logger.info(
          "[MaterializationWorker] level=#{level_str} ok triples=#{triple_count} duration_ms=#{duration_ms}"
        )

        {:ok, triple_count}

      {:error, reason} ->
        Tracer.with_span("materialization.worker.refresh", %{
          "level" => level_str,
          "triple_count" => 0,
          "duration_ms" => duration_ms,
          "status" => "error"
        }) do
          Tracer.set_attributes(%{
            "level" => level_str,
            "duration_ms" => duration_ms,
            "status" => "error",
            "error.reason" => inspect(reason)
          })
          :ok
        end

        Logger.error(
          "[MaterializationWorker] level=#{level_str} error reason=#{inspect(reason)} duration_ms=#{duration_ms}"
        )

        # Armstrong: let-it-crash — raise so Task.Supervisor logs the failure
        raise RuntimeError,
          message: "[MaterializationWorker] CONSTRUCT failed level=#{level_str}: #{inspect(reason)}"
    end
  end
end
