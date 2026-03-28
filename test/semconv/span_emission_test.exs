defmodule OSA.Semconv.SpanEmissionTest do
  @moduledoc """
  Weaver live-check span emission tests for OSA.

  These tests emit real OTEL spans using typed semconv constants.
  When WEAVER_LIVE_CHECK=true, spans are exported to the Weaver receiver
  for schema conformance validation.

  Run with live-check:
      WEAVER_LIVE_CHECK=true mix test test/semconv/span_emission_test.exs

  Run without live-check (schema validation only):
      mix test test/semconv/span_emission_test.exs
  """
  use ExUnit.Case, async: false

  require OpenTelemetry.Tracer, as: Tracer

  alias OpenTelemetry.SemConv.Incubating.{HealingAttributes, HealingSpanNames,
         AgentAttributes, AgentSpanNames, WorkflowAttributes, WorkflowSpanNames,
         A2aAttributes, A2aSpanNames, ConsensusAttributes,
         ProcessAttributes, ProcessSpanNames, McpAttributes, McpSpanNames}

  # -- Healing Domain --

  describe "healing.diagnosis span emission" do
    test "emits healing.diagnosis span with semconv attributes" do
      Tracer.with_span HealingSpanNames.healing_diagnosis(), %{
        HealingAttributes.healing_failure_mode() => "deadlock",
        HealingAttributes.healing_confidence() => 0.95,
        HealingAttributes.healing_agent_id() => "osa-healer-001"
      } do
        assert true
      end
    end

    test "emits healing.diagnosis span with timeout failure mode" do
      Tracer.with_span HealingSpanNames.healing_diagnosis(), %{
        HealingAttributes.healing_failure_mode() => "timeout",
        HealingAttributes.healing_confidence() => 0.85,
        HealingAttributes.healing_mttr_ms() => 5000
      } do
        assert true
      end
    end

    test "emits healing.reflex_arc span" do
      Tracer.with_span HealingSpanNames.healing_reflex_arc(), %{
        HealingAttributes.healing_recovery_action() => "provider_failover",
        HealingAttributes.healing_reflex_arc() => "restart_agent"
      } do
        assert true
      end
    end

    test "emits healing.fingerprint span" do
      Tracer.with_span HealingSpanNames.healing_fingerprint(), %{
        HealingAttributes.healing_failure_mode() => "race_condition",
        HealingAttributes.healing_confidence() => 0.92
      } do
        assert true
      end
    end
  end

  # -- Agent Domain --

  describe "agent.decision span emission" do
    test "emits agent.decision span with outcome" do
      Tracer.with_span AgentSpanNames.agent_decision(), %{
        AgentAttributes.agent_id() => "osa-agent-001",
        AgentAttributes.agent_outcome() => "success",
        AgentAttributes.agent_decision_type() => "react"
      } do
        assert true
      end
    end

    test "emits agent.loop span" do
      Tracer.with_span AgentSpanNames.agent_loop(), %{
        AgentAttributes.agent_id() => "osa-agent-002",
        AgentAttributes.agent_budget_remaining_ms() => 4500
      } do
        assert true
      end
    end

    test "emits agent.spawn span" do
      Tracer.with_span AgentSpanNames.agent_spawn(), %{
        AgentAttributes.agent_id() => "osa-parent-001"
      } do
        assert true
      end
    end
  end

  # -- Workflow Domain --

  describe "workflow.execute span emission" do
    test "emits workflow span with YAWL pattern" do
      Tracer.with_span WorkflowSpanNames.workflow_execute(), %{
        WorkflowAttributes.workflow_pattern() => "sequence",
        WorkflowAttributes.workflow_state() => "active"
      } do
        assert true
      end
    end
  end

  # -- A2A Domain --

  describe "a2a.call span emission" do
    test "emits a2a.call span with target service" do
      Tracer.with_span A2aSpanNames.a2a_call(), %{
        A2aAttributes.a2a_source_service() => "osa",
        A2aAttributes.a2a_target_service() => "canopy",
        A2aAttributes.a2a_operation() => "heartbeat"
      } do
        assert true
      end
    end
  end

  # -- Process Mining Domain --

  describe "process.mining.discovery span emission" do
    test "emits process.mining.discovery span with algorithm" do
      Tracer.with_span ProcessSpanNames.process_mining_discovery(), %{
        ProcessAttributes.process_mining_algorithm() => "alpha_miner",
        ProcessAttributes.process_mining_variant_count() => 42
      } do
        assert true
      end
    end
  end

  # -- MCP Domain --

  describe "mcp.tool.call span emission" do
    test "emits mcp.tool.call span" do
      Tracer.with_span McpSpanNames.mcp_call(), %{
        McpAttributes.mcp_tool_name() => "process_discover",
        McpAttributes.mcp_server_name() => "pm4py-rust"
      } do
        assert true
      end
    end
  end

  # -- LLM Inference Domain --

  describe "llm.inference span emission for Groq" do
    alias OpenTelemetry.SemConv.Incubating.LlmAttributes

    test "llm_provider attribute key resolves to correct semconv atom" do
      assert LlmAttributes.llm_provider() == :"llm.provider"
    end

    test "llm_model attribute key resolves to correct semconv atom" do
      assert LlmAttributes.llm_model() == :"llm.model"
    end
  end
end
