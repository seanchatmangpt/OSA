defmodule OpenTelemetry.SemConv.Incubating.ProcessAttributes do
  @moduledoc """
  Process semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Name of the process activity (event class) from the XES log.

  Stability: `development`
  """
  @spec process_mining_activity() :: :"process.mining.activity"
  def process_mining_activity, do: :"process.mining.activity"

  @doc """
  Process discovery algorithm used.

  Stability: `development`
  """
  @spec process_mining_algorithm() :: :"process.mining.algorithm"
  def process_mining_algorithm, do: :"process.mining.algorithm"

  @doc """
  Values for `process.mining.algorithm`.
  """
  @spec process_mining_algorithm_values() :: %{
    alpha_miner: :alpha_miner,
    inductive_miner: :inductive_miner,
    heuristics_miner: :heuristics_miner
  }
  def process_mining_algorithm_values do
    %{
      alpha_miner: :alpha_miner,
      inductive_miner: :inductive_miner,
      heuristics_miner: :heuristics_miner
    }
  end

  @doc """
  Number of events in the process trace.

  Stability: `development`
  """
  @spec process_mining_event_count() :: :"process.mining.event_count"
  def process_mining_event_count, do: :"process.mining.event_count"

  @doc """
  File path or identifier of the XES event log being mined.

  Stability: `development`
  """
  @spec process_mining_log_path() :: :"process.mining.log_path"
  def process_mining_log_path, do: :"process.mining.log_path"

  @doc """
  Identifier of the process trace from the XES event log.

  Stability: `development`
  """
  @spec process_mining_trace_id() :: :"process.mining.trace_id"
  def process_mining_trace_id, do: :"process.mining.trace_id"
end