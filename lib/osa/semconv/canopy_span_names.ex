defmodule OpenTelemetry.SemConv.Incubating.CanopySpanNames do
  @moduledoc """
  Canopy semantic convention span names.

  Namespace: `canopy`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Canopy adapter invocation — calling an external service via a Canopy adapter.

  Span: `span.canopy.adapter_call`
  Kind: `client`
  Stability: `development`
  """
  @spec canopy_adapter_call() :: String.t()
  def canopy_adapter_call, do: "canopy.adapter_call"

  @doc """
  Broadcast of a signal or command to all connected agents.

  Span: `span.canopy.broadcast`
  Kind: `producer`
  Stability: `development`
  """
  @spec canopy_broadcast() :: String.t()
  def canopy_broadcast, do: "canopy.broadcast"

  @doc """
  Command dispatch through the Canopy workspace protocol.

  Span: `span.canopy.command`
  Kind: `producer`
  Stability: `development`
  """
  @spec canopy_command() :: String.t()
  def canopy_command, do: "canopy.command"

  @doc """
  Canopy heartbeat dispatch — periodic health signal sent to connected services.

  Span: `span.canopy.heartbeat`
  Kind: `internal`
  Stability: `development`
  """
  @spec canopy_heartbeat() :: String.t()
  def canopy_heartbeat, do: "canopy.heartbeat"

  @doc """
  Individual heartbeat probe — one RTT measurement to a single OSA node.

  Span: `span.canopy.heartbeat.probe`
  Kind: `internal`
  Stability: `development`
  """
  @spec canopy_heartbeat_probe() :: String.t()
  def canopy_heartbeat_probe, do: "canopy.heartbeat.probe"

  @doc """
  Canopy workspace session creation — initializing a new collaboration session.

  Span: `span.canopy.session.create`
  Kind: `server`
  Stability: `development`
  """
  @spec canopy_session_create() :: String.t()
  def canopy_session_create, do: "canopy.session.create"

  @doc """
  Creating a point-in-time snapshot of the canopy workspace state.

  Span: `span.canopy.snapshot.create`
  Kind: `internal`
  Stability: `development`
  """
  @spec canopy_snapshot_create() :: String.t()
  def canopy_snapshot_create, do: "canopy.snapshot.create"

  @doc """
  Reconciling workspace state between peers — resolving conflicts and applying updates.

  Span: `span.canopy.workspace.reconcile`
  Kind: `internal`
  Stability: `development`
  """
  @spec canopy_workspace_reconcile() :: String.t()
  def canopy_workspace_reconcile, do: "canopy.workspace.reconcile"

  @doc """
  Synchronization of workspace state across connected agents.

  Span: `span.canopy.workspace.sync`
  Kind: `internal`
  Stability: `development`
  """
  @spec canopy_workspace_sync() :: String.t()
  def canopy_workspace_sync, do: "canopy.workspace.sync"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      canopy_adapter_call(),
      canopy_broadcast(),
      canopy_command(),
      canopy_heartbeat(),
      canopy_heartbeat_probe(),
      canopy_session_create(),
      canopy_snapshot_create(),
      canopy_workspace_reconcile(),
      canopy_workspace_sync()
    ]
  end
end