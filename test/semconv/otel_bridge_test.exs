defmodule OptimalSystemAgent.Semconv.OtelBridgeTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Semconv.OtelBridge

  # Chicago TDD: typed constants prevent schema drift
  # If the semconv schema renames an attribute, these tests fail at compile time

  test "healing domain constants match semconv schema" do
    assert OtelBridge.healing_failure_mode() == :"healing.failure_mode"
    assert OtelBridge.healing_confidence() == :"healing.confidence"
    assert OtelBridge.healing_agent_id() == :"healing.agent_id"
  end

  test "healing soundness constants match semconv schema" do
    assert OtelBridge.healing_timeout_ms() == :"healing.timeout_ms"
    assert OtelBridge.healing_max_iterations() == :"healing.max_iterations"
    assert OtelBridge.healing_iteration() == :"healing.iteration"
    assert OtelBridge.healing_recovery_complete() == :"healing.recovery_complete"
  end

  test "a2a domain constants match semconv schema" do
    assert OtelBridge.a2a_operation() == :"a2a.operation"
    assert OtelBridge.a2a_deal_id() == :"a2a.deal.id"
    assert OtelBridge.a2a_agent_id() == :"a2a.agent.id"
    assert OtelBridge.a2a_deal_type() == :"a2a.deal.type"
    assert OtelBridge.a2a_task_id() == :"a2a.task.id"
    assert OtelBridge.a2a_task_priority() == :"a2a.task.priority"
    assert OtelBridge.a2a_capability_name() == :"a2a.capability.name"
    assert OtelBridge.a2a_negotiation_round() == :"a2a.negotiation.round"
    assert OtelBridge.a2a_negotiation_status() == :"a2a.negotiation.status"
    assert OtelBridge.a2a_source_service() == :"a2a.source.service"
    assert OtelBridge.a2a_target_service() == :"a2a.target.service"
  end

  test "a2a_negotiation_state returns correct atom" do
    assert OtelBridge.a2a_negotiation_state() == :"a2a.negotiation.state"
  end

  test "a2a_negotiation_timeout_ms returns correct atom" do
    assert OtelBridge.a2a_negotiation_timeout_ms() == :"a2a.negotiation.timeout_ms"
  end

  test "a2a_deal_value returns correct atom" do
    assert OtelBridge.a2a_deal_value() == :"a2a.deal.value"
  end

  test "a2a_negotiation_state_values includes all states" do
    values = OtelBridge.a2a_negotiation_state_values()
    assert values.proposed == :"proposed"
    assert values.counter == :"counter"
    assert values.accepted == :"accepted"
    assert values.rejected == :"rejected"
    assert values.expired == :"expired"
  end

  test "a2a_task_priority_values returns task priority enum" do
    values = OtelBridge.a2a_task_priority_values()
    assert values.critical == :critical
    assert values.high == :high
    assert values.normal == :normal
    assert values.low == :low
  end

  test "a2a_negotiation_status_values returns negotiation status enum" do
    values = OtelBridge.a2a_negotiation_status_values()
    assert values.pending == :pending
    assert values.accepted == :accepted
    assert values.rejected == :rejected
    assert values.counter_offer == :counter_offer
    assert values.expired == :expired
  end

  test "agent domain constants match semconv schema" do
    assert OtelBridge.agent_id() == :"agent.id"
    assert OtelBridge.agent_decision() == :"agent.decision"
  end

  test "mcp domain constants match semconv schema" do
    assert OtelBridge.mcp_tool_name() == :"mcp.tool.name"
    assert OtelBridge.mcp_server_id() == :"mcp.server.id"
  end

  test "signal domain constants match semconv schema" do
    assert OtelBridge.signal_sn_ratio() == :"signal.sn_ratio"
    assert OtelBridge.signal_mode() == :"signal.mode"
    assert OtelBridge.signal_genre() == :"signal.genre"
    assert OtelBridge.signal_format() == :"signal.format"
    assert OtelBridge.signal_quality_threshold() == :"signal.quality.threshold"
    assert OtelBridge.signal_weight() == :"signal.weight"
  end

  test "signal_genre_values includes all signal genres" do
    values = OtelBridge.signal_genre_values()
    assert values.spec == :spec
    assert values.brief == :brief
    assert values.report == :report
    assert values.plan == :plan
    assert values.decision == :decision
  end

  test "signal_format_values includes all signal formats" do
    values = OtelBridge.signal_format_values()
    assert values.markdown == :markdown
    assert values.json == :json
    assert values.yaml == :yaml
    assert values.code == :code
  end

  test "consensus domain constants match semconv schema" do
    assert OtelBridge.consensus_round_num() == :"consensus.round_num"
    assert OtelBridge.consensus_phase() == :"consensus.phase"
    assert OtelBridge.consensus_view_number() == :"consensus.view_number"
    assert OtelBridge.consensus_node_id() == :"consensus.node_id"
    assert OtelBridge.consensus_leader_id() == :"consensus.leader.id"
    assert OtelBridge.consensus_vote_count() == :"consensus.vote_count"
    assert OtelBridge.consensus_quorum_size() == :"consensus.quorum_size"
    assert OtelBridge.consensus_block_hash() == :"consensus.block_hash"
    assert OtelBridge.consensus_latency_ms() == :"consensus.latency_ms"
    assert OtelBridge.consensus_round_type() == :"consensus.round_type"
  end

  test "consensus_phase_values returns HotStuff BFT phase enum" do
    values = OtelBridge.consensus_phase_values()
    assert values.prepare == :prepare
    assert values.pre_commit == :pre_commit
    assert values.commit == :commit
    assert values.decide == :decide
    assert values.view_change == :view_change
  end

  test "consensus_round_type_values returns BFT round type enum" do
    values = OtelBridge.consensus_round_type_values()
    assert values.prepare == :prepare
    assert values.promise == :promise
    assert values.accept == :accept
    assert values.learn == :learn
  end

  test "events domain constants match semconv schema" do
    assert OtelBridge.event_name() == :"event.name"
    assert OtelBridge.event_domain() == :"event.domain"
    assert OtelBridge.event_severity() == :"event.severity"
    assert OtelBridge.event_source() == :"event.source"
    assert OtelBridge.event_correlation_id() == :"event.correlation_id"
  end

  test "event_domain_values returns structured event domain enum" do
    values = OtelBridge.event_domain_values()
    assert values.agent == :agent
    assert values.compliance == :compliance
    assert values.healing == :healing
    assert values.workflow == :workflow
    assert values.system == :system
  end

  test "event_severity_values returns severity level enum" do
    values = OtelBridge.event_severity_values()
    assert values.debug == :debug
    assert values.info == :info
    assert values.warn == :warn
    assert values.error == :error
    assert values.fatal == :fatal
  end

  test "process mining domain constants match semconv schema" do
    assert OtelBridge.process_mining_trace_id() == :"process.mining.trace_id"
    assert OtelBridge.process_mining_activity() == :"process.mining.activity"
    assert OtelBridge.process_mining_algorithm() == :"process.mining.algorithm"
    assert OtelBridge.process_mining_case_count() == :"process.mining.case_count"
    assert OtelBridge.process_mining_event_count() == :"process.mining.event_count"
    assert OtelBridge.process_mining_variant_count() == :"process.mining.variant_count"
    assert OtelBridge.process_mining_log_path() == :"process.mining.log_path"
    assert OtelBridge.process_mining_dfg_node_count() == :"process.mining.dfg.node_count"
    assert OtelBridge.process_mining_dfg_edge_count() == :"process.mining.dfg.edge_count"
    assert OtelBridge.process_mining_petri_net_place_count() == :"process.mining.petri_net.place_count"
    assert OtelBridge.process_mining_petri_net_transition_count() == :"process.mining.petri_net.transition_count"
    assert OtelBridge.process_mining_conformance_deviation_type() == :"process.mining.conformance.deviation_type"
  end

  test "process mining conformance iteration 7 constants match semconv schema" do
    assert OtelBridge.process_mining_conformance_score() == :"process.mining.conformance.score"
    assert OtelBridge.process_mining_conformance_deviation_count() == :"process.mining.conformance.deviation_count"
    assert OtelBridge.process_mining_model_type() == :"process.mining.model_type"
  end

  test "process_mining_model_type_values includes all model types" do
    values = OtelBridge.process_mining_model_type_values()
    assert values.petri_net == :"petri_net"
    assert values.bpmn == :"bpmn"
    assert values.declare == :"declare"
    assert values.dfg == :"dfg"
  end

  test "process_mining_algorithm_values returns discovery algorithm enum" do
    values = OtelBridge.process_mining_algorithm_values()
    assert values.alpha_miner == :alpha_miner
    assert values.inductive_miner == :inductive_miner
    assert values.heuristics_miner == :heuristics_miner
  end

  test "process_mining_conformance_deviation_type_values returns deviation type enum" do
    values = OtelBridge.process_mining_conformance_deviation_type_values()
    assert values.missing_activity == :missing_activity
    assert values.extra_activity == :extra_activity
    assert values.wrong_order == :wrong_order
    assert values.loop_violation == :loop_violation
  end

  test "canopy domain constants match semconv schema" do
    assert OtelBridge.canopy_heartbeat_tier() == :"canopy.heartbeat.tier"
    assert OtelBridge.canopy_adapter_type() == :"canopy.adapter.type"
    assert OtelBridge.canopy_workspace_id() == :"canopy.workspace.id"
    assert OtelBridge.canopy_command_type() == :"canopy.command.type"
    assert OtelBridge.canopy_command_source() == :"canopy.command.source"
    assert OtelBridge.canopy_command_target() == :"canopy.command.target"
    assert OtelBridge.canopy_heartbeat_status() == :"canopy.heartbeat.status"
    assert OtelBridge.canopy_signal_mode() == :"canopy.signal.mode"
  end

  test "canopy_adapter_type_values returns adapter type enum" do
    values = OtelBridge.canopy_adapter_type_values()
    assert values.osa == :osa
    assert values.mcp == :mcp
    assert values.business_os == :business_os
    assert values.webhook == :webhook
  end

  test "canopy_command_type_values returns command type enum" do
    values = OtelBridge.canopy_command_type_values()
    assert values.execute == :execute
    assert values.query == :query
    assert values.route == :route
    assert values.broadcast == :broadcast
    assert values.sync == :sync
    assert values.delegate == :delegate
    assert values.agent_dispatch == :agent_dispatch
    assert values.workflow_trigger == :workflow_trigger
    assert values.data_query == :data_query
    assert values.heartbeat_check == :heartbeat_check
    assert values.config_reload == :config_reload
  end

  test "canopy_heartbeat_status_values returns heartbeat status enum" do
    values = OtelBridge.canopy_heartbeat_status_values()
    assert values.healthy == :healthy
    assert values.degraded == :degraded
    assert values.critical == :critical
    assert values.timeout == :timeout
  end

  test "workflow domain constants match semconv schema" do
    assert OtelBridge.workflow_id() == :"workflow.id"
    assert OtelBridge.workflow_pattern() == :"workflow.pattern"
    assert OtelBridge.workflow_state() == :"workflow.state"
  end

  test "bos domain constants match semconv schema" do
    assert OtelBridge.bos_compliance_severity() == :"bos.compliance.severity"
    assert OtelBridge.bos_compliance_framework() == :"bos.compliance.framework"
    assert OtelBridge.bos_audit_trail_id() == :"bos.audit.trail.id"
    assert OtelBridge.bos_audit_event_type() == :"bos.audit.event_type"
    assert OtelBridge.bos_audit_actor_id() == :"bos.audit.actor_id"
    assert OtelBridge.bos_compliance_control_id() == :"bos.compliance.control_id"
    assert OtelBridge.bos_gap_severity() == :"bos.gap.severity"
    assert OtelBridge.bos_gap_remediation_days() == :"bos.gap.remediation_days"
  end

  test "bos_audit_event_type_values returns audit event type enum" do
    values = OtelBridge.bos_audit_event_type_values()
    assert values.data_access == :data_access
    assert values.config_change == :config_change
    assert values.permission_grant == :permission_grant
    assert values.compliance_check == :compliance_check
    assert values.gap_detection == :gap_detection
  end

  test "bos_compliance_framework_values returns compliance framework enum" do
    values = OtelBridge.bos_compliance_framework_values()
    assert values.soc2 == :SOC2
    assert values.hipaa == :HIPAA
    assert values.gdpr == :GDPR
    assert values.sox == :SOX
    assert values.custom == :CUSTOM
  end

  test "bos_gap_severity_values returns gap severity enum" do
    values = OtelBridge.bos_gap_severity_values()
    assert values.critical == :critical
    assert values.high == :high
    assert values.medium == :medium
    assert values.low == :low
  end
end
