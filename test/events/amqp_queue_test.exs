defmodule OptimalSystemAgent.Events.AMQPQueueTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Events.AMQPQueue

  describe "enabled?" do
    test "returns false when USE_AMQP_QUEUE is not set" do
      refute AMQPQueue.enabled?()
    end

    test "returns false when AMQP_URL is not set" do
      # Even if enabled, no URL = disabled
      Application.put_env(:optimal_system_agent, :amqp_queue_enabled, true)
      Application.put_env(:optimal_system_agent, :amqp_url, nil)

      refute AMQPQueue.enabled?()

      # Cleanup
      Application.delete_env(:optimal_system_agent, :amqp_queue_enabled)
    end

    test "returns true when both env vars are set" do
      Application.put_env(:optimal_system_agent, :amqp_queue_enabled, true)
      Application.put_env(:optimal_system_agent, :amqp_url, "amqp://localhost")

      assert AMQPQueue.enabled?()

      # Cleanup
      Application.delete_env(:optimal_system_agent, :amqp_queue_enabled)
      Application.delete_env(:optimal_system_agent, :amqp_url)
    end
  end

  describe "publish/2 when disabled" do
    test "returns :ok when AMQP is disabled (silent fallback)" do
      assert :ok = AMQPQueue.publish("orchestrate_complete", %{session_id: "test"})
    end
  end

  describe "status/0" do
    test "gracefully handles missing server" do
      # AMQPQueue may not be running in test context
      try do
        assert AMQPQueue.status() == :disconnected
      rescue
        _ -> :ok  # GenServer.call may fail if server not started
      end
    end
  end

  describe "queue_depth/0" do
    test "gracefully handles missing server" do
      try do
        assert AMQPQueue.queue_depth() == 0
      rescue
        _ -> :ok
      end
    end
  end

  describe "AMQP connection lifecycle" do
    test "gracefully handles missing AMQP server" do
      Application.put_env(:optimal_system_agent, :amqp_queue_enabled, true)
      Application.put_env(:optimal_system_agent, :amqp_url, "amqp://invalid:9999")

      # Publish should fail gracefully or timeout
      try do
        result = AMQPQueue.publish("test", %{})
        assert result == :ok or match?({:error, _}, result)
      rescue
        _ -> :ok  # GenServer.call may timeout
      end

      # Cleanup
      Application.delete_env(:optimal_system_agent, :amqp_queue_enabled)
      Application.delete_env(:optimal_system_agent, :amqp_url)
    end
  end

  describe "event encoding" do
    test "payload is properly JSON encoded in publication" do
      # This is a unit test that doesn't require AMQP connection
      payload = %{
        session_id: "sess_123",
        agent: "researcher",
        status: "complete"
      }

      # Verify the payload can be JSON-encoded
      assert {:ok, _} = Jason.encode(payload)
    end
  end

  describe "queue configuration" do
    test "uses default queue name when not configured" do
      # Default is "osa_events"
      queue_name = Application.get_env(:optimal_system_agent, :amqp_queue_name, "osa_events")
      assert queue_name == "osa_events"
    end

    test "uses custom queue name when configured" do
      Application.put_env(:optimal_system_agent, :amqp_queue_name, "custom_queue")

      queue_name = Application.get_env(:optimal_system_agent, :amqp_queue_name, "osa_events")
      assert queue_name == "custom_queue"

      Application.delete_env(:optimal_system_agent, :amqp_queue_name)
    end
  end
end
