defmodule OpenTelemetry.SemConv.Incubating.ChatmangptAttributes do
  @moduledoc """
  Chatmangpt semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Unique identifier of the agent processing the operation.

  Stability: `development`
  """
  @spec chatmangpt_agent_id() :: :"chatmangpt.agent.id"
  def chatmangpt_agent_id, do: :"chatmangpt.agent.id"

  @doc """
  Whether the operation exceeded its time budget.

  Stability: `development`
  """
  @spec chatmangpt_budget_exceeded() :: :"chatmangpt.budget.exceeded"
  def chatmangpt_budget_exceeded, do: :"chatmangpt.budget.exceeded"

  @doc """
  Time budget allocated for the operation in milliseconds.

  Stability: `development`
  """
  @spec chatmangpt_budget_time_ms() :: :"chatmangpt.budget.time_ms"
  def chatmangpt_budget_time_ms, do: :"chatmangpt.budget.time_ms"

  @doc """
  Priority tier of the operation, used for budget enforcement.

  Stability: `development`
  """
  @spec chatmangpt_service_tier() :: :"chatmangpt.service.tier"
  def chatmangpt_service_tier, do: :"chatmangpt.service.tier"

  @doc """
  Values for `chatmangpt.service.tier`.
  """
  @spec chatmangpt_service_tier_values() :: %{
    critical: :critical,
    high: :high,
    normal: :normal,
    low: :low
  }
  def chatmangpt_service_tier_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end
end