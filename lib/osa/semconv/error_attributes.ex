defmodule OpenTelemetry.SemConv.Incubating.ErrorAttributes do
  @moduledoc """
  Error semantic convention attributes.

  Namespace: `error`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Describes a class of error the operation ended with.

  Attribute: `error.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `timeout`, `java.net.UnknownHostException`, `server_certificate_invalid`, `500`
  """
  @spec error_type() :: :error_type
  def error_type, do: :error_type

  @doc """
  Enumerated values for `error.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `timeout` | `"timeout"` | timeout |
  | `cancelled` | `"cancelled"` | cancelled |
  | `internal` | `"internal"` | internal |
  | `unavailable` | `"unavailable"` | unavailable |
  """
  @spec error_type_values() :: %{
    timeout: :timeout,
    cancelled: :cancelled,
    internal: :internal,
    unavailable: :unavailable
  }
  def error_type_values do
    %{
      timeout: :timeout,
      cancelled: :cancelled,
      internal: :internal,
      unavailable: :unavailable
    }
  end

  defmodule ErrorTypeValues do
    @moduledoc """
    Typed constants for the `error.type` attribute.
    """

    @doc "timeout"
    @spec timeout() :: :timeout
    def timeout, do: :timeout

    @doc "cancelled"
    @spec cancelled() :: :cancelled
    def cancelled, do: :cancelled

    @doc "internal"
    @spec internal() :: :internal
    def internal, do: :internal

    @doc "unavailable"
    @spec unavailable() :: :unavailable
    def unavailable, do: :unavailable

  end

end