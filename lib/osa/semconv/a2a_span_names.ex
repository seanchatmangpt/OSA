defmodule OpenTelemetry.SemConv.Incubating.A2aSpanNames do
  @moduledoc """
  A2a semantic convention span names.

  Namespace: `a2a`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Span emitted when the agent card endpoint is served.

  Span: `span.a2a.agent_card.serve`
  Kind: `server`
  Stability: `development`
  """
  @spec a2a_agent_card_serve() :: String.t()
  def a2a_agent_card_serve, do: "a2a.agent_card.serve"

  @doc """
  Running an A2A capability auction — agents bid for task allocation based on capability and cost.

  Span: `span.a2a.auction.run`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_auction_run() :: String.t()
  def a2a_auction_run, do: "a2a.auction.run"

  @doc """
  Bid evaluation — scoring and ranking agent bids to select the best provider for a task.

  Span: `span.a2a.bid.evaluate`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_bid_evaluate() :: String.t()
  def a2a_bid_evaluate, do: "a2a.bid.evaluate"

  @doc """
  An agent-to-agent call — one ChatmanGPT service invoking another via the A2A protocol.

  Span: `span.a2a.call`
  Kind: `client`
  Stability: `development`
  """
  @spec a2a_call() :: String.t()
  def a2a_call, do: "a2a.call"

  @doc """
  Matching a capability request to available agents — selecting best provider.

  Span: `span.a2a.capability.match`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_capability_match() :: String.t()
  def a2a_capability_match, do: "a2a.capability.match"

  @doc """
  Capability negotiation between two A2A agents — determining what capabilities can be fulfilled.

  Span: `span.a2a.capability.negotiate`
  Kind: `client`
  Stability: `development`
  """
  @spec a2a_capability_negotiate() :: String.t()
  def a2a_capability_negotiate, do: "a2a.capability.negotiate"

  @doc """
  Registration of an agent capability in the A2A capability registry.

  Span: `span.a2a.capability.register`
  Kind: `server`
  Stability: `development`
  """
  @spec a2a_capability_register() :: String.t()
  def a2a_capability_register, do: "a2a.capability.register"

  @doc """
  Contract amendment — negotiating a modification to an existing A2A service contract.

  Span: `span.a2a.contract.amend`
  Kind: `client`
  Stability: `development`
  """
  @spec a2a_contract_amend() :: String.t()
  def a2a_contract_amend, do: "a2a.contract.amend"

  @doc """
  Initiating or updating an A2A contract dispute between agents.

  Span: `span.a2a.contract.dispute`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_contract_dispute() :: String.t()
  def a2a_contract_dispute, do: "a2a.contract.dispute"

  @doc """
  Execution of an A2A service contract — running contract obligations and tracking progress toward completion.

  Span: `span.a2a.contract.execute`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_contract_execute() :: String.t()
  def a2a_contract_execute, do: "a2a.contract.execute"

  @doc """
  Negotiation of an A2A service contract — establishing terms, SLA, and obligations between two agents.

  Span: `span.a2a.contract.negotiate`
  Kind: `client`
  Stability: `development`
  """
  @spec a2a_contract_negotiate() :: String.t()
  def a2a_contract_negotiate, do: "a2a.contract.negotiate"

  @doc """
  Creation of an A2A deal between two agents.

  Span: `span.a2a.create_deal`
  Kind: `server`
  Stability: `development`
  """
  @spec a2a_create_deal() :: String.t()
  def a2a_create_deal, do: "a2a.create_deal"

  @doc """
  Status transition of an A2A deal through its lifecycle (pending → active → completed).

  Span: `span.a2a.deal.status_transition`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_deal_status_transition() :: String.t()
  def a2a_deal_status_transition, do: "a2a.deal.status_transition"

  @doc """
  Resolution of an A2A dispute between agents — arbitration and settlement process.

  Span: `span.a2a.dispute.resolve`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_dispute_resolve() :: String.t()
  def a2a_dispute_resolve, do: "a2a.dispute.resolve"

  @doc """
  A2A escrow creation — establishing a payment escrow for a deal between two agents.

  Span: `span.a2a.escrow.create`
  Kind: `server`
  Stability: `development`
  """
  @spec a2a_escrow_create() :: String.t()
  def a2a_escrow_create, do: "a2a.escrow.create"

  @doc """
  A2A escrow release — settling a payment escrow upon deal completion or dispute resolution.

  Span: `span.a2a.escrow.release`
  Kind: `server`
  Stability: `development`
  """
  @spec a2a_escrow_release() :: String.t()
  def a2a_escrow_release, do: "a2a.escrow.release"

  @doc """
  Transfer of knowledge or capability data between agents via A2A.

  Span: `span.a2a.knowledge.transfer`
  Kind: `producer`
  Stability: `development`
  """
  @spec a2a_knowledge_transfer() :: String.t()
  def a2a_knowledge_transfer, do: "a2a.knowledge.transfer"

  @doc """
  Batched delivery of multiple A2A messages — aggregates messages for efficient transport.

  Span: `span.a2a.message.batch`
  Kind: `producer`
  Stability: `development`
  """
  @spec a2a_message_batch() :: String.t()
  def a2a_message_batch, do: "a2a.message.batch"

  @doc """
  Span emitted when an A2A agent receives an incoming message.

  Span: `span.a2a.message.receive`
  Kind: `server`
  Stability: `development`
  """
  @spec a2a_message_receive() :: String.t()
  def a2a_message_receive, do: "a2a.message.receive"

  @doc """
  Routing of an A2A message to the appropriate target agent based on priority and routing rules.

  Span: `span.a2a.message.route`
  Kind: `producer`
  Stability: `development`
  """
  @spec a2a_message_route() :: String.t()
  def a2a_message_route, do: "a2a.message.route"

  @doc """
  Multi-round deal negotiation between two agents.

  Span: `span.a2a.negotiate`
  Kind: `client`
  Stability: `development`
  """
  @spec a2a_negotiate() :: String.t()
  def a2a_negotiate, do: "a2a.negotiate"

  @doc """
  State machine transition in an A2A multi-round negotiation protocol.

  Span: `span.a2a.negotiation.state_transition`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_negotiation_state_transition() :: String.t()
  def a2a_negotiation_state_transition, do: "a2a.negotiation.state_transition"

  @doc """
  Applying a penalty or reward to an agent based on contract performance — updates trust score and balance.

  Span: `span.a2a.penalty.apply`
  Kind: `server`
  Stability: `development`
  """
  @spec a2a_penalty_apply() :: String.t()
  def a2a_penalty_apply, do: "a2a.penalty.apply"

  @doc """
  A2A protocol version negotiation between two agents — determining compatible protocol version.

  Span: `span.a2a.protocol.negotiate`
  Kind: `client`
  Stability: `development`
  """
  @spec a2a_protocol_negotiate() :: String.t()
  def a2a_protocol_negotiate, do: "a2a.protocol.negotiate"

  @doc """
  A2A reputation decay event — applying time-based or violation-triggered reputation score reduction.

  Span: `span.a2a.reputation.decay`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_reputation_decay() :: String.t()
  def a2a_reputation_decay, do: "a2a.reputation.decay"

  @doc """
  Updating an agent's reputation score based on the outcome of a completed interaction.

  Span: `span.a2a.reputation.update`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_reputation_update() :: String.t()
  def a2a_reputation_update, do: "a2a.reputation.update"

  @doc """
  Span emitted when an A2A agent dispatches a skill for execution.

  Span: `span.a2a.skill.invoke`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_skill_invoke() :: String.t()
  def a2a_skill_invoke, do: "a2a.skill.invoke"

  @doc """
  SLA validation for an A2A operation — measures actual latency against deadline.

  Span: `span.a2a.sla.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_sla_check() :: String.t()
  def a2a_sla_check, do: "a2a.sla.check"

  @doc """
  SLO evaluation — assessing whether A2A operation met service level objectives.

  Span: `span.a2a.slo.evaluate`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_slo_evaluate() :: String.t()
  def a2a_slo_evaluate, do: "a2a.slo.evaluate"

  @doc """
  Span emitted when an A2A task reaches a terminal state (completed or failed).

  Span: `span.a2a.task.complete`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_task_complete() :: String.t()
  def a2a_task_complete, do: "a2a.task.complete"

  @doc """
  Span emitted when an A2A task is created via tasks/send.

  Span: `span.a2a.task.create`
  Kind: `server`
  Stability: `development`
  """
  @spec a2a_task_create() :: String.t()
  def a2a_task_create, do: "a2a.task.create"

  @doc """
  Delegation of a task from one agent to another via A2A.

  Span: `span.a2a.task.delegate`
  Kind: `producer`
  Stability: `development`
  """
  @spec a2a_task_delegate() :: String.t()
  def a2a_task_delegate, do: "a2a.task.delegate"

  @doc """
  Span emitted when an A2A task state transitions (e.g., submitted→working).

  Span: `span.a2a.task.update`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_task_update() :: String.t()
  def a2a_task_update, do: "a2a.task.update"

  @doc """
  Evaluation of an agent's trust score based on reputation history and interaction outcomes.

  Span: `span.a2a.trust.evaluate`
  Kind: `internal`
  Stability: `development`
  """
  @spec a2a_trust_evaluate() :: String.t()
  def a2a_trust_evaluate, do: "a2a.trust.evaluate"

  @doc """
  Federated trust evaluation — agent joins or queries a trust ring for cross-federation capability authorization.

  Span: `span.a2a.trust.federate`
  Kind: `client`
  Stability: `development`
  """
  @spec a2a_trust_federate() :: String.t()
  def a2a_trust_federate, do: "a2a.trust.federate"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      a2a_agent_card_serve(),
      a2a_auction_run(),
      a2a_bid_evaluate(),
      a2a_call(),
      a2a_capability_match(),
      a2a_capability_negotiate(),
      a2a_capability_register(),
      a2a_contract_amend(),
      a2a_contract_dispute(),
      a2a_contract_execute(),
      a2a_contract_negotiate(),
      a2a_create_deal(),
      a2a_deal_status_transition(),
      a2a_dispute_resolve(),
      a2a_escrow_create(),
      a2a_escrow_release(),
      a2a_knowledge_transfer(),
      a2a_message_batch(),
      a2a_message_receive(),
      a2a_message_route(),
      a2a_negotiate(),
      a2a_negotiation_state_transition(),
      a2a_penalty_apply(),
      a2a_protocol_negotiate(),
      a2a_reputation_decay(),
      a2a_reputation_update(),
      a2a_skill_invoke(),
      a2a_sla_check(),
      a2a_slo_evaluate(),
      a2a_task_complete(),
      a2a_task_create(),
      a2a_task_delegate(),
      a2a_task_update(),
      a2a_trust_evaluate(),
      a2a_trust_federate()
    ]
  end
end