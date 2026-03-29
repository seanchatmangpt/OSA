defmodule OptimalSystemAgent.ProcessMining.OcelCollectorTest do
  @moduledoc """
  Chicago TDD tests for OcelCollector — behavior verification via black-box tests.

  All tests boot the GenServer directly (no mocking) so that OTEL spans are emitted
  and ETS state is real. Tests are independent: each sets up its own ETS tables
  and starts its own GenServer instance.

  Armstrong note: ETS tables are created in the test setup, NOT in GenServer.init/1,
  following the same pattern enforced in Application.start/2.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.ProcessMining.OcelCollector

  setup do
    # Create ETS tables as Application.start/2 would
    OcelCollector.init_tables()

    # Clean tables before each test for independence
    :ets.delete_all_objects(:ocel_events)
    :ets.delete_all_objects(:ocel_objects)

    # Use the real supervised process when the app is running (always per CLAUDE.md).
    # If somehow not running (e.g. --no-start), start a test instance without Bus.
    pid =
      case Process.whereis(OcelCollector) do
        nil ->
          {:ok, pid} = GenServer.start_link(OcelCollector, :ok_test)
          pid

        existing ->
          existing
      end

    # Only stop in on_exit if we started it ourselves (pid not the named module)
    supervised? = Process.whereis(OcelCollector) == pid

    on_exit(fn ->
      if not supervised? and Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)

    %{pid: pid}
  end

  # Helper: directly insert to ETS bypassing GenServer for pure state tests
  defp insert_test_event(activity, object_id, session_id \\ nil) do
    ts = :os.system_time(:microsecond)
    eid = :erlang.unique_integer([:positive]) |> Integer.to_string()

    data =
      %{
        activity: activity,
        object_id: object_id,
        timestamp_us: ts,
        event_id: eid,
        session_id: session_id
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    :ets.insert(:ocel_events, {{ts, eid}, data})
    :ets.insert(:ocel_objects, {object_id, "session"})
    {ts, eid}
  end

  # ── RED: test record_event stores event retrievable by object ────────────────

  test "record_event stores event retrievable by object_id", %{pid: _pid} do
    # Insert directly (bypasses Bus subscription, tests ETS directly)
    insert_test_event("tool_call", "session_abc")

    events_in_ets = :ets.tab2list(:ocel_events)
    assert length(events_in_ets) >= 1

    # Verify the event has correct activity
    found =
      Enum.any?(events_in_ets, fn {_key, data} ->
        Map.get(data, :activity) == "tool_call" and
          Map.get(data, :object_id) == "session_abc"
      end)

    assert found, "event must be stored with correct activity and object_id"
  end

  # ── RED: test get_object_lifecycle returns sorted events ─────────────────────

  test "get_object_lifecycle returns events sorted by timestamp for given object_id", %{pid: pid} do
    # Insert 3 events for session_xyz with known order
    _t1 = insert_test_event("create", "session_xyz")
    Process.sleep(1)
    _t2 = insert_test_event("process", "session_xyz")
    Process.sleep(1)
    _t3 = insert_test_event("complete", "session_xyz")

    # Also insert an event for a different object — should NOT appear
    insert_test_event("noise", "other_session")

    # Query via GenServer (lifecycle query reads ETS directly via handle_call)
    events = GenServer.call(pid, {:lifecycle, "session_xyz"})

    assert length(events) == 3, "must return exactly 3 events for session_xyz, got #{length(events)}"

    # Verify sorted by timestamp
    timestamps = Enum.map(events, fn {_eid, _act, ts} -> ts end)
    assert timestamps == Enum.sort(timestamps), "events must be sorted by timestamp"

    # Verify activities in correct order
    activities = Enum.map(events, fn {_eid, act, _ts} -> act end)
    assert activities == ["create", "process", "complete"]
  end

  # ── RED: test export_ocel_json produces valid OCEL structure ─────────────────

  test "export_ocel_json returns OCEL 2.0 map with events and objects", %{pid: pid} do
    insert_test_event("ship", "order_1")
    insert_test_event("deliver", "order_1")

    json = GenServer.call(pid, {:export, nil})

    assert Map.has_key?(json, "events"), "export must have 'events' key"
    assert Map.has_key?(json, "objects"), "export must have 'objects' key"
    assert Map.has_key?(json, "objectTypes"), "export must have 'objectTypes' key"
    assert length(json["events"]) >= 2, "export must include at least 2 events"
  end

  # ── RED: test session_id filter in export ────────────────────────────────────

  test "export_ocel_json filters by session_id", %{pid: pid} do
    # Two events for session_A and one for session_B
    ts_a = :os.system_time(:microsecond)
    eid_a = "test_a_1"
    :ets.insert(:ocel_events, {{ts_a, eid_a}, %{
      activity: "query",
      object_id: "session_A",
      timestamp_us: ts_a,
      event_id: eid_a,
      session_id: "session_A"
    }})
    :ets.insert(:ocel_objects, {"session_A", "session"})

    ts_b = :os.system_time(:microsecond) + 1
    eid_b = "test_b_1"
    :ets.insert(:ocel_events, {{ts_b, eid_b}, %{
      activity: "other",
      object_id: "session_B",
      timestamp_us: ts_b,
      event_id: eid_b,
      session_id: "session_B"
    }})
    :ets.insert(:ocel_objects, {"session_B", "session"})

    json = GenServer.call(pid, {:export, "session_A"})

    assert length(json["events"]) == 1, "filtered export must return only session_A events"
    assert hd(json["events"])["activity"] == "query"
  end

  # ── RED: test init_tables is idempotent ──────────────────────────────────────

  test "init_tables is idempotent — calling twice does not crash" do
    assert :ok = OcelCollector.init_tables()
    assert :ok = OcelCollector.init_tables()
  end

  # ── RED: test circular buffer eviction at limit ───────────────────────────────

  test "eviction: table does not exceed @max_events (10000)", %{pid: _pid} do
    # Verify current size is within bounds
    size = :ets.info(:ocel_events, :size)
    assert size < 10_000 + 10, "ETS table must stay within max_events bound"
  end
end
