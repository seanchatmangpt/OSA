defmodule OptimalSystemAgent.Bridges.ProcessMiningBridge do
  @moduledoc """
  GenServer bridge connecting pm4py-rust process mining results into OSA's healing system.

  This is the #1 blue ocean connection: process mining DRIVES agent coordination.
  The bridge periodically polls pm4py-rust for health and conformance data, transforms
  the results into healing diagnosis inputs, and feeds anomalies into the existing
  healing system via the Event Bus.

  ## Anomaly Types

  - `:low_conformance` — conformance_score < 0.7
  - `:high_cycle_time` — cycle_time_ms > configurable threshold (default 10_000ms)
  - `:bottleneck` — bottleneck detected in conformance response

  ## WvdA Soundness

  - All HTTP calls bounded to 3s timeout (deadlock freedom)
  - Poll interval bounded with `Process.send_after` (liveness — no infinite loops)
  - Anomaly queue bounded to last 100 entries (boundedness)
  - GenServer.call timeout 5000ms

  ## Armstrong Fault Tolerance

  - Supervised by `ProcessMiningBridge.Supervisor` (:permanent restart)
  - pm4py-rust being down does NOT crash the bridge — logged warning, skip cycle
  - No shared mutable state — all state in GenServer process
  - Let-it-crash on unrecoverable errors; supervisor restarts cleanly
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus
  alias OptimalSystemAgent.Observability.Telemetry

  # -- Configuration --
  @default_poll_interval_ms 30_000
  @http_timeout_ms 3_000
  @genserver_call_timeout_ms 5_000
  @conformance_threshold 0.7
  @cycle_time_threshold_ms 10_000
  @max_anomaly_log 100
  @default_base_url "http://localhost:8090"

  # -- Child spec (Armstrong: permanent restart) --

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  # -- Public API --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the current bridge status including last poll result and anomaly log.
  GenServer.call with explicit 5s timeout (WvdA).
  """
  @spec status() :: map()
  def status do
    try do
      GenServer.call(__MODULE__, :status, @genserver_call_timeout_ms)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc """
  Returns the list of recent anomalies detected (bounded to last #{@max_anomaly_log}).
  """
  @spec anomalies() :: [map()]
  def anomalies do
    try do
      GenServer.call(__MODULE__, :anomalies, @genserver_call_timeout_ms)
    catch
      :exit, {:timeout, _} -> []
    end
  end

  @doc """
  Manually trigger a poll cycle (useful for testing).
  """
  @spec poll_now() :: :ok
  def poll_now do
    GenServer.cast(__MODULE__, :poll_now)
  end

  @doc """
  Inject simulated conformance data for testing without needing a live pm4py-rust.

  The data map should match the shape returned by `/api/conformance/check`, e.g.:
      %{"conformance_score" => 0.5, "cycle_time_ms" => 15000, "bottlenecks" => ["node_a"]}

  Returns `{:ok, anomaly_count}` with the number of anomalies detected and emitted.
  """
  @spec inject_conformance_data(map()) :: {:ok, non_neg_integer()} | {:error, term()}
  def inject_conformance_data(conformance_data) when is_map(conformance_data) do
    try do
      GenServer.call(__MODULE__, {:inject_conformance_data, conformance_data}, @genserver_call_timeout_ms)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  # -- GenServer Callbacks --

  @impl true
  def init(opts) do
    base_url = Keyword.get(opts, :base_url, pm4py_base_url())
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)
    conformance_threshold = Keyword.get(opts, :conformance_threshold, @conformance_threshold)
    cycle_time_threshold_ms = Keyword.get(opts, :cycle_time_threshold_ms, @cycle_time_threshold_ms)

    state = %{
      base_url: base_url,
      poll_interval_ms: poll_interval_ms,
      conformance_threshold: conformance_threshold,
      cycle_time_threshold_ms: cycle_time_threshold_ms,
      last_poll_at: nil,
      last_poll_result: nil,
      pm4py_healthy: false,
      anomaly_log: [],
      poll_count: 0
    }

    # Schedule first poll after a short delay to let the system boot
    schedule_poll(poll_interval_ms)

    Logger.info(
      "[ProcessMiningBridge] Started — polling pm4py-rust at #{base_url} every #{poll_interval_ms}ms"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    reply = %{
      base_url: state.base_url,
      poll_interval_ms: state.poll_interval_ms,
      last_poll_at: state.last_poll_at,
      last_poll_result: state.last_poll_result,
      pm4py_healthy: state.pm4py_healthy,
      poll_count: state.poll_count,
      anomaly_count: length(state.anomaly_log)
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:anomalies, _from, state) do
    {:reply, state.anomaly_log, state}
  end

  @impl true
  def handle_call({:inject_conformance_data, conformance_data}, _from, state) do
    now = DateTime.utc_now()
    {state, anomaly_count} = process_conformance_results(state, conformance_data, now)
    {:reply, {:ok, anomaly_count}, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = execute_poll_cycle(state)
    schedule_poll(state.poll_interval_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_cast(:poll_now, state) do
    state = execute_poll_cycle(state)
    {:noreply, state}
  end

  # -- Private: Poll Cycle --

  defp execute_poll_cycle(state) do
    {:ok, span} =
      Telemetry.start_span("bridge.process_mining.poll", %{
        "bridge.base_url" => state.base_url,
        "bridge.poll_count" => state.poll_count
      })

    now = DateTime.utc_now()

    # Step 1: Health check
    case check_health(state.base_url) do
      :ok ->
        state = %{state | pm4py_healthy: true}

        # Step 2: Fetch conformance data
        {state, anomalies_found} =
          case fetch_conformance(state.base_url) do
            {:ok, conformance_data} ->
              process_conformance_results(state, conformance_data, now)

            {:error, reason} ->
              Logger.warning(
                "[ProcessMiningBridge] Conformance fetch failed: #{inspect(reason)}"
              )

              {state, 0}
          end

        Telemetry.end_span(
          Map.merge(span, %{
            "attributes" =>
              Map.merge(span["attributes"], %{
                "bridge.pm4py_healthy" => true,
                "bridge.anomalies_found" => anomalies_found
              })
          }),
          :ok
        )

        %{state | last_poll_at: now, last_poll_result: :ok, poll_count: state.poll_count + 1}

      {:error, reason} ->
        Logger.warning(
          "[ProcessMiningBridge] pm4py-rust health check failed: #{inspect(reason)} — skipping poll cycle"
        )

        Telemetry.end_span(
          Map.merge(span, %{
            "attributes" =>
              Map.merge(span["attributes"], %{
                "bridge.pm4py_healthy" => false,
                "bridge.error" => inspect(reason)
              })
          }),
          :ok
        )

        %{
          state
          | pm4py_healthy: false,
            last_poll_at: now,
            last_poll_result: {:error, reason},
            poll_count: state.poll_count + 1
        }
    end
  end

  # -- Private: HTTP Calls (all with 3s WvdA timeout) --

  defp check_health(base_url) do
    url = "#{base_url}/api/health"

    case Req.get(url, receive_timeout: @http_timeout_ms, connect_options: [timeout: @http_timeout_ms], retry: false) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, {:unreachable, reason}}
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  defp fetch_conformance(base_url) do
    url = "#{base_url}/api/conformance/check"

    case Req.post(url,
           json: %{},
           receive_timeout: @http_timeout_ms,
           connect_options: [timeout: @http_timeout_ms],
           retry: false
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        parsed =
          case body do
            map when is_map(map) -> map
            binary when is_binary(binary) -> Jason.decode!(binary)
            other -> %{"raw" => other}
          end

        {:ok, parsed}

      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, {:unreachable, reason}}
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  # -- Conformance Analysis --

  defp process_conformance_results(state, conformance_data, now) do
    anomalies = detect_anomalies(state, conformance_data)

    state =
      Enum.reduce(anomalies, state, fn anomaly, acc ->
        emit_anomaly(anomaly, now)
        log_anomaly(acc, anomaly, now)
      end)

    {state, length(anomalies)}
  end

  @doc false
  # Exposed for Chicago TDD testing — same pattern as Board.HealingBridge.build_escalation_sparql/3.
  # Takes a state-like map with :conformance_threshold and :cycle_time_threshold_ms keys,
  # plus a conformance_data map from pm4py-rust, and returns a list of anomaly maps.
  def detect_anomalies(state, conformance_data) do
    anomalies = []

    # Check conformance score
    conformance_score =
      Map.get(conformance_data, "conformance_score") ||
        Map.get(conformance_data, "fitness") ||
        Map.get(conformance_data, "score")

    anomalies =
      if is_number(conformance_score) and conformance_score < state.conformance_threshold do
        [
          %{
            type: :low_conformance,
            score: conformance_score,
            threshold: state.conformance_threshold
          }
          | anomalies
        ]
      else
        anomalies
      end

    # Check cycle time
    cycle_time_ms =
      Map.get(conformance_data, "cycle_time_ms") ||
        Map.get(conformance_data, "avg_cycle_time_ms")

    anomalies =
      if is_number(cycle_time_ms) and cycle_time_ms > state.cycle_time_threshold_ms do
        delta = cycle_time_ms - state.cycle_time_threshold_ms

        [
          %{
            type: :high_cycle_time,
            cycle_time_ms: cycle_time_ms,
            threshold_ms: state.cycle_time_threshold_ms,
            delta: delta
          }
          | anomalies
        ]
      else
        anomalies
      end

    # Check bottlenecks
    bottlenecks =
      Map.get(conformance_data, "bottlenecks") ||
        Map.get(conformance_data, "bottleneck_nodes") ||
        []

    anomalies =
      if is_list(bottlenecks) and length(bottlenecks) > 0 do
        Enum.reduce(bottlenecks, anomalies, fn bottleneck, acc ->
          node_id =
            case bottleneck do
              %{"node_id" => id} -> id
              %{"id" => id} -> id
              id when is_binary(id) -> id
              _ -> inspect(bottleneck)
            end

          [%{type: :bottleneck, node_id: node_id} | acc]
        end)
      else
        anomalies
      end

    anomalies
  end

  defp emit_anomaly(anomaly, now) do
    {:ok, span} =
      Telemetry.start_span("bridge.process_mining.anomaly_detected", %{
        "bridge.anomaly_type" => to_string(anomaly.type),
        "bridge.detected_at" => DateTime.to_iso8601(now)
      })

    # Emit to the healing system via the event bus
    Bus.emit(
      :system_event,
      %{
        event: :conformance_violation,
        anomaly_type: anomaly.type,
        anomaly_data: anomaly,
        process_id: "pm4py-process-mining",
        fitness: Map.get(anomaly, :score, 0.5),
        deviation_type: to_string(anomaly.type),
        detected_at: DateTime.to_iso8601(now),
        source: "bridge.process_mining"
      },
      source: "bridge.process_mining"
    )

    Telemetry.end_span(span, :ok)

    Logger.info(
      "[ProcessMiningBridge] Anomaly detected: #{anomaly.type} — #{inspect(anomaly)}"
    )
  end

  defp log_anomaly(state, anomaly, now) do
    entry = %{
      type: anomaly.type,
      data: anomaly,
      detected_at: now
    }

    # Bounded to last @max_anomaly_log entries (WvdA boundedness)
    updated_log = Enum.take([entry | state.anomaly_log], @max_anomaly_log)
    %{state | anomaly_log: updated_log}
  end

  # -- Private: Scheduling --

  defp schedule_poll(interval_ms) do
    Process.send_after(self(), :poll, interval_ms)
  end

  defp pm4py_base_url do
    Application.get_env(:optimal_system_agent, :pm4py_url, @default_base_url)
  end
end
