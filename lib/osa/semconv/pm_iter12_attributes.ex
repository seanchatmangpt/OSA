defmodule OpenTelemetry.SemConv.PmIter12Attributes do
  @moduledoc "Process mining streaming semantic convention attributes (iter12)."

  @spec pm_streaming_window_size :: :"process_mining.streaming.window_size"
  def pm_streaming_window_size, do: :"process_mining.streaming.window_size"

  @spec pm_streaming_lag_ms :: :"process_mining.streaming.lag_ms"
  def pm_streaming_lag_ms, do: :"process_mining.streaming.lag_ms"

  @spec pm_drift_detected :: :"process_mining.drift.detected"
  def pm_drift_detected, do: :"process_mining.drift.detected"

  @spec pm_drift_severity :: :"process_mining.drift.severity"
  def pm_drift_severity, do: :"process_mining.drift.severity"
end
