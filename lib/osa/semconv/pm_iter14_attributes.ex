defmodule OpenTelemetry.SemConv.PmIter14Attributes do
  @moduledoc "Process Mining simulation semantic convention attributes (iter14)."

  @spec process_mining_simulation_cases :: :"process_mining.simulation.cases"
  def process_mining_simulation_cases, do: :"process_mining.simulation.cases"

  @spec process_mining_simulation_noise_rate :: :"process_mining.simulation.noise_rate"
  def process_mining_simulation_noise_rate, do: :"process_mining.simulation.noise_rate"

  @spec process_mining_simulation_duration_ms :: :"process_mining.simulation.duration_ms"
  def process_mining_simulation_duration_ms, do: :"process_mining.simulation.duration_ms"

  @spec process_mining_replay_token_count :: :"process_mining.replay.token_count"
  def process_mining_replay_token_count, do: :"process_mining.replay.token_count"
end
