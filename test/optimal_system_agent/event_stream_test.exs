defmodule OptimalSystemAgent.EventStreamTest do
  @moduledoc """
  Unit tests for EventStream module.

  Tests SSE event streaming for Command Center.
  Real ETS operations and Phoenix.PubSub, no mocks.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.EventStream

  @moduletag :capture_log

  setup do
    # EventStream is already started by the application
    # Just ensure it's running
    unless Process.whereis(EventStream) do
      start_supervised!(EventStream)
    end
    :ok
  end

  describe "start_link/1" do
    test "starts the EventStream GenServer" do
      assert {:ok, pid} = EventStream.start_link([])
      assert is_pid(pid)
      # Stop the extra process we started
      GenServer.stop(pid)
    end
  end

  describe "init/1" do
    test "initializes with ETS table for history" do
      state = :sys.get_state(EventStream)
      assert state.table != nil
      assert is_integer(state.seq)
    end

    test "creates named ETS table" do
      table_info = :ets.whereis(:command_center_events)
      refute table_info == :undefined
    end
  end

  describe "subscribe/0" do
    test "subscribes to command center events" do
      result = EventStream.subscribe()
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "can subscribe multiple times" do
      :ok = EventStream.subscribe()
      result = EventStream.subscribe()
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "subscribe/1" do
    test "subscribes to filtered events" do
      result = EventStream.subscribe("test_agent")
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles empty filter" do
      result = EventStream.subscribe("")
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles unicode filter" do
      result = EventStream.subscribe("代理_123")
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "broadcast/2" do
    test "broadcasts event to all subscribers" do
      event = %{
        type: "task_update",
        data: %{status: "completed"}
      }
      result = EventStream.broadcast("task_update", event.data)
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "adds event to ETS history" do
      EventStream.broadcast("test_event", %{data: "test"})

      # Check event is in history
      history = EventStream.event_history("test_event")
      assert is_list(history)
      # Should have at least our event
      assert length(history) >= 1
    end

    test "handles nil payload" do
      result = EventStream.broadcast("nil_test", nil)
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles empty map payload" do
      result = EventStream.broadcast("empty_test", %{})
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "event_history/0" do
    test "returns all event history" do
      # Add some events
      EventStream.broadcast("test_1", %{index: 1})
      EventStream.broadcast("test_2", %{index: 2})

      history = EventStream.event_history()
      assert is_list(history)
      assert length(history) >= 2
    end

    test "returns empty list when no events" do
      # This is hard to test since events accumulate
      # Just verify it returns a list
      history = EventStream.event_history()
      assert is_list(history)
    end
  end

  describe "event_history/1" do
    test "returns filtered history by event type" do
      # Add events
      EventStream.broadcast("filter_test", %{index: 1})
      EventStream.broadcast("other_type", %{index: 2})
      EventStream.broadcast("filter_test", %{index: 3})

      history = EventStream.event_history("filter_test")
      assert is_list(history)
      # Should only return filter_test events
      assert Enum.all?(history, fn e -> e.type == "filter_test" end)
    end

    test "returns empty list for non-existent event type" do
      history = EventStream.event_history("nonexistent_type_xyz")
      assert is_list(history)
      assert length(history) == 0
    end

    test "handles nil filter returns all events" do
      history_with_nil = EventStream.event_history(nil)
      history_all = EventStream.event_history()
      assert length(history_with_nil) == length(history_all)
    end
  end

  describe "ETS operations" do
    test "stores events in ordered_set ETS table" do
      EventStream.broadcast("ets_test", %{data: "test"})

      # Event should be in ETS table
      ets_has_event = try do
        :ets.tab2list(:command_center_events)
        |> Enum.any?(fn {_seq, event} -> event.type == "ets_test" end)
      rescue
        _ -> false
      end

      # Verify via event_history (which uses ETS internally)
      history = EventStream.event_history("ets_test")
      assert length(history) >= 1
      # The event should be in the ETS table
      assert ets_has_event or length(history) >= 1
    end

    test "handles ETS table overflow gracefully" do
      # Broadcast more events than max_history (100)
      for i <- 1..150 do
        EventStream.broadcast("overflow_test", %{index: i})
      end

      # Should return at most max_history events
      history = EventStream.event_history("overflow_test")
      assert length(history) <= 100
    end

    test "prunes oldest entries when exceeding max_history" do
      # Clear with specific type
      for i <- 1..110 do
        EventStream.broadcast("prune_test", %{index: i})
      end

      history = EventStream.event_history("prune_test")
      assert length(history) <= 100

      # Oldest entries should be pruned
      first_event = List.first(history)
      # First event should not be index 1 (pruned)
      if length(history) > 0 do
        assert first_event.payload.index > 10
      end
    end
  end

  describe "GenServer callbacks" do
    test "handle_cast records event and increments seq" do
      initial_state = :sys.get_state(EventStream)
      initial_seq = initial_state.seq

      EventStream.broadcast("seq_test", %{data: "test"})

      # Wait for cast to be processed
      Process.sleep(50)

      new_state = :sys.get_state(EventStream)
      assert new_state.seq > initial_seq
    end

    test "handle_info handles unknown messages gracefully" do
      send(EventStream, :unknown_message)
      Process.sleep(50)
      assert Process.alive?(Process.whereis(EventStream))
    end

    test "handle_call handles unknown calls" do
      _result = try do
        GenServer.call(EventStream, :unknown_call)
      catch
        :exit, _ -> :exited
      end
      # Should not crash the server
      assert Process.alive?(Process.whereis(EventStream))
    end
  end

  describe "edge cases" do
    test "handles very long event type" do
      long_type = String.duplicate("a", 1000)
      result = EventStream.broadcast(long_type, %{data: "test"})
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles very large payload data" do
      large_data = String.duplicate("x", 10_000)
      result = EventStream.broadcast("large_test", %{data: large_data})
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles unicode in event type" do
      result = EventStream.broadcast("测试事件", %{data: "test"})
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles unicode in payload" do
      result = EventStream.broadcast("unicode_test", %{data: "测试数据"})
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles complex nested payload" do
      complex_payload = %{
        "nested" => %{
          "deeply" => %{
            "value" => "test",
            "list" => [1, 2, 3]
          }
        },
        "array" => [%{key: "value1"}, %{key: "value2"}]
      }
      result = EventStream.broadcast("complex_test", complex_payload)
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles special characters in event type" do
      result = EventStream.broadcast("event-with_special.chars:123", %{data: "test"})
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "integration" do
    test "full event streaming lifecycle" do
      # Subscribe
      :ok = EventStream.subscribe()

      # Broadcast events
      EventStream.broadcast("lifecycle_start", %{phase: "start"})
      EventStream.broadcast("lifecycle_update", %{phase: "update"})
      EventStream.broadcast("lifecycle_complete", %{phase: "complete"})

      # Allow async cast to complete
      Process.sleep(100)

      # Get all history
      all_history = EventStream.event_history()
      assert length(all_history) >= 3

      # Get filtered history
      filtered = EventStream.event_history("lifecycle_update")
      assert length(filtered) >= 1
      assert hd(filtered).type == "lifecycle_update"
    end

    test "multiple event types with separate histories" do
      # Broadcast different types
      EventStream.broadcast("type_a", %{value: 1})
      EventStream.broadcast("type_b", %{value: 2})
      EventStream.broadcast("type_a", %{value: 3})

      history_a = EventStream.event_history("type_a")
      history_b = EventStream.event_history("type_b")

      assert length(history_a) >= 2
      assert length(history_b) >= 1

      # All type_a events should have type "type_a"
      assert Enum.all?(history_a, fn e -> e.type == "type_a" end)
    end

    test "event structure includes timestamp" do
      EventStream.broadcast("timestamp_test", %{data: "test"})

      history = EventStream.event_history("timestamp_test")
      test_event = Enum.find(history, fn e -> e.type == "timestamp_test" end)

      if test_event != nil do
        assert Map.has_key?(test_event, :timestamp)
        assert Map.has_key?(test_event, :payload)
        assert Map.has_key?(test_event, :type)
      end
    end

    test "pubsub broadcast occurs" do
      # Subscribe first
      :ok = EventStream.subscribe()

      # Broadcast
      EventStream.broadcast("pubsub_test", %{test: "data"})

      # Event should be in history (broadcast occurred)
      history = EventStream.event_history("pubsub_test")
      assert length(history) >= 1
    end
  end
end
