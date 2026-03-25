defmodule OpenTelemetry.SemConv.HealingIter14Attributes do
  @moduledoc "Healing pattern library semantic convention attributes (iter14)."

  @spec healing_pattern_id :: :"healing.pattern.id"
  def healing_pattern_id, do: :"healing.pattern.id"

  @spec healing_pattern_library_size :: :"healing.pattern.library_size"
  def healing_pattern_library_size, do: :"healing.pattern.library_size"

  @spec healing_pattern_match_confidence :: :"healing.pattern.match_confidence"
  def healing_pattern_match_confidence, do: :"healing.pattern.match_confidence"
end
