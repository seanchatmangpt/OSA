defmodule OpenTelemetry.SemConv.ChatmangptIter16Attributes do
  @moduledoc "Wave 9 Iteration 16: ChatmanGPT Session attributes."

  def chatmangpt_session_id, do: :"chatmangpt.session.id"
  def chatmangpt_session_token_count, do: :"chatmangpt.session.token_count"
  def chatmangpt_session_model_switches, do: :"chatmangpt.session.model_switches"
  def chatmangpt_session_turn_count, do: :"chatmangpt.session.turn_count"
end
