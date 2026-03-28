defmodule OpenTelemetry.SemConv.Incubating.JtbdAttributes do
  @moduledoc """
  Jtbd semantic convention attributes.

  Namespace: `jtbd`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  HotStuff BFT block hash — tamper-proof contract ID for blockchain validation.

  Attribute: `jtbd.contract.block_hash`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `0xabc123def456`, `0x123456789abcdef`, `block-hash-wave12-001`
  """
  @spec jtbd_contract_block_hash() :: :"jtbd.contract.block_hash"
  def jtbd_contract_block_hash, do: :"jtbd.contract.block_hash"

  @doc """
  Number of consensus nodes that validated and signed the contract.

  Attribute: `jtbd.contract.consensus_nodes`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `3`, `5`, `7`
  """
  @spec jtbd_contract_consensus_nodes() :: :"jtbd.contract.consensus_nodes"
  def jtbd_contract_consensus_nodes, do: :"jtbd.contract.consensus_nodes"

  @doc """
  Total contract value in USD for closed contracts.

  Attribute: `jtbd.contract.contract_value_usd`
  Type: `double`
  Stability: `development`
  Requirement: `required`
  Examples: `50000.0`, `250000.0`, `2000000.0`
  """
  @spec jtbd_contract_contract_value_usd() :: :"jtbd.contract.contract_value_usd"
  def jtbd_contract_contract_value_usd, do: :"jtbd.contract.contract_value_usd"

  @doc """
  Number of contracts successfully closed and signed.

  Attribute: `jtbd.contract.contracts_closed`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `1`, `5`, `20`
  """
  @spec jtbd_contract_contracts_closed() :: :"jtbd.contract.contracts_closed"
  def jtbd_contract_contracts_closed, do: :"jtbd.contract.contracts_closed"

  @doc """
  FIBO (Financial Industry Business Ontology) validation result — true if contract conforms to ontology.

  Attribute: `jtbd.contract.fibo_validated`
  Type: `boolean`
  Stability: `development`
  Requirement: `required`
  Examples: `true`, `false`
  """
  @spec jtbd_contract_fibo_validated() :: :"jtbd.contract.fibo_validated"
  def jtbd_contract_fibo_validated, do: :"jtbd.contract.fibo_validated"

  @doc """
  Legal/compliance framework enforced (e.g., "SOX", "GDPR", "HIPAA", "CCPA").

  Attribute: `jtbd.contract.framework`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `SOX`, `GDPR`, `HIPAA`, `CCPA`
  """
  @spec jtbd_contract_framework() :: :"jtbd.contract.framework"
  def jtbd_contract_framework, do: :"jtbd.contract.framework"

  @doc """
  ISO8601 contract signature timestamp.

  Attribute: `jtbd.contract.signed_at`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `2026-03-24T14:30:00Z`, `2026-03-26T09:15:00Z`
  """
  @spec jtbd_contract_signed_at() :: :"jtbd.contract.signed_at"
  def jtbd_contract_signed_at, do: :"jtbd.contract.signed_at"

  @doc """
  Number of deals advanced to next pipeline stage.

  Attribute: `jtbd.deal.deals_progressed`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `5`, `20`, `50`
  """
  @spec jtbd_deal_deals_progressed() :: :"jtbd.deal.deals_progressed"
  def jtbd_deal_deals_progressed, do: :"jtbd.deal.deals_progressed"

  @doc """
  ISO8601 forecast close date for progressed deals.

  Attribute: `jtbd.deal.forecast_close_date`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `2026-04-30T00:00:00Z`, `2026-06-15T00:00:00Z`, `2026-12-31T00:00:00Z`
  """
  @spec jtbd_deal_forecast_close_date() :: :"jtbd.deal.forecast_close_date"
  def jtbd_deal_forecast_close_date, do: :"jtbd.deal.forecast_close_date"

  @doc """
  Total pipeline value of progressed deals in USD.

  Attribute: `jtbd.deal.pipeline_value_usd`
  Type: `double`
  Stability: `development`
  Requirement: `required`
  Examples: `50000.0`, `250000.0`, `1000000.0`
  """
  @spec jtbd_deal_pipeline_value_usd() :: :"jtbd.deal.pipeline_value_usd"
  def jtbd_deal_pipeline_value_usd, do: :"jtbd.deal.pipeline_value_usd"

  @doc """
  CRM pipeline stage before progression (e.g., "qualify", "proposal", "negotiation").

  Attribute: `jtbd.deal.stage_from`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `qualify`, `proposal`, `negotiation`, `close`
  """
  @spec jtbd_deal_stage_from() :: :"jtbd.deal.stage_from"
  def jtbd_deal_stage_from, do: :"jtbd.deal.stage_from"

  @doc """
  CRM pipeline stage after progression.

  Attribute: `jtbd.deal.stage_to`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `proposal`, `negotiation`, `close`, `won`
  """
  @spec jtbd_deal_stage_to() :: :"jtbd.deal.stage_to"
  def jtbd_deal_stage_to, do: :"jtbd.deal.stage_to"

  @doc """
  DMAIC phase name — identifies the current phase in a DMAIC (Define/Measure/Analyze/Improve/Control) cycle.

  Attribute: `jtbd.dmaic.phase_name`
  Type: `enum`
  Stability: `development`
  Requirement: `required`
  Examples: `define`, `measure`, `analyze`, `improve`, `control`
  """
  @spec jtbd_dmaic_phase_name() :: :"jtbd.dmaic.phase_name"
  def jtbd_dmaic_phase_name, do: :"jtbd.dmaic.phase_name"

  @doc """
  Enumerated values for `jtbd.dmaic.phase_name`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `define` | `"define"` | define |
  | `measure` | `"measure"` | measure |
  | `analyze` | `"analyze"` | analyze |
  | `improve` | `"improve"` | improve |
  | `control` | `"control"` | control |
  """
  @spec jtbd_dmaic_phase_name_values() :: %{
    define: :define,
    measure: :measure,
    analyze: :analyze,
    improve: :improve,
    control: :control
  }
  def jtbd_dmaic_phase_name_values do
    %{
      define: :define,
      measure: :measure,
      analyze: :analyze,
      improve: :improve,
      control: :control
    }
  end

  defmodule JtbdDmaicPhaseNameValues do
    @moduledoc """
    Typed constants for the `jtbd.dmaic.phase_name` attribute.
    """

    @doc "define"
    @spec define() :: :define
    def define, do: :define

    @doc "measure"
    @spec measure() :: :measure
    def measure, do: :measure

    @doc "analyze"
    @spec analyze() :: :analyze
    def analyze, do: :analyze

    @doc "improve"
    @spec improve() :: :improve
    def improve, do: :improve

    @doc "control"
    @spec control() :: :control
    def control, do: :control

  end

  @doc """
  Number of contacts evaluated in ICP qualification.

  Attribute: `jtbd.icp.contacts_evaluated`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `150`, `500`, `1000`
  """
  @spec jtbd_icp_contacts_evaluated() :: :"jtbd.icp.contacts_evaluated"
  def jtbd_icp_contacts_evaluated, do: :"jtbd.icp.contacts_evaluated"

  @doc """
  Number of contacts qualified as ICP targets.

  Attribute: `jtbd.icp.contacts_qualified`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `45`, `125`, `300`
  """
  @spec jtbd_icp_contacts_qualified() :: :"jtbd.icp.contacts_qualified"
  def jtbd_icp_contacts_qualified, do: :"jtbd.icp.contacts_qualified"

  @doc """
  ICP qualification rate — ratio of qualified contacts to evaluated contacts (0.0-1.0).

  Attribute: `jtbd.icp.qualification_rate`
  Type: `double`
  Stability: `development`
  Requirement: `required`
  Examples: `0.3`, `0.6`, `0.9`
  """
  @spec jtbd_icp_qualification_rate() :: :"jtbd.icp.qualification_rate"
  def jtbd_icp_qualification_rate, do: :"jtbd.icp.qualification_rate"

  @doc """
  Number of contacts enrolled in outreach sequence.

  Attribute: `jtbd.outreach.contacts_enrolled`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `25`, `100`, `500`
  """
  @spec jtbd_outreach_contacts_enrolled() :: :"jtbd.outreach.contacts_enrolled"
  def jtbd_outreach_contacts_enrolled, do: :"jtbd.outreach.contacts_enrolled"

  @doc """
  Total messages queued for this outreach sequence.

  Attribute: `jtbd.outreach.messages_queued`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `50`, `200`, `1000`
  """
  @spec jtbd_outreach_messages_queued() :: :"jtbd.outreach.messages_queued"
  def jtbd_outreach_messages_queued, do: :"jtbd.outreach.messages_queued"

  @doc """
  Messages remaining within daily rate limit for outreach platform.

  Attribute: `jtbd.outreach.rate_limit_remaining`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `500`, `1000`, `5000`
  """
  @spec jtbd_outreach_rate_limit_remaining() :: :"jtbd.outreach.rate_limit_remaining"
  def jtbd_outreach_rate_limit_remaining, do: :"jtbd.outreach.rate_limit_remaining"

  @doc """
  Identifier of the outreach sequence being executed.

  Attribute: `jtbd.outreach.sequence_id`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `seq-nurture-001`, `seq-launch-2026q1`, `seq-re-engage-vip`
  """
  @spec jtbd_outreach_sequence_id() :: :"jtbd.outreach.sequence_id"
  def jtbd_outreach_sequence_id, do: :"jtbd.outreach.sequence_id"

  @doc """
  Current step number within the outreach sequence (1-indexed).

  Attribute: `jtbd.outreach.step_number`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `1`, `5`, `10`
  """
  @spec jtbd_outreach_step_number() :: :"jtbd.outreach.step_number"
  def jtbd_outreach_step_number, do: :"jtbd.outreach.step_number"

  @doc """
  Process model type used for PI analysis (petri_net, dfg, event_log, bpmn).

  Attribute: `jtbd.pi.model_type`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `petri_net`, `dfg`, `event_log`, `bpmn`
  """
  @spec jtbd_pi_model_type() :: :"jtbd.pi.model_type"
  def jtbd_pi_model_type, do: :"jtbd.pi.model_type"

  @doc """
  Natural language query submitted to process intelligence engine.

  Attribute: `jtbd.pi.query`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `What is the critical path?`, `Where are the bottlenecks?`, `Which cases are stalled?`
  """
  @spec jtbd_pi_query() :: :"jtbd.pi.query"
  def jtbd_pi_query, do: :"jtbd.pi.query"

  @doc """
  Number of tokens in the plain-English response from process intelligence engine.

  Attribute: `jtbd.pi.response_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `150`, `500`, `2000`
  """
  @spec jtbd_pi_response_tokens() :: :"jtbd.pi.response_tokens"
  def jtbd_pi_response_tokens, do: :"jtbd.pi.response_tokens"

  @doc """
  Java 26 retrofit complexity score (0.0-1.0) — higher indicates more complex migration.

  Attribute: `jtbd.retrofit.complexity_score`
  Type: `double`
  Stability: `development`
  Requirement: `required`
  Examples: `0.25`, `0.55`, `0.85`
  """
  @spec jtbd_retrofit_complexity_score() :: :"jtbd.retrofit.complexity_score"
  def jtbd_retrofit_complexity_score, do: :"jtbd.retrofit.complexity_score"

  @doc """
  Estimated days to complete full Java 26 retrofit.

  Attribute: `jtbd.retrofit.estimated_days`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `10`, `30`, `90`
  """
  @spec jtbd_retrofit_estimated_days() :: :"jtbd.retrofit.estimated_days"
  def jtbd_retrofit_estimated_days, do: :"jtbd.retrofit.estimated_days"

  @doc """
  Source to target Java version gap (e.g., "17 -> 26").

  Attribute: `jtbd.retrofit.java_version_gap`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `11 -> 26`, `17 -> 26`, `21 -> 26`
  """
  @spec jtbd_retrofit_java_version_gap() :: :"jtbd.retrofit.java_version_gap"
  def jtbd_retrofit_java_version_gap, do: :"jtbd.retrofit.java_version_gap"

  @doc """
  Number of Java modules analyzed during retrofit assessment.

  Attribute: `jtbd.retrofit.modules_analyzed`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `10`, `50`, `150`
  """
  @spec jtbd_retrofit_modules_analyzed() :: :"jtbd.retrofit.modules_analyzed"
  def jtbd_retrofit_modules_analyzed, do: :"jtbd.retrofit.modules_analyzed"

  @doc """
  Enumerated JTBD scenario identifier — identifies the job-to-be-done being instrumented.

  Attribute: `jtbd.scenario.id`
  Type: `enum`
  Stability: `development`
  Requirement: `required`
  Examples: `agent_decision_loop`, `process_discovery`, `compliance_check`, `icp_qualification`, `process_intelligence_query`
  """
  @spec jtbd_scenario_id() :: :"jtbd.scenario.id"
  def jtbd_scenario_id, do: :"jtbd.scenario.id"

  @doc """
  Enumerated values for `jtbd.scenario.id`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `agent_decision_loop` | `"agent_decision_loop"` | agent_decision_loop |
  | `process_discovery` | `"process_discovery"` | process_discovery |
  | `compliance_check` | `"compliance_check"` | compliance_check |
  | `cross_system_handoff` | `"cross_system_handoff"` | cross_system_handoff |
  | `workspace_sync` | `"workspace_sync"` | workspace_sync |
  | `consensus_round` | `"consensus_round"` | consensus_round |
  | `healing_recovery` | `"healing_recovery"` | healing_recovery |
  | `a2a_deal_lifecycle` | `"a2a_deal_lifecycle"` | a2a_deal_lifecycle |
  | `mcp_tool_execution` | `"mcp_tool_execution"` | mcp_tool_execution |
  | `conformance_drift` | `"conformance_drift"` | conformance_drift |
  | `yawl_v6_checkpoint` | `"yawl_v6_checkpoint"` | yawl_v6_checkpoint |
  | `icp_qualification` | `"icp_qualification"` | icp_qualification |
  | `retrofit_complexity_scoring` | `"retrofit_complexity_scoring"` | retrofit_complexity_scoring |
  | `outreach_sequence_execution` | `"outreach_sequence_execution"` | outreach_sequence_execution |
  | `deal_progression` | `"deal_progression"` | deal_progression |
  | `contract_closure` | `"contract_closure"` | contract_closure |
  | `process_intelligence_query` | `"process_intelligence_query"` | process_intelligence_query |
  """
  @spec jtbd_scenario_id_values() :: %{
    agent_decision_loop: :agent_decision_loop,
    process_discovery: :process_discovery,
    compliance_check: :compliance_check,
    cross_system_handoff: :cross_system_handoff,
    workspace_sync: :workspace_sync,
    consensus_round: :consensus_round,
    healing_recovery: :healing_recovery,
    a2a_deal_lifecycle: :a2a_deal_lifecycle,
    mcp_tool_execution: :mcp_tool_execution,
    conformance_drift: :conformance_drift,
    yawl_v6_checkpoint: :yawl_v6_checkpoint,
    icp_qualification: :icp_qualification,
    retrofit_complexity_scoring: :retrofit_complexity_scoring,
    outreach_sequence_execution: :outreach_sequence_execution,
    deal_progression: :deal_progression,
    contract_closure: :contract_closure,
    process_intelligence_query: :process_intelligence_query
  }
  def jtbd_scenario_id_values do
    %{
      agent_decision_loop: :agent_decision_loop,
      process_discovery: :process_discovery,
      compliance_check: :compliance_check,
      cross_system_handoff: :cross_system_handoff,
      workspace_sync: :workspace_sync,
      consensus_round: :consensus_round,
      healing_recovery: :healing_recovery,
      a2a_deal_lifecycle: :a2a_deal_lifecycle,
      mcp_tool_execution: :mcp_tool_execution,
      conformance_drift: :conformance_drift,
      yawl_v6_checkpoint: :yawl_v6_checkpoint,
      icp_qualification: :icp_qualification,
      retrofit_complexity_scoring: :retrofit_complexity_scoring,
      outreach_sequence_execution: :outreach_sequence_execution,
      deal_progression: :deal_progression,
      contract_closure: :contract_closure,
      process_intelligence_query: :process_intelligence_query
    }
  end

  defmodule JtbdScenarioIdValues do
    @moduledoc """
    Typed constants for the `jtbd.scenario.id` attribute.
    """

    @doc "agent_decision_loop"
    @spec agent_decision_loop() :: :agent_decision_loop
    def agent_decision_loop, do: :agent_decision_loop

    @doc "process_discovery"
    @spec process_discovery() :: :process_discovery
    def process_discovery, do: :process_discovery

    @doc "compliance_check"
    @spec compliance_check() :: :compliance_check
    def compliance_check, do: :compliance_check

    @doc "cross_system_handoff"
    @spec cross_system_handoff() :: :cross_system_handoff
    def cross_system_handoff, do: :cross_system_handoff

    @doc "workspace_sync"
    @spec workspace_sync() :: :workspace_sync
    def workspace_sync, do: :workspace_sync

    @doc "consensus_round"
    @spec consensus_round() :: :consensus_round
    def consensus_round, do: :consensus_round

    @doc "healing_recovery"
    @spec healing_recovery() :: :healing_recovery
    def healing_recovery, do: :healing_recovery

    @doc "a2a_deal_lifecycle"
    @spec a2a_deal_lifecycle() :: :a2a_deal_lifecycle
    def a2a_deal_lifecycle, do: :a2a_deal_lifecycle

    @doc "mcp_tool_execution"
    @spec mcp_tool_execution() :: :mcp_tool_execution
    def mcp_tool_execution, do: :mcp_tool_execution

    @doc "conformance_drift"
    @spec conformance_drift() :: :conformance_drift
    def conformance_drift, do: :conformance_drift

    @doc "yawl_v6_checkpoint"
    @spec yawl_v6_checkpoint() :: :yawl_v6_checkpoint
    def yawl_v6_checkpoint, do: :yawl_v6_checkpoint

    @doc "icp_qualification"
    @spec icp_qualification() :: :icp_qualification
    def icp_qualification, do: :icp_qualification

    @doc "retrofit_complexity_scoring"
    @spec retrofit_complexity_scoring() :: :retrofit_complexity_scoring
    def retrofit_complexity_scoring, do: :retrofit_complexity_scoring

    @doc "outreach_sequence_execution"
    @spec outreach_sequence_execution() :: :outreach_sequence_execution
    def outreach_sequence_execution, do: :outreach_sequence_execution

    @doc "deal_progression"
    @spec deal_progression() :: :deal_progression
    def deal_progression, do: :deal_progression

    @doc "contract_closure"
    @spec contract_closure() :: :contract_closure
    def contract_closure, do: :contract_closure

    @doc "process_intelligence_query"
    @spec process_intelligence_query() :: :process_intelligence_query
    def process_intelligence_query, do: :process_intelligence_query

  end

  @doc """
  Final outcome of the scenario step — success, failure, timeout, or fallback activated.

  Attribute: `jtbd.scenario.outcome`
  Type: `enum`
  Stability: `development`
  Requirement: `required`
  Examples: `success`, `failure`, `timeout`, `fallback`
  """
  @spec jtbd_scenario_outcome() :: :"jtbd.scenario.outcome"
  def jtbd_scenario_outcome, do: :"jtbd.scenario.outcome"

  @doc """
  Enumerated values for `jtbd.scenario.outcome`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `success` | `"success"` | success |
  | `failure` | `"failure"` | failure |
  | `timeout` | `"timeout"` | timeout |
  | `fallback` | `"fallback"` | fallback |
  """
  @spec jtbd_scenario_outcome_values() :: %{
    success: :success,
    failure: :failure,
    timeout: :timeout,
    fallback: :fallback
  }
  def jtbd_scenario_outcome_values do
    %{
      success: :success,
      failure: :failure,
      timeout: :timeout,
      fallback: :fallback
    }
  end

  defmodule JtbdScenarioOutcomeValues do
    @moduledoc """
    Typed constants for the `jtbd.scenario.outcome` attribute.
    """

    @doc "success"
    @spec success() :: :success
    def success, do: :success

    @doc "failure"
    @spec failure() :: :failure
    def failure, do: :failure

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "fallback"
    @spec fallback() :: :fallback
    def fallback, do: :fallback

  end

  @doc """
  Human-readable name of the current scenario step (e.g., "fetch_agent_definition", "classify_failure").

  Attribute: `jtbd.scenario.step`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `fetch_agent_definition`, `classify_failure`, `evaluate_state`
  """
  @spec jtbd_scenario_step() :: :"jtbd.scenario.step"
  def jtbd_scenario_step, do: :"jtbd.scenario.step"

  @doc """
  Ordinal position of this step within the scenario (1-indexed).

  Attribute: `jtbd.scenario.step_num`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `1`, `2`, `3`, `4`, `5`
  """
  @spec jtbd_scenario_step_num() :: :"jtbd.scenario.step_num"
  def jtbd_scenario_step_num, do: :"jtbd.scenario.step_num"

  @doc """
  Total number of steps expected in this scenario execution.

  Attribute: `jtbd.scenario.step_total`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `10`, `15`, `20`
  """
  @spec jtbd_scenario_step_total() :: :"jtbd.scenario.step_total"
  def jtbd_scenario_step_total, do: :"jtbd.scenario.step_total"

  @doc """
  ChatmanGPT system executing this JTBD scenario step.

  Attribute: `jtbd.scenario.system`
  Type: `enum`
  Stability: `development`
  Requirement: `required`
  Examples: `osa`, `businessos`, `canopy`, `pm4py_rust`
  """
  @spec jtbd_scenario_system() :: :"jtbd.scenario.system"
  def jtbd_scenario_system, do: :"jtbd.scenario.system"

  @doc """
  Enumerated values for `jtbd.scenario.system`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `osa` | `"osa"` | osa |
  | `businessos` | `"businessos"` | businessos |
  | `canopy` | `"canopy"` | canopy |
  | `pm4py_rust` | `"pm4py_rust"` | pm4py_rust |
  """
  @spec jtbd_scenario_system_values() :: %{
    osa: :osa,
    businessos: :businessos,
    canopy: :canopy,
    pm4py_rust: :pm4py_rust
  }
  def jtbd_scenario_system_values do
    %{
      osa: :osa,
      businessos: :businessos,
      canopy: :canopy,
      pm4py_rust: :pm4py_rust
    }
  end

  defmodule JtbdScenarioSystemValues do
    @moduledoc """
    Typed constants for the `jtbd.scenario.system` attribute.
    """

    @doc "osa"
    @spec osa() :: :osa
    def osa, do: :osa

    @doc "businessos"
    @spec businessos() :: :businessos
    def businessos, do: :businessos

    @doc "canopy"
    @spec canopy() :: :canopy
    def canopy, do: :canopy

    @doc "pm4py_rust"
    @spec pm4py_rust() :: :pm4py_rust
    def pm4py_rust, do: :pm4py_rust

  end

  @doc """
  Wave identifier for the scenario (e.g., "wave12", "wave13"). Defaults to "wave12".

  Attribute: `jtbd.scenario.wave`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `wave12`, `wave13`, `wave14`
  """
  @spec jtbd_scenario_wave() :: :"jtbd.scenario.wave"
  def jtbd_scenario_wave, do: :"jtbd.scenario.wave"

  @doc """
  Human-readable error description when scenario.outcome is failure or timeout.

  Attribute: `jtbd.scenario.error_reason`
  Type: `string`
  Stability: `development`
  Requirement: `{"conditionally_required": "when jtbd.scenario.outcome is 'failure' or 'timeout'"}`
  Examples: `deadlock_detected`, `timeout_exceeded_30s`, `validation_failed`
  """
  @spec jtbd_scenario_error_reason() :: :"jtbd.scenario.error_reason"
  def jtbd_scenario_error_reason, do: :"jtbd.scenario.error_reason"

  @doc """
  Outcome of the DMAIC phase — completed successfully, failed, or skipped.

  Attribute: `jtbd.dmaic.phase_outcome`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `completed`, `failed`, `skipped`
  """
  @spec jtbd_dmaic_phase_outcome() :: :"jtbd.dmaic.phase_outcome"
  def jtbd_dmaic_phase_outcome, do: :"jtbd.dmaic.phase_outcome"

  @doc """
  Enumerated values for `jtbd.dmaic.phase_outcome`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `completed` | `"completed"` | completed |
  | `failed` | `"failed"` | failed |
  | `skipped` | `"skipped"` | skipped |
  """
  @spec jtbd_dmaic_phase_outcome_values() :: %{
    completed: :completed,
    failed: :failed,
    skipped: :skipped
  }
  def jtbd_dmaic_phase_outcome_values do
    %{
      completed: :completed,
      failed: :failed,
      skipped: :skipped
    }
  end

  defmodule JtbdDmaicPhaseOutcomeValues do
    @moduledoc """
    Typed constants for the `jtbd.dmaic.phase_outcome` attribute.
    """

    @doc "completed"
    @spec completed() :: :completed
    def completed, do: :completed

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

    @doc "skipped"
    @spec skipped() :: :skipped
    def skipped, do: :skipped

  end

  @doc """
  JTBD scenario identifier associated with this DMAIC phase transition.

  Attribute: `jtbd.dmaic.scenario_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `wave12-001`, `dmaic-scenario-abc`, `process-improvement-q1`
  """
  @spec jtbd_dmaic_scenario_id() :: :"jtbd.dmaic.scenario_id"
  def jtbd_dmaic_scenario_id, do: :"jtbd.dmaic.scenario_id"

  @doc """
  Identifier of the agent executing or participating in this scenario step.

  Attribute: `jtbd.scenario.agent_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healing-agent-1`, `consensus-agent-2`, `discovery-agent-1`
  """
  @spec jtbd_scenario_agent_id() :: :"jtbd.scenario.agent_id"
  def jtbd_scenario_agent_id, do: :"jtbd.scenario.agent_id"

  @doc """
  Fitness score of the discovered process model against the event log (0.0-1.0). Higher values indicate better replay fitness.

  Attribute: `jtbd.scenario.fitness`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.75`, `0.95`, `1.0`
  """
  @spec jtbd_scenario_fitness() :: :"jtbd.scenario.fitness"
  def jtbd_scenario_fitness, do: :"jtbd.scenario.fitness"

  @doc """
  Iteration or attempt number within a repeating loop (e.g., retry attempt, consensus round iteration).

  Attribute: `jtbd.scenario.iteration`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec jtbd_scenario_iteration() :: :"jtbd.scenario.iteration"
  def jtbd_scenario_iteration, do: :"jtbd.scenario.iteration"

  @doc """
  Measured latency (elapsed time) for this scenario step in milliseconds.

  Attribute: `jtbd.scenario.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `42`, `156`, `5000`
  """
  @spec jtbd_scenario_latency_ms() :: :"jtbd.scenario.latency_ms"
  def jtbd_scenario_latency_ms, do: :"jtbd.scenario.latency_ms"

  @doc """
  Format of the process model produced or consumed by this scenario step (e.g., "pnml", "bpmn", "dfg").

  Attribute: `jtbd.scenario.model_format`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pnml`, `bpmn`, `dfg`, `xes`
  """
  @spec jtbd_scenario_model_format() :: :"jtbd.scenario.model_format"
  def jtbd_scenario_model_format, do: :"jtbd.scenario.model_format"

  @doc """
  Number of places in the Petri net model produced by this scenario step.

  Attribute: `jtbd.scenario.place_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `14`, `32`
  """
  @spec jtbd_scenario_place_count() :: :"jtbd.scenario.place_count"
  def jtbd_scenario_place_count, do: :"jtbd.scenario.place_count"

  @doc """
  Identifier of the Claude Code task or work item associated with this scenario step.

  Attribute: `jtbd.scenario.task_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `task-wave12-001`, `task-001`, `task-abc-123`
  """
  @spec jtbd_scenario_task_id() :: :"jtbd.scenario.task_id"
  def jtbd_scenario_task_id, do: :"jtbd.scenario.task_id"

  @doc """
  Jaeger trace ID or OpenTelemetry trace link for full observability of this scenario step.

  Attribute: `jtbd.scenario.trace_link`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4bf92f3577b34da6a3ce929d0e0e4736`, `trace://jaeger-local/abc123...`
  """
  @spec jtbd_scenario_trace_link() :: :"jtbd.scenario.trace_link"
  def jtbd_scenario_trace_link, do: :"jtbd.scenario.trace_link"

  @doc """
  Number of transitions in the Petri net model produced by this scenario step.

  Attribute: `jtbd.scenario.transition_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4`, `8`, `20`
  """
  @spec jtbd_scenario_transition_count() :: :"jtbd.scenario.transition_count"
  def jtbd_scenario_transition_count, do: :"jtbd.scenario.transition_count"

end