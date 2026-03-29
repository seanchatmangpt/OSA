defmodule OptimalSystemAgent.A2A.Registry do
  @moduledoc """
  A2A agent registry — probes /.well-known/agent.json for all known agents
  at startup and every 60 seconds. Stores discovered cards in ETS.

  Armstrong principles:
  - Each probe runs in Task.start (crash-isolated per agent)
  - 5s probe timeout prevents blocked probes from holding up refresh cycle
  - ETS table survives GenServer restarts (data is read-only between writes)

  WvdA boundedness:
  - ETS table has fixed set of known agents (not unbounded growth)
  - Refresh timer is 60s fixed interval (Process.send_after)
  """

  use GenServer
  require Logger

  @table :a2a_registry
  @refresh_ms 60_000
  @probe_timeout_ms 5_000

  @known_agents [
    %{name: "osa", base_url: "http://localhost:8089"},
    %{name: "businessos", base_url: "http://localhost:8001"},
    %{name: "canopy", base_url: "http://localhost:9089"},
    %{name: "pm4py-rust", base_url: "http://localhost:8090"}
  ]

  # ── Public API ──────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Return all discovered agents as a list of maps."
  def all_agents do
    case :ets.whereis(@table) do
      :undefined -> []
      _tid ->
        :ets.tab2list(@table)
        |> Enum.map(fn {_name, card} -> card end)
    end
  end

  @doc "Return a single agent card by name, or nil."
  def get_agent(name) do
    case :ets.whereis(@table) do
      :undefined -> nil
      _tid ->
        case :ets.lookup(@table, name) do
          [{^name, card}] -> card
          [] -> nil
        end
    end
  end

  @doc "Trigger an immediate refresh outside of the scheduled interval."
  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  # ── GenServer callbacks ──────────────────────────────────────────

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    schedule_refresh()
    # Probe immediately at startup (non-blocking)
    send(self(), :refresh)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:refresh, state) do
    probe_all()
    schedule_refresh()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    probe_all()
    {:noreply, state}
  end

  # ── Private ──────────────────────────────────────────────────────

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_ms)
  end

  defp probe_all do
    Enum.each(@known_agents, fn agent ->
      # Armstrong: each probe is crash-isolated — failure of one probe
      # does not affect probes of other agents
      Task.start(fn -> probe_agent(agent) end)
    end)
  end

  defp probe_agent(%{name: name, base_url: base_url}) do
    url = "#{base_url}/.well-known/agent.json"

    opts = [receive_timeout: @probe_timeout_ms, retry: false]

    case Req.get(url, opts) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        card = Map.merge(body, %{"_discovered_at" => DateTime.utc_now() |> DateTime.to_iso8601()})
        :ets.insert(@table, {name, card})
        Logger.debug("[A2A.Registry] Discovered #{name} at #{base_url}")

      {:ok, %{status: status}} ->
        Logger.debug("[A2A.Registry] Probe #{name}: HTTP #{status} — skipping")

      {:error, reason} ->
        Logger.debug("[A2A.Registry] Probe #{name} failed: #{inspect(reason)} — skipping")
    end
  end
end
