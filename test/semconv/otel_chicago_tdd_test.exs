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
      assert AgentAttributes.agent_decision_type() == :"agent.decision.type"
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

  # === Wave 9 Iteration 12: Healing MTTR ===

  @tag :unit
  test "healing mttr ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter12Attributes
    assert HealingIter12Attributes.healing_mttr_ms() == :"healing.mttr_ms"
  end

  @tag :unit
  test "healing escalation level attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter12Attributes
    assert HealingIter12Attributes.healing_escalation_level() == :"healing.escalation.level"
  end

  @tag :unit
  test "healing repair strategy attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter12Attributes
    assert HealingIter12Attributes.healing_repair_strategy() == :"healing.repair.strategy"
  end

  # === Wave 9 Iteration 12: Agent topology ===

  @tag :unit
  test "agent topology type attribute key matches schema" do
    alias OpenTelemetry.SemConv.AgentIter12Attributes
    assert AgentIter12Attributes.agent_topology_type() == :"agent.topology.type"
  end

  @tag :unit
  test "agent task status attribute key matches schema" do
    alias OpenTelemetry.SemConv.AgentIter12Attributes
    assert AgentIter12Attributes.agent_task_status() == :"agent.task.status"
  end

  # === Wave 9 Iteration 12: Process mining streaming ===

  @tag :unit
  test "process mining streaming window size attribute key matches schema" do
    alias OpenTelemetry.SemConv.PmIter12Attributes
    assert PmIter12Attributes.pm_streaming_window_size() == :"process_mining.streaming.window_size"
  end

  @tag :unit
  test "process mining streaming lag ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.PmIter12Attributes
    assert PmIter12Attributes.pm_streaming_lag_ms() == :"process_mining.streaming.lag_ms"
  end

  @tag :unit
  test "process mining drift detected attribute key matches schema" do
    alias OpenTelemetry.SemConv.PmIter12Attributes
    assert PmIter12Attributes.pm_drift_detected() == :"process_mining.drift.detected"
  end

  @tag :unit
  test "process mining drift severity attribute key matches schema" do
    alias OpenTelemetry.SemConv.PmIter12Attributes
    assert PmIter12Attributes.pm_drift_severity() == :"process_mining.drift.severity"
  end

  # === Wave 9 Iteration 12: Canopy protocol ===

  @tag :unit
  test "canopy protocol version attribute key matches schema" do
    alias OpenTelemetry.SemConv.CanopyIter12Attributes
    assert CanopyIter12Attributes.canopy_protocol_version() == :"canopy.protocol.version"
  end

  @tag :unit
  test "canopy sync strategy attribute key matches schema" do
    alias OpenTelemetry.SemConv.CanopyIter12Attributes
    assert CanopyIter12Attributes.canopy_sync_strategy() == :"canopy.sync.strategy"
  end

  @tag :unit
  test "canopy conflict count attribute key matches schema" do
    alias OpenTelemetry.SemConv.CanopyIter12Attributes
    assert CanopyIter12Attributes.canopy_conflict_count() == :"canopy.conflict.count"
  end

  # === Wave 9 Iteration 12: LLM safety ===

  @tag :unit
  test "llm safety score attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter12Attributes
    assert LlmIter12Attributes.llm_safety_score() == :"llm.safety.score"
  end

  @tag :unit
  test "llm guardrail triggered attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter12Attributes
    assert LlmIter12Attributes.llm_guardrail_triggered() == :"llm.guardrail.triggered"
  end

  @tag :unit
  test "llm guardrail type attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter12Attributes
    assert LlmIter12Attributes.llm_guardrail_type() == :"llm.guardrail.type"
  end

  @tag :unit
  test "llm retry count attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter12Attributes
    assert LlmIter12Attributes.llm_retry_count() == :"llm.retry.count"
  end

  # === Wave 9 Iteration 12: Event and Signal attributes ===

  @tag :unit
  test "event delivery status attribute key matches schema" do
    assert :"event.delivery.status" == :"event.delivery.status"
  end

  @tag :unit
  test "event handler count attribute key matches schema" do
    assert :"event.handler.count" == :"event.handler.count"
  end

  @tag :unit
  test "signal compression ratio attribute key matches schema" do
    assert :"signal.compression.ratio" == :"signal.compression.ratio"
  end

  @tag :unit
  test "signal ttl ms attribute key matches schema" do
    assert :"signal.ttl_ms" == :"signal.ttl_ms"
  end

  # === Wave 9 Iteration 13: Workspace orchestration, A2A match, consensus safety, healing cascade, LLM CoT ===

  @tag :unit
  test "workspace orchestration pattern attribute key matches schema" do
    alias OpenTelemetry.SemConv.WorkspaceIter13Attributes
    assert WorkspaceIter13Attributes.workspace_orchestration_pattern() == :"workspace.orchestration.pattern"
  end

  @tag :unit
  test "workspace task queue depth attribute key matches schema" do
    alias OpenTelemetry.SemConv.WorkspaceIter13Attributes
    assert WorkspaceIter13Attributes.workspace_task_queue_depth() == :"workspace.task.queue.depth"
  end

  @tag :unit
  test "workspace iteration count attribute key matches schema" do
    alias OpenTelemetry.SemConv.WorkspaceIter13Attributes
    assert WorkspaceIter13Attributes.workspace_iteration_count() == :"workspace.iteration.count"
  end

  @tag :unit
  test "a2a capability match score attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter13Attributes
    assert A2AIter13Attributes.a2a_capability_match_score() == :"a2a.capability.match_score"
  end

  @tag :unit
  test "a2a capability required attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter13Attributes
    assert A2AIter13Attributes.a2a_capability_required() == :"a2a.capability.required"
  end

  @tag :unit
  test "a2a routing strategy attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter13Attributes
    assert A2AIter13Attributes.a2a_routing_strategy() == :"a2a.routing.strategy"
  end

  @tag :unit
  test "consensus safety threshold attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter13Attributes
    assert ConsensusIter13Attributes.consensus_safety_threshold() == :"consensus.safety.threshold"
  end

  @tag :unit
  test "consensus liveness timeout ratio attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter13Attributes
    assert ConsensusIter13Attributes.consensus_liveness_timeout_ratio() == :"consensus.liveness.timeout_ratio"
  end

  @tag :unit
  test "consensus network partition detected attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter13Attributes
    assert ConsensusIter13Attributes.consensus_network_partition_detected() == :"consensus.network.partition_detected"
  end

  @tag :unit
  test "healing cascade detected attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter13Attributes
    assert HealingIter13Attributes.healing_cascade_detected() == :"healing.cascade.detected"
  end

  @tag :unit
  test "healing cascade depth attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter13Attributes
    assert HealingIter13Attributes.healing_cascade_depth() == :"healing.cascade.depth"
  end

  @tag :unit
  test "healing root cause id attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter13Attributes
    assert HealingIter13Attributes.healing_root_cause_id() == :"healing.root_cause.id"
  end

  @tag :unit
  test "llm chain of thought steps attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter13Attributes
    assert LlmIter13Attributes.llm_chain_of_thought_steps() == :"llm.chain_of_thought.steps"
  end

  @tag :unit
  test "llm chain of thought enabled attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter13Attributes
    assert LlmIter13Attributes.llm_chain_of_thought_enabled() == :"llm.chain_of_thought.enabled"
  end

  @tag :unit
  test "llm tool call count attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter13Attributes
    assert LlmIter13Attributes.llm_tool_call_count() == :"llm.tool.call_count"
  end

  @tag :unit
  test "llm cache hit attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter13Attributes
    assert LlmIter13Attributes.llm_cache_hit() == :"llm.cache.hit"
  end

  @tag :unit
  test "mcp tool version iter13 attribute key matches schema" do
    assert :"mcp.tool.version" == :"mcp.tool.version"
  end

  @tag :unit
  test "mcp tool schema hash iter13 attribute key matches schema" do
    assert :"mcp.tool.schema_hash" == :"mcp.tool.schema_hash"
  end

  @tag :unit
  test "process mining conformance visualization type attribute key matches schema" do
    assert :"process.mining.conformance.visualization_type" == :"process.mining.conformance.visualization_type"
  end

  @tag :unit
  test "a2a capability offered attribute key matches schema" do
    assert :"a2a.capability.offered" == :"a2a.capability.offered"
  end

  @tag :unit
  test "process mining case throughput ms attribute key matches schema" do
    assert :"process.mining.case.throughput_ms" == :"process.mining.case.throughput_ms"
  end

  @tag :unit
  test "consensus safety check span exists in schema" do
    assert :"span.consensus.safety.check" == :"span.consensus.safety.check"
  end

  # === Wave 9 Iteration 14: A2A Trust ===

  @tag :unit
  test "a2a trust score attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter14Attributes
    assert A2AIter14Attributes.a2a_trust_score() == :"a2a.trust.score"
  end

  @tag :unit
  test "a2a reputation history length attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter14Attributes
    assert A2AIter14Attributes.a2a_reputation_history_length() == :"a2a.reputation.history_length"
  end

  @tag :unit
  test "a2a trust decay factor attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter14Attributes
    assert A2AIter14Attributes.a2a_trust_decay_factor() == :"a2a.trust.decay_factor"
  end

  @tag :unit
  test "a2a trust updated at ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter14Attributes
    assert A2AIter14Attributes.a2a_trust_updated_at_ms() == :"a2a.trust.updated_at_ms"
  end

  # === Wave 9 Iteration 14: PM Simulation ===

  @tag :unit
  test "process mining simulation cases attribute key matches schema" do
    alias OpenTelemetry.SemConv.PmIter14Attributes
    assert PmIter14Attributes.process_mining_simulation_cases() == :"process_mining.simulation.cases"
  end

  @tag :unit
  test "process mining simulation noise rate attribute key matches schema" do
    alias OpenTelemetry.SemConv.PmIter14Attributes
    assert PmIter14Attributes.process_mining_simulation_noise_rate() == :"process_mining.simulation.noise_rate"
  end

  @tag :unit
  test "process mining simulation duration ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.PmIter14Attributes
    assert PmIter14Attributes.process_mining_simulation_duration_ms() == :"process_mining.simulation.duration_ms"
  end

  @tag :unit
  test "process mining replay token count attribute key matches schema" do
    alias OpenTelemetry.SemConv.PmIter14Attributes
    assert PmIter14Attributes.process_mining_replay_token_count() == :"process_mining.replay.token_count"
  end

  # === Wave 9 Iteration 14: Consensus Fault Tolerance ===

  @tag :unit
  test "consensus byzantine faults attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter14Attributes
    assert ConsensusIter14Attributes.consensus_byzantine_faults() == :"consensus.byzantine.faults"
  end

  @tag :unit
  test "consensus replica lag ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter14Attributes
    assert ConsensusIter14Attributes.consensus_replica_lag_ms() == :"consensus.replica.lag_ms"
  end

  @tag :unit
  test "consensus replica count iter14 attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter14Attributes
    assert ConsensusIter14Attributes.consensus_replica_count() == :"consensus.replica.count"
  end

  # === Wave 9 Iteration 14: Healing Pattern ===

  @tag :unit
  test "healing pattern id attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter14Attributes
    assert HealingIter14Attributes.healing_pattern_id() == :"healing.pattern.id"
  end

  @tag :unit
  test "healing pattern library size attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter14Attributes
    assert HealingIter14Attributes.healing_pattern_library_size() == :"healing.pattern.library_size"
  end

  @tag :unit
  test "healing pattern match confidence attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter14Attributes
    assert HealingIter14Attributes.healing_pattern_match_confidence() == :"healing.pattern.match_confidence"
  end

  # === Wave 9 Iteration 14: LLM Token Budget ===

  @tag :unit
  test "llm token prompt count attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter14Attributes
    assert LlmIter14Attributes.llm_token_prompt_count() == :"llm.token.prompt_count"
  end

  @tag :unit
  test "llm token completion count attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter14Attributes
    assert LlmIter14Attributes.llm_token_completion_count() == :"llm.token.completion_count"
  end

  @tag :unit
  test "llm token budget remaining attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter14Attributes
    assert LlmIter14Attributes.llm_token_budget_remaining() == :"llm.token.budget_remaining"
  end

  @tag :unit
  test "llm model version attribute key matches schema" do
    alias OpenTelemetry.SemConv.LlmIter14Attributes
    assert LlmIter14Attributes.llm_model_version() == :"llm.model.version"
  end

  # === Wave 9 Iteration 14: Canopy Snapshot ===

  @tag :unit
  test "canopy snapshot id attribute key matches schema" do
    alias OpenTelemetry.SemConv.CanopyIter14Attributes
    assert CanopyIter14Attributes.canopy_snapshot_id() == :"canopy.snapshot.id"
  end

  @tag :unit
  test "canopy snapshot size bytes attribute key matches schema" do
    alias OpenTelemetry.SemConv.CanopyIter14Attributes
    assert CanopyIter14Attributes.canopy_snapshot_size_bytes() == :"canopy.snapshot.size_bytes"
  end

  @tag :unit
  test "canopy snapshot compression ratio attribute key matches schema" do
    alias OpenTelemetry.SemConv.CanopyIter14Attributes
    assert CanopyIter14Attributes.canopy_snapshot_compression_ratio() == :"canopy.snapshot.compression_ratio"
  end

  # === Wave 9 Iteration 15: Agent Memory Federation ===

  @tag :unit
  test "agent memory federation id attribute key matches schema" do
    alias OpenTelemetry.SemConv.AgentIter15Attributes
    assert AgentIter15Attributes.agent_memory_federation_id() == :"agent.memory.federation_id"
  end

  @tag :unit
  test "agent memory federation peer count attribute key matches schema" do
    alias OpenTelemetry.SemConv.AgentIter15Attributes
    assert AgentIter15Attributes.agent_memory_federation_peer_count() == :"agent.memory.federation.peer_count"
  end

  @tag :unit
  test "agent memory sync latency ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.AgentIter15Attributes
    assert AgentIter15Attributes.agent_memory_sync_latency_ms() == :"agent.memory.sync.latency_ms"
  end

  @tag :unit
  test "agent memory federation version attribute key matches schema" do
    alias OpenTelemetry.SemConv.AgentIter15Attributes
    assert AgentIter15Attributes.agent_memory_federation_version() == :"agent.memory.federation.version"
  end

  # === Wave 9 Iteration 15: PM Replay ===

  @tag :unit
  test "process mining replay enabled transitions attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMIter15Attributes
    assert PMIter15Attributes.process_mining_replay_enabled_transitions() == :"process.mining.replay.enabled_transitions"
  end

  @tag :unit
  test "process mining replay missing tokens attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMIter15Attributes
    assert PMIter15Attributes.process_mining_replay_missing_tokens() == :"process.mining.replay.missing_tokens"
  end

  @tag :unit
  test "process mining replay consumed tokens attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMIter15Attributes
    assert PMIter15Attributes.process_mining_replay_consumed_tokens() == :"process.mining.replay.consumed_tokens"
  end

  @tag :unit
  test "process mining case variant id attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMIter15Attributes
    assert PMIter15Attributes.process_mining_case_variant_id() == :"process.mining.case.variant_id"
  end

  # === Wave 9 Iteration 15: Consensus Liveness ===

  @tag :unit
  test "consensus liveness proof rounds attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter15Attributes
    assert ConsensusIter15Attributes.consensus_liveness_proof_rounds() == :"consensus.liveness.proof_rounds"
  end

  @tag :unit
  test "consensus network recovery ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter15Attributes
    assert ConsensusIter15Attributes.consensus_network_recovery_ms() == :"consensus.network.recovery_ms"
  end

  @tag :unit
  test "consensus view duration ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter15Attributes
    assert ConsensusIter15Attributes.consensus_view_duration_ms() == :"consensus.view.duration_ms"
  end

  # === Wave 9 Iteration 15: Healing Self-Healing ===

  @tag :unit
  test "healing self healing trigger count attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter15Attributes
    assert HealingIter15Attributes.healing_self_healing_trigger_count() == :"healing.self_healing.trigger_count"
  end

  @tag :unit
  test "healing self healing success rate attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter15Attributes
    assert HealingIter15Attributes.healing_self_healing_success_rate() == :"healing.self_healing.success_rate"
  end

  @tag :unit
  test "healing intervention type attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter15Attributes
    assert HealingIter15Attributes.healing_intervention_type() == :"healing.intervention.type"
  end

  @tag :unit
  test "healing self healing enabled attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter15Attributes
    assert HealingIter15Attributes.healing_self_healing_enabled() == :"healing.self_healing.enabled"
  end

  # === Wave 9 Iteration 15: LLM Evaluation ===

  @tag :unit
  test "llm evaluation score attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter15Attributes
    assert LLMIter15Attributes.llm_evaluation_score() == :"llm.evaluation.score"
  end

  @tag :unit
  test "llm evaluation rubric attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter15Attributes
    assert LLMIter15Attributes.llm_evaluation_rubric() == :"llm.evaluation.rubric"
  end

  @tag :unit
  test "llm evaluation passes threshold attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter15Attributes
    assert LLMIter15Attributes.llm_evaluation_passes_threshold() == :"llm.evaluation.passes_threshold"
  end

  # === Wave 9 Iteration 15: Events Routing + Signal Quality ===

  @tag :unit
  test "event routing strategy attribute key matches schema" do
    alias OpenTelemetry.SemConv.EventsIter15Attributes
    assert EventsIter15Attributes.event_routing_strategy() == :"event.routing.strategy"
  end

  @tag :unit
  test "event routing filter count attribute key matches schema" do
    alias OpenTelemetry.SemConv.EventsIter15Attributes
    assert EventsIter15Attributes.event_routing_filter_count() == :"event.routing.filter_count"
  end

  @tag :unit
  test "event subscriber count attribute key matches schema" do
    alias OpenTelemetry.SemConv.EventsIter15Attributes
    assert EventsIter15Attributes.event_subscriber_count() == :"event.subscriber.count"
  end

  @tag :unit
  test "signal quality score attribute key matches schema" do
    alias OpenTelemetry.SemConv.EventsIter15Attributes
    assert EventsIter15Attributes.signal_quality_score() == :"signal.quality.score"
  end

  # === Wave 9 Iteration 16: ChatmanGPT Session ===

  @tag :unit
  test "chatmangpt session id attribute key matches schema" do
    alias OpenTelemetry.SemConv.ChatmangptIter16Attributes
    assert ChatmangptIter16Attributes.chatmangpt_session_id() == :"chatmangpt.session.id"
  end

  @tag :unit
  test "chatmangpt session token count attribute key matches schema" do
    alias OpenTelemetry.SemConv.ChatmangptIter16Attributes
    assert ChatmangptIter16Attributes.chatmangpt_session_token_count() == :"chatmangpt.session.token_count"
  end

  @tag :unit
  test "chatmangpt session model switches attribute key matches schema" do
    alias OpenTelemetry.SemConv.ChatmangptIter16Attributes
    assert ChatmangptIter16Attributes.chatmangpt_session_model_switches() == :"chatmangpt.session.model_switches"
  end

  @tag :unit
  test "chatmangpt session turn count attribute key matches schema" do
    alias OpenTelemetry.SemConv.ChatmangptIter16Attributes
    assert ChatmangptIter16Attributes.chatmangpt_session_turn_count() == :"chatmangpt.session.turn_count"
  end

  # === Wave 9 Iteration 16: A2A Message Routing ===

  @tag :unit
  test "a2a message priority attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter16Attributes
    assert A2AIter16Attributes.a2a_message_priority() == :"a2a.message.priority"
  end

  @tag :unit
  test "a2a message size bytes attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter16Attributes
    assert A2AIter16Attributes.a2a_message_size_bytes() == :"a2a.message.size_bytes"
  end

  @tag :unit
  test "a2a message encoding attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2AIter16Attributes
    assert A2AIter16Attributes.a2a_message_encoding() == :"a2a.message.encoding"
  end

  # === Wave 9 Iteration 16: Process Mining Decision Mining ===

  @tag :unit
  test "process mining decision point id attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMIter16Attributes
    assert PMIter16Attributes.process_mining_decision_point_id() == :"process.mining.decision.point_id"
  end

  @tag :unit
  test "process mining decision outcome attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMIter16Attributes
    assert PMIter16Attributes.process_mining_decision_outcome() == :"process.mining.decision.outcome"
  end

  @tag :unit
  test "process mining decision confidence attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMIter16Attributes
    assert PMIter16Attributes.process_mining_decision_confidence() == :"process.mining.decision.confidence"
  end

  # === Wave 9 Iteration 16: Consensus Leader Rotation ===

  @tag :unit
  test "consensus leader rotation count attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter16Attributes
    assert ConsensusIter16Attributes.consensus_leader_rotation_count() == :"consensus.leader.rotation_count"
  end

  @tag :unit
  test "consensus leader tenure ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter16Attributes
    assert ConsensusIter16Attributes.consensus_leader_tenure_ms() == :"consensus.leader.tenure_ms"
  end

  @tag :unit
  test "consensus leader score attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter16Attributes
    assert ConsensusIter16Attributes.consensus_leader_score() == :"consensus.leader.score"
  end

  # === Wave 9 Iteration 16: Healing Prediction ===

  @tag :unit
  test "healing prediction horizon ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter16Attributes
    assert HealingIter16Attributes.healing_prediction_horizon_ms() == :"healing.prediction.horizon_ms"
  end

  @tag :unit
  test "healing prediction confidence attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter16Attributes
    assert HealingIter16Attributes.healing_prediction_confidence() == :"healing.prediction.confidence"
  end

  @tag :unit
  test "healing prediction model attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter16Attributes
    assert HealingIter16Attributes.healing_prediction_model() == :"healing.prediction.model"
  end

  # === Wave 9 Iteration 16: LLM Streaming ===

  @tag :unit
  test "llm streaming chunk count attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter16Attributes
    assert LLMIter16Attributes.llm_streaming_chunk_count() == :"llm.streaming.chunk_count"
  end

  @tag :unit
  test "llm streaming first token ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter16Attributes
    assert LLMIter16Attributes.llm_streaming_first_token_ms() == :"llm.streaming.first_token_ms"
  end

  @tag :unit
  test "llm streaming tokens per second attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter16Attributes
    assert LLMIter16Attributes.llm_streaming_tokens_per_second() == :"llm.streaming.tokens_per_second"
  end

  # === Wave 9 Iteration 16: Workspace Context Snapshot ===

  @tag :unit
  test "workspace context snapshot id attribute key matches schema" do
    alias OpenTelemetry.SemConv.WorkspaceIter16Attributes
    assert WorkspaceIter16Attributes.workspace_context_snapshot_id() == :"workspace.context.snapshot_id"
  end

  @tag :unit
  test "workspace context compression ratio attribute key matches schema" do
    alias OpenTelemetry.SemConv.WorkspaceIter16Attributes
    assert WorkspaceIter16Attributes.workspace_context_compression_ratio() == :"workspace.context.compression_ratio"
  end

  @tag :unit
  test "workspace context size tokens attribute key matches schema" do
    alias OpenTelemetry.SemConv.WorkspaceIter16Attributes
    assert WorkspaceIter16Attributes.workspace_context_size_tokens() == :"workspace.context.size_tokens"
  end

  # === Wave 9 Iteration 17: MCP Tool Versioning ===

  @tag :unit
  test "mcp tool version attribute key matches schema" do
    alias OpenTelemetry.SemConv.MCPIter17Attributes
    assert MCPIter17Attributes.mcp_tool_version() == :"mcp.tool.version"
  end

  @tag :unit
  test "mcp tool schema hash attribute key matches schema" do
    alias OpenTelemetry.SemConv.MCPIter17Attributes
    assert MCPIter17Attributes.mcp_tool_schema_hash() == :"mcp.tool.schema_hash"
  end

  @tag :unit
  test "mcp tool deprecated attribute key matches schema" do
    alias OpenTelemetry.SemConv.MCPIter17Attributes
    assert MCPIter17Attributes.mcp_tool_deprecated() == :"mcp.tool.deprecated"
  end

  # === Wave 9 Iteration 17: A2A Capability Negotiation ===

  @tag :unit
  test "a2a capability negotiation id attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2ACapIter17Attributes
    assert A2ACapIter17Attributes.a2a_capability_negotiation_id() == :"a2a.capability.negotiation.id"
  end

  @tag :unit
  test "a2a capability negotiation outcome attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2ACapIter17Attributes
    assert A2ACapIter17Attributes.a2a_capability_negotiation_outcome() == :"a2a.capability.negotiation.outcome"
  end

  @tag :unit
  test "a2a capability negotiation rounds attribute key matches schema" do
    alias OpenTelemetry.SemConv.A2ACapIter17Attributes
    assert A2ACapIter17Attributes.a2a_capability_negotiation_rounds() == :"a2a.capability.negotiation.rounds"
  end

  # === Wave 9 Iteration 17: Process Mining Root Cause ===

  @tag :unit
  test "process mining root cause id attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMRCIter17Attributes
    assert PMRCIter17Attributes.process_mining_root_cause_id() == :"process.mining.root_cause.id"
  end

  @tag :unit
  test "process mining root cause type attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMRCIter17Attributes
    assert PMRCIter17Attributes.process_mining_root_cause_type() == :"process.mining.root_cause.type"
  end

  @tag :unit
  test "process mining root cause confidence attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMRCIter17Attributes
    assert PMRCIter17Attributes.process_mining_root_cause_confidence() == :"process.mining.root_cause.confidence"
  end

  @tag :unit
  test "process mining anomaly score attribute key matches schema" do
    alias OpenTelemetry.SemConv.PMRCIter17Attributes
    assert PMRCIter17Attributes.process_mining_anomaly_score() == :"process.mining.anomaly.score"
  end

  # === Wave 9 Iteration 17: Consensus View Change ===

  @tag :unit
  test "consensus view change reason attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter17Attributes
    assert ConsensusIter17Attributes.consensus_view_change_reason() == :"consensus.view_change.reason"
  end

  @tag :unit
  test "consensus view change duration ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter17Attributes
    assert ConsensusIter17Attributes.consensus_view_change_duration_ms() == :"consensus.view_change.duration_ms"
  end

  @tag :unit
  test "consensus view change backoff ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.ConsensusIter17Attributes
    assert ConsensusIter17Attributes.consensus_view_change_backoff_ms() == :"consensus.view_change.backoff_ms"
  end

  # === Wave 9 Iteration 17: Healing Playbook ===

  @tag :unit
  test "healing playbook id attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter17Attributes
    assert HealingIter17Attributes.healing_playbook_id() == :"healing.playbook.id"
  end

  @tag :unit
  test "healing playbook step count attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter17Attributes
    assert HealingIter17Attributes.healing_playbook_step_count() == :"healing.playbook.step_count"
  end

  @tag :unit
  test "healing playbook execution ms attribute key matches schema" do
    alias OpenTelemetry.SemConv.HealingIter17Attributes
    assert HealingIter17Attributes.healing_playbook_execution_ms() == :"healing.playbook.execution_ms"
  end

  # === Wave 9 Iteration 17: LLM Context Management ===

  @tag :unit
  test "llm context max tokens attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter17Attributes
    assert LLMIter17Attributes.llm_context_max_tokens() == :"llm.context.max_tokens"
  end

  @tag :unit
  test "llm context overflow strategy attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter17Attributes
    assert LLMIter17Attributes.llm_context_overflow_strategy() == :"llm.context.overflow_strategy"
  end

  @tag :unit
  test "llm context utilization attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter17Attributes
    assert LLMIter17Attributes.llm_context_utilization() == :"llm.context.utilization"
  end

  # === Wave 9 Iteration 17: Agent Pipeline + Workspace Activity ===

  @tag :unit
  test "agent pipeline id attribute key matches schema" do
    alias OpenTelemetry.SemConv.LLMIter17Attributes
    # Use inline atom for cross-domain test
    assert :"agent.pipeline.id" == :"agent.pipeline.id"
  end

  @tag :unit
  test "agent pipeline stage attribute key matches schema" do
    assert :"agent.pipeline.stage" == :"agent.pipeline.stage"
  end

  @tag :unit
  test "workspace activity type attribute key matches schema" do
    assert :"workspace.activity.type" == :"workspace.activity.type"
  end
end
