defmodule OptimalSystemAgent.Channels.HTTP.TraceContext do
  @moduledoc """
  Plug middleware that extracts W3C traceparent header from incoming HTTP requests.

  The traceparent header format (W3C standard):
    00-{trace_id}-{span_id}-{flags}

  Example:
    00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01

  If a traceparent header is present:
    1. Parses trace_id and parent_span_id
    2. Sets process dictionary: Process.put(:otel_trace_context, %{...})
    3. Logs the extraction at debug level

  If no traceparent header is present:
    1. Generates a new trace_id (UUID)
    2. Sets process dictionary with generated trace_id
    3. Logs at debug level (not an error condition)

  This middleware is safe for all requests (GET, POST, etc.) and does not
  break existing requests without traceparent headers.

  WvdA Requirement: Every request must have a trace context for deadlock/liveness
  verification across OSA components.
  """
  @behaviour Plug

  require Logger

  import Plug.Conn

  @doc """
  Initialize the plug (no options required).
  """
  @impl Plug
  def init(opts), do: opts

  @doc """
  Extract traceparent header and set process dictionary.
  """
  @impl Plug
  def call(conn, _opts) do
    case get_req_header(conn, "traceparent") do
      [header | _] ->
        case parse_traceparent(header) do
          {:ok, trace_id, parent_span_id, flags} ->
            trace_context = %{
              trace_id: trace_id,
              parent_span_id: parent_span_id,
              flags: flags,
              source: :http_header
            }
            Process.put(:otel_trace_context, trace_context)
            Logger.debug("[TraceContext] Extracted from header: trace_id=#{trace_id}, parent_span_id=#{parent_span_id}, flags=#{flags}")
            conn

          {:error, reason} ->
            Logger.warning("[TraceContext] Failed to parse traceparent header: #{reason}, generating new trace_id")
            trace_id = generate_trace_id()
            trace_context = %{
              trace_id: trace_id,
              parent_span_id: nil,
              flags: "00",
              source: :generated
            }
            Process.put(:otel_trace_context, trace_context)
            conn
        end

      [] ->
        # No traceparent header: generate new trace_id
        trace_id = generate_trace_id()
        trace_context = %{
          trace_id: trace_id,
          parent_span_id: nil,
          flags: "00",
          source: :generated
        }
        Process.put(:otel_trace_context, trace_context)
        Logger.debug("[TraceContext] No traceparent header, generated new trace_id=#{trace_id}")
        conn
    end
  end

  @doc """
  Parse W3C traceparent header format: 00-{trace_id}-{span_id}-{flags}

  Returns:
    {:ok, trace_id, parent_span_id, flags} if valid
    {:error, reason} if invalid
  """
  @spec parse_traceparent(String.t()) :: {:ok, String.t(), String.t(), String.t()} | {:error, String.t()}
  def parse_traceparent(header) when is_binary(header) do
    case String.split(header, "-") do
      ["00", trace_id, span_id, flags] when byte_size(trace_id) == 32 and byte_size(span_id) == 16 and byte_size(flags) == 2 ->
        # Validate hex encoding (basic check)
        if valid_hex?(trace_id) and valid_hex?(span_id) and valid_hex?(flags) do
          {:ok, trace_id, span_id, flags}
        else
          {:error, "invalid hex characters in traceparent"}
        end

      ["00", trace_id, span_id, _flags] ->
        {:error, "trace_id must be 32 hex chars (got #{byte_size(trace_id)}), span_id must be 16 hex chars (got #{byte_size(span_id)})"}

      parts ->
        {:error, "expected 4 parts separated by '-', got #{length(parts)}"}
    end
  rescue
    e ->
      {:error, "exception parsing traceparent: #{Exception.message(e)}"}
  end

  @doc """
  Get the trace context from process dictionary.

  Returns:
    %{trace_id: string, parent_span_id: string | nil, flags: string, source: atom} if set
    nil if not set
  """
  @spec get_trace_context() :: map() | nil
  def get_trace_context do
    Process.get(:otel_trace_context, nil)
  end

  @doc """
  Get only the trace_id from process dictionary.

  Returns:
    string if trace context is set
    nil if not set
  """
  @spec get_trace_id() :: String.t() | nil
  def get_trace_id do
    case get_trace_context() do
      %{trace_id: trace_id} -> trace_id
      nil -> nil
    end
  end

  @doc """
  Get only the parent_span_id from process dictionary.

  Returns:
    string if parent_span_id is set
    nil if not set or not available
  """
  @spec get_parent_span_id() :: String.t() | nil
  def get_parent_span_id do
    case get_trace_context() do
      %{parent_span_id: parent_span_id} when not is_nil(parent_span_id) -> parent_span_id
      _ -> nil
    end
  end

  # ── Private helpers ──────────────────────────────────────────────────────

  @doc false
  defp valid_hex?(str) do
    String.match?(str, ~r/^[0-9a-f]+$/i)
  end

  @doc false
  defp generate_trace_id do
    # Generate a 32-character hex string (128-bit trace ID)
    <<
      a::48,
      b::48,
      c::32
    >> = :crypto.strong_rand_bytes(16)

    :io_lib.format("~12.16.0b~12.16.0b~8.16.0b", [a, b, c])
    |> List.to_string()
    |> String.downcase()
  end
end
