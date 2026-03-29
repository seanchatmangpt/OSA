defmodule OpenTelemetry.SemConv.Incubating.GroqSpanNames do
  @moduledoc """
   Bridges the Groq response to a YAWL workflow action (launch_case, start_workitem, complete_workitem, checkpoint) semantic convention span names.

  Namespace: `groq`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Span for a Groq LLM call that produces a YAWL workflow routing decision. Bridges the Groq response to a YAWL workflow action (launch_case, start_workitem, complete_workitem, checkpoint). The decision.wcp_pattern identifies which WCP pattern the LLM decision is targeting.


  Span: `span.groq.workflow.decision`
  Kind: `client`
  Stability: `development`
  """
  @spec groq_workflow_decision() :: String.t()
  def groq_workflow_decision, do: "groq.workflow.decision"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      groq_workflow_decision()
    ]
  end
end