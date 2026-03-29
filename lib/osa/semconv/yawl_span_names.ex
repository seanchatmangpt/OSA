defmodule OpenTelemetry.SemConv.Incubating.YawlSpanNames do
  @moduledoc """
   One span per case_id semantic convention span names.

  Namespace: `yawl`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Root span for a YAWL workflow case. One span per case_id. Encapsulates the full lifecycle from INSTANCE_CREATED to INSTANCE_COMPLETED or INSTANCE_CANCELLED. The yawl.case.id is the correlation key linking all task execution spans.


  Span: `span.yawl.case`
  Kind: `internal`
  Stability: `development`
  """
  @spec yawl_case() :: String.t()
  def yawl_case, do: "yawl.case"

  @doc """
  Client span for launching a new YAWL case via the embedded server HTTP endpoint (POST /api/cases/launch). Emitted by CaseLifecycle GenServer.


  Span: `span.yawl.case.launch`
  Kind: `client`
  Stability: `development`
  """
  @spec yawl_case_launch() :: String.t()
  def yawl_case_launch, do: "yawl.case.launch"

  @doc """
  Span for a single YAWL task execution within a case. Child of span.yawl.case. Covers the full task lifecycle: TASK_ENABLED → TASK_STARTED (tokens consumed) → TASK_COMPLETED (tokens produced). The yawl.token.consumed and yawl.token.produced attributes record Petri net token flow.


  Span: `span.yawl.task.execution`
  Kind: `internal`
  Stability: `development`
  """
  @spec yawl_task_execution() :: String.t()
  def yawl_task_execution, do: "yawl.task.execution"

  @doc """
  Client span for completing (checking in) a YAWL work item via the embedded server (POST /api/cases/{id}/workitems/{wid}/complete). Emitted by CaseLifecycle GenServer.


  Span: `span.yawl.workitem.complete`
  Kind: `client`
  Stability: `development`
  """
  @spec yawl_workitem_complete() :: String.t()
  def yawl_workitem_complete, do: "yawl.workitem.complete"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      yawl_case(),
      yawl_case_launch(),
      yawl_task_execution(),
      yawl_workitem_complete()
    ]
  end
end