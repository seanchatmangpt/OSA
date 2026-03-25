defmodule OpenTelemetry.SemConv.Incubating.AgentAttributes do
  @moduledoc """
  Agent semantic convention attributes.

  Namespace: `agent`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Type of decision made by the agent in the ReAct loop.

  Attribute: `agent.decision_type`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `tool_call`, `observation`, `final_answer`, `escalate`
  """
  @spec agent_decision_type() :: :"agent.decision_type"
  def agent_decision_type, do: :"agent.decision_type"

  @doc """
  Unique identifier of the agent.

  Attribute: `agent.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent-1`, `osa-react-agent`, `healing-agent-1`
  """
  @spec agent_id() :: :"agent.id"
  def agent_id, do: :"agent.id"

  @doc """
  The LLM model used for agent inference.

  Attribute: `agent.llm_model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-sonnet-4-6`, `claude-haiku-4-5`
  """
  @spec agent_llm_model() :: :"agent.llm_model"
  def agent_llm_model, do: :"agent.llm_model"

  @doc """
  Outcome of the agent decision.

  Attribute: `agent.outcome`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `success`, `failure`, `escalated`
  """
  @spec agent_outcome() :: :"agent.outcome"
  def agent_outcome, do: :"agent.outcome"

  @doc """
  Enumerated values for `agent.outcome`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `success` | `"success"` | success |
  | `failure` | `"failure"` | failure |
  | `escalated` | `"escalated"` | escalated |
  """
  @spec agent_outcome_values() :: %{
    success: :success,
    failure: :failure,
    escalated: :escalated
  }
  def agent_outcome_values do
    %{
      success: :success,
      failure: :failure,
      escalated: :escalated
    }
  end

  defmodule AgentOutcomeValues do
    @moduledoc """
    Typed constants for the `agent.outcome` attribute.
    """

    @doc "success"
    @spec success() :: :success
    def success, do: :success

    @doc "failure"
    @spec failure() :: :failure
    def failure, do: :failure

    @doc "escalated"
    @spec escalated() :: :escalated
    def escalated, do: :escalated

  end

  @doc """
  Total token count for the agent inference.

  Attribute: `agent.token_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `256`, `1024`, `4096`
  """
  @spec agent_token_count() :: :"agent.token_count"
  def agent_token_count, do: :"agent.token_count"

end