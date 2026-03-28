defmodule OpenTelemetry.SemConv.Incubating.DecisionAttributes do
  @moduledoc """
  Decision semantic convention attributes.

  Namespace: `decision`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  JSON-encoded result of the Groq workflow decision (e.g. action, confidence).

  Attribute: `decision.result`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `{"action":"launch_case","confidence":0.95}`
  """
  @spec decision_result() :: :"decision.result"
  def decision_result, do: :"decision.result"

  @doc """
  The YAWL Workflow Control-flow Pattern identifier that the Groq decision targets.

  Attribute: `decision.wcp_pattern`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `WCP01`, `WCP02`, `WCP04`
  """
  @spec decision_wcp_pattern() :: :"decision.wcp_pattern"
  def decision_wcp_pattern, do: :"decision.wcp_pattern"

end