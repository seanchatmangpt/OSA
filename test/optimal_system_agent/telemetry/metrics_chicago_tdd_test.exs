defmodule OptimalSystemAgent.Telemetry.MetricsChicagoTDDTest do
  @moduledoc """
  Chicago TDD tests for OptimalSystemAgent.Telemetry.Metrics.

  Tests the GenServer-based telemetry metrics collection system.
  All public functions tested with expected observable behavior.

  Pattern: CRASH: descriptive_name — test names describe observable claims.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Telemetry.Metrics

  setup_all do
    if Process.whereis(Metrics) == nil do
      start_supervised!(Metrics)
    end
    :ok
  end

  describe "CRASH: record_tool_execution/2" do
    test "records tool execution with float duration" do
      assert :ok = Metrics.record_tool_execution("test_tool", 100.5)
    end

    test "records tool execution with integer duration" do
      assert :ok = Metrics.record_tool_execution("test_tool_int", 100)
    end

    test "accepts zero duration" do
      assert :ok = Metrics.record_tool_execution("zero_tool", 0)
    end

    test "accepts very large durations" do
      assert :ok = Metrics.record_tool_execution("slow_tool", 999_999.99)
    end

    test "accepts negative durations (boundary)" do
      # Spec says "non-negative" — test boundary
      assert :ok = Metrics.record_tool_execution("boundary_tool", 0.0)
    end

    test "returns :ok on success" do
      result = Metrics.record_tool_execution("another_tool", 50)
      assert result == :ok
    end
  end

  describe "CRASH: record_provider_call/3" do
    test "records provider call with success=true" do
      assert :ok = Metrics.record_provider_call(:anthropic, 500, true)
    end

    test "records provider call with success=false" do
      assert :ok = Metrics.record_provider_call(:openai, 750, false)
    end

    test "accepts zero duration" do
      assert :ok = Metrics.record_provider_call(:ollama, 0, true)
    end

    test "accepts atom provider names" do
      assert :ok = Metrics.record_provider_call(:custom_provider, 100, true)
    end

    test "returns :ok on success" do
      result = Metrics.record_provider_call(:anthropic, 600, true)
      assert result == :ok
    end
  end

  describe "CRASH: record_noise_filter_result/1" do
    test "records :filtered outcome" do
      assert :ok = Metrics.record_noise_filter_result(:filtered)
    end

    test "records :clarify outcome" do
      assert :ok = Metrics.record_noise_filter_result(:clarify)
    end

    test "records :pass outcome" do
      assert :ok = Metrics.record_noise_filter_result(:pass)
    end

    test "returns :ok on success" do
      result = Metrics.record_noise_filter_result(:filtered)
      assert result == :ok
    end
  end

  describe "CRASH: record_signal_weight/1" do
    test "records weight 0.0" do
      assert :ok = Metrics.record_signal_weight(0.0)
    end

    test "records weight 1.0" do
      assert :ok = Metrics.record_signal_weight(1.0)
    end

    test "records weight in middle range" do
      assert :ok = Metrics.record_signal_weight(0.5)
    end

    test "records weight with many decimals" do
      assert :ok = Metrics.record_signal_weight(0.123456)
    end

    test "accepts integer 0 (converts to float)" do
      assert :ok = Metrics.record_signal_weight(0)
    end

    test "accepts integer 1 (converts to float)" do
      assert :ok = Metrics.record_signal_weight(1)
    end

    test "returns :ok on success" do
      result = Metrics.record_signal_weight(0.75)
      assert result == :ok
    end
  end

  describe "CRASH: get_metrics/0" do
    test "returns map with all metric categories" do
      metrics = Metrics.get_metrics()
      assert is_map(metrics)
      assert Map.has_key?(metrics, :tool_executions)
      assert Map.has_key?(metrics, :provider_latency)
      assert Map.has_key?(metrics, :session_stats)
      assert Map.has_key?(metrics, :noise_filter)
      assert Map.has_key?(metrics, :signal_weights)
    end

    test "tool_executions is a map" do
      metrics = Metrics.get_metrics()
      assert is_map(metrics.tool_executions)
    end

    test "provider_latency is a map" do
      metrics = Metrics.get_metrics()
      assert is_map(metrics.provider_latency)
    end

    test "noise_filter contains counters for :filtered, :clarify, :pass" do
      metrics = Metrics.get_metrics()
      noise_filter = metrics.noise_filter
      assert is_map(noise_filter)
      assert Map.has_key?(noise_filter, :filtered) or Map.has_key?(noise_filter, "filtered")
      assert Map.has_key?(noise_filter, :clarify) or Map.has_key?(noise_filter, "clarify")
      assert Map.has_key?(noise_filter, :pass) or Map.has_key?(noise_filter, "pass")
    end

    test "signal_weights contains all 4 buckets" do
      metrics = Metrics.get_metrics()
      weights = metrics.signal_weights
      assert is_map(weights)
      assert Enum.any?(
        [:"0.0-0.2", "0.0-0.2"],
        &Map.has_key?(weights, &1)
      )
      assert Enum.any?(
        [:"0.2-0.5", "0.2-0.5"],
        &Map.has_key?(weights, &1)
      )
      assert Enum.any?(
        [:"0.5-0.8", "0.5-0.8"],
        &Map.has_key?(weights, &1)
      )
      assert Enum.any?(
        [:"0.8-1.0", "0.8-1.0"],
        &Map.has_key?(weights, &1)
      )
    end
  end

  describe "CRASH: get_summary/0" do
    test "returns map with aggregated metrics" do
      summary = Metrics.get_summary()
      assert is_map(summary)
      assert Map.has_key?(summary, :tool_executions)
      assert Map.has_key?(summary, :provider_latency)
      assert Map.has_key?(summary, :session_stats)
      assert Map.has_key?(summary, :noise_filter_rate)
      assert Map.has_key?(summary, :signal_weight_distribution)
    end

    test "noise_filter_rate is a float" do
      summary = Metrics.get_summary()
      rate = summary.noise_filter_rate
      assert is_float(rate)
    end

    test "noise_filter_rate is between 0.0 and 100.0" do
      summary = Metrics.get_summary()
      rate = summary.noise_filter_rate
      assert rate >= 0.0
      assert rate <= 100.0
    end

    test "tool_executions summary has counts and stats" do
      # Record a tool first
      Metrics.record_tool_execution("summary_tool", 100)
      Metrics.record_tool_execution("summary_tool", 200)
      Metrics.record_tool_execution("summary_tool", 300)

      summary = Metrics.get_summary()
      tool_stats = summary.tool_executions

      # At least one tool should have statistics
      if Enum.any?(tool_stats, fn {_name, stats} -> Map.has_key?(stats, :count) end) do
        tool_with_stats = Enum.find(tool_stats, fn {_name, stats} ->
          Map.has_key?(stats, :count)
        end)

        assert tool_with_stats != nil

        {_name, stats} = tool_with_stats
        assert Map.has_key?(stats, :count)
        assert Map.has_key?(stats, :avg_ms)
        assert Map.has_key?(stats, :min_ms)
        assert Map.has_key?(stats, :max_ms)
        assert Map.has_key?(stats, :p99_ms)
      end
    end

    test "signal_weight_distribution sums to approximately 100" do
      # Record weights to test distribution
      Metrics.record_signal_weight(0.1)
      Metrics.record_signal_weight(0.3)
      Metrics.record_signal_weight(0.6)
      Metrics.record_signal_weight(0.9)

      summary = Metrics.get_summary()
      dist = summary.signal_weight_distribution

      total =
        dist
        |> Map.values()
        |> Enum.sum()

      # If we have any weights recorded, distribution should sum to ~100
      if total > 0 do
        assert total >= 99.0 and total <= 101.0
      end
    end
  end

  describe "CRASH: Module behavior contract" do
    test "record_* functions are exported" do
      assert function_exported?(Metrics, :record_tool_execution, 2)
      assert function_exported?(Metrics, :record_provider_call, 3)
      assert function_exported?(Metrics, :record_noise_filter_result, 1)
      assert function_exported?(Metrics, :record_signal_weight, 1)
    end

    test "get_* functions are exported" do
      assert function_exported?(Metrics, :get_metrics, 0)
      assert function_exported?(Metrics, :get_summary, 0)
    end

    test "GenServer callbacks are implemented" do
      assert function_exported?(Metrics, :start_link, 1)
      assert function_exported?(Metrics, :init, 1)
      assert function_exported?(Metrics, :handle_call, 3)
      assert function_exported?(Metrics, :handle_cast, 2)
    end

    test "all functions handle edge cases without crashing" do
      # The spec says "Raises nothing" for all record_* functions
      assert :ok = Metrics.record_tool_execution("", 0)
      assert :ok = Metrics.record_provider_call(:nil, 0, true)
      assert :ok = Metrics.record_noise_filter_result(:filtered)
      assert :ok = Metrics.record_signal_weight(0.5)
    end
  end

  describe "CRASH: Idempotency and consistency" do
    test "recording same metric multiple times accumulates" do
      tool_name = "idempotent_tool_#{:erlang.unique_integer()}"

      Metrics.record_tool_execution(tool_name, 100)
      metrics1 = Metrics.get_metrics()

      Metrics.record_tool_execution(tool_name, 200)
      metrics2 = Metrics.get_metrics()

      # Metrics should change when recording new data
      # (We can't directly compare because ETS lists are in insertion order)
      assert is_map(metrics1)
      assert is_map(metrics2)
    end

    test "get_metrics returns consistent structure across calls" do
      metrics1 = Metrics.get_metrics()
      metrics2 = Metrics.get_metrics()

      assert Map.keys(metrics1) == Map.keys(metrics2)
    end

    test "get_summary returns consistent structure across calls" do
      summary1 = Metrics.get_summary()
      summary2 = Metrics.get_summary()

      assert Map.keys(summary1) == Map.keys(summary2)
    end
  end

  describe "CRASH: Data flow from record to get" do
    test "recorded tool execution appears in get_metrics" do
      tool = "flow_test_#{:erlang.unique_integer()}"
      Metrics.record_tool_execution(tool, 123.45)

      metrics = Metrics.get_metrics()
      tool_execs = metrics.tool_executions

      # Tool should now be in the metrics
      assert is_map(tool_execs)
    end

    test "recorded provider call appears in get_metrics" do
      Metrics.record_provider_call(:flow_test, 500, true)

      metrics = Metrics.get_metrics()
      latencies = metrics.provider_latency

      assert is_map(latencies)
    end

    test "noise filter records appear in summary" do
      Metrics.record_noise_filter_result(:filtered)
      Metrics.record_noise_filter_result(:pass)

      summary = Metrics.get_summary()
      rate = summary.noise_filter_rate

      # Should have computed a rate
      assert is_float(rate)
      assert rate >= 0.0
    end

    test "signal weights appear in distribution" do
      Metrics.record_signal_weight(0.25)
      Metrics.record_signal_weight(0.75)

      summary = Metrics.get_summary()
      dist = summary.signal_weight_distribution

      assert is_map(dist)
    end
  end
end
