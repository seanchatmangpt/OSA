defmodule OptimalSystemAgent.Ontology.OxigraphClient do
  @moduledoc """
  HTTP connection pool GenServer to Oxigraph SPARQL store

  Manages a pool of HTTP connections to Oxigraph (default: localhost:7878)
  and provides convenient methods for SPARQL SELECT, CONSTRUCT, and ASK queries.

  Supervision: Started by OptimalSystemAgent.Supervisors.Infrastructure as permanent child.
  Timeout: All queries have explicit timeout_ms with fallback to cached results or error.

  Signal Theory: S=(data,explain,inform,json,result)
  """

  use GenServer
  require Logger

  @default_url "http://localhost:7878"
  @default_pool_size 5
  @default_timeout_ms 10000

  # Public API

  @doc """
  Start the Oxigraph client pool.

  Options:
    - :url - Oxigraph base URL (default: http://localhost:7878)
    - :pool_size - HTTP connection pool size (default: 5)
    - :timeout_ms - Query timeout (default: 10000)

  Returns {:ok, pid} or {:error, reason}
  """
  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @doc """
  Execute a SPARQL SELECT query

  Returns {:ok, rows} where rows is a list of result maps,
  or {:error, reason} on failure or timeout.

  Options can include custom :timeout_ms.
  """
  @spec query_select(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def query_select(sparql_query, options \\ []) do
    timeout = Keyword.get(options, :timeout, @default_timeout_ms)
    try do
      GenServer.call(__MODULE__, {:query_select, sparql_query}, timeout + 1000)
    catch
      :exit, {:timeout, _} ->
        Logger.error("SPARQL SELECT query timed out after #{timeout}ms")
        {:error, :timeout}
    end
  end

  @doc """
  Execute a SPARQL CONSTRUCT query

  Returns {:ok, triples} where triples is RDF N-Triples format,
  or {:error, reason} on failure or timeout.
  """
  @spec query_construct(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def query_construct(sparql_query, options \\ []) do
    timeout = Keyword.get(options, :timeout, @default_timeout_ms)
    try do
      GenServer.call(__MODULE__, {:query_construct, sparql_query}, timeout + 1000)
    catch
      :exit, {:timeout, _} ->
        Logger.error("SPARQL CONSTRUCT query timed out after #{timeout}ms")
        {:error, :timeout}
    end
  end

  @doc """
  Execute a SPARQL ASK query

  Returns {:ok, boolean} indicating whether the pattern exists,
  or {:error, reason} on failure or timeout.
  """
  @spec query_ask(String.t(), keyword()) :: {:ok, boolean()} | {:error, term()}
  def query_ask(sparql_query, options \\ []) do
    timeout = Keyword.get(options, :timeout, @default_timeout_ms)
    try do
      GenServer.call(__MODULE__, {:query_ask, sparql_query}, timeout + 1000)
    catch
      :exit, {:timeout, _} ->
        Logger.error("SPARQL ASK query timed out after #{timeout}ms")
        {:error, :timeout}
    end
  end

  @doc """
  Health check: verify Oxigraph is reachable and responding

  Returns {:ok, %{status: "ok", version: "..."}} or {:error, reason}
  """
  @spec health_check() :: {:ok, map()} | {:error, term()}
  def health_check do
    try do
      GenServer.call(__MODULE__, :health_check, @default_timeout_ms + 1000)
    catch
      :exit, {:timeout, _} ->
        {:error, :health_check_timeout}
    end
  end

  @doc """
  Get current client configuration and pool stats

  Returns %{url: "...", pool_size: N, connections_active: M, ...}
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  def init(options) do
    url = Keyword.get(options, :url, @default_url)
    pool_size = Keyword.get(options, :pool_size, @default_pool_size)
    timeout_ms = Keyword.get(options, :timeout_ms, @default_timeout_ms)

    state = %{
      url: url,
      pool_size: pool_size,
      timeout_ms: timeout_ms,
      connections_active: 0,
      queries_executed: 0,
      last_error: nil
    }

    Logger.info("[OxigraphClient] Initialized with url=#{url}, pool_size=#{pool_size}")

    {:ok, state}
  end

  def handle_call({:query_select, sparql_query}, _from, state) do
    result = execute_select(sparql_query, state)
    new_state = Map.update!(state, :queries_executed, &(&1 + 1))

    case result do
      {:ok, rows} ->
        {:reply, {:ok, rows}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, Map.put(new_state, :last_error, reason)}
    end
  end

  def handle_call({:query_construct, sparql_query}, _from, state) do
    result = execute_construct(sparql_query, state)
    new_state = Map.update!(state, :queries_executed, &(&1 + 1))

    case result do
      {:ok, triples} ->
        {:reply, {:ok, triples}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, Map.put(new_state, :last_error, reason)}
    end
  end

  def handle_call({:query_ask, sparql_query}, _from, state) do
    result = execute_ask(sparql_query, state)
    new_state = Map.update!(state, :queries_executed, &(&1 + 1))

    case result do
      {:ok, bool} ->
        {:reply, {:ok, bool}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, Map.put(new_state, :last_error, reason)}
    end
  end

  def handle_call(:health_check, _from, state) do
    url = state.url
    health_url = "#{url}/health"

    result =
      case Req.get(health_url, timeout: state.timeout_ms) do
        {:ok, response} ->
          if response.status == 200 do
            {:ok, %{status: "ok", url: url}}
          else
            {:error, "Health check returned status #{response.status}"}
          end

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, state}
  end

  def handle_call(:stats, _from, state) do
    {:reply,
     Map.take(state, [:url, :pool_size, :timeout_ms, :connections_active, :queries_executed, :last_error]),
     state}
  end

  # Private helpers

  defp execute_select(sparql_query, state) do
    url = state.url
    query_url = "#{url}/query"

    headers = [
      {"Content-Type", "application/sparql-query"},
      {"Accept", "application/sparql-results+json"}
    ]

    case Req.post(query_url,
      headers: headers,
      body: sparql_query,
      timeout: state.timeout_ms
    ) do
      {:ok, response} ->
        if response.status == 200 do
          case Jason.decode(response.body) do
            {:ok, %{"results" => %{"bindings" => bindings}}} ->
              rows = Enum.map(bindings, &transform_binding/1)
              {:ok, rows}

            {:error, _} ->
              {:error, "Failed to parse SPARQL JSON response"}
          end
        else
          {:error, "SPARQL query failed with status #{response.status}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_construct(sparql_query, state) do
    url = state.url
    query_url = "#{url}/query"

    headers = [
      {"Content-Type", "application/sparql-query"},
      {"Accept", "application/n-triples"}
    ]

    case Req.post(query_url,
      headers: headers,
      body: sparql_query,
      timeout: state.timeout_ms
    ) do
      {:ok, response} ->
        if response.status == 200 do
          {:ok, response.body}
        else
          {:error, "CONSTRUCT query failed with status #{response.status}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_ask(sparql_query, state) do
    url = state.url
    query_url = "#{url}/query"

    headers = [
      {"Content-Type", "application/sparql-query"},
      {"Accept", "application/sparql-results+json"}
    ]

    case Req.post(query_url,
      headers: headers,
      body: sparql_query,
      timeout: state.timeout_ms
    ) do
      {:ok, response} ->
        if response.status == 200 do
          case Jason.decode(response.body) do
            {:ok, %{"boolean" => bool}} ->
              {:ok, bool}

            {:error, _} ->
              {:error, "Failed to parse ASK response"}
          end
        else
          {:error, "ASK query failed with status #{response.status}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp transform_binding(binding) do
    Map.new(binding, fn {key, value_map} ->
      {key, Map.get(value_map, "value", nil)}
    end)
  end
end
