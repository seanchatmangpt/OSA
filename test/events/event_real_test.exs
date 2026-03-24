defmodule OptimalSystemAgent.Events.EventRealTest do
  @moduledoc """
  Chicago TDD integration tests for Events.Event (CloudEvents struct).

  NO MOCKS. Tests real event construction, child events, serialization.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Events.Event

  describe "Event.new/2" do
    test "CRASH: creates event with type and source" do
      event = Event.new("user_message", "agent-1")
      assert event.type == "user_message"
      assert event.source == "agent-1"
      assert is_binary(event.id)
      assert event.specversion == "1.0.2"
      assert event.time != nil
    end
  end

  describe "Event.new/3" do
    test "CRASH: creates event with data" do
      event = Event.new("tool_call", "agent-1", %{result: "ok"})
      assert event.data == %{result: "ok"}
    end
  end

  describe "Event.new/4 — full opts" do
    test "CRASH: creates event with all opts" do
      event = Event.new("test", "src", nil, [
        session_id: "sess-1",
        correlation_id: "corr-1",
        parent_id: "parent-1",
        signal_mode: :execute,
        signal_genre: :inform,
        signal_type: :request,
        signal_format: :text,
        signal_sn: 0.85
      ])
      assert event.session_id == "sess-1"
      assert event.correlation_id == "corr-1"
      assert event.parent_id == "parent-1"
      assert event.signal_mode == :execute
      assert event.signal_sn == 0.85
    end

    test "CRASH: custom id overrides generated id" do
      event = Event.new("test", "src", nil, id: "custom-id")
      assert event.id == "custom-id"
    end

    test "CRASH: custom time overrides default time" do
      custom_time = ~U[2025-01-01 00:00:00Z]
      event = Event.new("test", "src", nil, time: custom_time)
      assert event.time == custom_time
    end
  end

  describe "Event.child/3-5" do
    test "CRASH: child inherits session_id and correlation_id" do
      parent = Event.new("parent", "src", nil, session_id: "s1", correlation_id: "c1", id: "p1")
      child = Event.child(parent, "child_event", "src")
      assert child.parent_id == "p1"
      assert child.session_id == "s1"
      assert child.correlation_id == "c1"
    end

    test "CRASH: child gets its own id" do
      parent = Event.new("parent", "src", nil, id: "p1")
      child = Event.child(parent, "child", "src")
      assert child.id != "p1"
    end

    test "CRASH: child with data" do
      parent = Event.new("parent", "src")
      child = Event.child(parent, "child", "src", %{key: "val"})
      assert child.data == %{key: "val"}
    end

    test "CRASH: child opts override inherited values" do
      parent = Event.new("parent", "src", nil, correlation_id: "old-corr")
      child = Event.child(parent, "child", "src", nil, correlation_id: "new-corr")
      assert child.correlation_id == "new-corr"
    end
  end

  describe "Event.to_map/1" do
    test "CRASH: returns map with non-nil fields" do
      event = Event.new("test", "src", nil, session_id: "s1")
      map = Event.to_map(event)
      assert is_map(map)
      assert map.type == "test"
      assert map.source == "src"
      assert map.session_id == "s1"
    end

    test "CRASH: nil fields are excluded" do
      event = Event.new("test", "src")
      map = Event.to_map(event)
      refute Map.has_key?(map, :session_id)
      refute Map.has_key?(map, :data)
    end
  end

  describe "Event.to_cloud_event/1" do
    test "CRASH: returns CloudEvents v1.0.2 format" do
      event = Event.new("user_message", "agent-1", "hello")
      ce = Event.to_cloud_event(event)
      assert ce["specversion"] == "1.0.2"
      assert ce["type"] == "user_message"
      assert ce["source"] == "agent-1"
      assert ce["datacontenttype"] == "application/json"
    end

    test "CRASH: includes time as ISO8601" do
      event = Event.new("test", "src")
      ce = Event.to_cloud_event(event)
      assert is_binary(ce["time"])
      assert ce["time"] != ""
    end

    test "CRASH: includes data when present" do
      event = Event.new("test", "src", %{key: "val"})
      ce = Event.to_cloud_event(event)
      assert ce["data"] == %{key: "val"}
    end

    test "CRASH: omits nil data" do
      event = Event.new("test", "src")
      ce = Event.to_cloud_event(event)
      refute Map.has_key?(ce, "data")
    end

    test "CRASH: includes signal fields when set" do
      event = Event.new("test", "src", nil, signal_mode: :execute, signal_sn: 0.9)
      ce = Event.to_cloud_event(event)
      assert ce["signal_mode"] == "execute"
      assert ce["signal_sn"] == 0.9
    end

    test "CRASH: merges extensions" do
      event = Event.new("test", "src", nil, extensions: %{custom: true})
      ce = Event.to_cloud_event(event)
      assert ce["custom"] == true
    end
  end
end
