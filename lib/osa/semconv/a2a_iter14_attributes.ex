defmodule OpenTelemetry.SemConv.A2AIter14Attributes do
  @moduledoc "A2A Trust semantic convention attributes (iter14)."

  @spec a2a_trust_score :: :"a2a.trust.score"
  def a2a_trust_score, do: :"a2a.trust.score"

  @spec a2a_reputation_history_length :: :"a2a.reputation.history_length"
  def a2a_reputation_history_length, do: :"a2a.reputation.history_length"

  @spec a2a_trust_decay_factor :: :"a2a.trust.decay_factor"
  def a2a_trust_decay_factor, do: :"a2a.trust.decay_factor"

  @spec a2a_trust_updated_at_ms :: :"a2a.trust.updated_at_ms"
  def a2a_trust_updated_at_ms, do: :"a2a.trust.updated_at_ms"
end
