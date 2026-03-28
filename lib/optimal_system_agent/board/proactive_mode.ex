defmodule OptimalSystemAgent.Board.ProactiveMode do
  @moduledoc """
  Thin façade for toggling autonomous process monitoring on and off.

  Delegates to `MonitoringScheduler` via `GenServer.call/3`.  Proactive mode
  controls whether the scheduler polls pm4py-rust for drift on each tick.

  ## Usage

      # Enable autonomous drift detection
      :ok = ProactiveMode.enable()

      # Disable (e.g. during maintenance windows)
      :ok = ProactiveMode.disable()

      # Query current state
      {:ok, %{enabled: true, last_drift: 0.03, drift_count: 7}} = ProactiveMode.status()
  """

  alias OptimalSystemAgent.Board.MonitoringScheduler

  @doc "Enable proactive drift monitoring."
  @spec enable() :: :ok
  def enable, do: GenServer.call(MonitoringScheduler, :enable, 5_000)

  @doc "Disable proactive drift monitoring."
  @spec disable() :: :ok
  def disable, do: GenServer.call(MonitoringScheduler, :disable, 5_000)

  @doc "Return current scheduler status map."
  @spec status() :: {:ok, map()}
  def status, do: GenServer.call(MonitoringScheduler, :get_status, 5_000)
end
