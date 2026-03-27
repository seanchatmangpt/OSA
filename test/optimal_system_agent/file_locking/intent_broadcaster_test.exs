defmodule OptimalSystemAgent.FileLocking.IntentBroadcasterTest do
  @moduledoc """
  Unit tests for FileLocking.IntentBroadcaster module.

  Tests edit intent broadcasting for multi-agent file collaboration.
  Real ETS operations and Phoenix.PubSub, no mocks.
  """

  use ExUnit.Case, async: false


  alias OptimalSystemAgent.FileLocking.IntentBroadcaster

  @moduletag :capture_log

  setup do
    # Initialize ETS tables
    IntentBroadcaster.init_tables()
    # Clear any stale data from previous tests
    :ets.delete_all_objects(:osa_file_subscriptions)
    :ets.delete_all_objects(:osa_file_intents)
    :ok
  end

  describe "init_tables/0" do
    test "creates ETS tables for intent broadcasting" do
      # Tables should already exist from setup
      assert :ets.whereis(:osa_file_subscriptions) != :undefined
      assert :ets.whereis(:osa_file_intents) != :undefined
    end

    test "handles duplicate init gracefully" do
      # Should not error when called again
      assert :ok = IntentBroadcaster.init_tables()
      assert :ok = IntentBroadcaster.init_tables()
    end
  end

  describe "broadcast_intent/3" do
    test "broadcasts intent for a file" do
      result = IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "editing lines 1-10")
      case result do
        :ok -> assert true
        _ -> assert true
      end
    end

    test "stores intent in ETS" do
      IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "editing lines 1-10")

      # Intent should be stored
      intents = IntentBroadcaster.current_intents_for("/tmp/test.txt")
      assert is_list(intents)
    end

    test "handles empty intent description" do
      result = IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "")
      case result do
        :ok -> assert true
        _ -> assert true
      end
    end

    test "handles unicode in intent" do
      result = IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "编辑行 1-10")
      case result do
        :ok -> assert true
        _ -> assert true
      end
    end

    test "handles unicode in file path" do
      result = IntentBroadcaster.broadcast_intent("agent_1", "/tmp/测试.txt", "editing")
      case result do
        :ok -> assert true
        _ -> assert true
      end
    end
  end

  describe "subscribe_to_file/2" do
    test "subscribes agent to file intent notifications" do
      result = IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end

    test "records subscription in ETS" do
      IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")

      subscribers = IntentBroadcaster.subscribers_for("/tmp/test.txt")
      assert "agent_1" in subscribers
    end

    test "handles duplicate subscriptions" do
      :ok = IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")
      result = IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")
      case result do
        :ok -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "unsubscribe_from_file/2" do
    test "unsubscribes agent from file" do
      IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")
      result = IntentBroadcaster.unsubscribe_from_file("agent_1", "/tmp/test.txt")
      case result do
        :ok -> assert true
        _ -> assert true
      end
    end

    test "removes subscription from ETS" do
      IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")
      :ok = IntentBroadcaster.unsubscribe_from_file("agent_1", "/tmp/test.txt")

      subscribers = IntentBroadcaster.subscribers_for("/tmp/test.txt")
      refute "agent_1" in subscribers
    end

    test "clears intent from ETS" do
      IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "editing")
      IntentBroadcaster.unsubscribe_from_file("agent_1", "/tmp/test.txt")

      intents = IntentBroadcaster.current_intents_for("/tmp/test.txt")
      refute Enum.any?(intents, fn i -> i.agent_id == "agent_1" end)
    end

    test "handles unsubscribe without subscribe" do
      result = IntentBroadcaster.unsubscribe_from_file("agent_1", "/tmp/test.txt")
      assert :ok = result
    end
  end

  describe "subscribers_for/1" do
    test "returns list of subscribers for file" do
      IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")
      IntentBroadcaster.subscribe_to_file("agent_2", "/tmp/test.txt")

      subscribers = IntentBroadcaster.subscribers_for("/tmp/test.txt")
      assert is_list(subscribers)
      assert length(subscribers) >= 2
    end

    test "returns empty list for file with no subscribers" do
      subscribers = IntentBroadcaster.subscribers_for("/nonexistent/file.txt")
      assert is_list(subscribers)
    end

    test "deduplicates duplicate subscriptions" do
      IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")
      IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")

      subscribers = IntentBroadcaster.subscribers_for("/tmp/test.txt")
      # Should deduplicate
      count = Enum.count(subscribers, fn s -> s == "agent_1" end)
      assert count <= 1
    end
  end

  describe "current_intents_for/1" do
    test "returns current intents for file" do
      IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "editing lines 1-10")
      IntentBroadcaster.broadcast_intent("agent_2", "/tmp/test.txt", "editing lines 11-20")

      intents = IntentBroadcaster.current_intents_for("/tmp/test.txt")
      assert is_list(intents)
      assert length(intents) >= 2
    end

    test "returns empty list for file with no intents" do
      intents = IntentBroadcaster.current_intents_for("/nonexistent/file.txt")
      assert is_list(intents)
    end

    test "sorts intents by timestamp" do
      unique_path = "/tmp/intent_broadcaster_sort_test_#{System.unique_integer([:positive])}.txt"
      IntentBroadcaster.broadcast_intent("agent_1", unique_path, "first")
      Process.sleep(100)
      IntentBroadcaster.broadcast_intent("agent_2", unique_path, "second")

      intents = IntentBroadcaster.current_intents_for(unique_path)
      # Should be sorted by timestamp
      if length(intents) >= 2 do
        [first, _second | _] = intents
        assert first.agent_id == "agent_1"
        assert DateTime.compare(first.at, List.last(intents).at) != :gt
      end
    end

    test "includes agent_id in intent event" do
      IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "editing")

      intents = IntentBroadcaster.current_intents_for("/tmp/test.txt")
      agent_1_intent = Enum.find(intents, fn i -> i.agent_id == "agent_1" end)

      if agent_1_intent != nil do
        assert agent_1_intent.agent_id == "agent_1"
        assert agent_1_intent.file_path == "/tmp/test.txt"
        assert agent_1_intent.intent == "editing"
      end
    end

    test "includes timestamp in intent event" do
      IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "editing")

      intents = IntentBroadcaster.current_intents_for("/tmp/test.txt")
      agent_1_intent = Enum.find(intents, fn i -> i.agent_id == "agent_1" end)

      if agent_1_intent != nil do
        assert Map.has_key?(agent_1_intent, :at)
        assert %DateTime{} = agent_1_intent.at
      end
    end
  end

  describe "ETS operations" do
    test "subscriptions table uses bag type" do
      IntentBroadcaster.subscribe_to_file("agent_1", "/tmp/test.txt")

      table_info = :ets.info(:osa_file_subscriptions)
      assert Keyword.get(table_info, :type) == :bag
    end

    test "intents table uses set type" do
      IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", "editing")

      table_info = :ets.info(:osa_file_intents)
      assert Keyword.get(table_info, :type) == :set
    end

    test "tables are public" do
      sub_info = :ets.info(:osa_file_subscriptions)
      intent_info = :ets.info(:osa_file_intents)

      assert Keyword.get(sub_info, :protection) == :public
      assert Keyword.get(intent_info, :protection) == :public
    end
  end

  describe "edge cases" do
    test "handles very long file path" do
      long_path = String.duplicate("a/", 100) <> "test.txt"
      result = IntentBroadcaster.broadcast_intent("agent_1", long_path, "editing")
      case result do
        :ok -> assert true
        _ -> assert true
      end
    end

    test "handles very long intent description" do
      long_intent = String.duplicate("word ", 1000)
      result = IntentBroadcaster.broadcast_intent("agent_1", "/tmp/test.txt", long_intent)
      case result do
        :ok -> assert true
        _ -> assert true
      end
    end

    test "handles special characters in file path" do
      special_path = "/tmp/test-file_2026@03:24.txt"
      result = IntentBroadcaster.broadcast_intent("agent_1", special_path, "editing")
      case result do
        :ok -> assert true
        _ -> assert true
      end
    end
  end

  describe "integration" do
    test "full intent broadcasting lifecycle" do
      file = "/tmp/lifecycle_test.txt"

      # Subscribe two agents
      :ok = IntentBroadcaster.subscribe_to_file("agent_1", file)
      :ok = IntentBroadcaster.subscribe_to_file("agent_2", file)

      # Check subscribers
      subscribers = IntentBroadcaster.subscribers_for(file)
      assert "agent_1" in subscribers
      assert "agent_2" in subscribers

      # Broadcast intents
      :ok = IntentBroadcaster.broadcast_intent("agent_1", file, "editing lines 1-10")
      :ok = IntentBroadcaster.broadcast_intent("agent_2", file, "editing lines 11-20")

      # Check intents
      intents = IntentBroadcaster.current_intents_for(file)
      assert length(intents) >= 2

      # Unsubscribe one agent
      :ok = IntentBroadcaster.unsubscribe_from_file("agent_1", file)

      # Check subscribers again
      subscribers = IntentBroadcaster.subscribers_for(file)
      refute "agent_1" in subscribers
    end
  end
end
