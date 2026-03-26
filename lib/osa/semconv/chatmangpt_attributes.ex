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
  Deployment environment for this ChatmanGPT instance.

  Attribute: `chatmangpt.deployment`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `development`, `production`
  """
  @spec chatmangpt_deployment() :: :"chatmangpt.deployment"
  def chatmangpt_deployment, do: :"chatmangpt.deployment"

  @doc """
  Enumerated values for `chatmangpt.deployment`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `development` | `"development"` | development |
  | `staging` | `"staging"` | staging |
  | `production` | `"production"` | production |
  """
  @spec chatmangpt_deployment_values() :: %{
    development: :development,
    staging: :staging,
    production: :production
  }
  def chatmangpt_deployment_values do
    %{
      development: :development,
      staging: :staging,
      production: :production
    }
  end

  defmodule ChatmangptDeploymentValues do
    @moduledoc """
    Typed constants for the `chatmangpt.deployment` attribute.
    """

    @doc "development"
    @spec development() :: :development
    def development, do: :development

    @doc "staging"
    @spec staging() :: :staging
    def staging, do: :staging

    @doc "production"
    @spec production() :: :production
    def production, do: :production

  end

  @doc """
  Shared identifier for a single Weaver live-check or CI run so spans across projects (OSA, Canopy, BusinessOS, pm4py-rust) can be filtered as one audit story.


  Attribute: `chatmangpt.run.correlation_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `550e8400-e29b-41d4-a716-446655440000`, `20260326T120000Z-abc123`
  """
  @spec chatmangpt_run_correlation_id() :: :"chatmangpt.run.correlation_id"
  def chatmangpt_run_correlation_id, do: :"chatmangpt.run.correlation_id"

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

  @doc """
  Unique identifier for the ChatmanGPT session.

  Attribute: `chatmangpt.session.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sess-abc123`, `sess-def456`
  """
  @spec chatmangpt_session_id() :: :"chatmangpt.session.id"
  def chatmangpt_session_id, do: :"chatmangpt.session.id"

  @doc """
  Number of times the model was switched during the session.

  Attribute: `chatmangpt.session.model_switches`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `2`, `5`
  """
  @spec chatmangpt_session_model_switches() :: :"chatmangpt.session.model_switches"
  def chatmangpt_session_model_switches, do: :"chatmangpt.session.model_switches"

  @doc """
  Total tokens consumed in the session so far.

  Attribute: `chatmangpt.session.token_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1024`, `4096`
  """
  @spec chatmangpt_session_token_count() :: :"chatmangpt.session.token_count"
  def chatmangpt_session_token_count, do: :"chatmangpt.session.token_count"

  @doc """
  Number of conversation turns in the session.

  Attribute: `chatmangpt.session.turn_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `10`, `50`
  """
  @spec chatmangpt_session_turn_count() :: :"chatmangpt.session.turn_count"
  def chatmangpt_session_turn_count, do: :"chatmangpt.session.turn_count"

  @doc """
  Version of the ChatmanGPT system emitting this telemetry.

  Attribute: `chatmangpt.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0.0`, `2.3.1-wave9`
  """
  @spec chatmangpt_version() :: :"chatmangpt.version"
  def chatmangpt_version, do: :"chatmangpt.version"

  @doc """
  Wave number of the ChatmanGPT development phase that produced this span.

  Attribute: `chatmangpt.wave`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `7`, `8`, `9`
  """
  @spec chatmangpt_wave() :: :"chatmangpt.wave"
  def chatmangpt_wave, do: :"chatmangpt.wave"

end