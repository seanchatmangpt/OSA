defmodule OpenTelemetry.SemConv.Incubating.BoardSpanNames do
  @moduledoc """
  Board semantic convention span names.

  Namespace: `board`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Board chair briefing rendered from L3 intelligence data

  Span: `span.board.briefing_render`
  Kind: `internal`
  Stability: `development`
  """
  @spec board_briefing_render() :: String.t()
  def board_briefing_render, do: "board.briefing_render"

  @doc """
  Conway's Law violation check for a department process

  Span: `span.board.conway_check`
  Kind: `internal`
  Stability: `development`
  """
  @spec board_conway_check() :: String.t()
  def board_conway_check, do: "board.conway_check"

  @doc """
  Periodic Conway + Little's Law monitoring check summary

  Span: `span.board.conway_check_summary`
  Kind: `internal`
  Stability: `development`
  """
  @spec board_conway_check_summary() :: String.t()
  def board_conway_check_summary, do: "board.conway_check_summary"

  @doc """
  Board KPIs computed from process mining event log

  Span: `span.board.kpi_compute`
  Kind: `internal`
  Stability: `development`
  """
  @spec board_kpi_compute() :: String.t()
  def board_kpi_compute, do: "board.kpi_compute"

  @doc """
  Periodic L0 sync — exports BusinessOS cases and handoffs to Oxigraph as RDF facts via bos CLI.

  Span: `span.board.l0_sync`
  Kind: `internal`
  Stability: `development`
  """
  @spec board_l0_sync() :: String.t()
  def board_l0_sync, do: "board.l0_sync"

  @doc """
  Board escalation emitted for a structural (Conway) violation

  Span: `span.board.structural_escalation`
  Kind: `internal`
  Stability: `development`
  """
  @spec board_structural_escalation() :: String.t()
  def board_structural_escalation, do: "board.structural_escalation"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      board_briefing_render(),
      board_conway_check(),
      board_conway_check_summary(),
      board_kpi_compute(),
      board_l0_sync(),
      board_structural_escalation()
    ]
  end
end