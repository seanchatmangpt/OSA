defmodule OpenTelemetry.SemConv.Incubating.BoardAttributes do
  @moduledoc """
  Board semantic convention attributes.

  Namespace: `board`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Conway score [0.0-1.0]: boundary handoff time / total cycle time

  Attribute: `board.conway_score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.4`, `0.72`
  """
  @spec board_conway_score() :: :"board.conway_score"
  def board_conway_score, do: :"board.conway_score"

  @doc """
  Number of departments with Conway violations detected

  Attribute: `board.conway_violation_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec board_conway_violation_count() :: :"board.conway_violation_count"
  def board_conway_violation_count, do: :"board.conway_violation_count"

  @doc """
  Type of board escalation emitted

  Attribute: `board.escalation_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `conway_violation`
  """
  @spec board_escalation_type() :: :"board.escalation_type"
  def board_escalation_type, do: :"board.escalation_type"

  @doc """
  Enumerated values for `board.escalation_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `conway_violation` | `"conway_violation"` | Structural org boundary bottleneck requiring board decision |
  """
  @spec board_escalation_type_values() :: %{
    conway_violation: :conway_violation
  }
  def board_escalation_type_values do
    %{
      conway_violation: :conway_violation
    }
  end

  defmodule BoardEscalationTypeValues do
    @moduledoc """
    Typed constants for the `board.escalation_type` attribute.
    """

    @doc "Structural org boundary bottleneck requiring board decision"
    @spec conway_violation() :: :conway_violation
    def conway_violation, do: :conway_violation

  end

  @doc """
  Number of board escalation events emitted this check

  Attribute: `board.escalations_emitted`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`
  """
  @spec board_escalations_emitted() :: :"board.escalations_emitted"
  def board_escalations_emitted, do: :"board.escalations_emitted"

  @doc """
  Whether the briefing includes the STRUCTURAL DECISIONS REQUIRED section

  Attribute: `board.has_structural_issues`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec board_has_structural_issues() :: :"board.has_structural_issues"
  def board_has_structural_issues, do: :"board.has_structural_issues"

  @doc """
  Number of conformance_violation healing events emitted

  Attribute: `board.healings_triggered`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `2`
  """
  @spec board_healings_triggered() :: :"board.healings_triggered"
  def board_healings_triggered, do: :"board.healings_triggered"

  @doc """
  Whether a Conway violation was detected (boundary time > 40% of cycle time)

  Attribute: `board.is_violation`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec board_is_violation() :: :"board.is_violation"
  def board_is_violation, do: :"board.is_violation"

  @doc """
  Number of departments with Little's Law queue violations

  Attribute: `board.littles_law_alert_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `2`, `5`
  """
  @spec board_littles_law_alert_count() :: :"board.littles_law_alert_count"
  def board_littles_law_alert_count, do: :"board.littles_law_alert_count"

  @doc """
  Department or process identifier being checked

  Attribute: `board.process_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `Engineering`, `Sales`, `Operations`, `Finance`
  """
  @spec board_process_id() :: :"board.process_id"
  def board_process_id, do: :"board.process_id"

  @doc """
  Number of sections in the board briefing (5 standard + 1 if Conway violations)

  Attribute: `board.section_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `6`
  """
  @spec board_section_count() :: :"board.section_count"
  def board_section_count, do: :"board.section_count"

  @doc """
  Count of Conway violations requiring board decision

  Attribute: `board.structural_issue_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `2`
  """
  @spec board_structural_issue_count() :: :"board.structural_issue_count"
  def board_structural_issue_count, do: :"board.structural_issue_count"

end