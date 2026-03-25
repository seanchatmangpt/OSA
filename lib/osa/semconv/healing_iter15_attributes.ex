defmodule OpenTelemetry.SemConv.HealingIter15Attributes do
  @moduledoc "Healing Self-Healing semantic convention attributes (iter15)."

  @spec healing_self_healing_trigger_count :: :"healing.self_healing.trigger_count"
  def healing_self_healing_trigger_count, do: :"healing.self_healing.trigger_count"

  @spec healing_self_healing_success_rate :: :"healing.self_healing.success_rate"
  def healing_self_healing_success_rate, do: :"healing.self_healing.success_rate"

  @spec healing_intervention_type :: :"healing.intervention.type"
  def healing_intervention_type, do: :"healing.intervention.type"

  @spec healing_self_healing_enabled :: :"healing.self_healing.enabled"
  def healing_self_healing_enabled, do: :"healing.self_healing.enabled"
end
