defmodule OptimalSystemAgent.A2A.TaskStreamTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.A2A.TaskStream

  setup_all do
    # Ensure PubSub is available for tests
    case Process.whereis(OptimalSystemAgent.PubSub) do
      nil ->
        {:ok, _} = Phoenix.PubSub.start_link(name: OptimalSystemAgent.PubSub)

      _ ->
        :ok
    end

    :ok
  end

  describe "subscribe/1 and publish/3" do
    test "receives published task events" do
      task_id = "test-task-#{System.unique_integer([:positive])}"
      :ok = TaskStream.subscribe(task_id)

      TaskStream.publish(task_id, "created", %{message: "hello"})

      receive do
        {:a2a_task_event, event} ->
          assert event.task_id == task_id
          assert event.status == "created"
          assert event.metadata.message == "hello"
          assert is_binary(event.timestamp)
      after
        500 -> flunk("Did not receive task event")
      end

      TaskStream.unsubscribe(task_id)
    end

    test "receives multiple events in order" do
      task_id = "test-task-order-#{System.unique_integer([:positive])}"
      :ok = TaskStream.subscribe(task_id)

      TaskStream.publish(task_id, "created", %{})
      TaskStream.publish(task_id, "running", %{})
      TaskStream.publish(task_id, "completed", %{})

      events =
        receive_all(3, 500, [])

      assert length(events) == 3
      assert Enum.map(events, & &1.status) == ["created", "running", "completed"]

      TaskStream.unsubscribe(task_id)
    end
  end

  describe "subscribe_all/0" do
    test "receives events from all tasks" do
      :ok = TaskStream.subscribe_all()

      task_id = "test-task-all-#{System.unique_integer([:positive])}"
      TaskStream.publish(task_id, "created", %{})

      receive do
        {:a2a_task_event, event} ->
          assert event.task_id == task_id
      after
        500 -> flunk("Did not receive task event via subscribe_all")
      end

      TaskStream.unsubscribe_all()
    end
  end

  describe "publish/3" do
    test "publishes without error" do
      task_id = "test-task-pub-#{System.unique_integer([:positive])}"
      assert {:ok, _count} = TaskStream.publish(task_id, "running", %{step: 1})
    end

    test "publishes with empty metadata" do
      task_id = "test-task-pub2-#{System.unique_integer([:positive])}"
      assert {:ok, _count} = TaskStream.publish(task_id, "completed", %{})
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────

  defp receive_all(0, _timeout, acc), do: Enum.reverse(acc)

  defp receive_all(count, timeout, acc) do
    receive do
      {:a2a_task_event, event} ->
        receive_all(count - 1, timeout, [event | acc])
    after
      timeout ->
        Enum.reverse(acc)
    end
  end
end
