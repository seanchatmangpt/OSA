defmodule OpenTelemetry.SemConv.HealingIter13Attributes do
  @moduledoc "Healing cascade detection semantic convention attributes (iter13)."
  def healing_cascade_detected, do: :"healing.cascade.detected"
  def healing_cascade_depth, do: :"healing.cascade.depth"
  def healing_root_cause_id, do: :"healing.root_cause.id"
end
