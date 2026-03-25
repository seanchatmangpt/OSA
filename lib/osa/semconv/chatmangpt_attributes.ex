defmodule OpenTelemetry.SemConv.Incubating.ChatmangptAttributes do
  @moduledoc """
  Chatmangpt semantic convention attributes.

  Namespace: `chatmangpt`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Unique identifier of the agent processing the operation.

  Attribute: `chatmangpt.agent.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent-healing-1`, `agent-consensus-2`, `osa-primary`
  """
  @spec chatmangpt_agent_id() :: :"chatmangpt.agent.id"
  def chatmangpt_agent_id, do: :"chatmangpt.agent.id"

  @doc """
  Whether the operation exceeded its time budget.

  Attribute: `chatmangpt.budget.exceeded`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `false`, `true`
  """
  @spec chatmangpt_budget_exceeded() :: :"chatmangpt.budget.exceeded"
  def chatmangpt_budget_exceeded, do: :"chatmangpt.budget.exceeded"

  @doc """
  Time budget allocated for the operation in milliseconds.

  Attribute: `chatmangpt.budget.time_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `5000`, `30000`
  """
  @spec chatmangpt_budget_time_ms() :: :"chatmangpt.budget.time_ms"
  def chatmangpt_budget_time_ms, do: :"chatmangpt.budget.time_ms"

  @doc """
  Priority tier of the operation, used for budget enforcement.

  Attribute: `chatmangpt.service.tier`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `normal`
  """
  @spec chatmangpt_service_tier() :: :"chatmangpt.service.tier"
  def chatmangpt_service_tier, do: :"chatmangpt.service.tier"

  @doc """
  Enumerated values for `chatmangpt.service.tier`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | Critical priority tier — highest resource budget |
  | `high` | `"high"` | High priority tier |
  | `normal` | `"normal"` | Normal priority tier |
  | `low` | `"low"` | Low priority tier — lowest resource budget |
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

  defmodule ChatmangptServiceTierValues do
    @moduledoc """
    Typed constants for the `chatmangpt.service.tier` attribute.
    """

    @doc "Critical priority tier — highest resource budget"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "High priority tier"
    @spec high() :: :high
    def high, do: :high

    @doc "Normal priority tier"
    @spec normal() :: :normal
    def normal, do: :normal

    @doc "Low priority tier — lowest resource budget"
    @spec low() :: :low
    def low, do: :low

  end

end