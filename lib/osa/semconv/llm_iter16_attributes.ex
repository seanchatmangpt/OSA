defmodule OpenTelemetry.SemConv.LLMIter16Attributes do
  @moduledoc "Wave 9 Iteration 16: LLM Streaming attributes."

  def llm_streaming_chunk_count, do: :"llm.streaming.chunk_count"
  def llm_streaming_first_token_ms, do: :"llm.streaming.first_token_ms"
  def llm_streaming_tokens_per_second, do: :"llm.streaming.tokens_per_second"
end
