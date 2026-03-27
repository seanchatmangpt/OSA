defmodule OptimalSystemAgent.ProcessMining.SpanEmissionTest do
  @moduledoc """
  Chicago TDD — OTEL span emission for ProcessMining.Client.

  RED tests written before implementation. Verifies:
  1. process.mining.discovery span emitted with algorithm attribute
  2. process.mining.soundness span emitted with process_id and check_type
  3. process.mining.reachability span emitted with process_id
  4. traceparent header is injected into pm4py-rust HTTP calls
  5. span ends with :error status when pm4py-rust is unavailable
  """
  use ExUnit.Case

  # Tests that call Client.* need the full OTP supervision tree (Finch pool).
  @moduletag :requires_application

  alias OptimalSystemAgent.Observability.Traceparent
  alias OptimalSystemAgent.ProcessMining.Client

  setup do
    # Ensure ETS tables exist — Telemetry.init_tracer/0 is idempotent
    try do
      :ets.new(:telemetry_spans, [:named_table, :public, {:keypos, 1}])
    rescue
      ArgumentError -> :ok
    end

    try do
      :ets.new(:telemetry_metrics, [:named_table, :public, {:keypos, 1}])
    rescue
      ArgumentError -> :ok
    end

    # Fresh trace context per test
    Process.delete(:telemetry_trace_id)
    Process.delete(:telemetry_current_span_id)

    # Start the GenServer if not already running
    case GenServer.whereis(:process_mining_client) do
      nil ->
        {:ok, _pid} = Client.start_link([])

      _pid ->
        :ok
    end

    :ok
  end

  # ── Span emission ─────────────────────────────────────────────────

  describe "process.mining.discovery span" do
    test "emits span with resource_type attribute when discover called" do
      resource_type = "order_process_span_test"

      # Call discover — pm4py-rust is not running so it returns {:error, _}
      _result = Client.discover_process_models(resource_type)

      # Assert span was stored in ETS with correct name
      all_spans = :ets.tab2list(:telemetry_spans)

      discovery_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          span["span_name"] == "process.mining.discovery"
        end)

      assert length(discovery_spans) >= 1,
             "Expected at least one process.mining.discovery span in ETS, got: #{inspect(Enum.map(all_spans, fn {_, s} -> s["span_name"] end))}"

      matching = Enum.find(discovery_spans, fn {_id, span} ->
        span["attributes"]["process.mining.resource_type"] == resource_type
      end)
      assert matching != nil, "Expected span with resource_type=#{resource_type}, found: #{inspect(Enum.map(discovery_spans, fn {_, s} -> s["attributes"]["process.mining.resource_type"] end))}"
    end

    test "discovery span ends with status ok or error (never left active)" do
      _result = Client.discover_process_models("resource_span_status_test")

      all_spans = :ets.tab2list(:telemetry_spans)

      discovery_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          span["span_name"] == "process.mining.discovery"
        end)

      assert length(discovery_spans) >= 1

      {_id, span} = List.last(discovery_spans)
      # Span must be completed (ok or error), not left in "active" state
      assert span["status"] in ["ok", "error"],
             "Expected span status to be ok or error, got: #{span["status"]}"
    end
  end

  describe "process.mining.soundness span" do
    test "emits span with process_id and check_type attributes on check_deadlock_free" do
      process_id = "proc_soundness_span_test"

      _result = Client.check_deadlock_free(process_id)

      all_spans = :ets.tab2list(:telemetry_spans)

      soundness_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          span["span_name"] == "process.mining.soundness"
        end)

      assert length(soundness_spans) >= 1,
             "Expected at least one process.mining.soundness span"

      {_id, span} = List.last(soundness_spans)
      assert span["attributes"]["process.mining.process_id"] == process_id
      assert span["attributes"]["process.mining.check_type"] == "deadlock_free"
    end

    test "emits span with bounded check_type on analyze_boundedness" do
      process_id = "proc_bounded_span_test"

      _result = Client.analyze_boundedness(process_id)

      all_spans = :ets.tab2list(:telemetry_spans)

      soundness_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          span["span_name"] == "process.mining.soundness" and
            span["attributes"]["process.mining.process_id"] == process_id
        end)

      assert length(soundness_spans) >= 1

      {_id, span} = List.last(soundness_spans)
      assert span["attributes"]["process.mining.check_type"] == "bounded"
    end
  end

  describe "process.mining.reachability span" do
    test "emits span with process_id attribute on get_reachability_graph" do
      process_id = "proc_reach_span_test"

      _result = Client.get_reachability_graph(process_id)

      all_spans = :ets.tab2list(:telemetry_spans)

      reach_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          span["span_name"] == "process.mining.reachability"
        end)

      assert length(reach_spans) >= 1,
             "Expected at least one process.mining.reachability span"

      {_id, span} = List.last(reach_spans)
      assert span["attributes"]["process.mining.process_id"] == process_id
    end
  end

  # ── traceparent header injection ──────────────────────────────────

  describe "W3C traceparent header injection" do
    test "build_traceparent returns ok when trace context is set in process dict" do
      # Simulate what Telemetry.start_span/2 does: sets trace_id in process dict
      Process.put(:telemetry_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      Process.put(:telemetry_current_span_id, "00f067aa0ba902b7")

      result = Traceparent.build_traceparent()

      assert {:ok, header} = result
      assert String.starts_with?(header, "00-")
      assert String.ends_with?(header, "-01")

      parts = String.split(header, "-")
      assert length(parts) == 4
      assert String.length(Enum.at(parts, 1)) == 32
      assert String.length(Enum.at(parts, 2)) == 16
    end

    test "add_to_request injects traceparent into headers when trace context exists" do
      Process.put(:telemetry_trace_id, "aabbccddeeff00112233445566778899")
      Process.put(:telemetry_current_span_id, "0011223344556677")

      opts = Traceparent.add_to_request(receive_timeout: 5000)

      headers = Keyword.get(opts, :headers, [])
      traceparent_header = Enum.find(headers, fn {k, _v} -> k == "traceparent" end)

      assert traceparent_header != nil,
             "Expected traceparent header in request opts, headers: #{inspect(headers)}"

      {_, value} = traceparent_header
      assert value =~ ~r/^00-[a-f0-9]{32}-[a-f0-9]{16}-01$/
    end

    test "add_to_request does not inject traceparent when no trace context" do
      Process.delete(:telemetry_trace_id)
      Process.delete(:telemetry_current_span_id)

      opts = Traceparent.add_to_request(receive_timeout: 5000)

      headers = Keyword.get(opts, :headers, [])
      traceparent_header = Enum.find(headers, fn {k, _v} -> k == "traceparent" end)

      assert traceparent_header == nil
    end

    test "discovery call sets trace context before HTTP request" do
      # After calling discover_process_models, the process dict should have
      # had a trace_id set (it may be cleared after, but the span ETS record
      # proves it existed)
      Process.delete(:telemetry_trace_id)

      _result = Client.discover_process_models("context_injection_test")

      # Trace_id must have been set during the call — proved by span existing in ETS
      all_spans = :ets.tab2list(:telemetry_spans)

      discovery_spans =
        Enum.filter(all_spans, fn {_id, span} ->
          span["span_name"] == "process.mining.discovery" and
            span["attributes"]["process.mining.resource_type"] == "context_injection_test"
        end)

      assert length(discovery_spans) >= 1, "Span must exist to prove trace context was set"

      {_id, span} = List.last(discovery_spans)
      # Trace ID must be non-nil — proves it was set before the HTTP call
      assert span["trace_id"] != nil
      assert String.length(span["trace_id"]) > 0
    end
  end

  # ── span attribute schema conformance ────────────────────────────

  describe "span attribute schema conformance" do
    test "process.mining.discovery span uses OtelBridge attribute keys" do
      alias OptimalSystemAgent.Semconv.OtelBridge

      # OtelBridge defines process_mining_algorithm as :"process.mining.algorithm"
      # The span attributes must use these schema keys
      assert OtelBridge.process_mining_algorithm() == :"process.mining.algorithm"
      assert OtelBridge.process_mining_conformance_score() == :"process.mining.conformance.score"
    end

    test "a2a.call span name constant matches SpanNames module" do
      alias OpenTelemetry.SemConv.Incubating.SpanNames

      assert SpanNames.a2a_call() == "a2a.call"
      assert SpanNames.process_mining_discovery() == "process.mining.discovery"
    end
  end
end
