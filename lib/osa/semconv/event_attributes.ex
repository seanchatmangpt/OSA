defmodule OpenTelemetry.SemConv.Incubating.EventAttributes do
  @moduledoc """
  Event semantic convention attributes.

  Namespace: `event`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  ID of the event that directly caused this event (parent-child causality chain).

  Attribute: `event.causation_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `evt-deadbeef01`, `span-4bf92f35`
  """
  @spec event_causation_id() :: :event_causation_id
  def event_causation_id, do: :event_causation_id

  @doc """
  Correlation ID linking related events across distributed services (trace-level grouping).

  Attribute: `event.correlation_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `corr-abc123-x7y`, `req-00f067aa0ba902b7`
  """
  @spec event_correlation_id() :: :event_correlation_id
  def event_correlation_id, do: :event_correlation_id

  @doc """
  Delivery status of the event in the event bus.

  Attribute: `event.delivery.status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `delivered`, `failed`
  """
  @spec event_delivery_status() :: :event_delivery_status
  def event_delivery_status, do: :event_delivery_status

  @doc """
  Enumerated values for `event.delivery.status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `delivered` | `"delivered"` | delivered |
  | `failed` | `"failed"` | failed |
  | `retrying` | `"retrying"` | retrying |
  | `dropped` | `"dropped"` | dropped |
  """
  @spec event_delivery_status_values() :: %{
    delivered: :delivered,
    failed: :failed,
    retrying: :retrying,
    dropped: :dropped
  }
  def event_delivery_status_values do
    %{
      delivered: :delivered,
      failed: :failed,
      retrying: :retrying,
      dropped: :dropped
    }
  end

  defmodule EventDeliveryStatusValues do
    @moduledoc """
    Typed constants for the `event.delivery.status` attribute.
    """

    @doc "delivered"
    @spec delivered() :: :delivered
    def delivered, do: :delivered

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

    @doc "retrying"
    @spec retrying() :: :retrying
    def retrying, do: :retrying

    @doc "dropped"
    @spec dropped() :: :dropped
    def dropped, do: :dropped

  end

  @doc """
  The domain of the structured event.

  Attribute: `event.domain`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent`, `compliance`
  """
  @spec event_domain() :: :event_domain
  def event_domain, do: :event_domain

  @doc """
  Enumerated values for `event.domain`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `agent` | `"agent"` | agent |
  | `compliance` | `"compliance"` | compliance |
  | `healing` | `"healing"` | healing |
  | `workflow` | `"workflow"` | workflow |
  | `system` | `"system"` | system |
  """
  @spec event_domain_values() :: %{
    agent: :agent,
    compliance: :compliance,
    healing: :healing,
    workflow: :workflow,
    system: :system
  }
  def event_domain_values do
    %{
      agent: :agent,
      compliance: :compliance,
      healing: :healing,
      workflow: :workflow,
      system: :system
    }
  end

  defmodule EventDomainValues do
    @moduledoc """
    Typed constants for the `event.domain` attribute.
    """

    @doc "agent"
    @spec agent() :: :agent
    def agent, do: :agent

    @doc "compliance"
    @spec compliance() :: :compliance
    def compliance, do: :compliance

    @doc "healing"
    @spec healing() :: :healing
    def healing, do: :healing

    @doc "workflow"
    @spec workflow() :: :workflow
    def workflow, do: :workflow

    @doc "system"
    @spec system() :: :system
    def system, do: :system

  end

  @doc """
  Number of handlers that received this event.

  Attribute: `event.handler.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `5`
  """
  @spec event_handler_count() :: :event_handler_count
  def event_handler_count, do: :event_handler_count

  @doc """
  The name of the event (e.g., "agent.started", "compliance.violation.detected").

  Attribute: `event.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent.started`, `healing.triggered`, `compliance.violation.detected`
  """
  @spec event_name() :: :event_name
  def event_name, do: :event_name

  @doc """
  Whether this event is a replay of a previously emitted event (idempotency tracking).

  Attribute: `event.replay`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec event_replay() :: :event_replay
  def event_replay, do: :event_replay

  @doc """
  Number of routing filters applied to determine event delivery targets.

  Attribute: `event.routing.filter_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `2`, `5`
  """
  @spec event_routing_filter_count() :: :event_routing_filter_count
  def event_routing_filter_count, do: :event_routing_filter_count

  @doc """
  Routing strategy used to deliver the event to subscribers.

  Attribute: `event.routing.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `broadcast`, `topic_based`
  """
  @spec event_routing_strategy() :: :event_routing_strategy
  def event_routing_strategy, do: :event_routing_strategy

  @doc """
  Enumerated values for `event.routing.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `broadcast` | `"broadcast"` | broadcast |
  | `unicast` | `"unicast"` | unicast |
  | `multicast` | `"multicast"` | multicast |
  | `topic_based` | `"topic_based"` | topic_based |
  | `content_based` | `"content_based"` | content_based |
  """
  @spec event_routing_strategy_values() :: %{
    broadcast: :broadcast,
    unicast: :unicast,
    multicast: :multicast,
    topic_based: :topic_based,
    content_based: :content_based
  }
  def event_routing_strategy_values do
    %{
      broadcast: :broadcast,
      unicast: :unicast,
      multicast: :multicast,
      topic_based: :topic_based,
      content_based: :content_based
    }
  end

  defmodule EventRoutingStrategyValues do
    @moduledoc """
    Typed constants for the `event.routing.strategy` attribute.
    """

    @doc "broadcast"
    @spec broadcast() :: :broadcast
    def broadcast, do: :broadcast

    @doc "unicast"
    @spec unicast() :: :unicast
    def unicast, do: :unicast

    @doc "multicast"
    @spec multicast() :: :multicast
    def multicast, do: :multicast

    @doc "topic_based"
    @spec topic_based() :: :topic_based
    def topic_based, do: :topic_based

    @doc "content_based"
    @spec content_based() :: :content_based
    def content_based, do: :content_based

  end

  @doc """
  Schema version of the event payload (for schema evolution tracking).

  Attribute: `event.schema.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0`, `2.3`, `3.0-rc1`
  """
  @spec event_schema_version() :: :event_schema_version
  def event_schema_version, do: :event_schema_version

  @doc """
  The severity level of the event.

  Attribute: `event.severity`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `info`, `error`
  """
  @spec event_severity() :: :event_severity
  def event_severity, do: :event_severity

  @doc """
  Enumerated values for `event.severity`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `debug` | `"debug"` | debug |
  | `info` | `"info"` | info |
  | `warn` | `"warn"` | warn |
  | `error` | `"error"` | error |
  | `fatal` | `"fatal"` | fatal |
  """
  @spec event_severity_values() :: %{
    debug: :debug,
    info: :info,
    warn: :warn,
    error: :error,
    fatal: :fatal
  }
  def event_severity_values do
    %{
      debug: :debug,
      info: :info,
      warn: :warn,
      error: :error,
      fatal: :fatal
    }
  end

  defmodule EventSeverityValues do
    @moduledoc """
    Typed constants for the `event.severity` attribute.
    """

    @doc "debug"
    @spec debug() :: :debug
    def debug, do: :debug

    @doc "info"
    @spec info() :: :info
    def info, do: :info

    @doc "warn"
    @spec warn() :: :warn
    def warn, do: :warn

    @doc "error"
    @spec error() :: :error
    def error, do: :error

    @doc "fatal"
    @spec fatal() :: :fatal
    def fatal, do: :fatal

  end

  @doc """
  The source component that emitted the event.

  Attribute: `event.source`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa.healing`, `businessos.compliance`, `canopy.heartbeat`
  """
  @spec event_source() :: :event_source
  def event_source, do: :event_source

  @doc """
  Service that emitted this event (e.g., osa, businessos, canopy).

  Attribute: `event.source.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `businessos`, `canopy`, `pm4py-rust`
  """
  @spec event_source_service() :: :event_source_service
  def event_source_service, do: :event_source_service

  @doc """
  Number of subscribers that received the event.

  Attribute: `event.subscriber.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `100`
  """
  @spec event_subscriber_count() :: :event_subscriber_count
  def event_subscriber_count, do: :event_subscriber_count

  @doc """
  Service that is the intended consumer of this event.

  Attribute: `event.target.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `businessos`, `canopy`
  """
  @spec event_target_service() :: :event_target_service
  def event_target_service, do: :event_target_service

  @doc """
  Schema version of the event payload for forward-compatibility tracking.

  Attribute: `event.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0`, `2.3.1`
  """
  @spec event_version() :: :event_version
  def event_version, do: :event_version

end