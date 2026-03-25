defmodule OpenTelemetry.SemConv.Incubating.EventAttributes do
  @moduledoc """
  Event semantic convention attributes.

  Namespace: `event`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Correlation ID linking related events across services.

  Attribute: `event.correlation_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `corr-abc-123`, `flow-xyz-789`
  """
  @spec event_correlation_id() :: :"event.correlation_id"
  def event_correlation_id, do: :"event.correlation_id"

  @doc """
  The domain of the structured event.

  Attribute: `event.domain`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent`, `compliance`
  """
  @spec event_domain() :: :"event.domain"
  def event_domain, do: :"event.domain"

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
  The name of the event (e.g., "agent.started", "compliance.violation.detected").

  Attribute: `event.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `agent.started`, `healing.triggered`, `compliance.violation.detected`
  """
  @spec event_name() :: :"event.name"
  def event_name, do: :"event.name"

  @doc """
  The severity level of the event.

  Attribute: `event.severity`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `info`, `error`
  """
  @spec event_severity() :: :"event.severity"
  def event_severity, do: :"event.severity"

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
  @spec event_source() :: :"event.source"
  def event_source, do: :"event.source"

  # === Wave 9 Iteration 9: Event Correlation ===

  @doc """
  ID of the event that caused this event (parent event in causal chain).

  Attribute: `event.causation_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `cause-abc-001`, `parent-event-xyz`
  """
  @spec event_causation_id() :: :"event.causation_id"
  def event_causation_id, do: :"event.causation_id"

  @doc """
  Schema version of the event payload.

  Attribute: `event.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0`, `2.3`
  """
  @spec event_version() :: :"event.version"
  def event_version, do: :"event.version"

  @doc """
  Service that is the source of this event.

  Attribute: `event.source.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `businessos`, `canopy`
  """
  @spec event_source_service() :: :"event.source.service"
  def event_source_service, do: :"event.source.service"

  @doc """
  Service that is the intended target/consumer of this event.

  Attribute: `event.target.service`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa`, `businessos`, `canopy`
  """
  @spec event_target_service() :: :"event.target.service"
  def event_target_service, do: :"event.target.service"

  @doc """
  Whether this event is a replay of a previously emitted event.

  Attribute: `event.replay`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec event_replay() :: :"event.replay"
  def event_replay, do: :"event.replay"

end