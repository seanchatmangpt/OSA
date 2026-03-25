defmodule OpenTelemetry.SemConv.Incubating.A2aAttributes do
  @moduledoc """
  A2a semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Identifier of the target agent in an A2A call.

  Stability: `development`
  """
  @spec a2a_agent_id() :: :"a2a.agent.id"
  def a2a_agent_id, do: :"a2a.agent.id"

  @doc """
  Identifier of the deal being created or operated on via A2A.

  Stability: `development`
  """
  @spec a2a_deal_id() :: :"a2a.deal.id"
  def a2a_deal_id, do: :"a2a.deal.id"

  @doc """
  Type of the A2A deal.

  Stability: `development`
  """
  @spec a2a_deal_type() :: :"a2a.deal.type"
  def a2a_deal_type, do: :"a2a.deal.type"

  @doc """
  The A2A operation name being invoked.

  Stability: `development`
  """
  @spec a2a_operation() :: :"a2a.operation"
  def a2a_operation, do: :"a2a.operation"

  @doc """
  Service initiating the A2A call (sender).

  Stability: `development`
  """
  @spec a2a_source_service() :: :"a2a.source.service"
  def a2a_source_service, do: :"a2a.source.service"

  @doc """
  Service receiving the A2A call (receiver).

  Stability: `development`
  """
  @spec a2a_target_service() :: :"a2a.target.service"
  def a2a_target_service, do: :"a2a.target.service"
end