defmodule OpenTelemetry.SemConv.Incubating.WorkflowSpanNames do
  @moduledoc """
  Workflow semantic convention span names.

  Namespace: `workflow`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Cancellation of a workflow region — all in-flight activities in region halted.

  Span: `span.workflow.cancel_region`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_cancel_region() :: String.t()
  def workflow_cancel_region, do: "workflow.cancel_region"

  @doc """
  Critical section execution — ensures atomic sequential execution of enclosed activities.

  Span: `span.workflow.critical_section`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_critical_section() :: String.t()
  def workflow_critical_section, do: "workflow.critical_section"

  @doc """
  Deferred exclusive choice — decision deferred until first branch fires.

  Span: `span.workflow.deferred_choice`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_deferred_choice() :: String.t()
  def workflow_deferred_choice, do: "workflow.deferred_choice"

  @doc """
  N-out-of-M join evaluation — fires when N of M branches complete.

  Span: `span.workflow.discriminator`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_discriminator() :: String.t()
  def workflow_discriminator, do: "workflow.discriminator"

  @doc """
  Exclusive choice pattern (WP-4) — XOR split, exactly one branch is selected based on condition.

  Span: `span.workflow.exclusive_choice`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_exclusive_choice() :: String.t()
  def workflow_exclusive_choice, do: "workflow.exclusive_choice"

  @doc """
  Execution of a single workflow step or activity in the YAWL workflow engine.

  Span: `span.workflow.execute`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_execute() :: String.t()
  def workflow_execute, do: "workflow.execute"

  @doc """
  Interleaved routing execution — activities in a set run one at a time in arbitrary order.

  Span: `span.workflow.interleaved_routing`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_interleaved_routing() :: String.t()
  def workflow_interleaved_routing, do: "workflow.interleaved_routing"

  @doc """
  Milestone gate check — execution blocked until milestone condition met.

  Span: `span.workflow.milestone`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_milestone() :: String.t()
  def workflow_milestone, do: "workflow.milestone"

  @doc """
  Multi-choice pattern (WP-6) — one or more branches selected based on runtime conditions.

  Span: `span.workflow.multi_choice`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_multi_choice() :: String.t()
  def workflow_multi_choice, do: "workflow.multi_choice"

  @doc """
  Multi-instance activity execution — N parallel instances of same activity.

  Span: `span.workflow.multi_instance`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_multi_instance() :: String.t()
  def workflow_multi_instance, do: "workflow.multi_instance"

  @doc """
  Parallel split pattern (WP-2) — single thread of control splits into N concurrent branches.

  Span: `span.workflow.parallel_split`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_parallel_split() :: String.t()
  def workflow_parallel_split, do: "workflow.parallel_split"

  @doc """
  Persistent trigger activation — trigger that persists in the environment until explicitly consumed.

  Span: `span.workflow.persistent_trigger`
  Kind: `producer`
  Stability: `development`
  """
  @spec workflow_persistent_trigger() :: String.t()
  def workflow_persistent_trigger, do: "workflow.persistent_trigger"

  @doc """
  Sequence pattern (WP-1) — activities execute in strict serial order.

  Span: `span.workflow.sequence`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_sequence() :: String.t()
  def workflow_sequence, do: "workflow.sequence"

  @doc """
  Simple merge pattern (WP-5) — merges two or more alternative branches without synchronization.

  Span: `span.workflow.simple_merge`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_simple_merge() :: String.t()
  def workflow_simple_merge, do: "workflow.simple_merge"

  @doc """
  Structured loop iteration — while-do execution with bounded iteration count.

  Span: `span.workflow.structured_loop`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_structured_loop() :: String.t()
  def workflow_structured_loop, do: "workflow.structured_loop"

  @doc """
  Structured synchronizing merge (WP-7) — merges branches, waiting for all that were activated.

  Span: `span.workflow.structured_sync_merge`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_structured_sync_merge() :: String.t()
  def workflow_structured_sync_merge, do: "workflow.structured_sync_merge"

  @doc """
  Synchronization pattern (WP-3) — waits for ALL concurrent branches to complete before merging.

  Span: `span.workflow.synchronization`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_synchronization() :: String.t()
  def workflow_synchronization, do: "workflow.synchronization"

  @doc """
  State transition within a workflow — moving from one state to another.

  Span: `span.workflow.transition`
  Kind: `internal`
  Stability: `development`
  """
  @spec workflow_transition() :: String.t()
  def workflow_transition, do: "workflow.transition"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      workflow_cancel_region(),
      workflow_critical_section(),
      workflow_deferred_choice(),
      workflow_discriminator(),
      workflow_exclusive_choice(),
      workflow_execute(),
      workflow_interleaved_routing(),
      workflow_milestone(),
      workflow_multi_choice(),
      workflow_multi_instance(),
      workflow_parallel_split(),
      workflow_persistent_trigger(),
      workflow_sequence(),
      workflow_simple_merge(),
      workflow_structured_loop(),
      workflow_structured_sync_merge(),
      workflow_synchronization(),
      workflow_transition()
    ]
  end
end