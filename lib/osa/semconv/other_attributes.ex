defmodule OpenTelemetry.SemConv.Incubating.OtherAttributes do
  @moduledoc """
  Other semantic convention attributes.

  Namespace: `other`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  The diagnosis mode or classification strategy used (e.g., deterministic, probabilistic).

  Attribute: `diagnosis_mode`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `deterministic`, `probabilistic`, `adaptive`
  """
  @spec diagnosis_mode() :: :"diagnosis_mode"
  def diagnosis_mode, do: :"diagnosis_mode"

  @doc """
  Execution time in milliseconds for healing operation.

  Attribute: `execution_time_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `2000`
  """
  @spec execution_time_ms() :: :"execution_time_ms"
  def execution_time_ms, do: :"execution_time_ms"

  @doc """
  Number of tests that failed.

  Attribute: `failed_tests`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec failed_tests() :: :"failed_tests"
  def failed_tests, do: :"failed_tests"

  @doc """
  Outcome of the healing fix operation.

  Attribute: `fix_result`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `success`, `partial`, `failed`
  """
  @spec fix_result() :: :"fix_result"
  def fix_result, do: :"fix_result"

  @doc """
  Enumerated values for `fix_result`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `success` | `"success"` | success |
  | `partial` | `"partial"` | partial |
  | `failed` | `"failed"` | failed |
  """
  @spec fix_result_values() :: %{
    success: :success,
    partial: :partial,
    failed: :failed
  }
  def fix_result_values do
    %{
      success: :success,
      partial: :partial,
      failed: :failed
    }
  end

  defmodule FixResultValues do
    @moduledoc """
    Typed constants for the `fix_result` attribute.
    """

    @doc "success"
    @spec success() :: :success
    def success, do: :success

    @doc "partial"
    @spec partial() :: :partial
    def partial, do: :partial

    @doc "failed"
    @spec failed() :: :failed
    def failed, do: :failed

  end

  @doc """
  Node identifier or name.

  Attribute: `node`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `node-1`, `primary`, `replica`
  """
  @spec node() :: :"node"
  def node, do: :"node"

  @doc """
  Number of tests that passed.

  Attribute: `passed_tests`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `5`, `10`
  """
  @spec passed_tests() :: :"passed_tests"
  def passed_tests, do: :"passed_tests"

  @doc """
  Consensus round number.

  Attribute: `round_num`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `100`
  """
  @spec round_num() :: :"round_num"
  def round_num, do: :"round_num"

  @doc """
  Timestamp in milliseconds since Unix epoch.

  Attribute: `timestamp`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1645123456789`, `1645123457000`
  """
  @spec timestamp() :: :"timestamp"
  def timestamp, do: :"timestamp"

  @doc """
  Tool identifier or name.

  Attribute: `tool`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `calculator`, `search`, `api`
  """
  @spec tool() :: :"tool"
  def tool, do: :"tool"

  @doc """
  Verification status.

  Attribute: `verification_status`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `pass`, `fail`
  """
  @spec verification_status() :: :"verification_status"
  def verification_status, do: :"verification_status"

  @doc """
  Enumerated values for `verification_status`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `pass` | `"pass"` | pass |
  | `fail` | `"fail"` | fail |
  """
  @spec verification_status_values() :: %{
    pass: :pass,
    fail: :fail
  }
  def verification_status_values do
    %{
      pass: :pass,
      fail: :fail
    }
  end

  defmodule VerificationStatusValues do
    @moduledoc """
    Typed constants for the `verification_status` attribute.
    """

    @doc "pass"
    @spec pass() :: :pass
    def pass, do: :pass

    @doc "fail"
    @spec fail() :: :fail
    def fail, do: :fail

  end

  @doc """
  Version identifier or string.

  Attribute: `version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0.0`, `v1`, `latest`
  """
  @spec version() :: :"version"
  def version, do: :"version"

end