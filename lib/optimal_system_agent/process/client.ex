defmodule OptimalSystemAgent.Process.Mining.Client do
  @moduledoc """
  HTTP client for pm4py-rust process mining engine.

  Provides WvdA-compliant interface with 10-second timeouts on all operations
  to enforce deadlock-freedom guarantees.

  ## WvdA Requirements

  Every call has explicit timeout_ms to prevent indefinite waits:
  - All `GenServer.call/3` operations use 10-second timeout
  - HTTP requests use `receive_timeout: 10_000` (milliseconds)
  - Timeout triggers escalation rather than silent failure

  ## Integration

  Used by Phase 4 WvdA agents:
  - Deadlock Detector (checks for circular lock chains)
  - Liveness Verifier (ensures all actions complete)
  - Boundedness Analyzer (verifies resource limits)
  - Settlement Monitor (tracks agent payment completion)
  - Optimizer (tunes process parameters)
  """

  use GenServer
  require Logger

  @pm4py_base_url Application.compile_env(
                     :optimal_system_agent,
                     :pm4py_url,
                     "http://localhost:8090"
                   )
  @default_timeout_ms 10_000

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Discover process models from resource type.

  Returns `{:ok, models}` or `{:error, reason}` within 10 seconds.
  """
  def discover_process_models(resource_type) do
    GenServer.call(__MODULE__, {:discover, resource_type}, @default_timeout_ms)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("ProcessMining.Client timeout on discover_process_models for #{resource_type}")
      {:error, :timeout}
  end

  @doc """
  Check if process is deadlock-free (WvdA safety property).

  Returns `{:ok, result}` or `{:error, reason}` within 10 seconds.
  """
  def check_deadlock_free(process_id) do
    GenServer.call(__MODULE__, {:check_deadlock_free, process_id}, @default_timeout_ms)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("ProcessMining.Client timeout on check_deadlock_free for #{process_id}")
      {:error, :timeout}
  end

  @doc """
  Get reachability graph for process (state space analysis).

  Returns `{:ok, graph}` or `{:error, reason}` within 10 seconds.
  """
  def get_reachability_graph(process_id) do
    GenServer.call(__MODULE__, {:reachability, process_id}, @default_timeout_ms)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("ProcessMining.Client timeout on get_reachability_graph for #{process_id}")
      {:error, :timeout}
  end

  @doc """
  Analyze boundedness (WvdA resource guarantee).

  Returns `{:ok, analysis}` or `{:error, reason}` within 10 seconds.
  """
  def analyze_boundedness(process_id) do
    GenServer.call(__MODULE__, {:boundedness, process_id}, @default_timeout_ms)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("ProcessMining.Client timeout on analyze_boundedness for #{process_id}")
      {:error, :timeout}
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %{base_url: @pm4py_base_url}}
  end

  @impl true
  def handle_call({:discover, resource_type}, _from, state) do
    result = http_get(state.base_url, "/process/discover/#{resource_type}")
    {:reply, result, state}
  end

  def handle_call({:check_deadlock_free, process_id}, _from, state) do
    result =
      http_post(state.base_url, "/process/soundness/#{process_id}", %{"check" => "deadlock_free"})

    {:reply, result, state}
  end

  def handle_call({:reachability, process_id}, _from, state) do
    result = http_get(state.base_url, "/process/reachability/#{process_id}")
    {:reply, result, state}
  end

  def handle_call({:boundedness, process_id}, _from, state) do
    result =
      http_post(state.base_url, "/process/soundness/#{process_id}", %{"check" => "bounded"})

    {:reply, result, state}
  end

  # Private HTTP helpers

  defp http_get(base, path) do
    url = base <> path

    case Req.get(url, receive_timeout: @default_timeout_ms) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("ProcessMining HTTP GET #{path} returned #{status}: #{inspect(body)}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.warning("ProcessMining HTTP GET #{path} failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp http_post(base, path, body) do
    url = base <> path

    case Req.post(url, json: body, receive_timeout: @default_timeout_ms) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("ProcessMining HTTP POST #{path} returned #{status}: #{inspect(body)}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.warning("ProcessMining HTTP POST #{path} failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
