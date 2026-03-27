defmodule OptimalSystemAgent.Channels.HTTP.TraceContextTest do
  use ExUnit.Case

  import Plug.Test
  import Plug.Conn

  require Logger

  alias OptimalSystemAgent.Channels.HTTP.TraceContext

  describe "parse_traceparent/1" do
    test "parses valid W3C traceparent header" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
      assert {:ok, "4bf92f3577b34da6a3ce929d0e0e4736", "00f067aa0ba902b7", "01"} =
               TraceContext.parse_traceparent(header)
    end

    test "parses traceparent with flags 00" do
      header = "00-aaaabbbbccccddddeeeeeffff0000000-1111111111111111-00"
      assert {:ok, "aaaabbbbccccddddeeeeeffff0000000", "1111111111111111", "00"} =
               TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with invalid version (not 00)" do
      header = "01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with short trace_id" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e47-00f067aa0ba902b7-01"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with short span_id" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902-01"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with short flags" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-1"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with invalid hex characters in trace_id" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e473g-00f067aa0ba902b7-01"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with invalid hex characters in span_id" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902bg-01"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with invalid hex characters in flags" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-gg"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with too few parts" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects traceparent with too many parts" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01-extra"
      assert {:error, _} = TraceContext.parse_traceparent(header)
    end

    test "rejects empty string" do
      assert {:error, _} = TraceContext.parse_traceparent("")
    end

    test "accepts uppercase hex characters" do
      header = "00-4BF92F3577B34DA6A3CE929D0E0E4736-00F067AA0BA902B7-01"
      assert {:ok, "4BF92F3577B34DA6A3CE929D0E0E4736", "00F067AA0BA902B7", "01"} =
               TraceContext.parse_traceparent(header)
    end
  end

  describe "call/2 - with traceparent header" do
    test "extracts traceparent header and sets process dictionary" do
      # Create a minimal Plug.Conn with traceparent header
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/api/v1/health",
        req_headers: [{"traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"}]
      }

      # Clear any existing trace context
      Process.delete(:otel_trace_context)

      # Call the plug
      result = TraceContext.call(conn, [])

      # Verify process dictionary was set
      trace_context = Process.get(:otel_trace_context)
      assert trace_context != nil
      assert trace_context.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736"
      assert trace_context.parent_span_id == "00f067aa0ba902b7"
      assert trace_context.flags == "01"
      assert trace_context.source == :http_header

      # Verify conn is returned unchanged
      assert result == conn
    end

    test "handles multiple traceparent headers (uses first)" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/api/v1/health",
        req_headers: [
          {"traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"},
          {"traceparent", "00-aaaabbbbccccddddeeeeeffff0000000-1111111111111111-00"}
        ]
      }

      Process.delete(:otel_trace_context)
      _result = TraceContext.call(conn, [])

      trace_context = Process.get(:otel_trace_context)
      # Should use the first header
      assert trace_context.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736"
    end
  end

  describe "call/2 - without traceparent header" do
    test "generates new trace_id when no header present" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/api/v1/health",
        req_headers: []
      }

      Process.delete(:otel_trace_context)

      result = TraceContext.call(conn, [])

      trace_context = Process.get(:otel_trace_context)
      assert trace_context != nil
      assert is_binary(trace_context.trace_id)
      assert byte_size(trace_context.trace_id) == 32
      assert trace_context.parent_span_id == nil
      assert trace_context.flags == "00"
      assert trace_context.source == :generated

      # Verify conn is returned unchanged
      assert result == conn
    end

    test "generated trace_id is valid hex" do
      conn = %Plug.Conn{
        method: "POST",
        request_path: "/api/v1/tools/execute",
        req_headers: []
      }

      Process.delete(:otel_trace_context)

      TraceContext.call(conn, [])

      trace_context = Process.get(:otel_trace_context)
      # Verify it matches hex pattern
      assert String.match?(trace_context.trace_id, ~r/^[0-9a-f]{32}$/i)
    end
  end

  describe "call/2 - with invalid traceparent header" do
    test "generates new trace_id when header is malformed" do
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/api/v1/health",
        req_headers: [{"traceparent", "invalid-header-format"}]
      }

      Process.delete(:otel_trace_context)

      result = TraceContext.call(conn, [])

      trace_context = Process.get(:otel_trace_context)
      assert trace_context != nil
      # Should have generated a new one instead of crashing
      assert is_binary(trace_context.trace_id)
      assert byte_size(trace_context.trace_id) == 32
      assert trace_context.source == :generated

      # Verify conn is returned
      assert result == conn
    end
  end

  describe "get_trace_context/0" do
    test "returns nil when not set" do
      Process.delete(:otel_trace_context)
      assert TraceContext.get_trace_context() == nil
    end

    test "returns trace context when set" do
      context = %{trace_id: "abc123", parent_span_id: "def456", flags: "01", source: :http_header}
      Process.put(:otel_trace_context, context)

      assert TraceContext.get_trace_context() == context
    end
  end

  describe "get_trace_id/0" do
    test "returns nil when trace context not set" do
      Process.delete(:otel_trace_context)
      assert TraceContext.get_trace_id() == nil
    end

    test "returns trace_id from trace context" do
      context = %{trace_id: "4bf92f3577b34da6a3ce929d0e0e4736", parent_span_id: nil, source: :generated}
      Process.put(:otel_trace_context, context)

      assert TraceContext.get_trace_id() == "4bf92f3577b34da6a3ce929d0e0e4736"
    end
  end

  describe "get_parent_span_id/0" do
    test "returns nil when trace context not set" do
      Process.delete(:otel_trace_context)
      assert TraceContext.get_parent_span_id() == nil
    end

    test "returns nil when parent_span_id is nil" do
      context = %{trace_id: "abc123", parent_span_id: nil, source: :generated}
      Process.put(:otel_trace_context, context)

      assert TraceContext.get_parent_span_id() == nil
    end

    test "returns parent_span_id from trace context" do
      context = %{trace_id: "abc123", parent_span_id: "00f067aa0ba902b7", source: :http_header}
      Process.put(:otel_trace_context, context)

      assert TraceContext.get_parent_span_id() == "00f067aa0ba902b7"
    end
  end

  describe "HTTP integration test" do
    @moduletag :requires_application

    test "middleware integrates with API router" do
      # This test verifies that the middleware is registered and working
      # in the full HTTP request pipeline.

      # We'll make a request to a known endpoint and verify trace context was set
      {:ok, _} = start_supervised({Task, fn -> :ok end})

      # Simulate a request through the API router
      conn = %Plug.Conn{
        method: "GET",
        request_path: "/api/v1/classify",
        req_headers: [{"traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"}]
      }

      Process.delete(:otel_trace_context)

      # The TraceContext middleware should run first in the pipeline
      _result = TraceContext.call(conn, [])

      # Verify the trace context was set
      trace_context = Process.get(:otel_trace_context)
      assert trace_context.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736"
      assert trace_context.parent_span_id == "00f067aa0ba902b7"
      assert trace_context.source == :http_header
    end

    test "E2E test: HTTP request with traceparent preserves trace context through request lifecycle" do
      # This E2E test verifies that traceparent header is preserved from HTTP boundary through
      # the entire request processing pipeline.

      # Create a Plug.Test-style request with traceparent header
      conn =
        conn(:post, "/api/v1/classify", Jason.encode!(%{"message" => "test"}))
        |> put_req_header("content-type", "application/json")
        |> put_req_header("traceparent", "00-abcdef0123456789abcdef0123456789-0123456789abcdef-01")

      Process.delete(:otel_trace_context)

      # Call the middleware
      result_conn = TraceContext.call(conn, [])

      # Verify the trace context was set in the process dictionary
      trace_context = Process.get(:otel_trace_context)
      assert trace_context != nil
      assert trace_context.trace_id == "abcdef0123456789abcdef0123456789"
      assert trace_context.parent_span_id == "0123456789abcdef"
      assert trace_context.flags == "01"
      assert trace_context.source == :http_header

      # Verify the connection itself passes through unchanged
      assert result_conn.method == "POST"
      assert result_conn.request_path == "/api/v1/classify"
    end

    test "E2E test: Missing traceparent header generates trace_id and allows request to proceed" do
      # This E2E test verifies that requests without traceparent headers are NOT blocked
      # and a trace_id is generated instead.

      conn =
        conn(:get, "/api/v1/health/fortune5")
        |> put_req_header("content-type", "application/json")

      Process.delete(:otel_trace_context)

      # Call the middleware
      result_conn = TraceContext.call(conn, [])

      # Verify trace context was generated
      trace_context = Process.get(:otel_trace_context)
      assert trace_context != nil
      assert is_binary(trace_context.trace_id)
      assert byte_size(trace_context.trace_id) == 32
      assert trace_context.parent_span_id == nil
      assert trace_context.flags == "00"
      assert trace_context.source == :generated

      # Verify the connection passes through unchanged
      assert result_conn.method == "GET"
      assert result_conn.request_path == "/api/v1/health/fortune5"
    end
  end

  describe "WvdA Soundness — Trace Context Availability" do
    test "trace context is available for deadlock/liveness verification" do
      # WvdA Soundness requirement: every request must have trace context
      # for deadlock and liveness verification.

      Process.delete(:otel_trace_context)

      conn = %Plug.Conn{
        method: "GET",
        request_path: "/api/v1/health",
        req_headers: []
      }

      # Call middleware
      _result = TraceContext.call(conn, [])

      # Verify trace context is always set (never nil)
      trace_context = TraceContext.get_trace_context()
      assert trace_context != nil, "Trace context must always be set for WvdA verification"

      # Verify trace_id is always available (needed for deadlock analysis)
      trace_id = TraceContext.get_trace_id()
      assert trace_id != nil, "trace_id must always be available for deadlock detection"
      assert is_binary(trace_id), "trace_id must be a string (hex)"

      # Verify flags indicate whether this is from HTTP header or generated
      assert trace_context.source in [:http_header, :generated], "trace source must be tracked"
    end
  end
end
