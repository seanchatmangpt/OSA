defmodule OpenTelemetry.SemConv.Incubating.ErrorAttributes do
  @moduledoc """
  Error semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Describes a class of error the operation ended with.

  Stability: `development`
  """
  @spec error_type() :: :"error.type"
  def error_type, do: :"error.type"

  @doc """
  Values for `error.type`.
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
end