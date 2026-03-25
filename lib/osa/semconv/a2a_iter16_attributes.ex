defmodule OpenTelemetry.SemConv.A2AIter16Attributes do
  @moduledoc "Wave 9 Iteration 16: A2A Message Routing attributes."

  def a2a_message_priority, do: :"a2a.message.priority"
  def a2a_message_size_bytes, do: :"a2a.message.size_bytes"
  def a2a_message_encoding, do: :"a2a.message.encoding"
  def a2a_message_ttl_ms, do: :"a2a.message.ttl_ms"
end
