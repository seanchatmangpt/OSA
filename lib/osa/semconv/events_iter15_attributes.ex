defmodule OpenTelemetry.SemConv.EventsIter15Attributes do
  @moduledoc "Event Routing and Signal Quality semantic convention attributes (iter15)."

  @spec event_routing_strategy :: :"event.routing.strategy"
  def event_routing_strategy, do: :"event.routing.strategy"

  @spec event_routing_filter_count :: :"event.routing.filter_count"
  def event_routing_filter_count, do: :"event.routing.filter_count"

  @spec event_subscriber_count :: :"event.subscriber.count"
  def event_subscriber_count, do: :"event.subscriber.count"

  @spec signal_quality_score :: :"signal.quality.score"
  def signal_quality_score, do: :"signal.quality.score"
end
