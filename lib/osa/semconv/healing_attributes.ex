defmodule OpenTelemetry.SemConv.Incubating.HealingAttributes do
  @moduledoc """
  Healing semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Identifier of the OSA agent that owns the healing operation.

  Stability: `development`
  """
  @spec healing_agent_id() :: :"healing.agent_id"
  def healing_agent_id, do: :"healing.agent_id"

  @doc """
  Confidence score for the failure mode classification, in range [0.0, 1.0].

  Stability: `development`
  """
  @spec healing_confidence() :: :"healing.confidence"
  def healing_confidence, do: :"healing.confidence"

  @doc """
  The classified failure mode detected by the healing diagnosis engine.

  Stability: `development`
  """
  @spec healing_failure_mode() :: :"healing.failure_mode"
  def healing_failure_mode, do: :"healing.failure_mode"

  @doc """
  Values for `healing.failure_mode`.
  """
  @spec healing_failure_mode_values() :: %{
    deadlock: :deadlock,
    timeout: :timeout,
    race_condition: :race_condition,
    memory_leak: :memory_leak,
    cascading_failure: :cascading_failure,
    stagnation: :stagnation,
    livelock: :livelock
  }
  def healing_failure_mode_values do
    %{
      deadlock: :deadlock,
      timeout: :timeout,
      race_condition: :race_condition,
      memory_leak: :memory_leak,
      cascading_failure: :cascading_failure,
      stagnation: :stagnation,
      livelock: :livelock
    }
  end

  @doc """
  Mean time to recovery in milliseconds for the healing operation.

  Stability: `development`
  """
  @spec healing_mttr_ms() :: :"healing.mttr_ms"
  def healing_mttr_ms, do: :"healing.mttr_ms"

  @doc """
  The recovery action taken by the reflex arc.

  Stability: `development`
  """
  @spec healing_recovery_action() :: :"healing.recovery_action"
  def healing_recovery_action, do: :"healing.recovery_action"

  @doc """
  The named reflex arc triggered during healing.

  Stability: `development`
  """
  @spec healing_reflex_arc() :: :"healing.reflex_arc"
  def healing_reflex_arc, do: :"healing.reflex_arc"
end