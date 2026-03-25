defmodule OptimalSystemAgent.Semconv.OtelBridge do
  @moduledoc """
  Thin bridge between ChatmanGPT semconv constants and OpenTelemetry API.

  Generated from semconv/model/ — provides typed attribute keys for use
  with :otel_tracer or opentelemetry_api when available.

  Part of the OTEL Weaver integration — ensures span attribute names
  match the semconv schema contract (Chicago TDD 3rd proof layer).
  """

  # Healing domain
  def healing_failure_mode, do: :"healing.failure_mode"
  def healing_confidence, do: :"healing.confidence"
  def healing_agent_id, do: :"healing.agent_id"

  # A2A domain
  def a2a_operation, do: :"a2a.operation"
  def a2a_deal_id, do: :"a2a.deal.id"
  def a2a_agent_id, do: :"a2a.agent.id"
  def a2a_deal_type, do: :"a2a.deal.type"
  def a2a_task_id, do: :"a2a.task.id"
  def a2a_task_priority, do: :"a2a.task.priority"
  def a2a_capability_name, do: :"a2a.capability.name"
  def a2a_negotiation_round, do: :"a2a.negotiation.round"
  def a2a_negotiation_status, do: :"a2a.negotiation.status"
  def a2a_source_service, do: :"a2a.source.service"
  def a2a_target_service, do: :"a2a.target.service"

  def a2a_task_priority_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end

  def a2a_negotiation_status_values do
    %{
      pending: :pending,
      accepted: :accepted,
      rejected: :rejected,
      counter_offer: :counter_offer,
      expired: :expired
    }
  end

  # Agent domain
  def agent_id, do: :"agent.id"
  def agent_decision, do: :"agent.decision"

  # MCP domain
  def mcp_tool_name, do: :"mcp.tool.name"
  def mcp_server_id, do: :"mcp.server.id"

  # Signal domain
  def signal_sn_ratio, do: :"signal.sn_ratio"
  def signal_mode, do: :"signal.mode"
  def signal_genre, do: :"signal.genre"

  # Consensus domain
  def consensus_round_num, do: :"consensus.round_num"
  def consensus_phase, do: :"consensus.phase"
  def consensus_view_number, do: :"consensus.view_number"
  def consensus_node_id, do: :"consensus.node_id"
  def consensus_leader_id, do: :"consensus.leader.id"
  def consensus_vote_count, do: :"consensus.vote_count"
  def consensus_quorum_size, do: :"consensus.quorum_size"
  def consensus_block_hash, do: :"consensus.block_hash"
  def consensus_latency_ms, do: :"consensus.latency_ms"

  def consensus_phase_values do
    %{
      prepare: :prepare,
      pre_commit: :pre_commit,
      commit: :commit,
      decide: :decide,
      view_change: :view_change
    }
  end

  def consensus_round_type, do: :"consensus.round_type"

  def consensus_round_type_values do
    %{
      prepare: :prepare,
      promise: :promise,
      accept: :accept,
      learn: :learn
    }
  end

  # Events domain
  def event_name, do: :"event.name"
  def event_domain, do: :"event.domain"
  def event_severity, do: :"event.severity"
  def event_source, do: :"event.source"
  def event_correlation_id, do: :"event.correlation_id"

  def event_domain_values do
    %{
      agent: :agent,
      compliance: :compliance,
      healing: :healing,
      workflow: :workflow,
      system: :system
    }
  end

  def event_severity_values do
    %{
      debug: :debug,
      info: :info,
      warn: :warn,
      error: :error,
      fatal: :fatal
    }
  end

  # Process mining domain (expanded)
  def process_mining_trace_id, do: :"process.mining.trace_id"
  def process_mining_activity, do: :"process.mining.activity"
  def process_mining_algorithm, do: :"process.mining.algorithm"
  def process_mining_case_count, do: :"process.mining.case_count"
  def process_mining_event_count, do: :"process.mining.event_count"
  def process_mining_variant_count, do: :"process.mining.variant_count"
  def process_mining_log_path, do: :"process.mining.log_path"
  def process_mining_dfg_node_count, do: :"process.mining.dfg.node_count"
  def process_mining_dfg_edge_count, do: :"process.mining.dfg.edge_count"
  def process_mining_petri_net_place_count, do: :"process.mining.petri_net.place_count"
  def process_mining_petri_net_transition_count, do: :"process.mining.petri_net.transition_count"
  def process_mining_conformance_deviation_type, do: :"process.mining.conformance.deviation_type"

  def process_mining_algorithm_values do
    %{
      alpha_miner: :alpha_miner,
      inductive_miner: :inductive_miner,
      heuristics_miner: :heuristics_miner
    }
  end

  def process_mining_conformance_deviation_type_values do
    %{
      missing_activity: :missing_activity,
      extra_activity: :extra_activity,
      wrong_order: :wrong_order,
      loop_violation: :loop_violation
    }
  end

  # Canopy domain
  def canopy_heartbeat_tier, do: :"canopy.heartbeat.tier"
  def canopy_adapter_type, do: :"canopy.adapter.type"
  def canopy_workspace_id, do: :"canopy.workspace.id"
  def canopy_command_type, do: :"canopy.command.type"
  def canopy_command_source, do: :"canopy.command.source"
  def canopy_command_target, do: :"canopy.command.target"
  def canopy_heartbeat_status, do: :"canopy.heartbeat.status"
  def canopy_signal_mode, do: :"canopy.signal.mode"

  def canopy_adapter_type_values do
    %{
      osa: :osa,
      mcp: :mcp,
      business_os: :business_os,
      webhook: :webhook
    }
  end

  def canopy_command_type_values do
    %{
      agent_dispatch: :agent_dispatch,
      workflow_trigger: :workflow_trigger,
      data_query: :data_query,
      heartbeat_check: :heartbeat_check,
      config_reload: :config_reload,
      execute: :execute,
      query: :query,
      route: :route,
      broadcast: :broadcast,
      sync: :sync,
      delegate: :delegate
    }
  end

  def canopy_heartbeat_status_values do
    %{
      healthy: :healthy,
      degraded: :degraded,
      critical: :critical,
      timeout: :timeout
    }
  end

  # Workflow domain
  def workflow_id, do: :"workflow.id"
  def workflow_pattern, do: :"workflow.pattern"
  def workflow_state, do: :"workflow.state"

  # BusinessOS domain
  def bos_compliance_severity, do: :"bos.compliance.severity"
  def bos_compliance_framework, do: :"bos.compliance.framework"
  def bos_audit_trail_id, do: :"bos.audit.trail.id"
  def bos_audit_event_type, do: :"bos.audit.event_type"
  def bos_audit_actor_id, do: :"bos.audit.actor_id"
  def bos_compliance_control_id, do: :"bos.compliance.control_id"
  def bos_gap_severity, do: :"bos.gap.severity"
  def bos_gap_remediation_days, do: :"bos.gap.remediation_days"

  def bos_audit_event_type_values do
    %{
      data_access: :data_access,
      config_change: :config_change,
      permission_grant: :permission_grant,
      compliance_check: :compliance_check,
      gap_detection: :gap_detection
    }
  end

  def bos_compliance_framework_values do
    %{
      soc2: :SOC2,
      hipaa: :HIPAA,
      gdpr: :GDPR,
      sox: :SOX,
      custom: :CUSTOM
    }
  end

  def bos_gap_severity_values do
    %{
      critical: :critical,
      high: :high,
      medium: :medium,
      low: :low
    }
  end
end
