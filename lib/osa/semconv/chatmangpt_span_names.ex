defmodule OpenTelemetry.SemConv.Incubating.ChatmangptSpanNames do
  @moduledoc """
  Chatmangpt semantic convention span names.

  Namespace: `chatmangpt`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Tracks a ChatmanGPT session — lifecycle from start to end with token and turn accounting.

  Span: `span.chatmangpt.session.track`
  Kind: `internal`
  Stability: `development`
  """
  @spec chatmangpt_session_track() :: String.t()
  def chatmangpt_session_track, do: "chatmangpt.session.track"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      chatmangpt_session_track()
    ]
  end
end