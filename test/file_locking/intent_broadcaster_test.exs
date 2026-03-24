defmodule OptimalSystemAgent.FileLocking.IntentBroadcasterTest do
  @moduledoc """
  Chicago TDD unit tests for IntentBroadcaster module.

  Tests file intent broadcasting via PubSub and ETS tracking.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.FileLocking.IntentBroadcaster

  @moduletag :capture_log
  @moduletag :skip

  setup do
    # Ensure ETS tables are initialized
    IntentBroadcaster.init_tables()

    # Generate unique file path for this test
    test_id = System.unique_integer([:positive])
    file_path = "/test/file_#{test_id}.ex"

    # Clean up ETS tables after each test
    on_exit(fn ->
      :ets.delete_all_objects(:osa_file_subscriptions)
      :ets.delete_all_objects(:osa_file_intents)
    end)

    %{file_path: file_path}
  end

  describe "init_tables/0" do
    test "creates ETS tables" do
      assert :ok = IntentBroadcaster.init_tables()
    end

    test "idempotent - can be called multiple times" do
      assert :ok = IntentBroadcaster.init_tables()
      assert :ok = IntentBroadcaster.init_tables()
    end
  end

  describe "broadcast_intent/3" do
    test "stores intent in ETS", %{file_path: file_path} do
      agent_id = "agent_1"
      intent = "testing intent"

      assert :ok = IntentBroadcaster.broadcast_intent(agent_id, file_path, intent)

      # Check that intent was stored
      intents = IntentBroadcaster.current_intents_for(file_path)
      assert length(intents) == 1
      assert hd(intents).agent_id == agent_id
      assert hd(intents).intent == intent
    end

    test "overwrites previous intent for same agent+file", %{file_path: file_path} do
      agent_id = "agent_1"

      IntentBroadcaster.broadcast_intent(agent_id, file_path, "first intent")
      IntentBroadcaster.broadcast_intent(agent_id, file_path, "second intent")

      intents = IntentBroadcaster.current_intents_for(file_path)
      assert length(intents) == 1
      assert hd(intents).intent == "second intent"
    end

    test "stores multiple intents for different agents", %{file_path: file_path} do
      IntentBroadcaster.broadcast_intent("agent_1", file_path, "intent 1")
      IntentBroadcaster.broadcast_intent("agent_2", file_path, "intent 2")

      intents = IntentBroadcaster.current_intents_for(file_path)
      assert length(intents) == 2
    end

    test "returns :ok even if PubSub is unavailable" do
      # This test verifies graceful degradation if PubSub is not running
      result = IntentBroadcaster.broadcast_intent("agent_1", "/test/file_unique.ex", "intent")
      assert result == :ok
    end
  end

  describe "subscribers_for/1" do
    test "returns empty list for file with no subscribers", %{file_path: file_path} do
      assert [] = IntentBroadcaster.subscribers_for(file_path)
    end

    test "returns subscribers after subscription", %{file_path: file_path} do
      # Note: subscribe_to_file requires PubSub, which may not be available in tests
      # We can test the ETS tracking directly by inserting manually
      :ets.insert(:osa_file_subscriptions, {file_path, "agent_1"})
      :ets.insert(:osa_file_subscriptions, {file_path, "agent_2"})

      subscribers = IntentBroadcaster.subscribers_for(file_path)
      assert length(subscribers) == 2
      assert "agent_1" in subscribers
      assert "agent_2" in subscribers
    end

    test "returns unique agent IDs", %{file_path: file_path} do
      # Insert duplicate subscriptions
      :ets.insert(:osa_file_subscriptions, {file_path, "agent_1"})
      :ets.insert(:osa_file_subscriptions, {file_path, "agent_1"})

      subscribers = IntentBroadcaster.subscribers_for(file_path)
      assert subscribers == ["agent_1"]
    end

    test "returns empty list for non-existent file" do
      assert [] = IntentBroadcaster.subscribers_for("/nonexistent/file_#{System.unique_integer()}.ex")
    end
  end

  describe "current_intents_for/1" do
    test "returns empty list for file with no intents", %{file_path: file_path} do
      assert [] = IntentBroadcaster.current_intents_for(file_path)
    end

    test "returns intents sorted by timestamp", %{file_path: file_path} do
      IntentBroadcaster.broadcast_intent("agent_1", file_path, "intent 1")
      Process.sleep(10)  # Ensure different timestamps
      IntentBroadcaster.broadcast_intent("agent_2", file_path, "intent 2")

      intents = IntentBroadcaster.current_intents_for(file_path)
      assert length(intents) == 2
      # Should be sorted by timestamp
      assert hd(intents).agent_id == "agent_1"
    end

    test "returns only intents for specified file" do
      file1 = "/test/file1_#{System.unique_integer()}.ex"
      file2 = "/test/file2_#{System.unique_integer()}.ex"

      IntentBroadcaster.broadcast_intent("agent_1", file1, "intent 1")
      IntentBroadcaster.broadcast_intent("agent_2", file2, "intent 2")

      intents1 = IntentBroadcaster.current_intents_for(file1)
      intents2 = IntentBroadcaster.current_intents_for(file2)

      assert length(intents1) == 1
      assert length(intents2) == 1
      assert hd(intents1).agent_id == "agent_1"
      assert hd(intents2).agent_id == "agent_2"
    end
  end

  describe "unsubscribe_from_file/2" do
    test "removes subscription from ETS", %{file_path: file_path} do
      # Manually insert subscription to test removal
      :ets.insert(:osa_file_subscriptions, {file_path, "agent_1"})

      assert :ok = IntentBroadcaster.unsubscribe_from_file("agent_1", file_path)

      subscribers = IntentBroadcaster.subscribers_for(file_path)
      assert "agent_1" not in subscribers
    end

    test "removes intent snapshot from ETS", %{file_path: file_path} do
      # Store an intent first
      IntentBroadcaster.broadcast_intent("agent_1", file_path, "intent")

      # Unsubscribe
      IntentBroadcaster.unsubscribe_from_file("agent_1", file_path)

      # Intent should be cleared
      intents = IntentBroadcaster.current_intents_for(file_path)
      assert [] = intents
    end

    test "returns :ok even if subscription doesn't exist" do
      assert :ok = IntentBroadcaster.unsubscribe_from_file("agent_1", "/nonexistent/file_#{System.unique_integer()}.ex")
    end
  end

  describe "integration - subscribe and broadcast" do
    test "full lifecycle with ETS tracking", %{file_path: file_path} do
      agent_id = "agent_#{System.unique_integer()}"

      # Initial state - no intents, no subscribers
      assert [] = IntentBroadcaster.current_intents_for(file_path)
      assert [] = IntentBroadcaster.subscribers_for(file_path)

      # Broadcast intent
      assert :ok = IntentBroadcaster.broadcast_intent(agent_id, file_path, "test intent")

      # Check intent was stored
      intents = IntentBroadcaster.current_intents_for(file_path)
      assert length(intents) == 1
      intent = hd(intents)
      assert intent.agent_id == agent_id
      assert intent.intent == "test intent"
      assert intent.file_path == file_path

      # Unsubscribe
      IntentBroadcaster.unsubscribe_from_file(agent_id, file_path)

      # Intent should be cleared
      assert [] = IntentBroadcaster.current_intents_for(file_path)
    end
  end
end
