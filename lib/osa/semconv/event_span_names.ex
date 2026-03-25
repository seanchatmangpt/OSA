defmodule OpenTelemetry.SemConv.Incubating.EventSpanNames do
  @moduledoc """
  Event semantic convention span names.

  Namespace: `event`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Event correlation — linking multiple events into a causal chain for distributed tracing.

  Span: `span.event.correlate`
  Kind: `internal`
  Stability: `development`
  """
  @spec event_correlate() :: String.t()
  def event_correlate, do: "event.correlate"

  @doc """
  Delivering an event to registered handlers in the event bus.

  Span: `span.event.deliver`
  Kind: `internal`
  Stability: `development`
  """
  @spec event_deliver() :: String.t()
  def event_deliver, do: "event.deliver"

  @doc """
  Emission of a structured log event to the event bus.

  Span: `span.event.emit`
  Kind: `producer`
  Stability: `development`
  """
  @spec event_emit() :: String.t()
  def event_emit, do: "event.emit"

  @doc """
  Processing of a received structured log event from the bus.

  Span: `span.event.process`
  Kind: `consumer`
  Stability: `development`
  """
  @spec event_process() :: String.t()
  def event_process, do: "event.process"

  @doc """
  Event replay — re-processing a previously emitted event for recovery or audit.

  Span: `span.event.replay`
  Kind: `internal`
  Stability: `development`
  """
  @spec event_replay() :: String.t()
  def event_replay, do: "event.replay"

  @doc """
  Routing an event to subscribers based on routing strategy and filters.

  Span: `span.event.route`
  Kind: `internal`
  Stability: `development`
  """
  @spec event_route() :: String.t()
  def event_route, do: "event.route"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      event_correlate(),
      event_deliver(),
      event_emit(),
      event_process(),
      event_replay(),
      event_route()
    ]
  end
end