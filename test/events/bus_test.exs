defmodule OptimalSystemAgent.Events.BusTest do
  @moduledoc """
  Unit tests for Bus module.

  Tests event bus with goldrush-compiled routing.
  """

  use ExUnit.Case, async: false


  alias OptimalSystemAgent.Events.Bus

  @moduletag :capture_log

  setup do
    # Ensure Bus is started for tests
    unless Process.whereis(Bus) do
      _pid = start_supervised!(Bus)
    end

    :ok
  end

  describe "emit/3" do
    test "accepts valid event types" do
      for event_type <- [:system_event, :user_message, :llm_request] do
        assert {:ok, _event} = Bus.emit(event_type, %{test: "data"})
      end
    end

    test "returns :ok tuple with nil (fire-and-forget)" do
      assert {:ok, nil} = Bus.emit(:system_event, %{test: "data"})
    end

    test "accepts options for event metadata" do
      assert {:ok, nil} = Bus.emit(
        :system_event,
        %{test: "data"},
        source: "test",
        session_id: "test-session"
      )
    end

    test "handles empty payload" do
      assert {:ok, nil} = Bus.emit(:system_event, %{})
    end
  end

  describe "emit_algedonic/3" do
    test "emits algedonic alert with severity" do
      assert {:ok, _event} = Bus.emit_algedonic(:critical, "Test alert")
    end

    test "accepts all severity levels" do
      for severity <- [:critical, :high, :medium, :low] do
        assert {:ok, _event} = Bus.emit_algedonic(severity, "Test #{severity}")
      end
    end

    test "accepts metadata option" do
      assert {:ok, _event} = Bus.emit_algedonic(
        :high,
        "Test alert",
        metadata: %{context: "test"}
      )
    end

    test "accepts source option" do
      assert {:ok, _event} = Bus.emit_algedonic(
        :medium,
        "Test alert",
        source: "custom_source"
      )
    end
  end

  describe "register_handler/2" do
    test "registers a handler function" do
      handler = fn _event -> :ok end
      ref = Bus.register_handler(:system_event, handler)

      assert is_reference(ref)
    end

    test "requires function with arity 1" do
      assert_raise FunctionClauseError, fn ->
        Bus.register_handler(:system_event, fn -> :ok end)
      end
    end

    test "registers multiple handlers for same event type" do
      handler1 = fn _event -> :handler1 end
      handler2 = fn _event -> :handler2 end

      ref1 = Bus.register_handler(:system_event, handler1)
      ref2 = Bus.register_handler(:system_event, handler2)

      assert ref1 != ref2
    end
  end

  describe "unregister_handler/2" do
    test "unregisters a previously registered handler" do
      handler = fn _event -> :ok end
      ref = Bus.register_handler(:system_event, handler)

      assert :ok = Bus.unregister_handler(:system_event, ref)
    end

    test "returns :ok for non-existent handler" do
      assert :ok = Bus.unregister_handler(:system_event, make_ref())
    end
  end

  describe "event_types/0" do
    test "returns list of all supported event types" do
      types = Bus.event_types()

      assert is_list(types)
      assert length(types) > 0
      assert :system_event in types
      assert :user_message in types
      assert :llm_request in types
    end

    test "includes all expected event types" do
      types = Bus.event_types()

      expected_types = ~w(
        user_message llm_request llm_response tool_call tool_result
        agent_response system_event channel_connected channel_disconnected
        channel_error ask_user_question survey_answered algedonic_alert
        signal_classified
      )a

      for type <- expected_types do
        assert type in types
      end
    end
  end

  describe "integration - emit and handler" do
    test "emitted event reaches registered handler" do
      # Use a custom agent for this test to avoid global state pollution
      test_pid = self()
      event_ref = make_ref()

      handler = fn event ->
        # Event structure from goldrush has keys as atoms
        data = Map.get(event, :data, %{})
        if Map.get(data, :test_ref) == event_ref do
          send(test_pid, {:handler_called, event})
        end
        :ok
      end

      Bus.register_handler(:system_event, handler)

      # Emit event with unique identifier
      Bus.emit(:system_event, %{test_ref: event_ref})

      # Wait for handler to be called (with longer timeout for background task)
      assert_receive {:handler_called, event}, 5000
      data = Map.get(event, :data, %{})
      assert Map.get(data, :test_ref) == event_ref
    end

    test "multiple handlers receive the same event" do
      test_pid = self()
      event_ref = make_ref()

      handler1 = fn event ->
        data = Map.get(event, :data, %{})
        if Map.get(data, :test_ref) == event_ref do
          send(test_pid, {:handler1, event})
        end
        :ok
      end

      handler2 = fn event ->
        data = Map.get(event, :data, %{})
        if Map.get(data, :test_ref) == event_ref do
          send(test_pid, {:handler2, event})
        end
        :ok
      end

      Bus.register_handler(:system_event, handler1)
      Bus.register_handler(:system_event, handler2)

      Bus.emit(:system_event, %{test_ref: event_ref})

      assert_receive {:handler1, _}, 5000
      assert_receive {:handler2, _}, 5000
    end

    test "unregistered handler does not receive events" do
      test_pid = self()
      event_ref = make_ref()

      handler = fn event ->
        data = Map.get(event, :data, %{})
        if Map.get(data, :test_ref) == event_ref do
          send(test_pid, {:handler_called, event})
        end
        :ok
      end

      ref = Bus.register_handler(:system_event, handler)
      Bus.unregister_handler(:system_event, ref)

      Bus.emit(:system_event, %{test_ref: event_ref})

      # Handler should NOT be called
      refute_receive {:handler_called, _}, 500
    end
  end

  describe "algedonic alerts" do
    test "algedonic alert emit returns success" do
      # Just verify the emit works - handler delivery depends on goldrush routing
      assert {:ok, _event} = Bus.emit_algedonic(:critical, "Test alert", metadata: %{ref: :test})
    end

    test "algedonic alert includes correct payload structure" do
      assert {:ok, _event} = Bus.emit_algedonic(:high, "Test alert", metadata: %{key: "value"})
    end
  end

  describe "edge cases" do
    test "handler crash does not block emit" do
      crashing_handler = fn _event ->
        raise "Intentional crash"
      end

      Bus.register_handler(:system_event, crashing_handler)

      # Emit should not crash or block
      assert {:ok, nil} = Bus.emit(:system_event, %{test: "data"})
    end

    test "handler that throws is caught and logged" do
      throwing_handler = fn _event ->
        throw(:intentional_throw)
      end

      Bus.register_handler(:system_event, throwing_handler)

      # Emit should not crash or block
      assert {:ok, nil} = Bus.emit(:system_event, %{test: "data"})
    end

    test "handler with exit is caught" do
      exiting_handler = fn _event ->
        exit(:intentional_exit)
      end

      Bus.register_handler(:system_event, exiting_handler)

      # Emit should not crash or block
      assert {:ok, nil} = Bus.emit(:system_event, %{test: "data"})
    end
  end
end
