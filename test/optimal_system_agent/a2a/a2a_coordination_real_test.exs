defmodule OptimalSystemAgent.A2A.CoordinationRealTest do
  @moduledoc """
  Real A2A Agent Coordination Tests.

  NO MOCKS. Tests validate A2A agent coordination with real PubSub
  and real task streaming.
  """

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :a2a

  alias OptimalSystemAgent.A2A.TaskStream

  setup_all do
    # Ensure PubSub is available for tests
    case Process.whereis(OptimalSystemAgent.PubSub) do
      nil ->
        {:ok, _} =
          Supervisor.start_link(
            [{Phoenix.PubSub, name: OptimalSystemAgent.PubSub}],
            strategy: :one_for_one
          )

      _ ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Task 9: A2A PubSub Coordination Tests
  # ---------------------------------------------------------------------------

  describe "A2A - PubSub Coordination" do
    test "CRASH: agents can subscribe to task channel" do
      :ok = TaskStream.subscribe_all()

      task_id = "coord-task-#{:erlang.unique_integer([:positive])}"

      TaskStream.publish(task_id, "created", %{message: "hello", user_id: "agent-1"})

      assert_receive {:a2a_task_event, %{task_id: ^task_id, status: "created"}}, 1000
    after
      TaskStream.unsubscribe_all()
    end

    test "CRASH: multiple agents receive same task" do
      # Subscribe once via TaskStream.subscribe_all
      :ok = TaskStream.subscribe_all()

      # Subscribe a second time directly to the same topic
      :ok = Phoenix.PubSub.subscribe(OptimalSystemAgent.PubSub, "a2a:tasks")

      # Allow subscriptions to register
      Process.sleep(50)

      task_id = "multi-task-#{:erlang.unique_integer([:positive])}"
      TaskStream.publish(task_id, "created", %{task_id: task_id})

      # Both subscriptions should receive the same event
      assert_receive {:a2a_task_event, %{task_id: ^task_id}}, 1000
      assert_receive {:a2a_task_event, %{task_id: ^task_id}}, 1000

      # Cleanup both subscriptions
      TaskStream.unsubscribe_all()
      Phoenix.PubSub.unsubscribe(OptimalSystemAgent.PubSub, "a2a:tasks")
    end

    test "CRASH: unsubscribe stops receiving messages" do
      :ok = TaskStream.subscribe_all()

      # Verify we can receive while subscribed
      task_id1 = "unsub-task-1-#{:erlang.unique_integer([:positive])}"
      TaskStream.publish(task_id1, "created", %{})
      assert_receive {:a2a_task_event, %{task_id: ^task_id1}}, 1000

      # Unsubscribe
      TaskStream.unsubscribe_all()

      # Publish after unsubscribe
      task_id2 = "unsub-task-2-#{:erlang.unique_integer([:positive])}"
      TaskStream.publish(task_id2, "created", %{})

      # Should NOT receive any message
      refute_receive {:a2a_task_event, _}, 500
    end
  end
end
