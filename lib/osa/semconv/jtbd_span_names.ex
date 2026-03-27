defmodule OpenTelemetry.SemConv.Incubating.JtbdSpanNames do
  @moduledoc """
  Jtbd semantic convention span names.

  Namespace: `jtbd`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  A complete iteration of a 10-scenario JTBD loop execution across ChatmanGPT integration chain.

  Span: `span.jtbd.loop`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_loop() :: String.t()
  def jtbd_loop, do: "jtbd.loop"

  @doc """
  A single step in a JTBD (Jobs-to-be-Done) scenario execution across ChatmanGPT systems.

  Span: `span.jtbd.scenario`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_scenario() :: String.t()
  def jtbd_scenario, do: "jtbd.scenario"

  @doc """
  A JTBD scenario step for closing and signing contracts with blockchain validation.

  Span: `span.jtbd.scenario.contract_closure`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_scenario_contract_closure() :: String.t()
  def jtbd_scenario_contract_closure, do: "jtbd.scenario.contract_closure"

  @doc """
  A JTBD scenario step for progressing deals through CRM pipeline stages.

  Span: `span.jtbd.scenario.deal_progression`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_scenario_deal_progression() :: String.t()
  def jtbd_scenario_deal_progression, do: "jtbd.scenario.deal_progression"

  @doc """
  A JTBD scenario step for ICP (Ideal Customer Profile) qualification in RevOps workflows.

  Span: `span.jtbd.scenario.icp_qualification`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_scenario_icp_qualification() :: String.t()
  def jtbd_scenario_icp_qualification, do: "jtbd.scenario.icp_qualification"

  @doc """
  A JTBD scenario step for executing multi-step outreach sequences in RevOps.

  Span: `span.jtbd.scenario.outreach_sequence_execution`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_scenario_outreach_sequence_execution() :: String.t()
  def jtbd_scenario_outreach_sequence_execution, do: "jtbd.scenario.outreach_sequence_execution"

  @doc """
  A JTBD scenario step for executing natural language queries against process intelligence engine.

  Span: `span.jtbd.scenario.process_intelligence_query`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_scenario_process_intelligence_query() :: String.t()
  def jtbd_scenario_process_intelligence_query, do: "jtbd.scenario.process_intelligence_query"

  @doc """
  A JTBD scenario step for assessing Java 26 retrofit complexity.

  Span: `span.jtbd.scenario.retrofit_complexity_scoring`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_scenario_retrofit_complexity_scoring() :: String.t()
  def jtbd_scenario_retrofit_complexity_scoring, do: "jtbd.scenario.retrofit_complexity_scoring"

  @doc """
  DMAIC phase transition in a JTBD Wave 12 scenario — tracks each step through
  the Define/Measure/Analyze/Improve/Control cycle.

  Span: `span.jtbd.dmaic.phase`
  Kind: `internal`
  Stability: `development`
  """
  @spec jtbd_dmaic_phase() :: String.t()
  def jtbd_dmaic_phase, do: "jtbd.dmaic.phase"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      jtbd_loop(),
      jtbd_scenario(),
      jtbd_scenario_contract_closure(),
      jtbd_scenario_deal_progression(),
      jtbd_scenario_icp_qualification(),
      jtbd_scenario_outreach_sequence_execution(),
      jtbd_scenario_process_intelligence_query(),
      jtbd_scenario_retrofit_complexity_scoring(),
      jtbd_dmaic_phase()
    ]
  end
end