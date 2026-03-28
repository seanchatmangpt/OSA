defmodule OpenTelemetry.SemConv.Incubating.A2aAttributes do
  @moduledoc """
  A2a semantic convention attributes.

  Namespace: `a2a`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Identifier of the target agent in an A2A call.

  Attribute: `a2a.agent.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `businessos-agent`, `osa-healing-agent`, `canopy-adapter`
  """
  @spec a2a_agent_id() :: :"a2a.agent.id"
  def a2a_agent_id, do: :"a2a.agent.id"

  @doc """
  Human-readable name of the A2A agent serving the request.

  Attribute: `a2a.agent.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pm4py-rust`, `osa-agent`, `canopy-orchestrator`
  """
  @spec a2a_agent_name() :: :"a2a.agent.name"
  def a2a_agent_name, do: :"a2a.agent.name"

  @doc """
  Number of output artifacts produced by a completed A2A task.

  Attribute: `a2a.artifact.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `10`
  """
  @spec a2a_artifact_count() :: :"a2a.artifact.count"
  def a2a_artifact_count, do: :"a2a.artifact.count"

  @doc """
  Number of bids received in the A2A auction.

  Attribute: `a2a.auction.bid_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `5`, `20`
  """
  @spec a2a_auction_bid_count() :: :"a2a.auction.bid_count"
  def a2a_auction_bid_count, do: :"a2a.auction.bid_count"

  @doc """
  Clearing price of the A2A auction in normalized units.

  Attribute: `a2a.auction.clearing_price`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.5`, `1.0`, `2.5`
  """
  @spec a2a_auction_clearing_price() :: :"a2a.auction.clearing_price"
  def a2a_auction_clearing_price, do: :"a2a.auction.clearing_price"

  @doc """
  Unique identifier of the A2A auction used for capability allocation.

  Attribute: `a2a.auction.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `auction-001`, `a2a-bid-x7f`
  """
  @spec a2a_auction_id() :: :"a2a.auction.id"
  def a2a_auction_id, do: :"a2a.auction.id"

  @doc """
  Agent identifier of the auction winner.

  Attribute: `a2a.auction.winner_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent-3`, `osa-worker-1`
  """
  @spec a2a_auction_winner_id() :: :"a2a.auction.winner_id"
  def a2a_auction_winner_id, do: :"a2a.auction.winner_id"

  @doc """
  Compression ratio achieved for the batch, range [0.0, 1.0]. 1.0 = no compression.

  Attribute: `a2a.batch.compression_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.35`, `0.6`, `1.0`
  """
  @spec a2a_batch_compression_ratio() :: :"a2a.batch.compression_ratio"
  def a2a_batch_compression_ratio, do: :"a2a.batch.compression_ratio"

  @doc """
  Delivery guarantee policy for the message batch.

  Attribute: `a2a.batch.delivery_policy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `at_most_once`, `at_least_once`, `exactly_once`
  """
  @spec a2a_batch_delivery_policy() :: :"a2a.batch.delivery_policy"
  def a2a_batch_delivery_policy, do: :"a2a.batch.delivery_policy"

  @doc """
  Enumerated values for `a2a.batch.delivery_policy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `at_most_once` | `"at_most_once"` | at_most_once |
  | `at_least_once` | `"at_least_once"` | at_least_once |
  | `exactly_once` | `"exactly_once"` | exactly_once |
  """
  @spec a2a_batch_delivery_policy_values() :: %{
    at_most_once: :at_most_once,
    at_least_once: :at_least_once,
    exactly_once: :exactly_once
  }
  def a2a_batch_delivery_policy_values do
    %{
      at_most_once: :at_most_once,
      at_least_once: :at_least_once,
      exactly_once: :exactly_once
    }
  end

  defmodule A2aBatchDeliveryPolicyValues do
    @moduledoc """
    Typed constants for the `a2a.batch.delivery_policy` attribute.
    """

    @doc "at_most_once"
    @spec at_most_once() :: :at_most_once
    def at_most_once, do: :at_most_once

    @doc "at_least_once"
    @spec at_least_once() :: :at_least_once
    def at_least_once, do: :at_least_once

    @doc "exactly_once"
    @spec exactly_once() :: :exactly_once
    def exactly_once, do: :exactly_once

  end

  @doc """
  Unique identifier for an A2A message batch.

  Attribute: `a2a.batch.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `batch-001`, `msg-batch-7f3a`
  """
  @spec a2a_batch_id() :: :"a2a.batch.id"
  def a2a_batch_id, do: :"a2a.batch.id"

  @doc """
  Number of messages in the batch.

  Attribute: `a2a.batch.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `10`, `100`
  """
  @spec a2a_batch_size() :: :"a2a.batch.size"
  def a2a_batch_size, do: :"a2a.batch.size"

  @doc """
  Composite bid score computed by the auction evaluation strategy, range [0.0, 1.0].

  Attribute: `a2a.bid.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.72`, `0.91`
  """
  @spec a2a_bid_score() :: :"a2a.bid.score"
  def a2a_bid_score, do: :"a2a.bid.score"

  @doc """
  Strategy used to evaluate and rank agent bids for task allocation.

  Attribute: `a2a.bid.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `lowest_cost`, `highest_trust`, `balanced`
  """
  @spec a2a_bid_strategy() :: :"a2a.bid.strategy"
  def a2a_bid_strategy, do: :"a2a.bid.strategy"

  @doc """
  Enumerated values for `a2a.bid.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `lowest_cost` | `"lowest_cost"` | lowest_cost |
  | `highest_trust` | `"highest_trust"` | highest_trust |
  | `fastest_response` | `"fastest_response"` | fastest_response |
  | `balanced` | `"balanced"` | balanced |
  """
  @spec a2a_bid_strategy_values() :: %{
    lowest_cost: :lowest_cost,
    highest_trust: :highest_trust,
    fastest_response: :fastest_response,
    balanced: :balanced
  }
  def a2a_bid_strategy_values do
    %{
      lowest_cost: :lowest_cost,
      highest_trust: :highest_trust,
      fastest_response: :fastest_response,
      balanced: :balanced
    }
  end

  defmodule A2aBidStrategyValues do
    @moduledoc """
    Typed constants for the `a2a.bid.strategy` attribute.
    """

    @doc "lowest_cost"
    @spec lowest_cost() :: :lowest_cost
    def lowest_cost, do: :lowest_cost

    @doc "highest_trust"
    @spec highest_trust() :: :highest_trust
    def highest_trust, do: :highest_trust

    @doc "fastest_response"
    @spec fastest_response() :: :fastest_response
    def fastest_response, do: :fastest_response

    @doc "balanced"
    @spec balanced() :: :balanced
    def balanced, do: :balanced

  end

  @doc """
  Identifier of the agent that won the bid evaluation.

  Attribute: `a2a.bid.winner_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent-007`, `billing-agent-1`
  """
  @spec a2a_bid_winner_id() :: :"a2a.bid.winner_id"
  def a2a_bid_winner_id, do: :"a2a.bid.winner_id"

  @doc """
  Confidence score for capability matching between requesting and providing agents [0.0, 1.0].

  Attribute: `a2a.capability.match_score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.72`, `0.4`
  """
  @spec a2a_capability_match_score() :: :"a2a.capability.match_score"
  def a2a_capability_match_score, do: :"a2a.capability.match_score"

  @doc """
  Name of the capability being advertised or requested in A2A negotiation.

  Attribute: `a2a.capability.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `healing.diagnosis`, `process.mining`, `compliance.check`
  """
  @spec a2a_capability_name() :: :"a2a.capability.name"
  def a2a_capability_name, do: :"a2a.capability.name"

  @doc """
  Unique identifier for the capability negotiation session.

  Attribute: `a2a.capability.negotiation.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `neg-001`, `cap-neg-abc123`
  """
  @spec a2a_capability_negotiation_id() :: :"a2a.capability.negotiation.id"
  def a2a_capability_negotiation_id, do: :"a2a.capability.negotiation.id"

  @doc """
  Outcome of the capability negotiation.

  Attribute: `a2a.capability.negotiation.outcome`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec a2a_capability_negotiation_outcome() :: :"a2a.capability.negotiation.outcome"
  def a2a_capability_negotiation_outcome, do: :"a2a.capability.negotiation.outcome"

  @doc """
  Enumerated values for `a2a.capability.negotiation.outcome`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `accepted` | `"accepted"` | accepted |
  | `rejected` | `"rejected"` | rejected |
  | `deferred` | `"deferred"` | deferred |
  | `partial` | `"partial"` | partial |
  """
  @spec a2a_capability_negotiation_outcome_values() :: %{
    accepted: :accepted,
    rejected: :rejected,
    deferred: :deferred,
    partial: :partial
  }
  def a2a_capability_negotiation_outcome_values do
    %{
      accepted: :accepted,
      rejected: :rejected,
      deferred: :deferred,
      partial: :partial
    }
  end

  defmodule A2aCapabilityNegotiationOutcomeValues do
    @moduledoc """
    Typed constants for the `a2a.capability.negotiation.outcome` attribute.
    """

    @doc "accepted"
    @spec accepted() :: :accepted
    def accepted, do: :accepted

    @doc "rejected"
    @spec rejected() :: :rejected
    def rejected, do: :rejected

    @doc "deferred"
    @spec deferred() :: :deferred
    def deferred, do: :deferred

    @doc "partial"
    @spec partial() :: :partial
    def partial, do: :partial

  end

  @doc """
  Number of rounds in the capability negotiation.

  Attribute: `a2a.capability.negotiation.rounds`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `5`
  """
  @spec a2a_capability_negotiation_rounds() :: :"a2a.capability.negotiation.rounds"
  def a2a_capability_negotiation_rounds, do: :"a2a.capability.negotiation.rounds"

  @doc """
  The capability name offered by the target agent.

  Attribute: `a2a.capability.offered`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `text.summarize`, `data.transform`
  """
  @spec a2a_capability_offered() :: :"a2a.capability.offered"
  def a2a_capability_offered, do: :"a2a.capability.offered"

  @doc """
  The capability name being requested by the source agent.

  Attribute: `a2a.capability.required`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `text.summarize`, `data.transform`, `image.classify`
  """
  @spec a2a_capability_required() :: :"a2a.capability.required"
  def a2a_capability_required, do: :"a2a.capability.required"

  @doc """
  Version of the agent capability being delegated.

  Attribute: `a2a.capability.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0.0`, `2.3.1`
  """
  @spec a2a_capability_version() :: :"a2a.capability.version"
  def a2a_capability_version, do: :"a2a.capability.version"

  @doc """
  Unique identifier for the contract amendment.

  Attribute: `a2a.contract.amendment.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `amend-001`, `contract-rev-5`
  """
  @spec a2a_contract_amendment_id() :: :"a2a.contract.amendment.id"
  def a2a_contract_amendment_id, do: :"a2a.contract.amendment.id"

  @doc """
  Reason for the contract amendment.

  Attribute: `a2a.contract.amendment.reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `scope_change`, `price_adjustment`
  """
  @spec a2a_contract_amendment_reason() :: :"a2a.contract.amendment.reason"
  def a2a_contract_amendment_reason, do: :"a2a.contract.amendment.reason"

  @doc """
  Enumerated values for `a2a.contract.amendment.reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `scope_change` | `"scope_change"` | scope_change |
  | `price_adjustment` | `"price_adjustment"` | price_adjustment |
  | `timeline_extension` | `"timeline_extension"` | timeline_extension |
  | `quality_revision` | `"quality_revision"` | quality_revision |
  """
  @spec a2a_contract_amendment_reason_values() :: %{
    scope_change: :scope_change,
    price_adjustment: :price_adjustment,
    timeline_extension: :timeline_extension,
    quality_revision: :quality_revision
  }
  def a2a_contract_amendment_reason_values do
    %{
      scope_change: :scope_change,
      price_adjustment: :price_adjustment,
      timeline_extension: :timeline_extension,
      quality_revision: :quality_revision
    }
  end

  defmodule A2aContractAmendmentReasonValues do
    @moduledoc """
    Typed constants for the `a2a.contract.amendment.reason` attribute.
    """

    @doc "scope_change"
    @spec scope_change() :: :scope_change
    def scope_change, do: :scope_change

    @doc "price_adjustment"
    @spec price_adjustment() :: :price_adjustment
    def price_adjustment, do: :price_adjustment

    @doc "timeline_extension"
    @spec timeline_extension() :: :timeline_extension
    def timeline_extension, do: :timeline_extension

    @doc "quality_revision"
    @spec quality_revision() :: :quality_revision
    def quality_revision, do: :quality_revision

  end

  @doc """
  Version number of the amended contract.

  Attribute: `a2a.contract.amendment.version`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`, `10`
  """
  @spec a2a_contract_amendment_version() :: :"a2a.contract.amendment.version"
  def a2a_contract_amendment_version, do: :"a2a.contract.amendment.version"

  @doc """
  Unique identifier for the A2A contract dispute.

  Attribute: `a2a.contract.dispute.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `contract-dispute-001`, `disp-contract-abc123`
  """
  @spec a2a_contract_dispute_id() :: :"a2a.contract.dispute.id"
  def a2a_contract_dispute_id, do: :"a2a.contract.dispute.id"

  @doc """
  Reason for the contract dispute.

  Attribute: `a2a.contract.dispute.reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `breach`, `ambiguity`, `force_majeure`
  """
  @spec a2a_contract_dispute_reason() :: :"a2a.contract.dispute.reason"
  def a2a_contract_dispute_reason, do: :"a2a.contract.dispute.reason"

  @doc """
  Enumerated values for `a2a.contract.dispute.reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `breach` | `"breach"` | breach |
  | `ambiguity` | `"ambiguity"` | ambiguity |
  | `force_majeure` | `"force_majeure"` | force_majeure |
  """
  @spec a2a_contract_dispute_reason_values() :: %{
    breach: :breach,
    ambiguity: :ambiguity,
    force_majeure: :force_majeure
  }
  def a2a_contract_dispute_reason_values do
    %{
      breach: :breach,
      ambiguity: :ambiguity,
      force_majeure: :force_majeure
    }
  end

  defmodule A2aContractDisputeReasonValues do
    @moduledoc """
    Typed constants for the `a2a.contract.dispute.reason` attribute.
    """

    @doc "breach"
    @spec breach() :: :breach
    def breach, do: :breach

    @doc "ambiguity"
    @spec ambiguity() :: :ambiguity
    def ambiguity, do: :ambiguity

    @doc "force_majeure"
    @spec force_majeure() :: :force_majeure
    def force_majeure, do: :force_majeure

  end

  @doc """
  Current status of the contract dispute.

  Attribute: `a2a.contract.dispute.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `open`, `arbitrating`, `resolved`
  """
  @spec a2a_contract_dispute_status() :: :"a2a.contract.dispute.status"
  def a2a_contract_dispute_status, do: :"a2a.contract.dispute.status"

  @doc """
  Enumerated values for `a2a.contract.dispute.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `open` | `"open"` | open |
  | `arbitrating` | `"arbitrating"` | arbitrating |
  | `resolved` | `"resolved"` | resolved |
  """
  @spec a2a_contract_dispute_status_values() :: %{
    open: :open,
    arbitrating: :arbitrating,
    resolved: :resolved
  }
  def a2a_contract_dispute_status_values do
    %{
      open: :open,
      arbitrating: :arbitrating,
      resolved: :resolved
    }
  end

  defmodule A2aContractDisputeStatusValues do
    @moduledoc """
    Typed constants for the `a2a.contract.dispute.status` attribute.
    """

    @doc "open"
    @spec open() :: :open
    def open, do: :open

    @doc "arbitrating"
    @spec arbitrating() :: :arbitrating
    def arbitrating, do: :arbitrating

    @doc "resolved"
    @spec resolved() :: :resolved
    def resolved, do: :resolved

  end

  @doc """
  Percentage of contract execution completed, range [0.0, 100.0].

  Attribute: `a2a.contract.execution.progress_pct`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `50.0`, `100.0`
  """
  @spec a2a_contract_execution_progress_pct() :: :"a2a.contract.execution.progress_pct"
  def a2a_contract_execution_progress_pct, do: :"a2a.contract.execution.progress_pct"

  @doc """
  The current execution status of the A2A contract.

  Attribute: `a2a.contract.execution.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `running`, `completed`, `failed`, `disputed`
  """
  @spec a2a_contract_execution_status() :: :"a2a.contract.execution.status"
  def a2a_contract_execution_status, do: :"a2a.contract.execution.status"

  @doc """
  Enumerated values for `a2a.contract.execution.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `running` | `"running"` | running |
  | `completed` | `"completed"` | completed |
  | `failed` | `"failed"` | failed |
  | `disputed` | `"disputed"` | disputed |
  """
  @spec a2a_contract_execution_status_values() :: %{
    running: :running,
    completed: :completed,
    failed: :failed,
    disputed: :disputed
  }
  def a2a_contract_execution_status_values do
    %{
      running: :running,
      completed: :completed,
      failed: :failed,
      disputed: :disputed
    }
  end

  defmodule A2aContractExecutionStatusValues do
    @moduledoc """
    Typed constants for the `a2a.contract.execution.status` attribute.
    """

    @doc "running"
    @spec running() :: :running
    def running, do: :running

    @doc "completed"
    @spec completed() :: :completed
    def completed, do: :completed

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

    @doc "disputed"
    @spec disputed() :: :disputed
    def disputed, do: :disputed

  end

  @doc """
  Unix timestamp (milliseconds) when the contract expires.

  Attribute: `a2a.contract.expiry_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1700000000000`, `1800000000000`
  """
  @spec a2a_contract_expiry_ms() :: :"a2a.contract.expiry_ms"
  def a2a_contract_expiry_ms, do: :"a2a.contract.expiry_ms"

  @doc """
  Unique identifier for an A2A service contract.

  Attribute: `a2a.contract.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `contract-xyz789`, `svc-contract-001`
  """
  @spec a2a_contract_id() :: :"a2a.contract.id"
  def a2a_contract_id, do: :"a2a.contract.id"

  @doc """
  SHA-256 hash of the contract terms for integrity verification.

  Attribute: `a2a.contract.terms_hash`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sha256:abc123...`, `sha256:def456...`
  """
  @spec a2a_contract_terms_hash() :: :"a2a.contract.terms_hash"
  def a2a_contract_terms_hash, do: :"a2a.contract.terms_hash"

  @doc """
  Number of times the contract terms were violated during the contract lifetime.

  Attribute: `a2a.contract.violation_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`
  """
  @spec a2a_contract_violation_count() :: :"a2a.contract.violation_count"
  def a2a_contract_violation_count, do: :"a2a.contract.violation_count"

  @doc """
  Currency unit for the deal value (ISO 4217 or token unit).

  Attribute: `a2a.deal.currency`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `USD`, `TOKEN`, `CREDIT`
  """
  @spec a2a_deal_currency() :: :"a2a.deal.currency"
  def a2a_deal_currency, do: :"a2a.deal.currency"

  @doc """
  Deal expiration time as Unix epoch milliseconds (Armstrong WvdA bounded lifetime).

  Attribute: `a2a.deal.expiry_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1745000000000`, `1750000000000`
  """
  @spec a2a_deal_expiry_ms() :: :"a2a.deal.expiry_ms"
  def a2a_deal_expiry_ms, do: :"a2a.deal.expiry_ms"

  @doc """
  Identifier of the deal being created or operated on via A2A.

  Attribute: `a2a.deal.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `deal-abc123`, `deal-2026-001`
  """
  @spec a2a_deal_id() :: :"a2a.deal.id"
  def a2a_deal_id, do: :"a2a.deal.id"

  @doc """
  Current status of the A2A deal in its lifecycle.

  Attribute: `a2a.deal.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pending`, `active`, `completed`
  """
  @spec a2a_deal_status() :: :"a2a.deal.status"
  def a2a_deal_status, do: :"a2a.deal.status"

  @doc """
  Enumerated values for `a2a.deal.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pending` | `"pending"` | pending |
  | `active` | `"active"` | active |
  | `completed` | `"completed"` | completed |
  | `cancelled` | `"cancelled"` | cancelled |
  | `disputed` | `"disputed"` | disputed |
  """
  @spec a2a_deal_status_values() :: %{
    pending: :pending,
    active: :active,
    completed: :completed,
    cancelled: :cancelled,
    disputed: :disputed
  }
  def a2a_deal_status_values do
    %{
      pending: :pending,
      active: :active,
      completed: :completed,
      cancelled: :cancelled,
      disputed: :disputed
    }
  end

  defmodule A2aDealStatusValues do
    @moduledoc """
    Typed constants for the `a2a.deal.status` attribute.
    """

    @doc "pending"
    @spec pending() :: :pending
    def pending, do: :pending

    @doc "active"
    @spec active() :: :active
    def active, do: :active

    @doc "completed"
    @spec completed() :: :completed
    def completed, do: :completed

    @doc "cancelled"
    @spec cancelled() :: :cancelled
    def cancelled, do: :cancelled

    @doc "disputed"
    @spec disputed() :: :disputed
    def disputed, do: :disputed

  end

  @doc """
  Type of the A2A deal.

  Attribute: `a2a.deal.type`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `data_access`, `compute_task`, `agent_collaboration`
  """
  @spec a2a_deal_type() :: :"a2a.deal.type"
  def a2a_deal_type, do: :"a2a.deal.type"

  @doc """
  Numeric value associated with the deal (e.g., computational cost, token budget).

  Attribute: `a2a.deal.value`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100.0`, `250.5`
  """
  @spec a2a_deal_value() :: :"a2a.deal.value"
  def a2a_deal_value, do: :"a2a.deal.value"

  @doc """
  Unique identifier for the A2A dispute case.

  Attribute: `a2a.dispute.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `dispute-001`, `disp-abc123`
  """
  @spec a2a_dispute_id() :: :"a2a.dispute.id"
  def a2a_dispute_id, do: :"a2a.dispute.id"

  @doc """
  The reason for the A2A dispute.

  Attribute: `a2a.dispute.reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `quality`, `sla_breach`
  """
  @spec a2a_dispute_reason() :: :"a2a.dispute.reason"
  def a2a_dispute_reason, do: :"a2a.dispute.reason"

  @doc """
  Enumerated values for `a2a.dispute.reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `quality` | `"quality"` | quality |
  | `sla_breach` | `"sla_breach"` | sla_breach |
  | `payment` | `"payment"` | payment |
  | `fraud` | `"fraud"` | fraud |
  | `technical` | `"technical"` | technical |
  """
  @spec a2a_dispute_reason_values() :: %{
    quality: :quality,
    sla_breach: :sla_breach,
    payment: :payment,
    fraud: :fraud,
    technical: :technical
  }
  def a2a_dispute_reason_values do
    %{
      quality: :quality,
      sla_breach: :sla_breach,
      payment: :payment,
      fraud: :fraud,
      technical: :technical
    }
  end

  defmodule A2aDisputeReasonValues do
    @moduledoc """
    Typed constants for the `a2a.dispute.reason` attribute.
    """

    @doc "quality"
    @spec quality() :: :quality
    def quality, do: :quality

    @doc "sla_breach"
    @spec sla_breach() :: :sla_breach
    def sla_breach, do: :sla_breach

    @doc "payment"
    @spec payment() :: :payment
    def payment, do: :payment

    @doc "fraud"
    @spec fraud() :: :fraud
    def fraud, do: :fraud

    @doc "technical"
    @spec technical() :: :technical
    def technical, do: :technical

  end

  @doc """
  Time taken to resolve the dispute in milliseconds.

  Attribute: `a2a.dispute.resolution_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `30000`, `86400000`
  """
  @spec a2a_dispute_resolution_ms() :: :"a2a.dispute.resolution_ms"
  def a2a_dispute_resolution_ms, do: :"a2a.dispute.resolution_ms"

  @doc """
  Current resolution status of the A2A dispute.

  Attribute: `a2a.dispute.resolution_status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `resolved`, `escalated`
  """
  @spec a2a_dispute_resolution_status() :: :"a2a.dispute.resolution_status"
  def a2a_dispute_resolution_status, do: :"a2a.dispute.resolution_status"

  @doc """
  Enumerated values for `a2a.dispute.resolution_status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pending` | `"pending"` | pending |
  | `resolved` | `"resolved"` | resolved |
  | `escalated` | `"escalated"` | escalated |
  """
  @spec a2a_dispute_resolution_status_values() :: %{
    pending: :pending,
    resolved: :resolved,
    escalated: :escalated
  }
  def a2a_dispute_resolution_status_values do
    %{
      pending: :pending,
      resolved: :resolved,
      escalated: :escalated
    }
  end

  defmodule A2aDisputeResolutionStatusValues do
    @moduledoc """
    Typed constants for the `a2a.dispute.resolution_status` attribute.
    """

    @doc "pending"
    @spec pending() :: :pending
    def pending, do: :pending

    @doc "resolved"
    @spec resolved() :: :resolved
    def resolved, do: :resolved

    @doc "escalated"
    @spec escalated() :: :escalated
    def escalated, do: :escalated

  end

  @doc """
  Amount held in escrow for the A2A deal.

  Attribute: `a2a.escrow.amount`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100.0`, `2500.5`, `0.001`
  """
  @spec a2a_escrow_amount() :: :"a2a.escrow.amount"
  def a2a_escrow_amount, do: :"a2a.escrow.amount"

  @doc """
  Unique identifier for the A2A escrow holding deal payment.

  Attribute: `a2a.escrow.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `escrow-abc123`, `esc-2026-03-25-001`
  """
  @spec a2a_escrow_id() :: :"a2a.escrow.id"
  def a2a_escrow_id, do: :"a2a.escrow.id"

  @doc """
  Condition under which the escrow funds are released.

  Attribute: `a2a.escrow.release_condition`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `completion`, `timeout`
  """
  @spec a2a_escrow_release_condition() :: :"a2a.escrow.release_condition"
  def a2a_escrow_release_condition, do: :"a2a.escrow.release_condition"

  @doc """
  Enumerated values for `a2a.escrow.release_condition`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `completion` | `"completion"` | completion |
  | `timeout` | `"timeout"` | timeout |
  | `manual` | `"manual"` | manual |
  | `dispute` | `"dispute"` | dispute |
  """
  @spec a2a_escrow_release_condition_values() :: %{
    completion: :completion,
    timeout: :timeout,
    manual: :manual,
    dispute: :dispute
  }
  def a2a_escrow_release_condition_values do
    %{
      completion: :completion,
      timeout: :timeout,
      manual: :manual,
      dispute: :dispute
    }
  end

  defmodule A2aEscrowReleaseConditionValues do
    @moduledoc """
    Typed constants for the `a2a.escrow.release_condition` attribute.
    """

    @doc "completion"
    @spec completion() :: :completion
    def completion, do: :completion

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "manual"
    @spec manual() :: :manual
    def manual, do: :manual

    @doc "dispute"
    @spec dispute() :: :dispute
    def dispute, do: :dispute

  end

  @doc """
  Time taken to release the escrow in milliseconds.

  Attribute: `a2a.escrow.release_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `5000`, `30000`
  """
  @spec a2a_escrow_release_ms() :: :"a2a.escrow.release_ms"
  def a2a_escrow_release_ms, do: :"a2a.escrow.release_ms"

  @doc """
  The reason the A2A escrow was released.

  Attribute: `a2a.escrow.release_reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `completion`, `dispute`
  """
  @spec a2a_escrow_release_reason() :: :"a2a.escrow.release_reason"
  def a2a_escrow_release_reason, do: :"a2a.escrow.release_reason"

  @doc """
  Enumerated values for `a2a.escrow.release_reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `completion` | `"completion"` | completion |
  | `timeout` | `"timeout"` | timeout |
  | `dispute` | `"dispute"` | dispute |
  | `manual` | `"manual"` | manual |
  """
  @spec a2a_escrow_release_reason_values() :: %{
    completion: :completion,
    timeout: :timeout,
    dispute: :dispute,
    manual: :manual
  }
  def a2a_escrow_release_reason_values do
    %{
      completion: :completion,
      timeout: :timeout,
      dispute: :dispute,
      manual: :manual
    }
  end

  defmodule A2aEscrowReleaseReasonValues do
    @moduledoc """
    Typed constants for the `a2a.escrow.release_reason` attribute.
    """

    @doc "completion"
    @spec completion() :: :completion
    def completion, do: :completion

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "dispute"
    @spec dispute() :: :dispute
    def dispute, do: :dispute

    @doc "manual"
    @spec manual() :: :manual
    def manual, do: :manual

  end

  @doc """
  The actual amount released from escrow (may differ from original if penalties applied).

  Attribute: `a2a.escrow.released_amount`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100.0`, `95.5`, `0.0`
  """
  @spec a2a_escrow_released_amount() :: :"a2a.escrow.released_amount"
  def a2a_escrow_released_amount, do: :"a2a.escrow.released_amount"

  @doc """
  Current status of the A2A escrow.

  Attribute: `a2a.escrow.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `held`, `released`
  """
  @spec a2a_escrow_status() :: :"a2a.escrow.status"
  def a2a_escrow_status, do: :"a2a.escrow.status"

  @doc """
  Enumerated values for `a2a.escrow.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pending` | `"pending"` | pending |
  | `held` | `"held"` | held |
  | `released` | `"released"` | released |
  | `disputed` | `"disputed"` | disputed |
  """
  @spec a2a_escrow_status_values() :: %{
    pending: :pending,
    held: :held,
    released: :released,
    disputed: :disputed
  }
  def a2a_escrow_status_values do
    %{
      pending: :pending,
      held: :held,
      released: :released,
      disputed: :disputed
    }
  end

  defmodule A2aEscrowStatusValues do
    @moduledoc """
    Typed constants for the `a2a.escrow.status` attribute.
    """

    @doc "pending"
    @spec pending() :: :pending
    def pending, do: :pending

    @doc "held"
    @spec held() :: :held
    def held, do: :held

    @doc "released"
    @spec released() :: :released
    def released, do: :released

    @doc "disputed"
    @spec disputed() :: :disputed
    def disputed, do: :disputed

  end

  @doc """
  Unique identifier for knowledge transfer.

  Attribute: `a2a.knowledge.transfer.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `kt-abc123`, `transfer-2026-03-25-001`
  """
  @spec a2a_knowledge_transfer_id() :: :"a2a.knowledge.transfer.id"
  def a2a_knowledge_transfer_id, do: :"a2a.knowledge.transfer.id"

  @doc """
  Size of knowledge payload in bytes.

  Attribute: `a2a.knowledge.transfer.size_bytes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `65536`, `1048576`
  """
  @spec a2a_knowledge_transfer_size_bytes() :: :"a2a.knowledge.transfer.size_bytes"
  def a2a_knowledge_transfer_size_bytes, do: :"a2a.knowledge.transfer.size_bytes"

  @doc """
  Topic or domain of knowledge being transferred.

  Attribute: `a2a.knowledge.transfer.topic`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `process_mining`, `agent_capability`, `compliance_rules`
  """
  @spec a2a_knowledge_transfer_topic() :: :"a2a.knowledge.transfer.topic"
  def a2a_knowledge_transfer_topic, do: :"a2a.knowledge.transfer.topic"

  @doc """
  Encoding format of the A2A message.

  Attribute: `a2a.message.encoding`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `json`, `protobuf`
  """
  @spec a2a_message_encoding() :: :"a2a.message.encoding"
  def a2a_message_encoding, do: :"a2a.message.encoding"

  @doc """
  Enumerated values for `a2a.message.encoding`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `json` | `"json"` | json |
  | `msgpack` | `"msgpack"` | msgpack |
  | `protobuf` | `"protobuf"` | protobuf |
  """
  @spec a2a_message_encoding_values() :: %{
    json: :json,
    msgpack: :msgpack,
    protobuf: :protobuf
  }
  def a2a_message_encoding_values do
    %{
      json: :json,
      msgpack: :msgpack,
      protobuf: :protobuf
    }
  end

  defmodule A2aMessageEncodingValues do
    @moduledoc """
    Typed constants for the `a2a.message.encoding` attribute.
    """

    @doc "json"
    @spec json() :: :json
    def json, do: :json

    @doc "msgpack"
    @spec msgpack() :: :msgpack
    def msgpack, do: :msgpack

    @doc "protobuf"
    @spec protobuf() :: :protobuf
    def protobuf, do: :protobuf

  end

  @doc """
  Unique identifier for this A2A message, used for deduplication and correlation.

  Attribute: `a2a.message.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `msg-123e4567-e89b`, `a2a-req-001`
  """
  @spec a2a_message_id() :: :"a2a.message.id"
  def a2a_message_id, do: :"a2a.message.id"

  @doc """
  Priority level of the A2A message.

  Attribute: `a2a.message.priority`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `high`
  """
  @spec a2a_message_priority() :: :"a2a.message.priority"
  def a2a_message_priority, do: :"a2a.message.priority"

  @doc """
  Enumerated values for `a2a.message.priority`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | critical |
  | `high` | `"high"` | high |
  | `normal` | `"normal"` | normal |
  | `low` | `"low"` | low |
  """
  @spec a2a_message_priority_values() :: %{
    critical: :critical,
    high: :high,
    normal: :normal,
    low: :low
  }
  def a2a_message_priority_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end

  defmodule A2aMessagePriorityValues do
    @moduledoc """
    Typed constants for the `a2a.message.priority` attribute.
    """

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "high"
    @spec high() :: :high
    def high, do: :high

    @doc "normal"
    @spec normal() :: :normal
    def normal, do: :normal

    @doc "low"
    @spec low() :: :low
    def low, do: :low

  end

  @doc """
  Role of the sender of an A2A message.

  Attribute: `a2a.message.role`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec a2a_message_role() :: :"a2a.message.role"
  def a2a_message_role, do: :"a2a.message.role"

  @doc """
  Enumerated values for `a2a.message.role`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `user` | `"user"` | Message originated from a user or calling agent. |
  | `agent` | `"agent"` | Message originated from this agent. |
  """
  @spec a2a_message_role_values() :: %{
    user: :user,
    agent: :agent
  }
  def a2a_message_role_values do
    %{
      user: :user,
      agent: :agent
    }
  end

  defmodule A2aMessageRoleValues do
    @moduledoc """
    Typed constants for the `a2a.message.role` attribute.
    """

    @doc "Message originated from a user or calling agent."
    @spec user() :: :user
    def user, do: :user

    @doc "Message originated from this agent."
    @spec agent() :: :agent
    def agent, do: :agent

  end

  @doc """
  Size of the A2A message payload in bytes.

  Attribute: `a2a.message.size_bytes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `256`, `1024`, `65536`
  """
  @spec a2a_message_size_bytes() :: :"a2a.message.size_bytes"
  def a2a_message_size_bytes, do: :"a2a.message.size_bytes"

  @doc """
  Time-to-live for the A2A message in milliseconds.

  Attribute: `a2a.message.ttl_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`
  """
  @spec a2a_message_ttl_ms() :: :"a2a.message.ttl_ms"
  def a2a_message_ttl_ms, do: :"a2a.message.ttl_ms"

  @doc """
  The negotiation round number in a multi-round deal negotiation.

  Attribute: `a2a.negotiation.round`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `2`, `3`
  """
  @spec a2a_negotiation_round() :: :"a2a.negotiation.round"
  def a2a_negotiation_round, do: :"a2a.negotiation.round"

  @doc """
  Current state in the A2A negotiation state machine.

  Attribute: `a2a.negotiation.state`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `proposed`, `accepted`
  """
  @spec a2a_negotiation_state() :: :"a2a.negotiation.state"
  def a2a_negotiation_state, do: :"a2a.negotiation.state"

  @doc """
  Enumerated values for `a2a.negotiation.state`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `proposed` | `"proposed"` | proposed |
  | `counter` | `"counter"` | counter |
  | `accepted` | `"accepted"` | accepted |
  | `rejected` | `"rejected"` | rejected |
  | `expired` | `"expired"` | expired |
  """
  @spec a2a_negotiation_state_values() :: %{
    proposed: :proposed,
    counter: :counter,
    accepted: :accepted,
    rejected: :rejected,
    expired: :expired
  }
  def a2a_negotiation_state_values do
    %{
      proposed: :proposed,
      counter: :counter,
      accepted: :accepted,
      rejected: :rejected,
      expired: :expired
    }
  end

  defmodule A2aNegotiationStateValues do
    @moduledoc """
    Typed constants for the `a2a.negotiation.state` attribute.
    """

    @doc "proposed"
    @spec proposed() :: :proposed
    def proposed, do: :proposed

    @doc "counter"
    @spec counter() :: :counter
    def counter, do: :counter

    @doc "accepted"
    @spec accepted() :: :accepted
    def accepted, do: :accepted

    @doc "rejected"
    @spec rejected() :: :rejected
    def rejected, do: :rejected

    @doc "expired"
    @spec expired() :: :expired
    def expired, do: :expired

  end

  @doc """
  Current status of an A2A deal negotiation.

  Attribute: `a2a.negotiation.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pending`, `accepted`
  """
  @spec a2a_negotiation_status() :: :"a2a.negotiation.status"
  def a2a_negotiation_status, do: :"a2a.negotiation.status"

  @doc """
  Enumerated values for `a2a.negotiation.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pending` | `"pending"` | pending |
  | `in_progress` | `"in_progress"` | in_progress |
  | `accepted` | `"accepted"` | accepted |
  | `rejected` | `"rejected"` | rejected |
  | `counter_offer` | `"counter_offer"` | counter_offer |
  | `expired` | `"expired"` | expired |
  | `timeout` | `"timeout"` | timeout |
  """
  @spec a2a_negotiation_status_values() :: %{
    pending: :pending,
    in_progress: :in_progress,
    accepted: :accepted,
    rejected: :rejected,
    counter_offer: :counter_offer,
    expired: :expired,
    timeout: :timeout
  }
  def a2a_negotiation_status_values do
    %{
      pending: :pending,
      in_progress: :in_progress,
      accepted: :accepted,
      rejected: :rejected,
      counter_offer: :counter_offer,
      expired: :expired,
      timeout: :timeout
    }
  end

  defmodule A2aNegotiationStatusValues do
    @moduledoc """
    Typed constants for the `a2a.negotiation.status` attribute.
    """

    @doc "pending"
    @spec pending() :: :pending
    def pending, do: :pending

    @doc "in_progress"
    @spec in_progress() :: :in_progress
    def in_progress, do: :in_progress

    @doc "accepted"
    @spec accepted() :: :accepted
    def accepted, do: :accepted

    @doc "rejected"
    @spec rejected() :: :rejected
    def rejected, do: :rejected

    @doc "counter_offer"
    @spec counter_offer() :: :counter_offer
    def counter_offer, do: :counter_offer

    @doc "expired"
    @spec expired() :: :expired
    def expired, do: :expired

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

  end

  @doc """
  Maximum time allowed for the negotiation round to complete in milliseconds.

  Attribute: `a2a.negotiation.timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5000`, `30000`
  """
  @spec a2a_negotiation_timeout_ms() :: :"a2a.negotiation.timeout_ms"
  def a2a_negotiation_timeout_ms, do: :"a2a.negotiation.timeout_ms"

  @doc """
  The A2A operation name being invoked.

  Attribute: `a2a.operation`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `create_deal`, `query_status`, `dispatch_task`, `get_capabilities`
  """
  @spec a2a_operation() :: :"a2a.operation"
  def a2a_operation, do: :"a2a.operation"

  @doc """
  Monetary or credit penalty amount applied to an agent for contract violation.

  Attribute: `a2a.penalty.amount`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5.0`, `25.5`
  """
  @spec a2a_penalty_amount() :: :"a2a.penalty.amount"
  def a2a_penalty_amount, do: :"a2a.penalty.amount"

  @doc """
  Currency code for the penalty/reward amount (ISO 4217).

  Attribute: `a2a.penalty.currency`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `USD`, `CREDITS`
  """
  @spec a2a_penalty_currency() :: :"a2a.penalty.currency"
  def a2a_penalty_currency, do: :"a2a.penalty.currency"

  @doc """
  Reason for applying a penalty to an agent in the A2A marketplace.

  Attribute: `a2a.penalty.reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sla_violation`, `timeout`
  """
  @spec a2a_penalty_reason() :: :"a2a.penalty.reason"
  def a2a_penalty_reason, do: :"a2a.penalty.reason"

  @doc """
  Enumerated values for `a2a.penalty.reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `sla_violation` | `"sla_violation"` | sla_violation |
  | `quality_failure` | `"quality_failure"` | quality_failure |
  | `timeout` | `"timeout"` | timeout |
  | `fraud` | `"fraud"` | fraud |
  """
  @spec a2a_penalty_reason_values() :: %{
    sla_violation: :sla_violation,
    quality_failure: :quality_failure,
    timeout: :timeout,
    fraud: :fraud
  }
  def a2a_penalty_reason_values do
    %{
      sla_violation: :sla_violation,
      quality_failure: :quality_failure,
      timeout: :timeout,
      fraud: :fraud
    }
  end

  defmodule A2aPenaltyReasonValues do
    @moduledoc """
    Typed constants for the `a2a.penalty.reason` attribute.
    """

    @doc "sla_violation"
    @spec sla_violation() :: :sla_violation
    def sla_violation, do: :sla_violation

    @doc "quality_failure"
    @spec quality_failure() :: :quality_failure
    def quality_failure, do: :quality_failure

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "fraud"
    @spec fraud() :: :fraud
    def fraud, do: :fraud

  end

  @doc """
  Whether the A2A protocol version in use is deprecated.

  Attribute: `a2a.protocol.deprecated`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec a2a_protocol_deprecated() :: :"a2a.protocol.deprecated"
  def a2a_protocol_deprecated, do: :"a2a.protocol.deprecated"

  @doc """
  Minimum A2A protocol version supported by the endpoint.

  Attribute: `a2a.protocol.min_version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0`, `1.1`
  """
  @spec a2a_protocol_min_version() :: :"a2a.protocol.min_version"
  def a2a_protocol_min_version, do: :"a2a.protocol.min_version"

  @doc """
  Time taken to negotiate the A2A protocol version in milliseconds.

  Attribute: `a2a.protocol.negotiation_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `20`, `100`
  """
  @spec a2a_protocol_negotiation_ms() :: :"a2a.protocol.negotiation_ms"
  def a2a_protocol_negotiation_ms, do: :"a2a.protocol.negotiation_ms"

  @doc """
  The A2A protocol version in use for this interaction.

  Attribute: `a2a.protocol.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0`, `1.1`, `2.0`
  """
  @spec a2a_protocol_version() :: :"a2a.protocol.version"
  def a2a_protocol_version, do: :"a2a.protocol.version"

  @doc """
  Current depth of the A2A request queue for the target agent.

  Attribute: `a2a.queue.depth`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `50`
  """
  @spec a2a_queue_depth() :: :"a2a.queue.depth"
  def a2a_queue_depth, do: :"a2a.queue.depth"

  @doc """
  Categorical trust level derived from the reputation score.

  Attribute: `a2a.reputation.category`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `trusted`, `neutral`
  """
  @spec a2a_reputation_category() :: :"a2a.reputation.category"
  def a2a_reputation_category, do: :"a2a.reputation.category"

  @doc """
  Enumerated values for `a2a.reputation.category`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `trusted` | `"trusted"` | trusted |
  | `neutral` | `"neutral"` | neutral |
  | `probation` | `"probation"` | probation |
  | `banned` | `"banned"` | banned |
  """
  @spec a2a_reputation_category_values() :: %{
    trusted: :trusted,
    neutral: :neutral,
    probation: :probation,
    banned: :banned
  }
  def a2a_reputation_category_values do
    %{
      trusted: :trusted,
      neutral: :neutral,
      probation: :probation,
      banned: :banned
    }
  end

  defmodule A2aReputationCategoryValues do
    @moduledoc """
    Typed constants for the `a2a.reputation.category` attribute.
    """

    @doc "trusted"
    @spec trusted() :: :trusted
    def trusted, do: :trusted

    @doc "neutral"
    @spec neutral() :: :neutral
    def neutral, do: :neutral

    @doc "probation"
    @spec probation() :: :probation
    def probation, do: :probation

    @doc "banned"
    @spec banned() :: :banned
    def banned, do: :banned

  end

  @doc """
  The absolute change in reputation score from this decay event (always negative or zero).

  Attribute: `a2a.reputation.decay.delta`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `-0.05`, `-0.1`, `-0.3`
  """
  @spec a2a_reputation_decay_delta() :: :"a2a.reputation.decay.delta"
  def a2a_reputation_decay_delta, do: :"a2a.reputation.decay.delta"

  @doc """
  The rate at which reputation decays per decay trigger event, range [0.0, 1.0].

  Attribute: `a2a.reputation.decay.rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.01`, `0.05`, `0.1`
  """
  @spec a2a_reputation_decay_rate() :: :"a2a.reputation.decay.rate"
  def a2a_reputation_decay_rate, do: :"a2a.reputation.decay.rate"

  @doc """
  The trigger that caused this reputation decay event.

  Attribute: `a2a.reputation.decay.trigger`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `time`, `interaction`, `violation`
  """
  @spec a2a_reputation_decay_trigger() :: :"a2a.reputation.decay.trigger"
  def a2a_reputation_decay_trigger, do: :"a2a.reputation.decay.trigger"

  @doc """
  Enumerated values for `a2a.reputation.decay.trigger`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `time` | `"time"` | time |
  | `interaction` | `"interaction"` | interaction |
  | `violation` | `"violation"` | violation |
  """
  @spec a2a_reputation_decay_trigger_values() :: %{
    time: :time,
    interaction: :interaction,
    violation: :violation
  }
  def a2a_reputation_decay_trigger_values do
    %{
      time: :time,
      interaction: :interaction,
      violation: :violation
    }
  end

  defmodule A2aReputationDecayTriggerValues do
    @moduledoc """
    Typed constants for the `a2a.reputation.decay.trigger` attribute.
    """

    @doc "time"
    @spec time() :: :time
    def time, do: :time

    @doc "interaction"
    @spec interaction() :: :interaction
    def interaction, do: :interaction

    @doc "violation"
    @spec violation() :: :violation
    def violation, do: :violation

  end

  @doc """
  Time-decay factor applied to older interactions in reputation calculation.

  Attribute: `a2a.reputation.decay_factor`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.99`
  """
  @spec a2a_reputation_decay_factor() :: :"a2a.reputation.decay_factor"
  def a2a_reputation_decay_factor, do: :"a2a.reputation.decay_factor"

  @doc """
  Number of past interactions used to compute the reputation score.

  Attribute: `a2a.reputation.history_length`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `50`, `200`
  """
  @spec a2a_reputation_history_length() :: :"a2a.reputation.history_length"
  def a2a_reputation_history_length, do: :"a2a.reputation.history_length"

  @doc """
  Total number of interactions used to compute the reputation score.

  Attribute: `a2a.reputation.interaction_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`
  """
  @spec a2a_reputation_interaction_count() :: :"a2a.reputation.interaction_count"
  def a2a_reputation_interaction_count, do: :"a2a.reputation.interaction_count"

  @doc """
  Agent reputation score in range [0.0, 1.0] based on historical interactions.

  Attribute: `a2a.reputation.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.92`
  """
  @spec a2a_reputation_score() :: :"a2a.reputation.score"
  def a2a_reputation_score, do: :"a2a.reputation.score"

  @doc """
  Number of retry attempts made for this A2A call before success or final failure.

  Attribute: `a2a.retry.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec a2a_retry_count() :: :"a2a.retry.count"
  def a2a_retry_count, do: :"a2a.retry.count"

  @doc """
  Monetary or credit reward amount granted to an agent for exceeding contract terms.

  Attribute: `a2a.reward.amount`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2.0`, `10.0`
  """
  @spec a2a_reward_amount() :: :"a2a.reward.amount"
  def a2a_reward_amount, do: :"a2a.reward.amount"

  @doc """
  The strategy used to route A2A requests to available agents.

  Attribute: `a2a.routing.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `best_match`, `load_balanced`
  """
  @spec a2a_routing_strategy() :: :"a2a.routing.strategy"
  def a2a_routing_strategy, do: :"a2a.routing.strategy"

  @doc """
  Enumerated values for `a2a.routing.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `best_match` | `"best_match"` | best_match |
  | `round_robin` | `"round_robin"` | round_robin |
  | `load_balanced` | `"load_balanced"` | load_balanced |
  | `priority_queue` | `"priority_queue"` | priority_queue |
  """
  @spec a2a_routing_strategy_values() :: %{
    best_match: :best_match,
    round_robin: :round_robin,
    load_balanced: :load_balanced,
    priority_queue: :priority_queue
  }
  def a2a_routing_strategy_values do
    %{
      best_match: :best_match,
      round_robin: :round_robin,
      load_balanced: :load_balanced,
      priority_queue: :priority_queue
    }
  end

  defmodule A2aRoutingStrategyValues do
    @moduledoc """
    Typed constants for the `a2a.routing.strategy` attribute.
    """

    @doc "best_match"
    @spec best_match() :: :best_match
    def best_match, do: :best_match

    @doc "round_robin"
    @spec round_robin() :: :round_robin
    def round_robin, do: :round_robin

    @doc "load_balanced"
    @spec load_balanced() :: :load_balanced
    def load_balanced, do: :load_balanced

    @doc "priority_queue"
    @spec priority_queue() :: :priority_queue
    def priority_queue, do: :priority_queue

  end

  @doc """
  Identifier of the A2A skill being invoked, matching the AgentCard skill list.

  Attribute: `a2a.skill.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pm4py_statistics`, `pm4py_discover_alpha`, `pm4py_conformance_token_replay`
  """
  @spec a2a_skill_id() :: :"a2a.skill.id"
  def a2a_skill_id, do: :"a2a.skill.id"

  @doc """
  Whether the A2A operation violated its SLA deadline.

  Attribute: `a2a.sla.breach`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec a2a_sla_breach() :: :"a2a.sla.breach"
  def a2a_sla_breach, do: :"a2a.sla.breach"

  @doc """
  SLA deadline in milliseconds from request initiation. Exceeding this is an SLA breach.

  Attribute: `a2a.sla.deadline_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `5000`, `30000`
  """
  @spec a2a_sla_deadline_ms() :: :"a2a.sla.deadline_ms"
  def a2a_sla_deadline_ms, do: :"a2a.sla.deadline_ms"

  @doc """
  Actual observed latency for this A2A operation in milliseconds.

  Attribute: `a2a.sla.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `42`, `1500`, `8000`
  """
  @spec a2a_sla_latency_ms() :: :"a2a.sla.latency_ms"
  def a2a_sla_latency_ms, do: :"a2a.sla.latency_ms"

  @doc """
  Number of SLO breaches in evaluation window.

  Attribute: `a2a.slo.breach_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `10`
  """
  @spec a2a_slo_breach_count() :: :"a2a.slo.breach_count"
  def a2a_slo_breach_count, do: :"a2a.slo.breach_count"

  @doc """
  SLO compliance rate [0.0, 1.0] over evaluation window.

  Attribute: `a2a.slo.compliance_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.999`, `0.95`
  """
  @spec a2a_slo_compliance_rate() :: :"a2a.slo.compliance_rate"
  def a2a_slo_compliance_rate, do: :"a2a.slo.compliance_rate"

  @doc """
  Identifier for the service level objective being evaluated.

  Attribute: `a2a.slo.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `slo-latency-p99`, `slo-availability-99.9`
  """
  @spec a2a_slo_id() :: :"a2a.slo.id"
  def a2a_slo_id, do: :"a2a.slo.id"

  @doc """
  Target latency in milliseconds for SLO compliance.

  Attribute: `a2a.slo.target_latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `1000`
  """
  @spec a2a_slo_target_latency_ms() :: :"a2a.slo.target_latency_ms"
  def a2a_slo_target_latency_ms, do: :"a2a.slo.target_latency_ms"

  @doc """
  Service initiating the A2A call (sender).

  Attribute: `a2a.source.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `businessos`, `canopy`
  """
  @spec a2a_source_service() :: :"a2a.source.service"
  def a2a_source_service, do: :"a2a.source.service"

  @doc """
  Service receiving the A2A call (receiver).

  Attribute: `a2a.target.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `businessos`, `canopy`
  """
  @spec a2a_target_service() :: :"a2a.target.service"
  def a2a_target_service, do: :"a2a.target.service"

  @doc """
  Unique identifier for a delegated task in A2A task delegation.

  Attribute: `a2a.task.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `task-abc-123`, `task-mining-456`
  """
  @spec a2a_task_id() :: :"a2a.task.id"
  def a2a_task_id, do: :"a2a.task.id"

  @doc """
  Priority level of a delegated A2A task.

  Attribute: `a2a.task.priority`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `high`, `normal`
  """
  @spec a2a_task_priority() :: :"a2a.task.priority"
  def a2a_task_priority, do: :"a2a.task.priority"

  @doc """
  Enumerated values for `a2a.task.priority`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | critical |
  | `high` | `"high"` | high |
  | `normal` | `"normal"` | normal |
  | `low` | `"low"` | low |
  """
  @spec a2a_task_priority_values() :: %{
    critical: :critical,
    high: :high,
    normal: :normal,
    low: :low
  }
  def a2a_task_priority_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end

  defmodule A2aTaskPriorityValues do
    @moduledoc """
    Typed constants for the `a2a.task.priority` attribute.
    """

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "high"
    @spec high() :: :high
    def high, do: :high

    @doc "normal"
    @spec normal() :: :normal
    def normal, do: :normal

    @doc "low"
    @spec low() :: :low
    def low, do: :low

  end

  @doc """
  Lifecycle state of an A2A task.

  Attribute: `a2a.task.state`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec a2a_task_state() :: :"a2a.task.state"
  def a2a_task_state, do: :"a2a.task.state"

  @doc """
  Enumerated values for `a2a.task.state`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `submitted` | `"submitted"` | Task has been received but work has not started. |
  | `working` | `"working"` | Task is actively being processed. |
  | `completed` | `"completed"` | Task finished successfully. |
  | `failed` | `"failed"` | Task terminated with an error. |
  | `canceled` | `"canceled"` | Task was explicitly canceled. |
  """
  @spec a2a_task_state_values() :: %{
    submitted: :submitted,
    working: :working,
    completed: :completed,
    failed: :failed,
    canceled: :canceled
  }
  def a2a_task_state_values do
    %{
      submitted: :submitted,
      working: :working,
      completed: :completed,
      failed: :failed,
      canceled: :canceled
    }
  end

  defmodule A2aTaskStateValues do
    @moduledoc """
    Typed constants for the `a2a.task.state` attribute.
    """

    @doc "Task has been received but work has not started."
    @spec submitted() :: :submitted
    def submitted, do: :submitted

    @doc "Task is actively being processed."
    @spec working() :: :working
    def working, do: :working

    @doc "Task finished successfully."
    @spec completed() :: :completed
    def completed, do: :completed

    @doc "Task terminated with an error."
    @spec failed() :: :failed
    def failed, do: :failed

    @doc "Task was explicitly canceled."
    @spec canceled() :: :canceled
    def canceled, do: :canceled

  end

  @doc """
  Transport protocol used for the A2A exchange.

  Attribute: `a2a.transport`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec a2a_transport() :: :"a2a.transport"
  def a2a_transport, do: :"a2a.transport"

  @doc """
  Enumerated values for `a2a.transport`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `http` | `"http"` | Standard HTTP JSON-RPC transport. |
  | `websocket` | `"websocket"` | WebSocket streaming transport. |
  """
  @spec a2a_transport_values() :: %{
    http: :http,
    websocket: :websocket
  }
  def a2a_transport_values do
    %{
      http: :http,
      websocket: :websocket
    }
  end

  defmodule A2aTransportValues do
    @moduledoc """
    Typed constants for the `a2a.transport` attribute.
    """

    @doc "Standard HTTP JSON-RPC transport."
    @spec http() :: :http
    def http, do: :http

    @doc "WebSocket streaming transport."
    @spec websocket() :: :websocket
    def websocket, do: :websocket

  end

  @doc """
  Minimum fraction of peers required to reach trust consensus, range [0.0, 1.0].

  Attribute: `a2a.trust.consensus_threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.67`, `0.75`, `1.0`
  """
  @spec a2a_trust_consensus_threshold() :: :"a2a.trust.consensus_threshold"
  def a2a_trust_consensus_threshold, do: :"a2a.trust.consensus_threshold"

  @doc """
  Exponential decay factor applied to historical trust scores, range (0.0, 1.0].

  Attribute: `a2a.trust.decay_factor`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.8`
  """
  @spec a2a_trust_decay_factor() :: :"a2a.trust.decay_factor"
  def a2a_trust_decay_factor, do: :"a2a.trust.decay_factor"

  @doc """
  Current trust epoch — increments on membership change or key rotation.

  Attribute: `a2a.trust.epoch`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `42`, `100`
  """
  @spec a2a_trust_epoch() :: :"a2a.trust.epoch"
  def a2a_trust_epoch, do: :"a2a.trust.epoch"

  @doc """
  Identifier of the federated trust ring this agent belongs to.

  Attribute: `a2a.trust.federation_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `fed-ring-alpha`, `enterprise-trust-01`
  """
  @spec a2a_trust_federation_id() :: :"a2a.trust.federation_id"
  def a2a_trust_federation_id, do: :"a2a.trust.federation_id"

  @doc """
  Number of peer agents in the trust federation.

  Attribute: `a2a.trust.peer_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3`, `7`, `12`
  """
  @spec a2a_trust_peer_count() :: :"a2a.trust.peer_count"
  def a2a_trust_peer_count, do: :"a2a.trust.peer_count"

  @doc """
  Trust score assigned to an agent interaction, range [0.0, 1.0]. Higher is more trusted.

  Attribute: `a2a.trust.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.42`, `1.0`
  """
  @spec a2a_trust_score() :: :"a2a.trust.score"
  def a2a_trust_score, do: :"a2a.trust.score"

  @doc """
  Unix timestamp (milliseconds) when the trust score was last updated.

  Attribute: `a2a.trust.updated_at_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1711320000000`, `1711323600000`
  """
  @spec a2a_trust_updated_at_ms() :: :"a2a.trust.updated_at_ms"
  def a2a_trust_updated_at_ms, do: :"a2a.trust.updated_at_ms"

end