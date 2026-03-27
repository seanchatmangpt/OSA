defmodule OptimalSystemAgent.Observability.Traceparent do
  @moduledoc """
  W3C Trace Context header injection for HTTP requests.

  Injects the W3C traceparent header (format: 00-{trace_id}-{span_id}-01)
  into all outgoing HTTP requests to enable distributed tracing.

  The trace_id and span_id are read from the current process's dictionary,
  set by OTEL span creation in the telemetry module.

  Format: https://www.w3.org/TR/trace-context/
    - version: "00" (fixed)
    - trace_id: 32 hex characters (128 bits)
    - span_id: 16 hex characters (64 bits)
    - trace_flags: "01" (sampled=true)
  """

  require Logger

  @doc """
  Add W3C traceparent header to request options if trace context exists.

  Returns modified request options with traceparent header added.
  If no trace context is available, returns options unchanged.

  ## Examples

      iex> opts = [url: "http://example.com", method: :post]
      iex> Traceparent.add_to_request(opts)
      [url: "http://example.com", method: :post, headers: [{"traceparent", "00-..."}]]
  """
  def add_to_request(req_opts) when is_list(req_opts) do
    case build_traceparent() do
      {:ok, traceparent} ->
        # Extract existing headers or create empty list
        existing_headers = Keyword.get(req_opts, :headers, [])

        # Build new headers list (convert to list if not already)
        headers_list =
          if is_list(existing_headers) do
            existing_headers
          else
            []
          end

        # Add traceparent to headers
        new_headers = [{"traceparent", traceparent} | headers_list]

        # Update or insert headers
        Keyword.put(req_opts, :headers, new_headers)

      :no_context ->
        # No trace context available, return options unchanged
        req_opts
    end
  end

  def add_to_request(req_opts), do: req_opts

  @doc """
  Build W3C traceparent header from current process context.

  Returns {:ok, "00-{trace_id}-{span_id}-01"} or :no_context if trace info unavailable.
  """
  def build_traceparent do
    trace_id = Process.get(:telemetry_trace_id)
    span_id = Process.get(:telemetry_current_span_id)

    case {trace_id, span_id} do
      {trace_id, span_id} when is_binary(trace_id) and is_binary(span_id) ->
        # Ensure trace_id is 32 hex chars and span_id is 16 hex chars.
        # sanitize_hex_id strips UUID dashes before padding/slicing so that
        # UUID-formatted IDs (e.g. "9287363b-c0aa-c4a6-be38-7eefd545ae47") become
        # valid 32-char hex strings rather than polluting the traceparent with extra dashes.
        trace_id_padded = pad_hex(sanitize_hex_id(trace_id), 32)
        span_id_padded = pad_hex(sanitize_hex_id(span_id), 16)

        traceparent = "00-#{trace_id_padded}-#{span_id_padded}-01"
        {:ok, traceparent}

      {trace_id, _} when is_binary(trace_id) ->
        # Only trace_id available, generate span_id
        span_id = generate_span_id()
        trace_id_padded = pad_hex(sanitize_hex_id(trace_id), 32)
        traceparent = "00-#{trace_id_padded}-#{span_id}-01"
        {:ok, traceparent}

      _ ->
        # No trace context
        :no_context
    end
  end

  @doc """
  Extract trace_id and span_id from a traceparent header string.

  Returns {:ok, {trace_id, span_id}} or :error if format is invalid.

  ## Examples

      iex> parse_traceparent("00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")
      {:ok, {"4bf92f3577b34da6a3ce929d0e0e4736", "00f067aa0ba902b7"}}
  """
  def parse_traceparent(header) when is_binary(header) do
    case String.split(header, "-") do
      ["00", trace_id, span_id, "01"] when byte_size(trace_id) == 32 and byte_size(span_id) == 16 ->
        {:ok, {trace_id, span_id}}

      _ ->
        :error
    end
  end

  def parse_traceparent(_), do: :error

  # ──────────────────────────────────────────────────────────────────────────
  # Private Helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp generate_span_id do
    # Generate 8 random bytes and convert to 16 hex characters
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end

  # Strip UUID dashes so that a UUID-formatted trace/span ID such as
  # "9287363b-c0aa-c4a6-be38-7eefd545ae47" is reduced to the raw 32-char hex
  # string "9287363bc0aac4a6be387eefd545ae47" before length-checking or slicing.
  defp sanitize_hex_id(id) when is_binary(id) do
    String.replace(id, "-", "")
  end

  defp pad_hex(hex, desired_length) when is_binary(hex) do
    current_length = String.length(hex)

    cond do
      current_length >= desired_length ->
        String.slice(hex, 0, desired_length)

      true ->
        padding = String.duplicate("0", desired_length - current_length)
        padding <> hex
    end
  end
end
