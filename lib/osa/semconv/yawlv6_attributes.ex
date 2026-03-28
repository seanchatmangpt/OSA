defmodule OpenTelemetry.SemConv.Incubating.Yawlv6Attributes do
  @moduledoc """
  Yawlv6 semantic convention attributes.

  Namespace: `yawlv6`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Number of YAWLv6 modules with passing tests during checkpoint execution.

  Attribute: `yawlv6.modules_complete`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `1`, `2`, `3`
  """
  @spec yawlv6_modules_complete() :: :yawlv6_modules_complete
  def yawlv6_modules_complete, do: :yawlv6_modules_complete

  @doc """
  Number of YAWLv6 tests that failed during checkpoint execution.

  Attribute: `yawlv6.tests_failed`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `0`, `2`, `5`
  """
  @spec yawlv6_tests_failed() :: :yawlv6_tests_failed
  def yawlv6_tests_failed, do: :yawlv6_tests_failed

  @doc """
  Number of YAWLv6 tests that passed during checkpoint execution.

  Attribute: `yawlv6.tests_passed`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `100`, `150`, `191`
  """
  @spec yawlv6_tests_passed() :: :yawlv6_tests_passed
  def yawlv6_tests_passed, do: :yawlv6_tests_passed

end