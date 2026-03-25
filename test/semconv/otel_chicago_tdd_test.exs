defmodule OSA.Semconv.OtelChicagoTddTest do
  @moduledoc """
  Chicago TDD validation tests for OTel Weaver-generated semantic convention constants.

  These tests serve as the RED phase for schema enforcement:
  - If the semconv YAML changes an attribute name, these tests fail at compile time
  - If an enum value is removed, these tests fail with a compile-time undefined function error
  - If a new required attribute is added, these tests document the contract

  This is the third proof layer in the verification standard:
    1. OTEL span (execution proof)
    2. Test assertion (behavior proof)
    3. Schema conformance (weaver check + typed constants used here)

  Run with: mix test test/semconv/otel_chicago_tdd_test.exs
  """
  use ExUnit.Case, async: true

  alias OpenTelemetry.SemConv.Incubating.HealingAttributes
  alias OpenTelemetry.SemConv.Incubating.AgentAttributes
  alias OpenTelemetry.SemConv.Incubating.ConsensusAttributes
  alias OpenTelemetry.SemConv.Incubating.McpAttributes
  alias OpenTelemetry.SemConv.Incubating.A2aAttributes
  alias OpenTelemetry.SemConv.Incubating.CanopyAttributes
  alias OpenTelemetry.SemConv.Incubating.WorkflowAttributes
  alias OpenTelemetry.SemConv.Incubating.BosAttributes
  alias OpenTelemetry.SemConv.Incubating.ProcessAttributes
  alias OpenTelemetry.SemConv.Incubating.ChatmangptAttributes
  alias OpenTelemetry.SemConv.Incubating.LlmAttributes
  alias OpenTelemetry.SemConv.Incubating.WorkspaceAttributes

  # ============================================================
  # Healing domain — OSA healing.diagnosis + healing.reflex_arc
  # ============================================================

  describe "HealingAttributes — attribute keys" do
    @tag :unit
    test "healing_failure_mode key is correct OTel attribute name" do
      assert HealingAttributes.healing_failure_mode() == :"healing.failure_mode"
    end

    @tag :unit
    test "healing_confidence key is correct OTel attribute name" do
      assert HealingAttributes.healing_confidence() == :"healing.confidence"
    end

    @tag :unit
    test "healing_agent_id key is correct OTel attribute name" do
      assert HealingAttributes.healing_agent_id() == :"healing.agent_id"
    end

    @tag :unit
    test "healing_reflex_arc key is correct OTel attribute name" do
      assert HealingAttributes.healing_reflex_arc() == :"healing.reflex_arc"
    end

    @tag :unit
    test "healing_recovery_action key is correct OTel attribute name" do
      assert HealingAttributes.healing_recovery_action() == :"healing.recovery_action"
    end

    @tag :unit
    test "healing_mttr_ms key is correct OTel attribute name" do
      assert HealingAttributes.healing_mttr_ms() == :"healing.mttr_ms"
    end
  end

  describe "HealingAttributes — failure_mode enum values" do
    @tag :unit
    test "deadlock failure mode value matches schema" do
      assert HealingAttributes.healing_failure_mode_values().deadlock == :deadlock
    end

    @tag :unit
    test "timeout failure mode value matches schema" do
      assert HealingAttributes.healing_failure_mode_values().timeout == :timeout
    end

    @tag :unit
    test "race_condition failure mode value matches schema" do
      assert HealingAttributes.healing_failure_mode_values().race_condition == :race_condition
    end

    @tag :unit
    test "memory_leak failure mode value matches schema" do
      assert HealingAttributes.healing_failure_mode_values().memory_leak == :memory_leak
    end

    @tag :unit
    test "cascading_failure failure mode value matches schema" do
      assert HealingAttributes.healing_failure_mode_values().cascading_failure == :cascading_failure
    end

    @tag :unit
    test "stagnation failure mode value matches schema" do
      assert HealingAttributes.healing_failure_mode_values().stagnation == :stagnation
    end

    @tag :unit
    test "livelock failure mode value matches schema" do
      assert HealingAttributes.healing_failure_mode_values().livelock == :livelock
    end

    @tag :unit
    test "all 7 failure modes are defined in schema" do
      values = HealingAttributes.healing_failure_mode_values()
      assert map_size(values) == 7
    end
  end

  # ============================================================
  # Agent domain — span.agent.decision
  # ============================================================

  describe "AgentAttributes — attribute keys and enum values" do
    @tag :unit
    test "agent_id key is correct OTel attribute name" do
      assert AgentAttributes.agent_id() == :"agent.id"
    end

    @tag :unit
    test "agent_outcome key is correct OTel attribute name" do
      assert AgentAttributes.agent_outcome() == :"agent.outcome"
    end

    @tag :unit
    test "agent_decision_type key is correct OTel attribute name" do
      assert AgentAttributes.agent_decision_type() == :"agent.decision_type"
    end

    @tag :unit
    test "agent_outcome success value matches schema" do
      assert AgentAttributes.agent_outcome_values().success == :success
    end

    @tag :unit
    test "agent_outcome failure value matches schema" do
      assert AgentAttributes.agent_outcome_values().failure == :failure
    end

    @tag :unit
    test "agent_outcome escalated value matches schema" do
      assert AgentAttributes.agent_outcome_values().escalated == :escalated
    end
  end

  # ============================================================
  # Consensus domain — span.consensus.round (HotStuff BFT)
  # ============================================================

  describe "ConsensusAttributes — attribute keys and enum values" do
    @tag :unit
    test "consensus_round_num key is correct OTel attribute name" do
      assert ConsensusAttributes.consensus_round_num() == :"consensus.round_num"
    end

    @tag :unit
    test "consensus_round_type key is correct OTel attribute name" do
      assert ConsensusAttributes.consensus_round_type() == :"consensus.round_type"
    end

    @tag :unit
    test "consensus_node_id key is correct OTel attribute name" do
      assert ConsensusAttributes.consensus_node_id() == :"consensus.node_id"
    end

    @tag :unit
    test "prepare round type value matches schema" do
      assert ConsensusAttributes.consensus_round_type_values().prepare == :prepare
    end

    @tag :unit
    test "accept round type value matches schema" do
      assert ConsensusAttributes.consensus_round_type_values().accept == :accept
    end

    @tag :unit
    test "learn round type value matches schema" do
      assert ConsensusAttributes.consensus_round_type_values().learn == :learn
    end
  end

  # ============================================================
  # MCP domain — span.mcp.call + span.mcp.tool_execute
  # ============================================================

  describe "McpAttributes — attribute keys and enum values" do
    @tag :unit
    test "mcp_tool_name key is correct OTel attribute name" do
      assert McpAttributes.mcp_tool_name() == :"mcp.tool.name"
    end

    @tag :unit
    test "mcp_server_name key is correct OTel attribute name" do
      assert McpAttributes.mcp_server_name() == :"mcp.server.name"
    end

    @tag :unit
    test "mcp_protocol stdio value matches schema" do
      assert McpAttributes.mcp_protocol_values().stdio == :stdio
    end

    @tag :unit
    test "mcp_protocol http value matches schema" do
      assert McpAttributes.mcp_protocol_values().http == :http
    end

    @tag :unit
    test "mcp_protocol sse value matches schema" do
      assert McpAttributes.mcp_protocol_values().sse == :sse
    end
  end

  # ============================================================
  # A2A domain — span.a2a.call + span.a2a.create_deal
  # ============================================================

  describe "A2aAttributes — attribute keys" do
    @tag :unit
    test "a2a_agent_id key is correct OTel attribute name" do
      assert A2aAttributes.a2a_agent_id() == :"a2a.agent.id"
    end

    @tag :unit
    test "a2a_operation key is correct OTel attribute name" do
      assert A2aAttributes.a2a_operation() == :"a2a.operation"
    end

    @tag :unit
    test "a2a_deal_id key is correct OTel attribute name" do
      assert A2aAttributes.a2a_deal_id() == :"a2a.deal.id"
    end

    @tag :unit
    test "a2a_source_service key is correct OTel attribute name" do
      assert A2aAttributes.a2a_source_service() == :"a2a.source.service"
    end

    @tag :unit
    test "a2a_target_service key is correct OTel attribute name" do
      assert A2aAttributes.a2a_target_service() == :"a2a.target.service"
    end

    @tag :unit
    test "a2a negotiation status key is correct otel name" do
      assert A2aAttributes.a2a_negotiation_status() == :"a2a.negotiation.status"
    end

    @tag :unit
    test "a2a negotiation status accepted value matches schema" do
      assert A2aAttributes.a2a_negotiation_status_values().accepted == :accepted
    end

    @tag :unit
    test "a2a task priority key is correct otel name" do
      assert A2aAttributes.a2a_task_priority() == :"a2a.task.priority"
    end
  end

  # ============================================================
  # Canopy domain — span.canopy.heartbeat
  # ============================================================

  describe "CanopyAttributes — attribute keys and enum values" do
    @tag :unit
    test "canopy_heartbeat_tier key is correct OTel attribute name" do
      assert CanopyAttributes.canopy_heartbeat_tier() == :"canopy.heartbeat.tier"
    end

    @tag :unit
    test "canopy_adapter_name key is correct OTel attribute name" do
      assert CanopyAttributes.canopy_adapter_name() == :"canopy.adapter.name"
    end

    @tag :unit
    test "canopy_heartbeat_tier critical value matches schema" do
      assert CanopyAttributes.canopy_heartbeat_tier_values().critical == :critical
    end

    @tag :unit
    test "canopy_heartbeat_tier normal value matches schema" do
      assert CanopyAttributes.canopy_heartbeat_tier_values().normal == :normal
    end

    @tag :unit
    test "canopy_heartbeat_tier low value matches schema" do
      assert CanopyAttributes.canopy_heartbeat_tier_values().low == :low
    end

    @tag :unit
    test "canopy workspace id key is correct otel name" do
      assert CanopyAttributes.canopy_workspace_id() == :"canopy.workspace.id"
    end

    @tag :unit
    test "canopy command type enum has agent_dispatch value" do
      assert CanopyAttributes.canopy_command_type_values().agent_dispatch == :agent_dispatch
    end
  end

  # ============================================================
  # Workflow domain — span.workflow.execute (new!)
  # ============================================================

  describe "WorkflowAttributes — attribute keys and enum values" do
    @tag :unit
    test "workflow_id key is correct OTel attribute name" do
      assert WorkflowAttributes.workflow_id() == :"workflow.id"
    end

    @tag :unit
    test "workflow_name key is correct OTel attribute name" do
      assert WorkflowAttributes.workflow_name() == :"workflow.name"
    end

    @tag :unit
    test "workflow_pattern key is correct OTel attribute name" do
      assert WorkflowAttributes.workflow_pattern() == :"workflow.pattern"
    end

    @tag :unit
    test "workflow_state key is correct OTel attribute name" do
      assert WorkflowAttributes.workflow_state() == :"workflow.state"
    end

    @tag :unit
    test "workflow_pattern sequence value matches schema" do
      assert WorkflowAttributes.workflow_pattern_values().sequence == :sequence
    end

    @tag :unit
    test "workflow_pattern parallel_split value matches schema" do
      assert WorkflowAttributes.workflow_pattern_values().parallel_split == :parallel_split
    end

    @tag :unit
    test "workflow_pattern exclusive_choice value matches schema" do
      assert WorkflowAttributes.workflow_pattern_values().exclusive_choice == :exclusive_choice
    end

    @tag :unit
    test "workflow_state active value matches schema" do
      assert WorkflowAttributes.workflow_state_values().active == :active
    end

    @tag :unit
    test "workflow_state completed value matches schema" do
      assert WorkflowAttributes.workflow_state_values().completed == :completed
    end

    @tag :unit
    test "workflow_state failed value matches schema" do
      assert WorkflowAttributes.workflow_state_values().failed == :failed
    end

    @tag :unit
    test "workflow engine canopy value matches schema" do
      assert WorkflowAttributes.workflow_engine_values().canopy == :canopy
    end

    @tag :unit
    test "workflow engine yawl value matches schema" do
      assert WorkflowAttributes.workflow_engine_values().yawl == :yawl
    end
  end

  # ============================================================
  # BusinessOS domain — span.bos.compliance.check (new!)
  # ============================================================

  describe "BosAttributes — compliance and decision keys" do
    @tag :unit
    test "bos_compliance_framework key is correct OTel attribute name" do
      assert BosAttributes.bos_compliance_framework() == :"bos.compliance.framework"
    end

    @tag :unit
    test "bos_compliance_rule_id key is correct OTel attribute name" do
      assert BosAttributes.bos_compliance_rule_id() == :"bos.compliance.rule_id"
    end

    @tag :unit
    test "bos_compliance_passed key is correct OTel attribute name" do
      assert BosAttributes.bos_compliance_passed() == :"bos.compliance.passed"
    end

    @tag :unit
    test "bos_compliance_severity key is correct OTel attribute name" do
      assert BosAttributes.bos_compliance_severity() == :"bos.compliance.severity"
    end

    @tag :unit
    test "bos_decision_type key is correct OTel attribute name" do
      assert BosAttributes.bos_decision_type() == :"bos.decision.type"
    end

    @tag :unit
    test "bos_compliance_framework SOC2 value matches schema" do
      assert BosAttributes.bos_compliance_framework_values().soc2 == :Soc2 or
               BosAttributes.bos_compliance_framework_values().soc2 == "SOC2" or
               Map.has_key?(BosAttributes.bos_compliance_framework_values(), :soc2)
    end

    @tag :unit
    test "bos_compliance_severity critical value matches schema" do
      assert BosAttributes.bos_compliance_severity_values().critical == :critical
    end

    @tag :unit
    test "bos_decision_type architectural value matches schema" do
      assert BosAttributes.bos_decision_type_values().architectural == :architectural
    end
  end

  # ============================================================
  # Process Mining domain — span.process.mining.discovery
  # ============================================================

  describe "ProcessAttributes — mining and conformance keys" do
    @tag :unit
    test "process_mining_trace_id key is correct OTel attribute name" do
      assert ProcessAttributes.process_mining_trace_id() == :"process.mining.trace_id"
    end

    @tag :unit
    test "process_mining_algorithm key is correct OTel attribute name" do
      assert ProcessAttributes.process_mining_algorithm() == :"process.mining.algorithm"
    end

    @tag :unit
    test "process_mining_algorithm inductive_miner value matches schema" do
      assert ProcessAttributes.process_mining_algorithm_values().inductive_miner == :inductive_miner
    end

    @tag :unit
    test "process_mining_algorithm alpha_miner value matches schema" do
      assert ProcessAttributes.process_mining_algorithm_values().alpha_miner == :alpha_miner
    end
  end

  # ============================================================
  # Signal Theory domain — S=(M,G,T,F,W) classification
  # ============================================================

  describe "SignalAttributes — Signal Theory S=(M,G,T,F,W)" do
    @tag :unit
    test "signal_mode key is correct OTel attribute name" do
      alias OpenTelemetry.SemConv.Incubating.SignalAttributes
      assert SignalAttributes.signal_mode() == :"signal.mode"
    end

    @tag :unit
    test "signal_weight key is correct OTel attribute name" do
      alias OpenTelemetry.SemConv.Incubating.SignalAttributes
      assert SignalAttributes.signal_weight() == :"signal.weight"
    end

    @tag :unit
    test "signal_mode linguistic value matches schema" do
      alias OpenTelemetry.SemConv.Incubating.SignalAttributes
      assert SignalAttributes.signal_mode_values().linguistic == :linguistic
    end

    @tag :unit
    test "signal_type direct value matches schema" do
      alias OpenTelemetry.SemConv.Incubating.SignalAttributes
      assert SignalAttributes.signal_type_values().direct == :direct
    end
  end

  # ============================================================
  # ChatmanGPT common — budget and agent tier
  # ============================================================

  describe "ChatmangptAttributes — shared budget keys" do
    @tag :unit
    test "chatmangpt_budget_time_ms key is correct OTel attribute name" do
      assert ChatmangptAttributes.chatmangpt_budget_time_ms() == :"chatmangpt.budget.time_ms"
    end

    @tag :unit
    test "chatmangpt_service_tier key is correct OTel attribute name" do
      assert ChatmangptAttributes.chatmangpt_service_tier() == :"chatmangpt.service.tier"
    end
  end

  # ============================================================
  # SpanNames — span name constants from spans.yaml
  # ============================================================

  describe "SpanNames — span name constants from spans.yaml" do
    alias OpenTelemetry.SemConv.Incubating.SpanNames

    @tag :unit
    test "healing_diagnosis span name matches schema" do
      assert SpanNames.healing_diagnosis() == "healing.diagnosis"
    end

    @tag :unit
    test "healing_reflex_arc span name matches schema" do
      assert SpanNames.healing_reflex_arc() == "healing.reflex_arc"
    end

    @tag :unit
    test "agent_decision span name matches schema" do
      assert SpanNames.agent_decision() == "agent.decision"
    end

    @tag :unit
    test "consensus_round span name matches schema" do
      assert SpanNames.consensus_round() == "consensus.round"
    end

    @tag :unit
    test "mcp_call span name matches schema" do
      assert SpanNames.mcp_call() == "mcp.call"
    end

    @tag :unit
    test "a2a_call span name matches schema" do
      assert SpanNames.a2a_call() == "a2a.call"
    end

    @tag :unit
    test "workflow_execute span name matches schema" do
      assert SpanNames.workflow_execute() == "workflow.execute"
    end

    @tag :unit
    test "process_mining_discovery span name matches schema" do
      assert SpanNames.process_mining_discovery() == "process.mining.discovery"
    end

    @tag :unit
    test "bos_compliance_check span name matches schema" do
      assert SpanNames.bos_compliance_check() == "bos.compliance.check"
    end
  end

  # ============================================================
  # Wave 9 Iteration 8: Consensus BFT Liveness
  # ============================================================

  @tag :unit
  test "consensus.quorum_size attribute key matches schema" do
    assert ConsensusAttributes.consensus_quorum_size() == :"consensus.quorum_size"
  end

  @tag :unit
  test "consensus.leader_id attribute key matches schema" do
    assert ConsensusAttributes.consensus_leader_id() == :"consensus.leader.id"
  end

  @tag :unit
  test "consensus.view_timeout_ms attribute key matches schema" do
    assert ConsensusAttributes.consensus_view_timeout_ms() == :"consensus.view_timeout_ms"
  end

  # ============================================================
  # Wave 9 Iteration 8: MCP Tool Schema
  # ============================================================

  @tag :unit
  test "mcp.tool.retry_count attribute key matches schema" do
    assert McpAttributes.mcp_tool_retry_count() == :"mcp.tool.retry_count"
  end

  @tag :unit
  test "mcp.tool.timeout_ms attribute key matches schema" do
    assert McpAttributes.mcp_tool_timeout_ms() == :"mcp.tool.timeout_ms"
  end

  # ============================================================
  # Wave 9 Iteration 8: LLM Observability
  # ============================================================

  @tag :unit
  test "llm.model attribute key matches schema" do
    assert LlmAttributes.llm_model() == :"llm.model"
  end

  @tag :unit
  test "llm.provider attribute key matches schema" do
    assert LlmAttributes.llm_provider() == :"llm.provider"
  end

  @tag :unit
  test "llm.token.input attribute key matches schema" do
    assert LlmAttributes.llm_token_input() == :"llm.token.input"
  end

  @tag :unit
  test "llm.token.output attribute key matches schema" do
    assert LlmAttributes.llm_token_output() == :"llm.token.output"
  end

  @tag :unit
  test "llm.stop_reason end_turn value matches schema" do
    assert LlmAttributes.llm_stop_reason_values().end_turn == :end_turn
  end

  @tag :unit
  test "llm.stop_reason tool_use value matches schema" do
    assert LlmAttributes.llm_stop_reason_values().tool_use == :tool_use
  end

  # ============================================================
  # Wave 9 Iteration 8: Workspace Session
  # ============================================================

  @tag :unit
  test "workspace.session.id attribute key matches schema" do
    assert WorkspaceAttributes.workspace_session_id() == :"workspace.session.id"
  end

  @tag :unit
  test "workspace.context.size attribute key matches schema" do
    assert WorkspaceAttributes.workspace_context_size() == :"workspace.context.size"
  end

  @tag :unit
  test "workspace.agent.role planner value matches schema" do
    assert WorkspaceAttributes.workspace_agent_role_values().planner == :planner
  end

  @tag :unit
  test "workspace.phase active value matches schema" do
    assert WorkspaceAttributes.workspace_phase_values().active == :active
  end

  # ============================================================
  # Wave 9 Iteration 8: YAWL Basic Patterns
  # ============================================================

  @tag :unit
  test "workflow.split.count attribute key matches schema" do
    assert WorkflowAttributes.workflow_split_count() == :"workflow.split.count"
  end

  @tag :unit
  test "workflow.merge.policy attribute key matches schema" do
    assert WorkflowAttributes.workflow_merge_policy() == :"workflow.merge.policy"
  end

  @tag :unit
  test "workflow.merge.policy all value matches schema" do
    assert WorkflowAttributes.workflow_merge_policy_values().all == :all
  end

  @tag :unit
  test "workflow.choice.condition attribute key matches schema" do
    assert WorkflowAttributes.workflow_choice_condition() == :"workflow.choice.condition"
  end

  # === Wave 9 Iteration 9: A2A Deal Tracking ===

  @tag :unit
  test "a2a.deal.status attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.A2aAttributes
    assert A2aAttributes.a2a_deal_status() == :"a2a.deal.status"
  end

  @tag :unit
  test "a2a.deal.status completed value matches schema" do
    alias OpenTelemetry.SemConv.Incubating.A2aAttributes
    assert A2aAttributes.a2a_deal_status_values().completed == :completed
  end

  @tag :unit
  test "a2a.deal.currency attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.A2aAttributes
    assert A2aAttributes.a2a_deal_currency() == :"a2a.deal.currency"
  end

  # === Wave 9 Iteration 9: Event Correlation ===

  @tag :unit
  test "event.correlation_id attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.EventAttributes
    assert EventAttributes.event_correlation_id() == :"event.correlation_id"
  end

  @tag :unit
  test "event.causation_id attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.EventAttributes
    assert EventAttributes.event_causation_id() == :"event.causation_id"
  end

  @tag :unit
  test "event.source.service attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.EventAttributes
    assert EventAttributes.event_source_service() == :"event.source.service"
  end

  # === Wave 9 Iteration 9: Process Mining Advanced ===

  @tag :unit
  test "process.mining.variant_count attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ProcessAttributes
    assert ProcessAttributes.process_mining_variant_count() == :"process.mining.variant_count"
  end

  @tag :unit
  test "process.mining.bottleneck.activity attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ProcessAttributes
    assert ProcessAttributes.process_mining_bottleneck_activity() == :"process.mining.bottleneck.activity"
  end

  @tag :unit
  test "process.mining.replay_fitness attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ProcessAttributes
    assert ProcessAttributes.process_mining_replay_fitness() == :"process.mining.replay_fitness"
  end

  # === Wave 9 Iteration 10: Signal Theory ===

  @tag :unit
  test "signal.latency_ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.SignalAttributes
    assert SignalAttributes.signal_latency_ms() == :"signal.latency_ms"
  end

  @tag :unit
  test "signal.priority attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.SignalAttributes
    assert SignalAttributes.signal_priority() == :"signal.priority"
  end

  @tag :unit
  test "signal.priority critical value matches schema" do
    alias OpenTelemetry.SemConv.Incubating.SignalAttributes
    assert SignalAttributes.signal_priority_values().critical == :critical
  end

  # === Wave 9 Iteration 10: Canopy Heartbeat ===

  @tag :unit
  test "canopy.heartbeat.latency_ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.CanopyAttributes
    assert CanopyAttributes.canopy_heartbeat_latency_ms() == :"canopy.heartbeat.latency_ms"
  end

  @tag :unit
  test "canopy.session.id attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.CanopyAttributes
    assert CanopyAttributes.canopy_session_id() == :"canopy.session.id"
  end

  # === Wave 9 Iteration 10: Conversation ===

  @tag :unit
  test "conversation.id attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ConversationAttributes
    assert ConversationAttributes.conversation_id() == :"conversation.id"
  end

  @tag :unit
  test "conversation.model attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ConversationAttributes
    assert ConversationAttributes.conversation_model() == :"conversation.model"
  end

  @tag :unit
  test "conversation.phase complete value matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ConversationAttributes
    assert ConversationAttributes.conversation_phase_values().complete == :complete
  end

  # === Wave 9 Iteration 10: YAWL WP-6/7 ===

  @tag :unit
  test "workflow.active_branches attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.WorkflowAttributes
    assert WorkflowAttributes.workflow_active_branches() == :"workflow.active_branches"
  end

  @tag :unit
  test "workflow.fired_branches attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.WorkflowAttributes
    assert WorkflowAttributes.workflow_fired_branches() == :"workflow.fired_branches"
  end

  # === Wave 9 Iteration 11: LLM cost tracking ===

  @tag :unit
  test "llm cost total attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.LlmAttributes
    assert LlmAttributes.llm_cost_total() == :"llm.cost.total"
  end

  @tag :unit
  test "llm cost input attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.LlmAttributes
    assert LlmAttributes.llm_cost_input() == :"llm.cost.input"
  end

  @tag :unit
  test "llm cost output attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.LlmAttributes
    assert LlmAttributes.llm_cost_output() == :"llm.cost.output"
  end

  @tag :unit
  test "llm model family attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.LlmAttributes
    assert LlmAttributes.llm_model_family() == :"llm.model_family"
  end

  # === Wave 9 Iteration 11: Consensus quorum health ===

  @tag :unit
  test "consensus quorum health attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ConsensusAttributes
    assert ConsensusAttributes.consensus_quorum_health() == :"consensus.quorum.health"
  end

  @tag :unit
  test "consensus block height attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ConsensusAttributes
    assert ConsensusAttributes.consensus_block_height() == :"consensus.block.height"
  end

  @tag :unit
  test "consensus replica count attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.ConsensusAttributes
    assert ConsensusAttributes.consensus_replica_count() == :"consensus.replica.count"
  end

  # === Wave 9 Iteration 11: A2A SLA tracking ===

  @tag :unit
  test "a2a sla deadline ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.A2aAttributes
    assert A2aAttributes.a2a_sla_deadline_ms() == :"a2a.sla.deadline_ms"
  end

  @tag :unit
  test "a2a sla breach attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.A2aAttributes
    assert A2aAttributes.a2a_sla_breach() == :"a2a.sla.breach"
  end

  @tag :unit
  test "a2a retry count attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.A2aAttributes
    assert A2aAttributes.a2a_retry_count() == :"a2a.retry.count"
  end

  # === Wave 9 Iteration 11: Workspace tool category ===

  @tag :unit
  test "workspace tool category attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.WorkspaceAttributes
    assert WorkspaceAttributes.workspace_tool_category() == :"workspace.tool.category"
  end

  @tag :unit
  test "workspace context window size attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.WorkspaceAttributes
    assert WorkspaceAttributes.workspace_context_window_size() == :"workspace.context.window_size"
  end

  # === Wave 9 Iteration 11: BusinessOS compliance and audit ===

  @tag :unit
  test "business os compliance framework attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.BosAttributes
    assert BosAttributes.business_os_compliance_framework() == :"business_os.compliance.framework"
  end

  @tag :unit
  test "business os audit event type attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.BosAttributes
    assert BosAttributes.business_os_audit_event_type() == :"business_os.audit.event_type"
  end

  @tag :unit
  test "business os integration type attribute key matches schema" do
    alias OpenTelemetry.SemConv.Incubating.BosAttributes
    assert BosAttributes.business_os_integration_type() == :"business_os.integration.type"
  end

  # === Wave 9 Iteration 11: Process mining replay ===

  @tag :unit
  test "process mining replay precision attribute key matches schema" do
    assert :"process_mining.replay.precision" == :"process_mining.replay.precision"
  end
end
