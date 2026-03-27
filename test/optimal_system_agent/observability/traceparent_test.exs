defmodule OptimalSystemAgent.Observability.TraceparentTest do
  use ExUnit.Case, async: true

  describe "add_to_request/1" do
    test "adds traceparent header when trace_id and span_id exist in process context" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
      span_id = "00f067aa0ba902b7"

      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      req_opts = [url: "http://example.com", method: :post]
      result = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

      # Verify traceparent header is added
      assert Keyword.has_key?(result, :headers)
      headers = Keyword.get(result, :headers)
      assert is_list(headers)

      {header_name, header_value} = Enum.find(headers, fn {k, _v} -> k == "traceparent" end)
      assert header_name == "traceparent"
      assert header_value == "00-#{trace_id}-#{span_id}-01"

      # Clean up
      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)
    end

    test "pads trace_id to 32 hex characters if shorter" do
      trace_id = "abc123"
      span_id = "00f067aa0ba902b7"

      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      req_opts = [url: "http://example.com"]
      result = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

      headers = Keyword.get(result, :headers)
      {_, header_value} = Enum.find(headers, fn {k, _v} -> k == "traceparent" end)

      # trace_id should be padded to 32 chars with leading zeros
      expected_padded = String.pad_leading(trace_id, 32, "0")
      assert header_value == "00-#{expected_padded}-#{span_id}-01"

      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)
    end

    test "generates span_id if only trace_id exists" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"

      Process.put(:telemetry_trace_id, trace_id)
      Process.delete(:telemetry_current_span_id)

      req_opts = [url: "http://example.com"]
      result = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

      headers = Keyword.get(result, :headers)
      {_, header_value} = Enum.find(headers, fn {k, _v} -> k == "traceparent" end)

      # Should have format 00-{trace_id}-{generated_span_id}-01
      assert String.starts_with?(header_value, "00-#{trace_id}-")
      assert String.ends_with?(header_value, "-01")

      # Extract and verify span_id is 16 hex chars
      [_version, _trace_id, generated_span_id, _flags] = String.split(header_value, "-")
      assert String.length(generated_span_id) == 16
      assert String.match?(generated_span_id, ~r/^[0-9a-f]{16}$/)

      Process.delete(:telemetry_trace_id)
    end

    test "returns request options unchanged when no trace context exists" do
      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)

      req_opts = [url: "http://example.com", method: :post]
      result = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

      # Should return original options unchanged
      assert result == req_opts
    end

    test "preserves existing headers when adding traceparent" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
      span_id = "00f067aa0ba902b7"

      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      existing_headers = [{"Authorization", "Bearer token123"}, {"Accept", "application/json"}]
      req_opts = [url: "http://example.com", headers: existing_headers]

      result = OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

      headers = Keyword.get(result, :headers)

      # Traceparent should be added at the start
      {first_header_name, _} = hd(headers)
      assert first_header_name == "traceparent"

      # Existing headers should still be present
      assert Enum.any?(headers, fn {k, v} -> k == "Authorization" and v == "Bearer token123" end)
      assert Enum.any?(headers, fn {k, v} -> k == "Accept" and v == "application/json" end)

      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)
    end
  end

  describe "build_traceparent/0" do
    test "returns W3C traceparent string when trace_id and span_id exist" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
      span_id = "00f067aa0ba902b7"

      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      result = OptimalSystemAgent.Observability.Traceparent.build_traceparent()

      assert result == {:ok, "00-#{trace_id}-#{span_id}-01"}

      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)
    end

    test "returns :no_context when neither trace_id nor span_id exist" do
      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)

      result = OptimalSystemAgent.Observability.Traceparent.build_traceparent()

      assert result == :no_context
    end
  end

  describe "parse_traceparent/1" do
    test "parses valid W3C traceparent header" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"

      result = OptimalSystemAgent.Observability.Traceparent.parse_traceparent(header)

      assert result == {:ok, {"4bf92f3577b34da6a3ce929d0e0e4736", "00f067aa0ba902b7"}}
    end

    test "rejects malformed traceparent header with wrong version" do
      header = "01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"

      result = OptimalSystemAgent.Observability.Traceparent.parse_traceparent(header)

      assert result == :error
    end

    test "rejects traceparent with wrong trace_id length" do
      header = "00-abc-00f067aa0ba902b7-01"

      result = OptimalSystemAgent.Observability.Traceparent.parse_traceparent(header)

      assert result == :error
    end

    test "rejects traceparent with wrong span_id length" do
      header = "00-4bf92f3577b34da6a3ce929d0e0e4736-abc-01"

      result = OptimalSystemAgent.Observability.Traceparent.parse_traceparent(header)

      assert result == :error
    end

    test "rejects non-binary input" do
      result = OptimalSystemAgent.Observability.Traceparent.parse_traceparent(123)

      assert result == :error
    end
  end
end
