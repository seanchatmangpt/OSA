defmodule OpenTelemetry.SemConv.Incubating.ConsensusAttributes do
  @moduledoc """
  Consensus semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Latency of the consensus round in milliseconds.

  Stability: `development`
  """
  @spec consensus_latency_ms() :: :"consensus.latency_ms"
  def consensus_latency_ms, do: :"consensus.latency_ms"

  @doc """
  Identifier of the consensus node.

  Stability: `development`
  """
  @spec consensus_node_id() :: :"consensus.node_id"
  def consensus_node_id, do: :"consensus.node_id"

  @doc """
  Required quorum size for the consensus round.

  Stability: `development`
  """
  @spec consensus_quorum_size() :: :"consensus.quorum_size"
  def consensus_quorum_size, do: :"consensus.quorum_size"

  @doc """
  The round number within the BFT consensus protocol.

  Stability: `development`
  """
  @spec consensus_round_num() :: :"consensus.round_num"
  def consensus_round_num, do: :"consensus.round_num"

  @doc """
  Phase of the BFT consensus round.

  Stability: `development`
  """
  @spec consensus_round_type() :: :"consensus.round_type"
  def consensus_round_type, do: :"consensus.round_type"

  @doc """
  Values for `consensus.round_type`.
  """
  @spec consensus_round_type_values() :: %{
    prepare: :prepare,
    promise: :promise,
    accept: :accept,
    learn: :learn
  }
  def consensus_round_type_values do
    %{
      prepare: :prepare,
      promise: :promise,
      accept: :accept,
      learn: :learn
    }
  end
end