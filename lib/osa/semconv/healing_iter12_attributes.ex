defmodule OpenTelemetry.SemConv.HealingIter12Attributes do
  @moduledoc "Healing MTTR and escalation semantic convention attributes (iter12)."

  @spec healing_mttr_ms :: :"healing.mttr_ms"
  def healing_mttr_ms, do: :"healing.mttr_ms"

  @spec healing_escalation_level :: :"healing.escalation.level"
  def healing_escalation_level, do: :"healing.escalation.level"

  @spec healing_repair_strategy :: :"healing.repair.strategy"
  def healing_repair_strategy, do: :"healing.repair.strategy"

  @spec healing_attempt :: :"healing.attempt"
  def healing_attempt, do: :"healing.attempt"
end
