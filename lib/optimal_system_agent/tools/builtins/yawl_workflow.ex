defmodule OptimalSystemAgent.Tools.Builtins.YawlWorkflow do
  @moduledoc """
  OSA tool for managing YAWL workflow cases via Interface A.

  Enables agents to upload YAWL specifications, launch and cancel workflow
  cases, query case state, and list all running cases against a YAWL engine.

  YAWL Interface A communicates via HTTP form-encoded POST (actions that
  mutate state) and query-string GET (read-only queries). Responses are XML
  fragments; success is indicated by `<success>…</success>` and failure by
  `<failure>…</failure>`.

  Configuration via environment variables:
    YAWL_ENGINE_URL — Base URL of the YAWL engine (default: http://localhost:8080)
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  @default_engine_url "http://localhost:8080"
  @default_timeout 30_000

  @valid_operations [
    "upload_spec",
    "launch_case",
    "cancel_case",
    "get_case_state",
    "list_cases"
  ]

  # ──────────────────────────────────────────────────────────────────────────
  # Behaviour Implementation
  # ──────────────────────────────────────────────────────────────────────────

  @impl true
  def safety, do: :write_safe

  @impl true
  def name, do: "yawl_workflow"

  @impl true
  def description do
    """
    Manage YAWL workflow cases via Interface A.

    Supported operations:
    - upload_spec:     Upload a YAWL specification XML to the engine (requires spec_xml)
    - launch_case:     Launch a new case from a loaded specification (requires spec_id)
    - cancel_case:     Cancel a running case (requires case_id)
    - get_case_state:  Retrieve the current state of a running case (requires case_id)
    - list_cases:      List all currently running cases (no extra parameters required)

    Returns a result map with operation outcome, parsed value from the YAWL XML
    response, and the raw XML for diagnostics.
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
          "description" => "YAWL Interface A operation to perform"
        },
        "spec_xml" => %{
          "type" => "string",
          "description" => "YAWL specification XML string (required for upload_spec)"
        },
        "spec_id" => %{
          "type" => "string",
          "description" => "Specification identifier as returned by upload_spec (required for launch_case)"
        },
        "case_id" => %{
          "type" => "string",
          "description" => "Running case identifier (required for cancel_case and get_case_state)"
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

  defp dispatch("upload_spec", %{"spec_xml" => spec_xml}) when is_binary(spec_xml) do
    ia_post(%{"action" => "upload", "specXML" => spec_xml})
  end

  defp dispatch("upload_spec", _params) do
    {:error, "upload_spec requires spec_xml parameter"}
  end

  defp dispatch("launch_case", %{"spec_id" => spec_id}) when is_binary(spec_id) do
    case ia_post(%{"action" => "launchCase", "specID" => spec_id}) do
      {:ok, %{"status" => "success", "value" => case_id} = result} when case_id != "" ->
        # Step 4: Subscribe EventStream to create case → trace_id mapping
        OptimalSystemAgent.Yawl.EventStream.subscribe(case_id)

        # Step 5: Verify trace_id created and log for task correlation
        trace_id = OptimalSystemAgent.Yawl.EventStream.lookup_trace_id(case_id)

        if trace_id do
          Logger.debug(
            "[YawlWorkflow] Launched case #{case_id} with trace_id=#{trace_id}"
          )

          # Return result with trace_id embedded for downstream task correlation
          {:ok, Map.put(result, "trace_id", trace_id)}
        else
          Logger.warning(
            "[YawlWorkflow] Case #{case_id} launched but trace_id not yet in ETS (EventStream may be async)"
          )

          # Still succeed — trace_id will be available shortly via EventStream
          {:ok, result}
        end

      other ->
        other
    end
  end

  defp dispatch("launch_case", _params) do
    {:error, "launch_case requires spec_id parameter"}
  end

  defp dispatch("cancel_case", %{"case_id" => case_id}) when is_binary(case_id) do
    ia_post(%{"action" => "cancelCase", "caseID" => case_id})
  end

  defp dispatch("cancel_case", _params) do
    {:error, "cancel_case requires case_id parameter"}
  end

  defp dispatch("get_case_state", %{"case_id" => case_id}) when is_binary(case_id) do
    ia_get(%{"action" => "getCaseState", "caseID" => case_id})
  end

  defp dispatch("get_case_state", _params) do
    {:error, "get_case_state requires case_id parameter"}
  end

  defp dispatch("list_cases", _params) do
    ia_get(%{"action" => "getAllRunningCases"})
  end

  # ──────────────────────────────────────────────────────────────────────────
  # HTTP Helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp ia_post(form_params) do
    url = engine_url() <> "/ia"

    req_opts = [
      url: url,
      method: :post,
      headers: [
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"Accept", "text/xml, application/xml"}
      ],
      form: form_params,
      receive_timeout: @default_timeout
    ]

    # Step 3: Inject W3C traceparent header for distributed tracing
    req_opts_with_trace = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

    execute_request(req_opts_with_trace, form_params)
  end

  defp ia_get(query_params) do
    url = engine_url() <> "/ia"

    req_opts = [
      url: url,
      method: :get,
      headers: [{"Accept", "text/xml, application/xml"}],
      params: query_params,
      receive_timeout: @default_timeout
    ]

    # Step 3: Inject W3C traceparent header for distributed tracing
    req_opts_with_trace = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

    execute_request(req_opts_with_trace, query_params)
  end

  defp execute_request(req_opts, context_params) do
    case Req.request(req_opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        parse_yawl_response(body)

      {:ok, %{status: status, body: body}} ->
        Logger.warning(
          "[YawlWorkflow] HTTP #{status} for #{inspect(context_params)}: #{truncate(body, 300)}"
        )

        {:error, "HTTP #{status}: #{truncate(body, 300)}"}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        Logger.warning("[YawlWorkflow] Connection refused — YAWL engine may not be running at #{engine_url()}")
        {:error, "Connection refused: YAWL engine not reachable at #{engine_url()}"}

      {:error, %Req.TransportError{reason: reason}} ->
        Logger.warning("[YawlWorkflow] Transport error: #{inspect(reason)}")
        {:error, "Connection failed: #{inspect(reason)}"}

      {:error, reason} ->
        Logger.warning("[YawlWorkflow] Request failed: #{inspect(reason)}")
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # XML Response Parsing
  # ──────────────────────────────────────────────────────────────────────────

  # YAWL Interface A responses are minimal XML fragments:
  #   <success>some_value_or_empty</success>
  #   <failure>reason text</failure>
  #
  # We extract the tag and inner text with a lightweight regex approach
  # to avoid requiring a full XML parser dependency.

  defp parse_yawl_response(body) when is_binary(body) do
    trimmed = String.trim(body)

    cond do
      match = Regex.run(~r|<success>(.*?)</success>|s, trimmed) ->
        [_full, value] = match
        {:ok, %{"status" => "success", "value" => String.trim(value), "raw_xml" => trimmed}}

      match = Regex.run(~r|<failure>(.*?)</failure>|s, trimmed) ->
        [_full, reason] = match
        Logger.warning("[YawlWorkflow] YAWL failure response: #{String.trim(reason)}")
        {:error, "YAWL failure: #{String.trim(reason)}"}

      trimmed == "" ->
        {:ok, %{"status" => "success", "value" => "", "raw_xml" => ""}}

      true ->
        # Unknown XML structure — return as-is so caller can inspect
        Logger.warning("[YawlWorkflow] Unexpected YAWL response format: #{truncate(trimmed, 200)}")
        {:ok, %{"status" => "unknown", "value" => trimmed, "raw_xml" => trimmed}}
    end
  end

  defp parse_yawl_response(body) do
    # Body decoded to non-binary (map/list) by Req — should not happen with XML
    {:ok, %{"status" => "unknown", "value" => inspect(body), "raw_xml" => inspect(body)}}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Validation
  # ──────────────────────────────────────────────────────────────────────────

  defp validate_operation(op) do
    if op in @valid_operations do
      :ok
    else
      {:error,
       "Invalid operation: #{op}. Valid operations: #{Enum.join(@valid_operations, ", ")}"}
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Config
  # ──────────────────────────────────────────────────────────────────────────

  defp engine_url do
    System.get_env("YAWL_ENGINE_URL") || @default_engine_url
  end

  defp truncate(str, max) when is_binary(str) and byte_size(str) > max do
    String.slice(str, 0, max) <> "..."
  end

  defp truncate(str, _max) when is_binary(str), do: str
  defp truncate(other, _max), do: inspect(other)
end
