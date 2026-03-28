defmodule OptimalSystemAgent.ProcessMining.OcelCollector do
  @moduledoc """
  OCEL 2.0 event collector — records OSA runtime events as an Object-Centric Event Log.

  Subscribes to the OSA Bus for all event types and materialises each event
  as an OCEL 2.0 record in two ETS tables:
    - `:ocel_events`  — ordered_set keyed `{timestamp_us, event_id}`, value = event_data map
    - `:ocel_objects` — set keyed `object_id`, value = `object_type` string

  This enables:
  - Connection 1 (paper): OCED as training data for predictive AI
  - Connection 4 (paper): RAG-grounded queries over real session event traces
  - OSA diagnosis grounding via `classify_with_ocpm_context/2`

  ## Armstrong Rules

  - `init_tables/0` MUST be called from `Application.start/2` — NOT from `GenServer.init/1`.
    ETS tables outlive processes and must exist before the supervisor starts children.
  - Bus event handling uses `GenServer.cast` only (never `call`) so the Bus is never blocked.
  - Circular buffer: max 10,000 events; oldest evicted when limit reached.
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus

  @max_events 10_000
  @event_types [:tool_call, :tool_result, :llm_request, :llm_response, :user_message, :agent_response]

  # ── Public API ────────────────────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Initialise ETS tables. MUST be called from `Application.start/2`, NOT `init/1`.

  Creates:
    - `:ocel_events`  — `ordered_set` keyed `{timestamp_us, event_id}` for replay order
    - `:ocel_objects` — `set` keyed `object_id` for fast O2O lookups
  """
  def init_tables do
    if :ets.whereis(:ocel_events) == :undefined do
      :ets.new(:ocel_events, [:named_table, :public, :ordered_set])
    end

    if :ets.whereis(:ocel_objects) == :undefined do
      :ets.new(:ocel_objects, [:named_table, :public, :set])
    end

    :ok
  end

  @doc """
  Record an OCEL event manually.

  - `activity` — activity name string (e.g. "tool_call", "llm_request")
  - `object_id` — identifier of the primary object involved (e.g. session_id, agent_id)
  - `attrs` — map of additional attributes
  """
  @spec record_event(String.t(), String.t(), map()) :: :ok
  def record_event(activity, object_id, attrs \\ %{}) do
    GenServer.cast(__MODULE__, {:record, activity, object_id, attrs})
  end

  @doc """
  Get the ordered event lifecycle for a specific object (session, agent, etc.).

  Returns a list of `{event_id, activity, timestamp_us}` tuples sorted by time.
  """
  @spec get_object_lifecycle(String.t(), String.t()) :: list()
  def get_object_lifecycle(object_id, _object_type \\ "session") do
    GenServer.call(__MODULE__, {:lifecycle, object_id})
  end

  @doc """
  Get the most recent N events from the collector.
  """
  @spec get_recent_events(pos_integer()) :: list()
  def get_recent_events(n \\ 100) do
    GenServer.call(__MODULE__, {:recent, n})
  end

  @doc """
  Export current event log as an OCEL 2.0 JSON-compatible map.

  The map follows the OCEL 2.0 JSON format:
  `%{"objectTypes" => [...], "objects" => [...], "events" => [...]}`
  """
  @spec export_ocel_json(String.t() | nil) :: map()
  def export_ocel_json(session_id \\ nil) do
    GenServer.call(__MODULE__, {:export, session_id})
  end

  # ── GenServer callbacks ───────────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    # Subscribe to all Bus event types using cast so we never block the Bus
    for type <- @event_types do
      Bus.register_handler(type, fn payload ->
        GenServer.cast(__MODULE__, {:bus_event, type, payload})
      end)
    end

    Logger.info("OcelCollector started — subscribed to #{length(@event_types)} event types")
    {:ok, %{}}
  end

  # Test-mode init — skip Bus subscription (Bus not running in ExUnit)
  @impl true
  def init(:ok_test) do
    Logger.info("OcelCollector started in test mode — no Bus subscription")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:bus_event, type, payload}, state) do
    activity = to_string(type)
    object_id = extract_object_id(payload)
    attrs = Map.take(payload, [:session_id, :agent_id, :tool_name, :model, :status])
    do_record(activity, object_id, attrs)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record, activity, object_id, attrs}, state) do
    do_record(activity, object_id, attrs)
    {:noreply, state}
  end

  @impl true
  def handle_call({:lifecycle, object_id}, _from, state) do
    # Scan all events, filter by object_id, sort by timestamp
    events =
      :ets.tab2list(:ocel_events)
      |> Enum.filter(fn {{_ts, _eid}, data} ->
        Map.get(data, :object_id) == object_id
      end)
      |> Enum.sort_by(fn {{ts, _eid}, _data} -> ts end)
      |> Enum.map(fn {{ts, eid}, data} ->
        {eid, Map.get(data, :activity, "unknown"), ts}
      end)

    {:reply, events, state}
  end

  @impl true
  def handle_call({:recent, n}, _from, state) do
    # ordered_set is naturally sorted by key = {ts, event_id}
    # :ets.last gives the most recent key; walk backwards
    events =
      :ets.tab2list(:ocel_events)
      |> Enum.sort_by(fn {{ts, _}, _} -> ts end, :desc)
      |> Enum.take(n)
      |> Enum.map(fn {_key, data} -> data end)

    {:reply, events, state}
  end

  @impl true
  def handle_call({:export, session_id}, _from, state) do
    all_entries = :ets.tab2list(:ocel_events)

    filtered =
      if session_id do
        Enum.filter(all_entries, fn {_key, data} ->
          Map.get(data, :session_id) == session_id
        end)
      else
        all_entries
      end

    events =
      filtered
      |> Enum.sort_by(fn {{ts, _eid}, _data} -> ts end)
      |> Enum.map(fn {{ts, eid}, data} ->
        %{
          "id" => eid,
          "activity" => Map.get(data, :activity, "unknown"),
          "timestamp" => format_timestamp(ts),
          "objects" => [Map.get(data, :object_id, "unknown")]
        }
      end)

    all_objects =
      :ets.tab2list(:ocel_objects)
      |> Enum.map(fn {id, type} -> %{"id" => id, "type" => type} end)

    object_types =
      all_objects
      |> Enum.map(& &1["type"])
      |> Enum.uniq()
      |> Enum.map(fn t -> %{"name" => t} end)

    json = %{
      "objectTypes" => object_types,
      "objects" => all_objects,
      "events" => events
    }

    {:reply, json, state}
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp do_record(activity, object_id, attrs) do
    ts = :os.system_time(:microsecond)
    event_id = :erlang.unique_integer([:positive, :monotonic]) |> Integer.to_string()

    event_data =
      Map.merge(attrs, %{
        activity: activity,
        object_id: object_id,
        timestamp_us: ts,
        event_id: event_id
      })

    :ets.insert(:ocel_events, {{ts, event_id}, event_data})

    object_type = infer_object_type(activity)
    :ets.insert(:ocel_objects, {object_id, object_type})

    evict_if_over_limit()
  end

  defp evict_if_over_limit do
    count = :ets.info(:ocel_events, :size)

    if count > @max_events do
      case :ets.first(:ocel_events) do
        :"$end_of_table" -> :ok
        oldest_key -> :ets.delete(:ocel_events, oldest_key)
      end
    end
  end

  defp extract_object_id(%{session_id: sid}) when is_binary(sid), do: sid
  defp extract_object_id(%{agent_id: aid}) when is_binary(aid), do: aid
  defp extract_object_id(%{"session_id" => sid}) when is_binary(sid), do: sid
  defp extract_object_id(%{"agent_id" => aid}) when is_binary(aid), do: aid
  defp extract_object_id(_), do: "osa"

  defp infer_object_type(activity) when activity in ["tool_call", "tool_result"], do: "tool"
  defp infer_object_type(activity) when activity in ["llm_request", "llm_response"], do: "llm"
  defp infer_object_type(activity) when activity in ["user_message", "agent_response"], do: "session"
  defp infer_object_type(_), do: "system"

  defp format_timestamp(ts_us) do
    dt = DateTime.from_unix!(ts_us, :microsecond)
    DateTime.to_iso8601(dt)
  end
end
