defmodule OptimalSystemAgent.ProcessMining.Client do
  @moduledoc """
  GenServer client for pm4py-rust HTTP API.

  Provides APIs for process discovery, soundness verification (deadlock-freedom, liveness, boundedness),
  and reachability analysis. All blocking operations enforce 10-second timeout (WvdA deadlock-freedom).

  Each public API call emits an OTEL span via Telemetry.start_span/end_span and injects
  a W3C traceparent header into the outbound HTTP request to pm4py-rust, enabling
  cross-project trace correlation in Jaeger.

  Span names (from SpanNames constants):
  - `process.mining.discovery`   — discover_process_models/1
  - `process.mining.soundness`   — check_deadlock_free/1 and analyze_boundedness/1
  - `process.mining.reachability` — get_reachability_graph/1

  Public API:
  - `discover_process_models(resource_type)` — GET /process/discover/{resource_type}
  - `check_deadlock_free(process_id)` — POST /process/soundness/{process_id} with {check: "deadlock_free"}
  - `get_reachability_graph(process_id)` — GET /process/reachability/{process_id}
  - `analyze_boundedness(process_id)` — POST /process/soundness/{process_id} with {check: "bounded"}

  ## Registration

  Registers as `:process_mining_client` in the supervision tree.
  """
  use GenServer
  require Logger

  alias OptimalSystemAgent.Observability.Telemetry
  alias OptimalSystemAgent.Observability.Traceparent

  @timeout_ms 10_000
  @pm4py_url Application.compile_env(:optimal_system_agent, :pm4py_url, "http://localhost:8090")

  # Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: :process_mining_client)
  end

  @doc """
  Discover process models for a resource type.

  Returns `{:ok, models}` or `{:error, reason}`.
  """
  def discover_process_models(resource_type) do
    GenServer.call(:process_mining_client, {:discover, resource_type}, @timeout_ms)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @doc """
  Check if a process is deadlock-free.

  Returns `{:ok, result}` or `{:error, reason}`.
  Result contains boolean `:deadlock_free` and confidence metrics.
  """
  def check_deadlock_free(process_id) do
    GenServer.call(:process_mining_client, {:check_soundness, process_id, "deadlock_free"}, @timeout_ms)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @doc """
  Get reachability graph for a process.

  Returns `{:ok, graph}` or `{:error, reason}`.
  Graph contains nodes and edges showing all reachable states.
  """
  def get_reachability_graph(process_id) do
    GenServer.call(:process_mining_client, {:reachability, process_id}, @timeout_ms)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @doc """
  Analyze boundedness properties of a process.

  Returns `{:ok, result}` or `{:error, reason}`.
  Result contains boolean `:bounded` and resource limits discovered.
  """
  def analyze_boundedness(process_id) do
    GenServer.call(:process_mining_client, {:check_soundness, process_id, "bounded"}, @timeout_ms)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    Logger.info("ProcessMining.Client starting with URL: #{@pm4py_url}")
    {:ok, %{url: @pm4py_url}}
  end

  @impl true
  def handle_call({:discover, resource_type}, _from, state) do
    result = do_discover(state.url, resource_type)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:check_soundness, process_id, check_type}, _from, state) do
    result = do_check_soundness(state.url, process_id, check_type)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:reachability, process_id}, _from, state) do
    result = do_reachability(state.url, process_id)
    {:reply, result, state}
  end

  # Private API

  defp do_discover(url, resource_type) do
    endpoint = "#{url}/process/discover/#{URI.encode(resource_type)}"

    {:ok, span} =
      Telemetry.start_span("process.mining.discovery", %{
        "process.mining.resource_type" => resource_type,
        "process.mining.endpoint" => endpoint
      })

    # Store current span ID so Traceparent.add_to_request picks it up
    Process.put(:telemetry_current_span_id, span["span_id"])

    req_opts = Traceparent.add_to_request(receive_timeout: @timeout_ms)

    result =
      case Req.get(endpoint, req_opts) do
        {:ok, response} ->
          case response.status do
            200 -> {:ok, response.body}
            status -> {:error, {:http, status, response.body}}
          end

        {:error, reason} ->
          Logger.error("ProcessMining discovery failed: #{inspect(reason)}")
          {:error, reason}
      end

    case result do
      {:ok, _} -> Telemetry.end_span(span, :ok)
      {:error, reason} -> Telemetry.end_span(span, :error, inspect(reason))
    end

    result
  end

  defp do_check_soundness(url, process_id, check_type) do
    endpoint = "#{url}/process/soundness/#{URI.encode(process_id)}"
    body = %{check: check_type}

    {:ok, span} =
      Telemetry.start_span("process.mining.soundness", %{
        "process.mining.process_id" => process_id,
        "process.mining.check_type" => check_type,
        "process.mining.endpoint" => endpoint
      })

    Process.put(:telemetry_current_span_id, span["span_id"])

    req_opts = Traceparent.add_to_request(json: body, receive_timeout: @timeout_ms)

    result =
      case Req.post(endpoint, req_opts) do
        {:ok, response} ->
          case response.status do
            200 -> {:ok, response.body}
            status -> {:error, {:http, status, response.body}}
          end

        {:error, reason} ->
          Logger.error("ProcessMining soundness check failed: #{inspect(reason)}")
          {:error, reason}
      end

    case result do
      {:ok, _} -> Telemetry.end_span(span, :ok)
      {:error, reason} -> Telemetry.end_span(span, :error, inspect(reason))
    end

    result
  end

  defp do_reachability(url, process_id) do
    endpoint = "#{url}/process/reachability/#{URI.encode(process_id)}"

    {:ok, span} =
      Telemetry.start_span("process.mining.reachability", %{
        "process.mining.process_id" => process_id,
        "process.mining.endpoint" => endpoint
      })

    Process.put(:telemetry_current_span_id, span["span_id"])

    req_opts = Traceparent.add_to_request(receive_timeout: @timeout_ms)

    result =
      case Req.get(endpoint, req_opts) do
        {:ok, response} ->
          case response.status do
            200 -> {:ok, response.body}
            status -> {:error, {:http, status, response.body}}
          end

        {:error, reason} ->
          Logger.error("ProcessMining reachability analysis failed: #{inspect(reason)}")
          {:error, reason}
      end

    case result do
      {:ok, _} -> Telemetry.end_span(span, :ok)
      {:error, reason} -> Telemetry.end_span(span, :error, inspect(reason))
    end

    result
  end
end
