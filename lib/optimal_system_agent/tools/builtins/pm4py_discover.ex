defmodule OptimalSystemAgent.Tools.Builtins.PM4PyDiscover do
  @moduledoc """
  OSA tool for process discovery using pm4py-rust.

  Enables agents to discover process models from event logs using various
  algorithms (Alpha Miner, Inductive Miner, Heuristic Miner, etc.) with
  optional conformance checking.

  Configuration via environment variables:
    PM4PY_HTTP_URL — Base URL (default: http://localhost:8090)
    PM4PY_TIMEOUT  — Request timeout in ms (default: 60_000)

  Budget integration: Reports discovery cost for agent planning.
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  @default_pm4py_url "http://localhost:8090"
  @default_timeout 60_000

  @valid_algorithms [
    "alpha_miner",
    "alpha_plus",
    "inductive_miner",
    "heuristic_miner",
    "causal_net",
    "split_miner",
    "declare",
    "log_skeleton",
    "ilp_miner"
  ]

  # ──────────────────────────────────────────────────────────────────────────
  # Behaviour Implementation
  # ──────────────────────────────────────────────────────────────────────────

  @impl true
  def safety, do: :sandboxed

  @impl true
  def name, do: "pm4py_discover"

  @impl true
  def description do
    """
    Discover process models from event logs using pm4py-rust.

    Supported algorithms:
    - alpha_miner: Classic Alpha Miner
    - alpha_plus: Alpha+ with lookahead
    - inductive_miner: Inductive Miner (flexible, recursive)
    - heuristic_miner: Heuristic-based (handles noise)
    - causal_net: Causal Net discovery
    - split_miner: Split Miner (control-flow intensive)
    - declare: Declare constraint mining
    - log_skeleton: Log Skeleton patterns
    - ilp_miner: Integer Linear Programming discovery

    Returns model structure, conformance metrics, and cost estimate for planning.
    """
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "event_log" => %{
          "type" => "string",
          "description" => "Event log as JSON string or CSV data"
        },
        "algorithm" => %{
          "type" => "string",
          "enum" => @valid_algorithms,
          "description" => "Discovery algorithm to use"
        },
        "conformance" => %{
          "type" => "boolean",
          "description" => "Whether to check conformance (default: true)"
        },
        "variant_analysis" => %{
          "type" => "boolean",
          "description" => "Whether to perform variant analysis (default: false)"
        }
      },
      "required" => ["event_log", "algorithm"]
    }
  end

  @impl true
  def execute(%{"event_log" => log_data, "algorithm" => algorithm} = params)
      when is_binary(log_data) and is_binary(algorithm) do
    conformance_enabled = Map.get(params, "conformance", true)
    _variant_analysis = Map.get(params, "variant_analysis", false)

    with :ok <- validate_algorithm(algorithm),
         {:ok, log_map} <- parse_log(log_data),
         {:ok, discovery_result} <- discover(log_map, algorithm),
         cost <- calculate_cost(log_map),
         conformance_result <- maybe_check_conformance(log_map, discovery_result, conformance_enabled),
         {:ok, merged} <- merge_results(discovery_result, conformance_result) do
      {:ok,
       %{
         "model" => merged,
         "cost" => cost,
         "algorithm" => algorithm,
         "log_stats" => %{
           "trace_count" => map_get_int(log_map, "trace_count", 0),
           "event_count" => map_get_int(log_map, "event_count", 0)
         }
       }}
    else
      {:error, reason} ->
        Logger.warning("[PM4PyDiscover] Discovery failed: #{reason}")
        {:error, reason}
    end
  end

  def execute(_) do
    {:error, "Missing required parameters: event_log, algorithm"}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Private Helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp validate_algorithm(algo) do
    if algo in @valid_algorithms do
      :ok
    else
      {:error, "Invalid algorithm: #{algo}. Valid: #{Enum.join(@valid_algorithms, ", ")}"}
    end
  end

  defp parse_log(log_data) when is_binary(log_data) do
    # Try JSON first, then assume CSV
    case Jason.decode(log_data) do
      {:ok, map} when is_map(map) ->
        {:ok, map}

      {:error, _} ->
        # Try CSV format (comma-separated, newline-delimited)
        parse_csv_log(log_data)

      _ ->
        {:error, "Event log must be valid JSON or CSV"}
    end
  end

  defp parse_csv_log(csv_data) when is_binary(csv_data) do
    lines = String.split(csv_data, "\n", trim: true)

    case lines do
      [header_line | data_lines] ->
        headers = String.split(header_line, ",", trim: true)

        events =
          data_lines
          |> Enum.map(&parse_csv_line(&1, headers))
          |> Enum.filter(&is_map/1)

        if Enum.empty?(events) do
          {:error, "CSV log contains no valid events"}
        else
          {:ok,
           %{
             "events" => events,
             "trace_count" => events |> Enum.map(&Map.get(&1, "case_id")) |> Enum.uniq() |> length(),
             "event_count" => length(events)
           }}
        end

      _ ->
        {:error, "CSV log must have header and data rows"}
    end
  end

  defp parse_csv_line(line, headers) do
    values = String.split(line, ",", trim: true)

    if length(values) == length(headers) do
      Enum.zip(headers, values) |> Map.new()
    else
      nil
    end
  end

  defp discover(log_map, algorithm) do
    url = pm4py_url() <> "/api/discover"
    payload = %{"log" => log_map, "algorithm" => algorithm}

    case http_post(url, payload) do
      {:ok, %{"model" => _model} = result} ->
        {:ok, result}

      {:ok, %{"error" => error}} ->
        {:error, "pm4py discovery error: #{error}"}

      {:error, reason} ->
        {:error, "Discovery HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp maybe_check_conformance(_log_map, _discovery_result, false) do
    # Conformance disabled
    nil
  end

  defp maybe_check_conformance(log_map, discovery_result, true) do
    url = pm4py_url() <> "/api/conformance"
    payload = %{"log" => log_map, "model" => Map.get(discovery_result, "model", %{})}

    case http_post(url, payload) do
      {:ok, result} ->
        result

      {:error, reason} ->
        Logger.warning("[PM4PyDiscover] Conformance check failed: #{inspect(reason)}")
        nil
    end
  end

  defp calculate_cost(log_map) do
    trace_count = map_get_int(log_map, "trace_count", 0)
    event_count = map_get_int(log_map, "event_count", 0)

    # Cost formula: 10 (base) + 5 * traces + 2 * events
    # Capped at reasonable max (avoid overflow for huge logs)
    base_cost = 10
    trace_cost = min(trace_count * 5, 10_000)
    event_cost = min(event_count * 2, 10_000)

    base_cost + trace_cost + event_cost
  end

  defp merge_results(discovery_result, conformance_result) do
    model = Map.get(discovery_result, "model", %{})

    merged = %{
      "model" => model,
      "algorithm_metadata" => Map.get(discovery_result, "metadata", %{})
    }

    merged =
      if is_map(conformance_result) do
        Map.put(merged, "conformance", conformance_result)
      else
        merged
      end

    {:ok, merged}
  end

  defp http_post(url, payload) do
    timeout = timeout()

    req_opts = [
      url: url,
      method: :post,
      headers: [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ],
      json: payload,
      receive_timeout: timeout
    ]

    case Req.request(req_opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, "Invalid JSON response"}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[PM4PyDiscover] HTTP #{status}: #{truncate(body, 200)}")
        {:error, "HTTP #{status}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {"Connection failed", reason}}

      {:error, reason} ->
        {:error, {"Request failed", reason}}
    end
  end

  defp pm4py_url do
    System.get_env("PM4PY_HTTP_URL") || @default_pm4py_url
  end

  defp timeout do
    case System.get_env("PM4PY_TIMEOUT") do
      nil -> @default_timeout
      val -> String.to_integer(val)
    end
  rescue
    _ -> @default_timeout
  end

  defp truncate(str, max) when byte_size(str) > max do
    String.slice(str, 0, max) <> "..."
  end

  defp truncate(str, _max), do: str

  defp map_get_int(map, key, default) when is_map(map) do
    case Map.get(map, key) do
      val when is_integer(val) -> val
      _ -> default
    end
  end

  defp map_get_int(_map, _key, default), do: default
end
