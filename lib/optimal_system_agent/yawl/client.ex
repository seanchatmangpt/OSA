defmodule OptimalSystemAgent.Yawl.Client do
  @moduledoc """
  GenServer HTTP client for the YAWL process-mining engine.

  Provides three operations against the YAWL engine running at the configured
  base URL (default: http://localhost:8080):

    * `health/0`             — GET /health.jsp
    * `discover/1`           — POST /api/process-mining/discover
    * `check_conformance/2`  — POST /api/process-mining/conformance

  All GenServer calls carry an explicit 10-second timeout.  Network or parse
  failures are normalised to tagged error tuples; the raw Req error is never
  propagated to callers.
  """

  use GenServer

  require Logger

  @timeout_ms 10_000
  @name __MODULE__

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Returns `:ok` when the YAWL engine responds with HTTP 200, otherwise
  `{:error, :unreachable | :timeout}`.
  """
  @spec health() :: :ok | {:error, :unreachable | :timeout}
  def health do
    try do
      GenServer.call(@name, :health, @timeout_ms)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc """
  POST an event log (JSON-encoded string) to the Alpha Miner discovery endpoint.

  Returns `{:ok, map}` on success or `{:error, reason}` on failure.
  """
  @spec discover(String.t()) :: {:ok, map()} | {:error, term()}
  def discover(event_log_json) do
    try do
      GenServer.call(@name, {:discover, event_log_json}, @timeout_ms)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc """
  POST a YAWL XML spec and an event log (JSON-encoded string) to the conformance
  endpoint.

  Returns `{:ok, %{fitness: float, violations: list}}` on success or
  `{:error, reason}` on failure.
  """
  @spec check_conformance(String.t(), String.t()) ::
          {:ok, %{fitness: float(), violations: list()}} | {:error, term()}
  def check_conformance(spec_xml, event_log_json) do
    try do
      GenServer.call(@name, {:check_conformance, spec_xml, event_log_json}, @timeout_ms)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    base_url =
      Application.get_env(:optimal_system_agent, :yawl_url, "http://localhost:8080")

    {:ok, %{base_url: base_url}}
  end

  @impl true
  def handle_call(:health, _from, %{base_url: base_url} = state) do
    url = base_url <> "/health.jsp"

    result =
      case Req.get(url, receive_timeout: @timeout_ms) do
        {:ok, %{status: status}} when status in 200..299 -> :ok
        {:ok, _} -> {:error, :unreachable}
        {:error, _} -> {:error, :unreachable}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:discover, event_log_json}, _from, %{base_url: base_url} = state) do
    url = base_url <> "/api/process-mining/discover"

    body =
      case Jason.decode(event_log_json) do
        {:ok, decoded} -> decoded
        {:error, _} -> %{"raw" => event_log_json}
      end

    result =
      case Req.post(url, json: body, receive_timeout: @timeout_ms) do
        {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
          parsed =
            case resp_body do
              map when is_map(map) -> map
              binary when is_binary(binary) -> Jason.decode!(binary)
              other -> %{"result" => other}
            end

          {:ok, parsed}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

        {:error, _} ->
          {:error, :yawl_unavailable}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(
        {:check_conformance, spec_xml, event_log_json},
        _from,
        %{base_url: base_url} = state
      ) do
    url = base_url <> "/api/process-mining/conformance"

    event_log =
      case Jason.decode(event_log_json) do
        {:ok, decoded} -> decoded
        {:error, _} -> %{"raw" => event_log_json}
      end

    body = %{"spec_xml" => spec_xml, "event_log" => event_log}

    result =
      case Req.post(url, json: body, receive_timeout: @timeout_ms) do
        {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
          parsed =
            case resp_body do
              map when is_map(map) -> map
              binary when is_binary(binary) -> Jason.decode!(binary)
              other -> %{"result" => other}
            end

          fitness = Map.get(parsed, "fitness", 0.0)
          violations = Map.get(parsed, "violations", [])
          {:ok, %{fitness: fitness, violations: violations}}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

        {:error, _} ->
          {:error, :yawl_unavailable}
      end

    {:reply, result, state}
  end
end
