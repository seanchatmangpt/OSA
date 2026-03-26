defmodule OpenTelemetry.SemConv.Incubating.ServiceAttributes do
  @moduledoc """
  Service semantic convention attributes.

  Namespace: `service`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Name of the service.

  Attribute: `service.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pm4py-rust`, `businessos`, `osa`, `canopy`
  """
  @spec service_name() :: :"service.name"
  def service_name, do: :"service.name"

  @doc """
  Namespace of the service.

  Attribute: `service.namespace`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `chatmangpt`, `miosa`
  """
  @spec service_namespace() :: :"service.namespace"
  def service_namespace, do: :"service.namespace"

  @doc """
  Version of the service.

  Attribute: `service.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0.0`, `v2026.3.27`
  """
  @spec service_version() :: :"service.version"
  def service_version, do: :"service.version"

end