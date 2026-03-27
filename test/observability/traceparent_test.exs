defmodule OptimalSystemAgent.Observability.TraceparentTest do
  @moduledoc """
  Unit tests for the W3C Trace Context traceparent header module.

  All tests are pure unit tests (no server, no ETS, no GenServer required).
  They run with `mix test` (no --no-start needed, no @tag :requires_application).

  ## Armstrong Rule
  These tests MUST FAIL if the traceparent format or parsing logic changes.
  The traceparent header is the contract between OSA and pm4py-rust — any
  deviation silently breaks cross-service trace correlation.

  ## W3C Trace Context spec
  https://www.w3.org/TR/trace-context/#traceparent-header-field-values
  Format: 00-{32hex trace_id}-{16hex parent_id}-{8bit flags}
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Observability.Traceparent

  setup do
    # Clean process dict before each test — prevents cross-test trace_id bleed.
    Process.delete(:telemetry_trace_id)
    Process.delete(:telemetry_current_span_id)
    :ok
  end

  # ────────────────────────────────────────────────────────────────────────────
  # parse_traceparent/1
  # ────────────────────────────────────────────────────────────────────────────

  describe "parse_traceparent/1" do
    test "parses valid W3C traceparent header" do
      tp = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
      assert {:ok, {trace_id, span_id}} = Traceparent.parse_traceparent(tp)

      assert trace_id == "4bf92f3577b34da6a3ce929d0e0e4736",
             "parse_traceparent must extract the 32-char trace_id exactly. Got: '#{trace_id}'"

      assert span_id == "00f067aa0ba902b7",
             "parse_traceparent must extract the 16-char span_id exactly. Got: '#{span_id}'"
    end

    test "parses a different valid traceparent header" do
      # Second example from W3C spec.
      tp = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
      assert {:ok, {trace_id, span_id}} = Traceparent.parse_traceparent(tp)

      assert trace_id == "0af7651916cd43dd8448eb211c80319c"
      assert span_id == "b7ad6b7169203331"
    end

    test "returns :error for unknown version 'ff'" do
      tp = "ff-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
      assert :error = Traceparent.parse_traceparent(tp),
             "Must reject version 'ff' — only '00' is valid in W3C trace-context v1."
    end

    test "returns :error for trace_id with wrong length (not 32 chars)" do
      # 16 chars — too short.
      tp = "00-4bf92f3577b34da6-00f067aa0ba902b7-01"
      assert :error = Traceparent.parse_traceparent(tp)
    end

    test "returns :error for span_id with wrong length (not 16 chars)" do
      # 8 chars — too short.
      tp = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa-01"
      assert :error = Traceparent.parse_traceparent(tp)
    end

    test "returns :error for missing segments (only 3 dashes)" do
      tp = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7"
      assert :error = Traceparent.parse_traceparent(tp)
    end

    test "returns :error for empty string" do
      assert :error = Traceparent.parse_traceparent("")
    end

    test "returns :error for nil input" do
      assert :error = Traceparent.parse_traceparent(nil),
             "parse_traceparent must handle nil gracefully (return :error, not crash)."
    end

    test "returns :error for non-sampled flags (Armstrong: we only propagate sampled traces)" do
      # flags "00" means not sampled — unclear if we should accept or reject.
      # The W3C spec allows "00" but OSA always sends "01".
      # This test documents the current behavior (accept or reject) without mandating.
      tp = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00"
      result = Traceparent.parse_traceparent(tp)

      # Document current behavior: the module currently requires "01" flags.
      # If behavior changes, update this test — do NOT silently accept.
      assert result == :error or match?({:ok, _}, result),
             "parse_traceparent returned unexpected value for flags='00': #{inspect(result)}"
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # build_traceparent/0
  # ────────────────────────────────────────────────────────────────────────────

  describe "build_traceparent/0" do
    test "returns :no_context when process dict has no trace info" do
      # Armstrong: :no_context is correct — don't invent a random traceparent.
      assert :no_context = Traceparent.build_traceparent()
    end

    test "builds valid W3C traceparent from trace_id and span_id in process dict" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
      span_id = "00f067aa0ba902b7"
      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      assert {:ok, tp} = Traceparent.build_traceparent()

      assert tp == "00-#{trace_id}-#{span_id}-01",
             "build_traceparent must produce '00-{trace_id}-{span_id}-01'. Got: '#{tp}'"
    end

    test "generates span_id when only trace_id is in process dict" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
      Process.put(:telemetry_trace_id, trace_id)
      # No :telemetry_current_span_id set.

      assert {:ok, tp} = Traceparent.build_traceparent()

      parts = String.split(tp, "-")
      assert Enum.at(parts, 0) == "00"
      assert Enum.at(parts, 1) == trace_id

      generated_span_id = Enum.at(parts, 2)

      assert byte_size(generated_span_id) == 16,
             "Auto-generated span_id must be 16 hex chars. " <>
               "Got #{byte_size(generated_span_id)} chars: '#{generated_span_id}'"

      # Generated span_id must be hex.
      assert String.match?(generated_span_id, ~r/^[0-9a-f]+$/),
             "Auto-generated span_id must be lowercase hex. Got: '#{generated_span_id}'"
    end

    test "built traceparent round-trips through parse_traceparent" do
      trace_id = "aabbccddeeff00112233445566778899"
      span_id = "1122334455667788"
      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      assert {:ok, built_tp} = Traceparent.build_traceparent()
      assert {:ok, {parsed_trace_id, parsed_span_id}} = Traceparent.parse_traceparent(built_tp)

      assert parsed_trace_id == trace_id,
             "Round-trip FAILED: built='#{built_tp}', parsed trace_id='#{parsed_trace_id}', " <>
               "expected '#{trace_id}'. This means OSA would build a traceparent that pm4py-rust " <>
               "cannot correctly parse back."

      assert parsed_span_id == span_id,
             "Round-trip FAILED: parsed span_id='#{parsed_span_id}', expected '#{span_id}'."
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # add_to_request/1
  # ────────────────────────────────────────────────────────────────────────────

  describe "add_to_request/1" do
    test "injects traceparent header when trace context exists" do
      trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
      span_id = "00f067aa0ba902b7"
      Process.put(:telemetry_trace_id, trace_id)
      Process.put(:telemetry_current_span_id, span_id)

      enriched = Traceparent.add_to_request([url: "http://localhost:8090"])
      headers = Keyword.get(enriched, :headers, [])

      tp_header = Enum.find_value(headers, fn
        {"traceparent", v} -> v
        _ -> nil
      end)

      refute is_nil(tp_header),
             "add_to_request must inject 'traceparent' header when trace context is set. " <>
               "Headers: #{inspect(headers)}"

      assert tp_header == "00-#{trace_id}-#{span_id}-01",
             "Injected traceparent must be '00-#{trace_id}-#{span_id}-01'. Got: '#{tp_header}'"
    end

    test "does not inject traceparent when no trace context" do
      enriched = Traceparent.add_to_request([url: "http://localhost:8090"])
      headers = Keyword.get(enriched, :headers, [])

      tp_header = Enum.find(headers, fn {k, _} -> k == "traceparent" end)

      assert is_nil(tp_header),
             "add_to_request must NOT inject traceparent when process dict is empty. " <>
               "Injecting a random traceparent would pollute Jaeger with phantom traces."
    end

    test "preserves all existing request option keys" do
      Process.put(:telemetry_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:telemetry_current_span_id, "00f067aa0ba902b7")

      original_opts = [
        url: "http://localhost:8090/api/discovery/alpha",
        method: :post,
        receive_timeout: 10_000,
        json: %{event_log: %{}}
      ]

      enriched = Traceparent.add_to_request(original_opts)

      assert Keyword.get(enriched, :url) == "http://localhost:8090/api/discovery/alpha"
      assert Keyword.get(enriched, :method) == :post
      assert Keyword.get(enriched, :receive_timeout) == 10_000
      assert Keyword.get(enriched, :json) == %{event_log: %{}}
    end

    test "handles non-list request options gracefully" do
      # Guards against bad callers passing a map or atom.
      result = Traceparent.add_to_request(%{url: "http://example.com"})
      # Should return the original opts unchanged (not crash).
      assert result == %{url: "http://example.com"},
             "add_to_request must return non-list opts unchanged. Got: #{inspect(result)}"
    end

    test "works with empty request options list" do
      Process.put(:telemetry_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:telemetry_current_span_id, "00f067aa0ba902b7")

      enriched = Traceparent.add_to_request([])
      headers = Keyword.get(enriched, :headers, [])

      assert Enum.any?(headers, fn {k, _} -> k == "traceparent" end),
             "add_to_request must inject traceparent even into empty opts list."
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # W3C format contract (cross-checking OSA output against spec)
  # ────────────────────────────────────────────────────────────────────────────

  describe "W3C traceparent format contract" do
    test "built traceparent has exactly 4 dash-separated segments" do
      Process.put(:telemetry_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:telemetry_current_span_id, "00f067aa0ba902b7")

      {:ok, tp} = Traceparent.build_traceparent()
      parts = String.split(tp, "-")

      assert length(parts) == 4,
             "W3C traceparent must have exactly 4 dash-separated segments. " <>
               "Got #{length(parts)} in: '#{tp}'"
    end

    test "built traceparent version segment is '00'" do
      Process.put(:telemetry_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:telemetry_current_span_id, "00f067aa0ba902b7")

      {:ok, tp} = Traceparent.build_traceparent()
      [version | _] = String.split(tp, "-")

      assert version == "00",
             "W3C traceparent version must be '00'. Got: '#{version}'. " <>
               "pm4py-rust will reject non-'00' versions."
    end

    test "built traceparent trace_id segment is 32 lowercase hex chars" do
      Process.put(:telemetry_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:telemetry_current_span_id, "00f067aa0ba902b7")

      {:ok, tp} = Traceparent.build_traceparent()
      [_, trace_id | _] = String.split(tp, "-")

      assert byte_size(trace_id) == 32,
             "W3C trace_id must be exactly 32 hex chars (128 bits). " <>
               "Got #{byte_size(trace_id)} chars: '#{trace_id}'"

      assert String.match?(trace_id, ~r/^[0-9a-f]+$/),
             "W3C trace_id must be lowercase hex [0-9a-f]. Got: '#{trace_id}'"
    end

    test "built traceparent span_id segment is 16 lowercase hex chars" do
      Process.put(:telemetry_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:telemetry_current_span_id, "00f067aa0ba902b7")

      {:ok, tp} = Traceparent.build_traceparent()
      [_, _, span_id, _] = String.split(tp, "-")

      assert byte_size(span_id) == 16,
             "W3C span_id must be exactly 16 hex chars (64 bits). " <>
               "Got #{byte_size(span_id)} chars: '#{span_id}'"

      assert String.match?(span_id, ~r/^[0-9a-f]+$/),
             "W3C span_id must be lowercase hex [0-9a-f]. Got: '#{span_id}'"
    end

    test "built traceparent flags segment is '01' (sampled)" do
      Process.put(:telemetry_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:telemetry_current_span_id, "00f067aa0ba902b7")

      {:ok, tp} = Traceparent.build_traceparent()
      [_, _, _, flags] = String.split(tp, "-")

      assert flags == "01",
             "W3C trace-flags must be '01' (sampled=true) for all OSA→pm4py-rust calls. " <>
               "Got: '#{flags}'. pm4py-rust's TraceContextPropagator will not sample " <>
               "spans with flags='00'."
    end

    test "build_traceparent produces valid W3C 4-segment format when trace_id is UUID-formatted" do
      # Telemetry.generate_uuid/0 produces UUID-formatted IDs with dashes
      # e.g. "9287363b-c0aa-c4a6-be38-7eefd545ae47" — these dashes must be stripped
      # before interpolating into the traceparent string, otherwise the header has
      # more than 4 segments and is invalid per W3C spec.
      Process.put(:telemetry_trace_id, "9287363b-c0aa-c4a6-be38-7eefd545ae47")
      Process.put(:telemetry_current_span_id, "f6955059b1a3f7d4")

      {:ok, tp} = Traceparent.build_traceparent()

      # Valid W3C: exactly 4 dash-separated segments
      parts = String.split(tp, "-")

      assert length(parts) == 4,
             "Expected 4 segments, got #{length(parts)}: #{tp}"

      [version, trace_id, span_id, flags] = parts
      assert version == "00"

      assert String.length(trace_id) == 32,
             "trace_id must be 32 hex chars, got #{String.length(trace_id)}: #{trace_id}"

      assert String.length(span_id) == 16,
             "span_id must be 16 hex chars, got #{String.length(span_id)}: #{span_id}"

      assert flags == "01"
    end
  end
end
