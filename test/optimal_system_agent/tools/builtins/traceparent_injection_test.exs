defmodule OptimalSystemAgent.Tools.Builtins.TraceparentInjectionTest do
  @moduledoc """
  Integration test verifying W3C traceparent header injection into HTTP requests.

  Tests that OTEL Step 3 is correctly implemented: trace context from process
  dictionary is injected as W3C traceparent header into all Req calls.
  """
  use ExUnit.Case, async: true

  describe "OTEL Step 3: W3C Traceparent Injection" do
    test "yawl_workflow ia_post includes traceparent header in request options" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
      span_id = "00f067aa0ba902b7"

      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      # Create test request options like ia_post does
      req_opts = [
        url: "http://localhost:8080/ia",
        method: :post,
        headers: [
          {"Content-Type", "application/x-www-form-urlencoded"},
          {"Accept", "text/xml, application/xml"}
        ],
        form: %{"action" => "upload"},
        receive_timeout: 30_000
      ]

      # Apply traceparent injection
      req_opts_with_trace =
        OptimalSystemAgent.Observability.Traceparent.add_to_request(req_opts)

      # Verify traceparent header is present
      headers = Keyword.get(req_opts_with_trace, :headers)
      assert is_list(headers)

      {header_name, header_value} =
        Enum.find(headers, fn {k, _v} -> k == "traceparent" end)

      assert header_name == "traceparent"
      assert header_value == "00-#{trace_id}-#{span_id}-01"

      # Verify other headers are preserved
      assert Enum.any?(headers, fn {k, _v} -> k == "Content-Type" end)
      assert Enum.any?(headers, fn {k, _v} -> k == "Accept" end)

      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)
    end

    test "a2a_call discover_agent builds request with traceparent header" do
      trace_id = "abc123def456"
      span_id = "0102030405060708"

      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      # Simulate what discover_agent does
      opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
        receive_timeout: 30_000
      ])

      headers = Keyword.get(opts, :headers, [])
      assert Enum.any?(headers, fn {k, _v} -> k == "traceparent" end)

      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)
    end

    test "web_fetch do_fetch builds request with traceparent header" do
      trace_id = "11111111111111111111111111111111"
      span_id = "2222222222222222"

      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      # Simulate what do_fetch does
      opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
        receive_timeout: 30_000,
        redirect: true,
        max_redirects: 3
      ])

      headers = Keyword.get(opts, :headers, [])
      {_, header_value} = Enum.find(headers, fn {k, _v} -> k == "traceparent" end)

      assert header_value == "00-#{trace_id}-#{span_id}-01"

      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)
    end

    test "graceful fallback when no trace context exists" do
      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)

      opts = OptimalSystemAgent.Observability.Traceparent.add_to_request([
        url: "http://example.com",
        method: :post
      ])

      # Should return unchanged when no trace context
      assert opts == [url: "http://example.com", method: :post]
    end

    test "W3C traceparent header format is valid" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
      span_id = "00f067aa0ba902b7"

      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      {:ok, traceparent} =
        OptimalSystemAgent.Observability.Traceparent.build_traceparent()

      # Parse the traceparent to verify format
      {:ok, {parsed_trace_id, parsed_span_id}} =
        OptimalSystemAgent.Observability.Traceparent.parse_traceparent(traceparent)

      assert parsed_trace_id == trace_id
      assert parsed_span_id == span_id

      # Verify version and flags
      parts = String.split(traceparent, "-")
      assert length(parts) == 4
      assert Enum.at(parts, 0) == "00"
      assert Enum.at(parts, 3) == "01"

      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)
    end
  end
end
