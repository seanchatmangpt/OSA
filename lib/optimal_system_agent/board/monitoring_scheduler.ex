defmodule OptimalSystemAgent.Board.MonitoringScheduler do
  @moduledoc """
  Autonomous process monitoring scheduler.

  Polls the pm4py-rust API every `interval_ms` (default 5 minutes) to check for
  process conformance drift. When drift is detected the scheduler broadcasts a
  `{:process_drift, score}` message on the `"board:monitoring"` PubSub topic so
  that HealingBridge and other subscribers can react immediately — without waiting
  for a manual board request.

  ## State (WvdA Boundedness)

  - `drift_scores` — ring buffer capped at 100 entries.  Old entries are dropped
    when the buffer is full (oldest-first).
  - `enabled` — boolean flag; when `false` incoming `:tick` messages are ignored
    so HTTP calls stop without stopping the GenServer.

  ## WvdA Soundness

  - HTTP call has explicit 10_000 ms timeout (no unbounded wait).
  - Timer uses `Process.send_after` (not a busy-loop).
  - Ring buffer has hard cap of 100 elements.
  - All `GenServer.call` public wrappers specify 5_000 ms timeout.

  ## Armstrong Fault Tolerance

  - `:permanent` restart — supervisor restarts on any crash.
  - HTTP failures are logged and do NOT crash the scheduler.
  - Timer is re-scheduled after every tick (success or failure).
  """

  use GenServer
  require Logger

  @pm4py_drift_url Application.compile_env(
                     :optimal_system_agent,
                     :pm4py_drift_url,
                     "http://localhost:8090/api/monitoring/drift"
                   )

  @http_timeout_ms 10_000
  @ring_buffer_max 100
  @pubsub_topic "board:monitoring"
  @default_interval_ms 300_000

  # ── Child spec ──────────────────────────────────────────────────────────────

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  # ── Public API ───────────────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Return `{:ok, %{last_drift: float | nil, enabled: boolean, drift_count: non_neg_integer}}`."
  @spec get_status() :: {:ok, map()}
  def get_status do
    GenServer.call(__MODULE__, :get_status, 5_000)
  end

  @doc "Disable automatic drift polling (proactive mode off)."
  @spec disable() :: :ok
  def disable do
    GenServer.call(__MODULE__, :disable, 5_000)
  end

  @doc "Re-enable automatic drift polling (proactive mode on)."
  @spec enable() :: :ok
  def enable do
    GenServer.call(__MODULE__, :enable, 5_000)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :interval_ms, @default_interval_ms)

    state = %{
      interval_ms: interval_ms,
      enabled: true,
      drift_scores: [],
      last_drift: nil,
      tick_ref: nil
    }

    Logger.info(
      "[Board.MonitoringScheduler] Started — interval=#{interval_ms}ms, " <>
        "endpoint=#{@pm4py_drift_url}"
    )

    {:ok, schedule_tick(state)}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      last_drift: state.last_drift,
      enabled: state.enabled,
      drift_count: length(state.drift_scores)
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call(:disable, _from, state) do
    Logger.info("[Board.MonitoringScheduler] Proactive mode DISABLED")
    {:reply, :ok, %{state | enabled: false}}
  end

  @impl true
  def handle_call(:enable, _from, state) do
    Logger.info("[Board.MonitoringScheduler] Proactive mode ENABLED")
    {:reply, :ok, %{state | enabled: true}}
  end

  @impl true
  def handle_info(:tick, %{enabled: false} = state) do
    # Reschedule even when disabled so we can be re-enabled without restarting.
    {:noreply, schedule_tick(state)}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state =
      case check_drift() do
        {:ok, %{"drift_detected" => true, "drift_score" => score}} ->
          Logger.info(
            "[Board.MonitoringScheduler] Drift detected — score=#{score}, broadcasting"
          )

          broadcast_drift(score)
          append_drift_score(state, score)

        {:ok, %{"drift_detected" => false}} ->
          Logger.debug("[Board.MonitoringScheduler] No drift detected")
          state

        {:ok, body} ->
          Logger.debug("[Board.MonitoringScheduler] Unexpected response body: #{inspect(body)}")
          state

        {:error, reason} ->
          Logger.warning(
            "[Board.MonitoringScheduler] Drift check failed: #{inspect(reason)}"
          )

          state
      end

    {:noreply, schedule_tick(new_state)}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private Helpers ──────────────────────────────────────────────────────────

  defp schedule_tick(%{interval_ms: interval_ms} = state) do
    ref = Process.send_after(self(), :tick, interval_ms)
    %{state | tick_ref: ref}
  end

  # HTTP call to pm4py-rust drift endpoint with 10s timeout (WvdA bounded).
  defp check_drift do
    task =
      Task.async(fn ->
        Req.get(@pm4py_drift_url, receive_timeout: @http_timeout_ms)
      end)

    case Task.yield(task, @http_timeout_ms + 1_000) || Task.shutdown(task) do
      {:ok, {:ok, %{status: 200, body: body}}} when is_map(body) ->
        {:ok, body}

      {:ok, {:ok, %{status: status}}} ->
        {:error, {:http_status, status}}

      {:ok, {:error, reason}} ->
        {:error, reason}

      nil ->
        {:error, :timeout}
    end
  end

  defp broadcast_drift(score) do
    try do
      Phoenix.PubSub.broadcast(
        OptimalSystemAgent.PubSub,
        @pubsub_topic,
        {:process_drift, score}
      )
    catch
      :exit, reason ->
        Logger.debug(
          "[Board.MonitoringScheduler] PubSub broadcast failed (not running?): " <>
            inspect(reason)
        )
    end
  end

  # Append a new score to the ring buffer, dropping the oldest entry when full.
  defp append_drift_score(%{drift_scores: scores} = state, score) do
    trimmed =
      if length(scores) >= @ring_buffer_max do
        Enum.drop(scores, 1)
      else
        scores
      end

    %{state | drift_scores: trimmed ++ [score], last_drift: score}
  end
end
