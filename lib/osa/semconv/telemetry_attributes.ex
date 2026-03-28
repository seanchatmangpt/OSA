defmodule OpenTelemetry.SemConv.Incubating.TelemetryAttributes do
  @moduledoc """
  Telemetry semantic convention attributes.

  Namespace: `telemetry`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Programming language of OpenTelemetry SDK.

  Attribute: `telemetry.sdk.language`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `erlang`, `rust`, `go`, `python`
  """
  @spec telemetry_sdk_language() :: :telemetry_sdk_language
  def telemetry_sdk_language, do: :telemetry_sdk_language

  @doc """
  OpenTelemetry SDK name.

  Attribute: `telemetry.sdk.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `opentelemetry`
  """
  @spec telemetry_sdk_name() :: :telemetry_sdk_name
  def telemetry_sdk_name, do: :telemetry_sdk_name

  @doc """
  Version of OpenTelemetry SDK.

  Attribute: `telemetry.sdk.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.7.0`, `0.20.0`
  """
  @spec telemetry_sdk_version() :: :telemetry_sdk_version
  def telemetry_sdk_version, do: :telemetry_sdk_version

end