defmodule OpenTelemetry.SemConv.Incubating.WorkflowAttributes do
  @moduledoc """
  Workflow semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  Workflow engine executing the workflow.

  Stability: `development`
  """
  @spec workflow_engine() :: :"workflow.engine"
  def workflow_engine, do: :"workflow.engine"

  @doc """
  Values for `workflow.engine`.
  """
  @spec workflow_engine_values() :: %{
    canopy: :canopy,
    yawl: :yawl,
    business_os: :business_os
  }
  def workflow_engine_values do
    %{
      canopy: :canopy,
      yawl: :yawl,
      business_os: :business_os
    }
  end

  @doc """
  Unique identifier for the workflow instance.

  Stability: `development`
  """
  @spec workflow_id() :: :"workflow.id"
  def workflow_id, do: :"workflow.id"

  @doc """
  Human-readable name of the workflow definition.

  Stability: `development`
  """
  @spec workflow_name() :: :"workflow.name"
  def workflow_name, do: :"workflow.name"

  @doc """
  YAWL workflow control-flow pattern applied in this step.

  Stability: `development`
  """
  @spec workflow_pattern() :: :"workflow.pattern"
  def workflow_pattern, do: :"workflow.pattern"

  @doc """
  Values for `workflow.pattern`.
  """
  @spec workflow_pattern_values() :: %{
    sequence: :sequence,
    parallel_split: :parallel_split,
    synchronization: :synchronization,
    exclusive_choice: :exclusive_choice,
    multi_choice: :multi_choice,
    structured_loop: :structured_loop,
    deferred_choice: :deferred_choice,
    milestone: :milestone
  }
  def workflow_pattern_values do
    %{
      sequence: :sequence,
      parallel_split: :parallel_split,
      synchronization: :synchronization,
      exclusive_choice: :exclusive_choice,
      multi_choice: :multi_choice,
      structured_loop: :structured_loop,
      deferred_choice: :deferred_choice,
      milestone: :milestone
    }
  end

  @doc """
  Execution state of the workflow instance.

  Stability: `development`
  """
  @spec workflow_state() :: :"workflow.state"
  def workflow_state, do: :"workflow.state"

  @doc """
  Values for `workflow.state`.
  """
  @spec workflow_state_values() :: %{
    pending: :pending,
    active: :active,
    completed: :completed,
    failed: :failed,
    cancelled: :cancelled,
    suspended: :suspended
  }
  def workflow_state_values do
    %{
      pending: :pending,
      active: :active,
      completed: :completed,
      failed: :failed,
      cancelled: :cancelled,
      suspended: :suspended
    }
  end

  @doc """
  The current step or activity name within the workflow.

  Stability: `development`
  """
  @spec workflow_step() :: :"workflow.step"
  def workflow_step, do: :"workflow.step"

  @doc """
  Total number of steps completed so far in the workflow.

  Stability: `development`
  """
  @spec workflow_step_count() :: :"workflow.step_count"
  def workflow_step_count, do: :"workflow.step_count"
end