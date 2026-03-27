defmodule OptimalSystemAgent.Tools.Builtins.YawlWorkItem do
  @moduledoc """
  OSA tool for managing YAWL work items via Interface B.

  Enables agents to interact with the YAWL workflow engine: list enabled
  work items, check them out for execution, check them back in with output
  data, and retrieve child work items for multiple-instance tasks.

  Configuration via environment variables:
    YAWL_ENGINE_URL      — Base URL (default: http://localhost:8080)
    YAWL_SESSION_HANDLE  — Session handle for auth (default: test_session)
    YAWL_TIMEOUT         — Request timeout in ms (default: 30_000)

  Interface B endpoints used:
    GET  /ib?action=getAvailableWorkItems
    POST /ib  action=checkOut&workItemID=...&sessionHandle=...
    POST /ib  action=checkIn&workItemID=...&data=<xml>&sessionHandle=...
    GET  /ib?action=getChildren&workItemID=...
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  @default_engine_url "http://localhost:8080"
  @default_session_handle "test_session"
  @default_timeout 30_000

  @valid_operations ["list_enabled", "checkout", "checkin", "get_children"]

  # ──────────────────────────────────────────────────────────────────────────
  # Behaviour Implementation
  # ──────────────────────────────────────────────────────────────────────────

  @impl true
  def safety, do: :write_safe

  @impl true
  def name, do: "yawl_work_item"

  @impl true
  def description do
    """
    Manage YAWL workflow engine work items via Interface B.

    Supported operations:
    - list_enabled:  List all available/enabled work items (optionally filter by case_id)
    - checkout:      Check out a work item to begin execution (requires work_item_id)
    - checkin:       Check in a completed work item with output data (requires work_item_id)
    - get_children:  Get child work items for a multiple-instance task (requires work_item_id)

    Returns parsed work item data from the YAWL engine XML responses.
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
          "description" => "Operation to perform on YAWL work items"
        },
        "work_item_id" => %{
          "type" => "string",
          "description" =>
            "Work item ID (required for checkout, checkin, get_children). " <>
              "Format: caseID:taskID:uniqueID (e.g. \"1.1:TaskA:abc123\")"
        },
        "case_id" => %{
          "type" => "string",
          "description" => "Filter list_enabled results to this case ID (e.g. \"1.1\")"
        },
        "output_data" => %{
          "type" => "object",
          "description" =>
            "Output data map for checkin operation. " <>
              "Keys and values are converted to XML data elements."
        }
      },
      "required" => ["operation"]
    }
  end

  @impl true
  def execute(%{"operation" => operation} = params) when is_binary(operation) do
    with :ok <- validate_operation(operation) do
      dispatch(operation, params)
    end
  end

  def execute(_) do
    {:error, "Missing required parameter: operation"}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Operation Dispatch
  # ──────────────────────────────────────────────────────────────────────────

  defp dispatch("list_enabled", params) do
    case_id_filter = Map.get(params, "case_id")
    url = engine_url() <> "/ib"
    query = [action: "getAvailableWorkItems", sessionHandle: session_handle()]

    case http_get(url, query) do
      {:ok, body} ->
        work_items = parse_work_items(body)

        filtered =
          if case_id_filter do
            Enum.filter(work_items, fn item ->
              String.starts_with?(Map.get(item, "case_id", ""), case_id_filter)
            end)
          else
            work_items
          end

        {:ok,
         %{
           "operation" => "list_enabled",
           "work_items" => filtered,
           "count" => length(filtered)
         }}

      {:error, reason} ->
        Logger.warning("[YawlWorkItem] list_enabled failed: #{inspect(reason)}")
        {:error, format_error(reason)}
    end
  end

  defp dispatch("checkout", %{"work_item_id" => work_item_id}) when is_binary(work_item_id) do
    url = engine_url() <> "/ib"

    form = [
      action: "checkOut",
      workItemID: work_item_id,
      sessionHandle: session_handle()
    ]

    case http_post_form(url, form) do
      {:ok, body} ->
        work_items = parse_work_items(body)
        set_trace_context_from_work_item(work_item_id)

        {:ok,
         %{
           "operation" => "checkout",
           "work_item_id" => work_item_id,
           "checked_out" => work_items,
           "count" => length(work_items)
         }}

      {:error, reason} ->
        Logger.warning("[YawlWorkItem] checkout failed for #{work_item_id}: #{inspect(reason)}")
        {:error, format_error(reason)}
    end
  end

  defp dispatch("checkout", _params) do
    {:error, "checkout requires work_item_id parameter"}
  end

  defp dispatch("checkin", %{"work_item_id" => work_item_id} = params)
       when is_binary(work_item_id) do
    output_data = Map.get(params, "output_data", %{})
    xml_data = map_to_xml(output_data)
    url = engine_url() <> "/ib"

    form = [
      action: "checkIn",
      workItemID: work_item_id,
      data: xml_data,
      sessionHandle: session_handle()
    ]

    case http_post_form(url, form) do
      {:ok, body} ->
        {:ok,
         %{
           "operation" => "checkin",
           "work_item_id" => work_item_id,
           "output_data" => output_data,
           "response" => extract_result(body)
         }}

      {:error, reason} ->
        Logger.warning("[YawlWorkItem] checkin failed for #{work_item_id}: #{inspect(reason)}")
        {:error, format_error(reason)}
    end
  end

  defp dispatch("checkin", _params) do
    {:error, "checkin requires work_item_id parameter"}
  end

  defp dispatch("get_children", %{"work_item_id" => work_item_id})
       when is_binary(work_item_id) do
    url = engine_url() <> "/ib"

    query = [
      action: "getChildren",
      workItemID: work_item_id,
      sessionHandle: session_handle()
    ]

    case http_get(url, query) do
      {:ok, body} ->
        children = parse_work_items(body)

        {:ok,
         %{
           "operation" => "get_children",
           "work_item_id" => work_item_id,
           "children" => children,
           "count" => length(children)
         }}

      {:error, reason} ->
        Logger.warning(
          "[YawlWorkItem] get_children failed for #{work_item_id}: #{inspect(reason)}"
        )

        {:error, format_error(reason)}
    end
  end

  defp dispatch("get_children", _params) do
    {:error, "get_children requires work_item_id parameter"}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Trace Context (OTEL Petri Net Correlation)
  # ──────────────────────────────────────────────────────────────────────────

  # Work item IDs are in "caseID:taskID:uniqueID" format.
  # Extract the caseID prefix, look up the trace_id from EventStream ETS,
  # and store it in the process dictionary so subsequent OTEL span creation
  # in this agent process becomes a child of the YAWL case trace.
  defp set_trace_context_from_work_item(work_item_id) when is_binary(work_item_id) do
    case String.split(work_item_id, ":", parts: 2) do
      [case_id | _] when case_id != "" ->
        if trace_id = OptimalSystemAgent.Yawl.EventStream.lookup_trace_id(case_id) do
          Process.put(:osa_yawl_trace_id, trace_id)
          Process.put(:osa_yawl_case_id, case_id)
          Logger.debug("[YawlWorkItem] trace context set: case=#{case_id} trace=#{trace_id}")
        end

      _ ->
        :ignore
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # XML Parsing
  # ──────────────────────────────────────────────────────────────────────────

  # Parse one or more <workItem> elements from a YAWL XML response body.
  # Falls back to an empty list on any parse failure so callers always get a list.
  defp parse_work_items(body) when is_binary(body) do
    case extract_xml_blocks(body, "workItem") do
      [] ->
        []

      blocks ->
        Enum.map(blocks, &parse_single_work_item/1)
    end
  end

  defp parse_work_items(_), do: []

  defp parse_single_work_item(xml_block) do
    %{
      "work_item_id" => extract_tag(xml_block, "uniqueID"),
      "case_id" => extract_tag(xml_block, "caseID"),
      "task_id" => extract_tag(xml_block, "taskID"),
      "task_name" => extract_tag(xml_block, "taskName"),
      "status" => extract_tag(xml_block, "status"),
      "raw_xml" => xml_block
    }
  end

  # Extract all occurrences of <tag>...</tag> blocks from an XML string.
  defp extract_xml_blocks(xml, tag) when is_binary(xml) and is_binary(tag) do
    pattern = ~r/<#{Regex.escape(tag)}(?:\s[^>]*)?>.*?<\/#{Regex.escape(tag)}>/s
    Regex.scan(pattern, xml) |> Enum.map(fn [match] -> match end)
  end

  # Extract the text content of the first occurrence of <tag>value</tag>.
  defp extract_tag(xml, tag) when is_binary(xml) and is_binary(tag) do
    pattern = ~r/<#{Regex.escape(tag)}(?:\s[^>]*)?>([^<]*)<\/#{Regex.escape(tag)}>/

    case Regex.run(pattern, xml, capture: :all_but_first) do
      [value] -> String.trim(value)
      _ -> nil
    end
  end

  # Pull a plain-text result or success indicator from a YAWL response.
  defp extract_result(body) when is_binary(body) do
    cond do
      String.contains?(body, "<success>") ->
        case extract_tag(body, "success") do
          nil -> "ok"
          val -> val
        end

      String.contains?(body, "<failure>") ->
        case extract_tag(body, "failure") do
          nil -> "failed"
          val -> "failed: #{val}"
        end

      String.length(body) > 0 ->
        String.slice(body, 0, 200)

      true ->
        "ok"
    end
  end

  defp extract_result(_), do: "ok"

  # ──────────────────────────────────────────────────────────────────────────
  # XML Serialisation (map → YAWL data element XML)
  # ──────────────────────────────────────────────────────────────────────────

  # Converts a flat map of output data into a YAWL-style <data> XML element.
  # Non-string values are converted via inspect/1 so the output is always valid XML text.
  #
  # Example: %{"result" => "approved", "score" => 42}
  #   → "<data><result>approved</result><score>42</score></data>"
  defp map_to_xml(data) when is_map(data) do
    inner =
      data
      |> Enum.map(fn {k, v} ->
        tag = xml_safe_tag(k)
        value = xml_escape(to_string_value(v))
        "<#{tag}>#{value}</#{tag}>"
      end)
      |> Enum.join("")

    "<data>#{inner}</data>"
  end

  defp map_to_xml(_), do: "<data/>"

  defp xml_safe_tag(key) when is_binary(key) do
    # Strip characters not valid in XML element names; fall back to "field" if empty.
    cleaned = Regex.replace(~r/[^a-zA-Z0-9_\-.]/, key, "_")
    if cleaned == "", do: "field", else: cleaned
  end

  defp xml_safe_tag(key), do: xml_safe_tag(to_string(key))

  defp xml_escape(str) when is_binary(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp to_string_value(v) when is_binary(v), do: v
  defp to_string_value(v) when is_integer(v), do: Integer.to_string(v)
  defp to_string_value(v) when is_float(v), do: Float.to_string(v)
  defp to_string_value(v) when is_boolean(v), do: Atom.to_string(v)
  defp to_string_value(v), do: inspect(v)

  # ──────────────────────────────────────────────────────────────────────────
  # HTTP Helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp http_get(url, query_params) do
    req_opts = [
      url: url,
      method: :get,
      params: query_params,
      headers: [{"Accept", "application/xml, text/xml, */*"}],
      receive_timeout: timeout()
    ]

    # Step 3: Inject W3C traceparent header for distributed tracing
    req_opts_with_trace = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

    case Req.request(req_opts_with_trace) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[YawlWorkItem] GET HTTP #{status}: #{truncate(to_string(body), 200)}")
        {:error, "HTTP #{status}: #{truncate(to_string(body), 100)}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {"Connection failed", reason}}

      {:error, reason} ->
        {:error, {"Request failed", reason}}
    end
  end

  defp http_post_form(url, form_params) do
    encoded = URI.encode_query(form_params)

    req_opts = [
      url: url,
      method: :post,
      headers: [
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"Accept", "application/xml, text/xml, */*"}
      ],
      body: encoded,
      receive_timeout: timeout()
    ]

    # Step 3: Inject W3C traceparent header for distributed tracing
    req_opts_with_trace = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

    case Req.request(req_opts_with_trace) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[YawlWorkItem] POST HTTP #{status}: #{truncate(to_string(body), 200)}")
        {:error, "HTTP #{status}: #{truncate(to_string(body), 100)}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {"Connection failed", reason}}

      {:error, reason} ->
        {:error, {"Request failed", reason}}
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Configuration
  # ──────────────────────────────────────────────────────────────────────────

  defp engine_url do
    System.get_env("YAWL_ENGINE_URL") || @default_engine_url
  end

  defp session_handle do
    System.get_env("YAWL_SESSION_HANDLE") || @default_session_handle
  end

  defp timeout do
    case System.get_env("YAWL_TIMEOUT") do
      nil -> @default_timeout
      val -> String.to_integer(val)
    end
  rescue
    _ -> @default_timeout
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Utilities
  # ──────────────────────────────────────────────────────────────────────────

  defp validate_operation(op) do
    if op in @valid_operations do
      :ok
    else
      {:error,
       "Invalid operation: #{op}. Valid operations: #{Enum.join(@valid_operations, ", ")}"}
    end
  end

  defp format_error({label, reason}) when is_binary(label) do
    "#{label}: #{inspect(reason)}"
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp truncate(str, max) when byte_size(str) > max do
    String.slice(str, 0, max) <> "..."
  end

  defp truncate(str, _max), do: str
end
