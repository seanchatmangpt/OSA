defmodule OpenTelemetry.SemConv.Incubating.AgentAttributes do
  @moduledoc """
  Agent semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Type of decision made by the agent in the ReAct loop.

  Stability: `development`
  """
  @spec agent_decision_type() :: :"agent.decision_type"
  def agent_decision_type, do: :"agent.decision_type"

  @doc """
  Unique identifier of the agent.

  Stability: `development`
  """
  @spec agent_id() :: :"agent.id"
  def agent_id, do: :"agent.id"

  @doc """
  The LLM model used for agent inference.

  Stability: `development`
  """
  @spec agent_llm_model() :: :"agent.llm_model"
  def agent_llm_model, do: :"agent.llm_model"

  @doc """
  Outcome of the agent decision.

  Stability: `development`
  """
  @spec agent_outcome() :: :"agent.outcome"
  def agent_outcome, do: :"agent.outcome"

  @doc """
  Values for `agent.outcome`.
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

  @doc """
  Total token count for the agent inference.

  Stability: `development`
  """
  @spec agent_token_count() :: :"agent.token_count"
  def agent_token_count, do: :"agent.token_count"
end