defmodule OSA.Semconv.SpanCoverageTest do
  @moduledoc """
  Regression gate: every span name constant in the semconv modules must be
  a non-empty, dotted-namespace string.

  Armstrong rule: if you add a span name constant and it is empty or not
  namespaced, this test fails immediately — making the breakage visible before
  any span reaches Jaeger.

  Run with: mix test test/semconv/span_coverage_test.exs
  """
  use ExUnit.Case, async: true

  # Primary consolidated span names module (used across all domains)
  alias OpenTelemetry.SemConv.Incubating.SpanNames

  # Domain-specific modules with all/0 accessor
  alias OpenTelemetry.SemConv.Incubating.HealingSpanNames
  alias OpenTelemetry.SemConv.Incubating.YawlSpanNames
  alias OpenTelemetry.SemConv.Incubating.BoardSpanNames
  alias OpenTelemetry.SemConv.Incubating.JtbdSpanNames
  alias OpenTelemetry.SemConv.Incubating.McpSpanNames
  alias OpenTelemetry.SemConv.Incubating.A2aSpanNames

  # ──────────────────────────────────────────────────────────────────────────
  # Part 1: Primary SpanNames module — all constants are valid dotted strings
  # ──────────────────────────────────────────────────────────────────────────

  describe "SpanNames primary module" do
    test "all span name functions return non-empty dotted namespace strings" do
      span_functions =
        SpanNames.__info__(:functions)
        |> Enum.filter(fn {_name, arity} -> arity == 0 end)
        |> Enum.map(fn {name, _} -> name end)

      assert length(span_functions) > 0,
             "SpanNames module must define at least one span name function"

      for func <- span_functions do
        span_name = apply(SpanNames, func, [])
        assert is_binary(span_name),
               "SpanNames.#{func}/0 must return a string, got: #{inspect(span_name)}"
        assert String.length(span_name) > 2,
               "SpanNames.#{func}/0 span name too short: #{inspect(span_name)}"
        assert String.contains?(span_name, "."),
               "SpanNames.#{func}/0 span '#{span_name}' must use dotted namespace format"
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Part 2: Healing domain spans (Agent 5)
  # ──────────────────────────────────────────────────────────────────────────

  describe "healing domain spans (Agent 5)" do
    test "healing.diagnosis is defined in SpanNames" do
      assert SpanNames.healing_diagnosis() == "healing.diagnosis"
    end

    test "healing.reflex_arc is defined in SpanNames" do
      assert SpanNames.healing_reflex_arc() == "healing.reflex_arc"
    end

    test "HealingSpanNames.all/0 contains healing.diagnosis and healing.reflex_arc" do
      all = HealingSpanNames.all()
      assert is_list(all)
      assert "healing.diagnosis" in all,
             "HealingSpanNames.all() must contain healing.diagnosis"
      assert "healing.reflex_arc" in all,
             "HealingSpanNames.all() must contain healing.reflex_arc"
    end

    test "all HealingSpanNames constants are non-empty dotted strings" do
      for span_name <- HealingSpanNames.all() do
        assert is_binary(span_name),
               "HealingSpanNames entry must be a string, got: #{inspect(span_name)}"
        assert String.contains?(span_name, "."),
               "HealingSpanNames '#{span_name}' must use dotted namespace format"
        assert String.starts_with?(span_name, "healing."),
               "HealingSpanNames '#{span_name}' must start with 'healing.'"
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Part 3: YAWL domain spans (Agent 6)
  # ──────────────────────────────────────────────────────────────────────────

  describe "yawl domain spans (Agent 6)" do
    test "yawl.case is defined in SpanNames" do
      assert SpanNames.yawl_case() == "yawl.case"
    end

    test "yawl.task.execution is defined in SpanNames" do
      assert SpanNames.yawl_task_execution() == "yawl.task.execution"
    end

    test "YawlSpanNames.all/0 contains yawl.case and yawl.task.execution" do
      all = YawlSpanNames.all()
      assert is_list(all)
      assert "yawl.case" in all,
             "YawlSpanNames.all() must contain yawl.case"
      assert "yawl.task.execution" in all,
             "YawlSpanNames.all() must contain yawl.task.execution"
    end

    test "all YawlSpanNames constants are non-empty dotted strings" do
      for span_name <- YawlSpanNames.all() do
        assert is_binary(span_name),
               "YawlSpanNames entry must be a string, got: #{inspect(span_name)}"
        assert String.contains?(span_name, "."),
               "YawlSpanNames '#{span_name}' must use dotted namespace format"
        assert String.starts_with?(span_name, "yawl."),
               "YawlSpanNames '#{span_name}' must start with 'yawl.'"
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Part 4: Process Mining domain spans (Agent 7)
  # ──────────────────────────────────────────────────────────────────────────

  describe "process mining domain spans (Agent 7)" do
    test "process.mining.discovery is defined in SpanNames" do
      assert SpanNames.process_mining_discovery() == "process.mining.discovery"
    end

    test "a2a.call is defined in SpanNames" do
      assert SpanNames.a2a_call() == "a2a.call"
    end

    test "conformance.check is defined in SpanNames" do
      assert SpanNames.conformance_check() == "conformance.check"
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Part 5: JTBD DMAIC domain spans (Agent 8)
  # ──────────────────────────────────────────────────────────────────────────

  describe "jtbd dmaic domain spans (Agent 8)" do
    test "jtbd.dmaic.phase is defined in SpanNames" do
      assert SpanNames.jtbd_dmaic_phase() == "jtbd.dmaic.phase"
    end

    test "jtbd.dmaic.phase is defined in JtbdSpanNames" do
      assert JtbdSpanNames.jtbd_dmaic_phase() == "jtbd.dmaic.phase"
    end

    test "JtbdSpanNames.all/0 contains jtbd scenario spans and dmaic phase" do
      all = JtbdSpanNames.all()
      assert is_list(all)
      assert "jtbd.dmaic.phase" in all,
             "JtbdSpanNames.all() must contain jtbd.dmaic.phase"
      assert length(all) >= 9,
             "JtbdSpanNames.all() must contain at least 9 spans, got #{length(all)}"
    end

    test "all JtbdSpanNames constants are non-empty dotted strings" do
      for span_name <- JtbdSpanNames.all() do
        assert is_binary(span_name),
               "JtbdSpanNames entry must be a string, got: #{inspect(span_name)}"
        assert String.contains?(span_name, "."),
               "JtbdSpanNames '#{span_name}' must use dotted namespace format"
        assert String.starts_with?(span_name, "jtbd."),
               "JtbdSpanNames '#{span_name}' must start with 'jtbd.'"
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Part 6: Board intelligence spans (pre-sprint, regression guard)
  # ──────────────────────────────────────────────────────────────────────────

  describe "board intelligence spans (pre-sprint)" do
    test "board.briefing_render is defined in BoardSpanNames" do
      assert BoardSpanNames.board_briefing_render() == "board.briefing_render"
    end

    test "board.conway_check is defined in BoardSpanNames" do
      assert BoardSpanNames.board_conway_check() == "board.conway_check"
    end

    test "board.structural_escalation is defined in BoardSpanNames" do
      assert BoardSpanNames.board_structural_escalation() == "board.structural_escalation"
    end

    test "all BoardSpanNames constants are non-empty dotted strings" do
      for span_name <- BoardSpanNames.all() do
        assert is_binary(span_name),
               "BoardSpanNames entry must be a string, got: #{inspect(span_name)}"
        assert String.contains?(span_name, "."),
               "BoardSpanNames '#{span_name}' must use dotted namespace format"
        assert String.starts_with?(span_name, "board."),
               "BoardSpanNames '#{span_name}' must start with 'board.'"
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Part 7: No duplicate span names across all domains
  # ──────────────────────────────────────────────────────────────────────────

  describe "no duplicate span names" do
    test "all span names across healing + yawl + jtbd + board + mcp + a2a are unique" do
      all_spans =
        HealingSpanNames.all() ++
          YawlSpanNames.all() ++
          JtbdSpanNames.all() ++
          BoardSpanNames.all() ++
          McpSpanNames.all() ++
          A2aSpanNames.all()

      unique_spans = Enum.uniq(all_spans)

      assert length(all_spans) == length(unique_spans),
             "Duplicate span names found: #{inspect(all_spans -- unique_spans)}"
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Part 8: MCP domain spans
  # ──────────────────────────────────────────────────────────────────────────

  describe "mcp domain spans" do
    test "mcp.tool_execute is defined in McpSpanNames" do
      assert McpSpanNames.mcp_tool_execute() == "mcp.tool_execute"
    end

    test "McpSpanNames.all/0 contains mcp.call and mcp.connection.establish" do
      all = McpSpanNames.all()
      assert is_list(all)
      assert "mcp.call" in all,
             "McpSpanNames.all() must contain mcp.call"
      assert "mcp.connection.establish" in all,
             "McpSpanNames.all() must contain mcp.connection.establish"
      assert length(all) >= 17,
             "McpSpanNames.all() must contain at least 17 spans, got #{length(all)}"
    end

    test "all McpSpanNames constants are non-empty dotted strings with mcp. prefix" do
      for span_name <- McpSpanNames.all() do
        assert is_binary(span_name),
               "McpSpanNames entry must be a string, got: #{inspect(span_name)}"
        assert String.contains?(span_name, "."),
               "McpSpanNames '#{span_name}' must use dotted namespace format"
        assert String.starts_with?(span_name, "mcp."),
               "McpSpanNames '#{span_name}' must start with 'mcp.'"
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Part 9: A2A domain spans
  # ──────────────────────────────────────────────────────────────────────────

  describe "a2a domain spans" do
    test "a2a.call is defined in A2aSpanNames" do
      assert A2aSpanNames.a2a_call() == "a2a.call"
    end

    test "a2a.task.delegate is defined in A2aSpanNames" do
      assert A2aSpanNames.a2a_task_delegate() == "a2a.task.delegate"
    end

    test "A2aSpanNames.all/0 contains a2a.call and a2a.negotiate" do
      all = A2aSpanNames.all()
      assert is_list(all)
      assert "a2a.call" in all,
             "A2aSpanNames.all() must contain a2a.call"
      assert "a2a.negotiate" in all,
             "A2aSpanNames.all() must contain a2a.negotiate"
      assert length(all) >= 29,
             "A2aSpanNames.all() must contain at least 29 spans, got #{length(all)}"
    end

    test "all A2aSpanNames constants are non-empty dotted strings with a2a. prefix" do
      for span_name <- A2aSpanNames.all() do
        assert is_binary(span_name),
               "A2aSpanNames entry must be a string, got: #{inspect(span_name)}"
        assert String.contains?(span_name, "."),
               "A2aSpanNames '#{span_name}' must use dotted namespace format"
        assert String.starts_with?(span_name, "a2a."),
               "A2aSpanNames '#{span_name}' must start with 'a2a.'"
      end
    end
  end
end
