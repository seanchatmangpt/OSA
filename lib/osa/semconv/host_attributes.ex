defmodule OpenTelemetry.SemConv.Incubating.HostAttributes do
  @moduledoc """
  Host semantic convention attributes.

  Namespace: `host`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Hardware architecture of the host.

  Attribute: `host.arch`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `amd64`, `arm64`, `x86_64`
  """
  @spec host_arch() :: :"host.arch"
  def host_arch, do: :"host.arch"

  @doc """
  Hostname of the system.

  Attribute: `host.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `localhost`, `prod-server-01`
  """
  @spec host_name() :: :"host.name"
  def host_name, do: :"host.name"

end