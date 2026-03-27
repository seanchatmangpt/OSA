defmodule OptimalSystemAgent.Tools.Builtins.YawlProcessMining do
  @moduledoc """
  YAWL → pm4py-rust process mining bridge tool.

  Chains two HTTP calls:

    1. Pull XES event log from the YAWL engine's logGateway endpoint.
    2. Send the parsed event log to pm4py-rust for discovery, conformance, or statistics.

  XES (IEEE XES XML) is parsed via Erlang's built-in :xmerl_scan into a JSON-serialisable
  map structure before forwarding to pm4py-rust — no extra XML dependency required.

  ## Configuration (environment variables)

    YAWL_ENGINE_URL — YAWL base URL            (default: http://localhost:8080)
    PM4PY_HTTP_URL  — pm4py-rust base URL       (default: http://localhost:8090)
    PM4PY_TIMEOUT   — Request timeout in ms     (default: 60_000)

  ## Operations

    discover           — Alpha/Inductive/Heuristic Miner on live YAWL log
    check_conformance  — Token-replay fitness/precision against a Petri net
    get_statistics     — Case/activity/performance statistics from live log
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  @default_yawl_url "http://localhost:8080"
  @default_pm4py_url "http://localhost:8090"
  @default_timeout 60_000

  @valid_algorithms ~w[alpha_miner alpha_plus inductive_miner heuristic_miner]
  @valid_operations ~w[discover check_conformance get_statistics]

  # ────────────────────────────────────────────────────────────────────────────
  # Behaviour implementation
  # ────────────────────────────────────────────────────────────────────────────

  @impl true
  def safety, do: :sandboxed

  @impl true
  def name, do: "yawl_process_mining"

  @impl true
  def description do
    """
    Pull XES event logs from a live YAWL engine and analyse them with pm4py-rust.

    Operations:
    - discover          : Discover a process model (Petri net) from the YAWL execution log.
    - check_conformance : Measure fitness/precision of a Petri net against the YAWL log.
    - get_statistics    : Return case count, activity frequencies, and performance stats.

    Requires the YAWL engine (YAWL_ENGINE_URL) and pm4py-rust (PM4PY_HTTP_URL) to be running.
    """
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "operation" => %{
          "type" => "string",
          "enum" => @valid_operations,
          "description" => "Mining operation: discover | check_conformance | get_statistics"
        },
        "spec_id" => %{
          "type" => "string",
          "description" => "YAWL specification ID whose log should be fetched (e.g. 'OrderFulfillment.ywl')"
        },
        "algorithm" => %{
          "type" => "string",
          "enum" => @valid_algorithms,
          "description" => "Discovery algorithm (discover only, default: alpha_miner)"
        },
        "petri_net" => %{
          "type" => "object",
          "description" => "Petri net JSON structure (check_conformance only)"
        }
      },
      "required" => ["operation", "spec_id"]
    }
  end

  @impl true
  def execute(%{"operation" => operation, "spec_id" => spec_id} = params)
      when is_binary(operation) and is_binary(spec_id) do
    with :ok <- validate_operation(operation),
         {:ok, xes_xml} <- fetch_xes_from_yawl(spec_id),
         {:ok, event_log} <- parse_xes(xes_xml) do
      dispatch(operation, event_log, params)
    else
      {:error, reason} ->
        Logger.warning("[YawlProcessMining] Failed for spec=#{spec_id} op=#{operation}: #{reason}")
        {:error, reason}
    end
  end

  def execute(_params) do
    {:error, "Missing required parameters: operation, spec_id"}
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Dispatch to operation handlers
  # ────────────────────────────────────────────────────────────────────────────

  defp dispatch("discover", event_log, params) do
    algorithm = Map.get(params, "algorithm", "alpha_miner")
    do_discover(event_log, algorithm)
  end

  defp dispatch("check_conformance", event_log, params) do
    petri_net = Map.get(params, "petri_net")
    do_check_conformance(event_log, petri_net)
  end

  defp dispatch("get_statistics", event_log, _params) do
    do_get_statistics(event_log)
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Step 1 — Fetch XES from YAWL logGateway
  # ────────────────────────────────────────────────────────────────────────────

  defp fetch_xes_from_yawl(spec_id) do
    url = yawl_url() <> "/logGateway"
    query = URI.encode_query(%{"action" => "getSpecificationXESLog", "specID" => spec_id})
    full_url = "#{url}?#{query}"

    Logger.debug("[YawlProcessMining] Fetching XES from #{full_url}")

    req_opts = [
      url: full_url,
      method: :get,
      headers: [{"Accept", "application/xml, text/xml, */*"}],
      receive_timeout: timeout()
    ]

    case Req.request(req_opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        if is_binary(body) and byte_size(body) > 0 do
          {:ok, body}
        else
          {:error, "YAWL returned an empty XES log for spec_id=#{spec_id}"}
        end

      {:ok, %{status: 404}} ->
        {:error, "YAWL spec not found: #{spec_id}"}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[YawlProcessMining] YAWL HTTP #{status}: #{truncate(body, 300)}")
        {:error, "YAWL logGateway returned HTTP #{status}"}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error,
         "YAWL engine is not reachable at #{yawl_url()} — is the engine running? Set YAWL_ENGINE_URL if needed."}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "YAWL connection failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "YAWL request failed: #{inspect(reason)}"}
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # XES XML → JSON event log conversion (using :xmerl_scan — built-in OTP)
  #
  # IEEE XES structure:
  #   <log>
  #     <trace>
  #       <string key="concept:name" value="case-42"/>
  #       <event>
  #         <string key="concept:name"  value="Submit Order"/>
  #         <date   key="time:timestamp" value="2026-01-01T10:00:00Z"/>
  #         <string key="lifecycle:transition" value="complete"/>
  #       </event>
  #       ...
  #     </trace>
  #     ...
  #   </log>
  #
  # We convert to the map shape pm4py_discover.ex uses:
  #   %{
  #     "events"      => [%{"case_id" => ..., "activity" => ..., "timestamp" => ..., ...}],
  #     "trace_count" => integer,
  #     "event_count" => integer
  #   }
  # ────────────────────────────────────────────────────────────────────────────

  defp parse_xes(xes_xml) when is_binary(xes_xml) do
    # :xmerl_scan requires a charlist
    xml_chars = String.to_charlist(xes_xml)

    try do
      {root, _rest} =
        :xmerl_scan.string(xml_chars,
          quiet: true,
          # Suppress DTD fetch warnings — XES references external schemas
          fetch_fun: fn _uri, state -> {:ok, {[], state}} end
        )

      events = extract_events(root)
      trace_count = events |> Enum.map(&Map.get(&1, "case_id")) |> Enum.uniq() |> length()

      {:ok,
       %{
         "events" => events,
         "trace_count" => trace_count,
         "event_count" => length(events)
       }}
    catch
      :exit, reason ->
        {:error, "XES XML parse error: #{inspect(reason)}"}
    end
  end

  # Extract all events from the :xmerl element tree.
  # Handles both <trace> children (standard XES) and top-level <event> children.
  defp extract_events({:xmlElement, :log, _, _, _, _, _, _, children, _, _, _}) do
    children
    |> Enum.flat_map(fn
      {:xmlElement, :trace, _, _, _, _, _, _, trace_children, _, _, _} ->
        case_id = extract_trace_id(trace_children)
        extract_trace_events(trace_children, case_id)

      {:xmlElement, :event, _, _, _, _, _, _, event_children, _, _, _} ->
        # Top-level events (no enclosing trace)
        [xes_attrs_to_event(event_children, "unknown")]

      _ ->
        []
    end)
  end

  defp extract_events(_other), do: []

  defp extract_trace_id(trace_children) do
    trace_children
    |> Enum.find_value("unknown", fn
      {:xmlElement, :string, _, _, _, _, attrs, _, _, _, _, _} ->
        if xmerl_attr(attrs, "key") == "concept:name" do
          xmerl_attr(attrs, "value") || "unknown"
        end

      _ ->
        nil
    end)
  end

  defp extract_trace_events(trace_children, case_id) do
    trace_children
    |> Enum.flat_map(fn
      {:xmlElement, :event, _, _, _, _, _, _, event_children, _, _, _} ->
        [xes_attrs_to_event(event_children, case_id)]

      _ ->
        []
    end)
  end

  # Convert XES <event> attribute elements into a flat map.
  # XES attribute elements are: <string key="..." value="..."/> etc.
  defp xes_attrs_to_event(event_children, case_id) do
    attr_map =
      event_children
      |> Enum.reduce(%{}, fn
        {:xmlElement, tag, _, _, _, _, attrs, _, _, _, _, _}, acc
        when tag in [:string, :date, :int, :float, :boolean, :id, :list, :container] ->
          key = xmerl_attr(attrs, "key")
          value = xmerl_attr(attrs, "value")

          if key && value do
            Map.put(acc, to_string(key), to_string(value))
          else
            acc
          end

        _, acc ->
          acc
      end)

    # Normalise well-known XES keys to the field names pm4py-rust expects
    activity = Map.get(attr_map, "concept:name", Map.get(attr_map, "Activity", "unknown"))
    timestamp = Map.get(attr_map, "time:timestamp", Map.get(attr_map, "time", ""))

    base = %{
      "case_id" => case_id,
      "activity" => activity,
      "timestamp" => timestamp
    }

    # Merge remaining attributes as extra context (lifecycle, resource, etc.)
    Map.merge(attr_map, base)
  end

  defp xmerl_attr(attrs, name) when is_list(attrs) do
    name_atom = if is_atom(name), do: name, else: String.to_atom(name)

    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name_atom, _, _, _, _, _, _, value, _} ->
        to_string(value)

      _ ->
        nil
    end)
  end

  defp xmerl_attr(_, _), do: nil

  # ────────────────────────────────────────────────────────────────────────────
  # Step 2a — Discover
  # ────────────────────────────────────────────────────────────────────────────

  defp do_discover(event_log, algorithm) do
    url = pm4py_url() <> "/api/discovery/alpha"

    payload = %{
      "event_log" => event_log,
      "variant" => algorithm
    }

    case http_post(url, payload) do
      {:ok, %{"model" => petri_net} = result} ->
        {:ok,
         %{
           "petri_net" => petri_net,
           "trace_count" => get_in(event_log, ["trace_count"]) || 0,
           "algorithm" => algorithm,
           "metadata" => Map.get(result, "metadata", %{})
         }}

      {:ok, %{"petri_net" => petri_net} = result} ->
        # Alternative shape some pm4py-rust versions return
        {:ok,
         %{
           "petri_net" => petri_net,
           "trace_count" => get_in(event_log, ["trace_count"]) || 0,
           "algorithm" => algorithm,
           "metadata" => Map.get(result, "metadata", %{})
         }}

      {:ok, %{"error" => err}} ->
        {:error, "pm4py-rust discovery error: #{err}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Step 2b — Conformance (token replay)
  # ────────────────────────────────────────────────────────────────────────────

  defp do_check_conformance(_event_log, nil) do
    {:error,
     "check_conformance requires a petri_net parameter. " <>
       "Run discover first to obtain one, then pass it back."}
  end

  defp do_check_conformance(event_log, petri_net) do
    url = pm4py_url() <> "/api/conformance/token-replay"

    payload = %{
      "event_log" => event_log,
      "petri_net" => petri_net
    }

    case http_post(url, payload) do
      {:ok, result} when is_map(result) ->
        fitness = Map.get(result, "fitness", Map.get(result, "average_trace_fitness"))
        precision = Map.get(result, "precision")

        {:ok,
         %{
           "fitness" => fitness,
           "precision" => precision,
           "is_conformant" => is_conformant?(fitness),
           "raw" => result
         }}

      {:ok, %{"error" => err}} ->
        {:error, "pm4py-rust conformance error: #{err}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp is_conformant?(fitness) when is_float(fitness), do: fitness >= 0.8
  defp is_conformant?(fitness) when is_integer(fitness), do: fitness >= 1
  defp is_conformant?(_), do: nil

  # ────────────────────────────────────────────────────────────────────────────
  # Step 2c — Statistics
  # ────────────────────────────────────────────────────────────────────────────

  defp do_get_statistics(event_log) do
    url = pm4py_url() <> "/api/statistics"

    case http_post(url, %{"event_log" => event_log}) do
      {:ok, result} when is_map(result) ->
        # Supplement with counts derived locally so callers always get them,
        # even if pm4py-rust omits them.
        enriched =
          result
          |> Map.put_new("trace_count", Map.get(event_log, "trace_count", 0))
          |> Map.put_new("event_count", Map.get(event_log, "event_count", 0))

        {:ok, enriched}

      {:ok, %{"error" => err}} ->
        {:error, "pm4py-rust statistics error: #{err}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # HTTP helpers
  # ────────────────────────────────────────────────────────────────────────────

  defp http_post(url, payload) do
    Logger.debug("[YawlProcessMining] POST #{url}")

    req_opts = [
      url: url,
      method: :post,
      headers: [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ],
      json: payload,
      receive_timeout: timeout()
    ]

    case Req.request(req_opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        case maybe_decode(body) do
          {:ok, decoded} ->
            {:ok, decoded}

          {:error, _} ->
            {:error, "pm4py-rust returned non-JSON response (status #{status})"}
        end

      {:ok, %{status: status, body: body}} ->
        body_preview = if is_binary(body), do: truncate(body, 300), else: inspect(body)
        Logger.warning("[YawlProcessMining] pm4py-rust HTTP #{status}: #{body_preview}")
        {:error, "pm4py-rust returned HTTP #{status}"}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error,
         "pm4py-rust is not reachable at #{pm4py_url()} — is pm4py-rust running? Set PM4PY_HTTP_URL if needed."}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "pm4py-rust connection failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "pm4py-rust request failed: #{inspect(reason)}"}
    end
  end

  # Req with json: already decodes; guard for raw-binary responses just in case.
  defp maybe_decode(body) when is_map(body), do: {:ok, body}
  defp maybe_decode(body) when is_list(body), do: {:ok, body}

  defp maybe_decode(body) when is_binary(body) do
    Jason.decode(body)
  end

  defp maybe_decode(body), do: {:ok, body}

  # ────────────────────────────────────────────────────────────────────────────
  # Validation
  # ────────────────────────────────────────────────────────────────────────────

  defp validate_operation(op) do
    if op in @valid_operations do
      :ok
    else
      {:error,
       "Invalid operation: #{op}. Valid operations: #{Enum.join(@valid_operations, ", ")}"}
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Config helpers
  # ────────────────────────────────────────────────────────────────────────────

  defp yawl_url do
    (System.get_env("YAWL_ENGINE_URL") || @default_yawl_url)
    |> String.trim_trailing("/")
  end

  defp pm4py_url do
    (System.get_env("PM4PY_HTTP_URL") || @default_pm4py_url)
    |> String.trim_trailing("/")
  end

  defp timeout do
    case System.get_env("PM4PY_TIMEOUT") do
      nil -> @default_timeout
      val -> String.to_integer(val)
    end
  rescue
    _ -> @default_timeout
  end

  defp truncate(str, max) when is_binary(str) and byte_size(str) > max do
    String.slice(str, 0, max) <> "..."
  end

  defp truncate(str, _max), do: str
end
