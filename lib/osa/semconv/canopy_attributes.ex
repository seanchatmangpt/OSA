defmodule OpenTelemetry.SemConv.Incubating.CanopyAttributes do
  @moduledoc """
  Canopy semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Action performed by the Canopy adapter.

  Stability: `development`
  """
  @spec canopy_adapter_action() :: :"canopy.adapter.action"
  def canopy_adapter_action, do: :"canopy.adapter.action"

  @doc """
  Name of the Canopy adapter being invoked.

  Stability: `development`
  """
  @spec canopy_adapter_name() :: :"canopy.adapter.name"
  def canopy_adapter_name, do: :"canopy.adapter.name"

  @doc """
  Time budget allocated for the Canopy operation in milliseconds.

  Stability: `development`
  """
  @spec canopy_budget_ms() :: :"canopy.budget.ms"
  def canopy_budget_ms, do: :"canopy.budget.ms"

  @doc """
  Priority tier of the heartbeat dispatch.

  Stability: `development`
  """
  @spec canopy_heartbeat_tier() :: :"canopy.heartbeat.tier"
  def canopy_heartbeat_tier, do: :"canopy.heartbeat.tier"

  @doc """
  Values for `canopy.heartbeat.tier`.
  """
  @spec canopy_heartbeat_tier_values() :: %{
    critical: :critical,
    high: :high,
    normal: :normal,
    low: :low
  }
  def canopy_heartbeat_tier_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end
end