defmodule OpenTelemetry.SemConv.HealingIter16Attributes do
  @moduledoc "Wave 9 Iteration 16: Healing Prediction attributes."

  def healing_prediction_horizon_ms, do: :"healing.prediction.horizon_ms"
  def healing_prediction_confidence, do: :"healing.prediction.confidence"
  def healing_prediction_model, do: :"healing.prediction.model"
end
