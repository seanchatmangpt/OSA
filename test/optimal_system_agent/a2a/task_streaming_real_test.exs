defmodule OptimalSystemAgent.A2A.TaskStreamingRealTest do
  @moduledoc """
  A2A Task Streaming Tests.

  NO MOCKS. Tests validate real task streaming via PubSub with
  telemetry emission verification.
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
  # Task 10: A2A Task Streaming Tests
  # ---------------------------------------------------------------------------

  describe "A2A - Task Streaming" do
    test "CRASH: task streams updates to subscribers" do
      task_id = "task-4"

      :ok = TaskStream.subscribe(task_id)

      # Publish 5 updates with progress metadata
      for percent <- [20, 40, 60, 80, 100] do
        TaskStream.publish(task_id, "running", %{progress: percent})
      end

      # Collect all 5 updates
      updates =
        receive_all_stream_events(5, 1000, [])
        |> Enum.map(fn %{metadata: %{progress: p}} -> p end)

      assert updates == [20, 40, 60, 80, 100]

      TaskStream.unsubscribe(task_id)
    end

    test "CRASH: task completion emits [:osa, :a2a, :task_stream] telemetry" do
      test_pid = self()
      handler_name = :"test_task_stream_telemetry_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :a2a, :task_stream],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, measurements, metadata})
        end,
        nil
      )

      task_id = "telemetry-task-#{:erlang.unique_integer()}"

      # Subscribe to receive PubSub events too
      :ok = TaskStream.subscribe(task_id)

      # Publish a completion event
      TaskStream.publish(task_id, "completed", %{output: "done"})

      # Verify telemetry was emitted with duration
      assert_receive {:telemetry_event, measurements, metadata}, 1000
      assert Map.has_key?(measurements, :duration)
      assert is_integer(measurements.duration)
      assert metadata.task_id == task_id
      assert metadata.status == "completed"

      # Verify PubSub event was also received
      assert_receive {:a2a_task_event, %{task_id: ^task_id, status: "completed"}}, 1000

      :telemetry.detach(handler_name)
      TaskStream.unsubscribe(task_id)
    end

    test "CRASH: multiple subscribers receive same task updates" do
      task_id = "multi-sub-task-#{:erlang.unique_integer([:positive])}"

      # Subscribe once via TaskStream.subscribe
      :ok = TaskStream.subscribe(task_id)

      # Subscribe a second time directly to the task-specific topic
      :ok = Phoenix.PubSub.subscribe(OptimalSystemAgent.PubSub, "a2a:task:#{task_id}")

      # Allow subscriptions to register
      Process.sleep(50)

      # Publish 3 updates
      for step <- [1, 2, 3] do
        TaskStream.publish(task_id, "running", %{step: step})
      end

      # First subscription receives all 3
      assert_receive {:a2a_task_event, %{metadata: %{step: 1}}}, 1000
      assert_receive {:a2a_task_event, %{metadata: %{step: 2}}}, 1000
      assert_receive {:a2a_task_event, %{metadata: %{step: 3}}}, 1000

      # Second subscription also receives all 3
      assert_receive {:a2a_task_event, %{metadata: %{step: 1}}}, 1000
      assert_receive {:a2a_task_event, %{metadata: %{step: 2}}}, 1000
      assert_receive {:a2a_task_event, %{metadata: %{step: 3}}}, 1000

      # Cleanup
      TaskStream.unsubscribe(task_id)
      Phoenix.PubSub.unsubscribe(OptimalSystemAgent.PubSub, "a2a:task:#{task_id}")
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp receive_all_stream_events(0, _timeout, acc), do: Enum.reverse(acc)

  defp receive_all_stream_events(count, timeout, acc) do
    receive do
      {:a2a_task_event, event} ->
        receive_all_stream_events(count - 1, timeout, [event | acc])
    after
      timeout ->
        Enum.reverse(acc)
    end
  end
end
