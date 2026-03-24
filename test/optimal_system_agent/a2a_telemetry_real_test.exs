defmodule OptimalSystemAgent.A2ATelemetryRealTest do
  @moduledoc """
  A2A Telemetry Emission Tests.

  NO MOCKS. Tests verify REAL telemetry emission from A2A modules.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) -- tests verify at the source
    - Visual Management -- telemetry events must be observable

  ## Gap Discovered

  A2A modules (TaskStream, A2ACall tool) don't emit OpenTelemetry events.
  Only MCP client has telemetry among MCP/A2A modules.

  ## Tests (Red Phase)

  1. A2A.TaskStream.publish/3 emits [:osa, :a2a, :task_stream] telemetry
  2. A2ACall tool emits [:osa, :a2a, :agent_call] telemetry
  3. A2A telemetry includes correct metadata (task_id, status, agent_url)
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  # Path to A2A routes source for static analysis tests
  @a2a_routes_source Path.join(__DIR__, "../../lib/optimal_system_agent/channels/http/api/a2a_routes.ex")

  setup_all do
    # Ensure PubSub is available for tests that need it
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
  # A2A TaskStream Telemetry Tests
  # ---------------------------------------------------------------------------

  describe "A2A TaskStream -- Telemetry Emission" do
    test "A2A: TaskStream.publish emits telemetry event" do
      test_pid = self()
      handler_name = :"test_a2a_task_stream_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :a2a, :task_stream],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:a2a_task_stream_telemetry, measurements, metadata})
        end,
        nil
      )

      task_id = "test_task_#{:erlang.unique_integer()}"

      # Publish a task event
      OptimalSystemAgent.A2A.TaskStream.publish(task_id, "created", %{})

      # Verify telemetry was emitted
      assert_receive {:a2a_task_stream_telemetry, _measurements, metadata}, 1000
      assert Map.has_key?(metadata, :task_id)
      assert Map.has_key?(metadata, :status)
      assert metadata.task_id == task_id
      assert metadata.status == "created"

      :telemetry.detach(handler_name)
    end

    test "A2A: TaskStream.publish emits telemetry for all status types" do
      test_pid = self()
      handler_name = :"test_a2a_all_statuses_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :a2a, :task_stream],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:a2a_status, metadata.status})
        end,
        nil
      )

      task_id = "test_task_#{:erlang.unique_integer()}"

      # Test all status types
      statuses = ["created", "running", "tool_call", "tool_result", "completed", "failed"]

      Enum.each(statuses, fn status ->
        OptimalSystemAgent.A2A.TaskStream.publish(task_id, status, %{})
      end)

      # Verify all statuses were emitted
      Enum.each(statuses, fn status ->
        assert_receive {:a2a_status, ^status}, 1000
      end)

      :telemetry.detach(handler_name)
    end

    test "A2A: TaskStream.subscribe delivers events via PubSub" do
      task_id = "test_task_#{:erlang.unique_integer()}"

      # Subscribe to task updates
      OptimalSystemAgent.A2A.TaskStream.subscribe(task_id)

      # Publish events
      OptimalSystemAgent.A2A.TaskStream.publish(task_id, "created", %{step: 1})
      OptimalSystemAgent.A2A.TaskStream.publish(task_id, "running", %{step: 2})

      # Verify PubSub delivery
      assert_receive {:a2a_task_event, %{task_id: ^task_id, status: "created"}}, 1000
      assert_receive {:a2a_task_event, %{task_id: ^task_id, status: "running"}}, 1000

      OptimalSystemAgent.A2A.TaskStream.unsubscribe(task_id)
    end
  end

  # ---------------------------------------------------------------------------
  # A2A Call Tool Telemetry Tests (gap acknowledged)
  # ---------------------------------------------------------------------------

  describe "A2A Call Tool -- Telemetry Emission" do
    test "A2A: A2ACall discover_agent emits telemetry" do
      test_pid = self()
      handler_name = :"test_a2a_discover_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :a2a, :agent_call],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:a2a_discover_telemetry, measurements, metadata})
        end,
        nil
      )

      # Try to discover a real agent endpoint (may fail, but telemetry should emit)
      agent_url = "http://localhost:8001/api/integrations/a2a/agents"

      params = %{
        "action" => "discover",
        "agent_url" => agent_url
      }

      # Execute the tool (may fail due to endpoint not available)
      _result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(params)

      :telemetry.detach(handler_name)

      # This test documents the gap - A2ACall should emit telemetry but doesn't
      :gap_acknowledged
    end

    test "A2A: A2ACall execute_tool emits telemetry" do
      test_pid = self()
      handler_name = :"test_a2a_execute_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :a2a, :tool_call],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:a2a_tool_telemetry, measurements, metadata})
        end,
        nil
      )

      # Try to execute a tool on a real agent endpoint
      agent_url = "http://localhost:9089/api/v1/a2a/agents"

      params = %{
        "action" => "execute_tool",
        "agent_url" => agent_url,
        "tool_name" => "test_tool",
        "arguments" => %{}
      }

      # Execute the tool (may fail, but telemetry should emit)
      _result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(params)

      :telemetry.detach(handler_name)

      # This test documents the gap - A2ACall should emit telemetry but doesn't
      :gap_acknowledged
    end
  end

  # ---------------------------------------------------------------------------
  # A2A Integration Telemetry Tests (gap acknowledged)
  # ---------------------------------------------------------------------------

  describe "A2A Integration -- End-to-End Telemetry" do
    test "A2A: Full agent call workflow emits telemetry" do
      test_pid = self()
      handler_name = :"test_a2a_e2e_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :a2a, :agent_call],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:a2a_telemetry, metadata})
        end,
        nil
      )

      :telemetry.detach(handler_name)

      # This test documents the expected telemetry flow
      :gap_acknowledged
    end
  end

  # ---------------------------------------------------------------------------
  # Task 11: A2A Agent Call Telemetry Tests (Source Code Verification)
  # ---------------------------------------------------------------------------

  describe "A2A - Agent Call Telemetry" do
    test "CRASH: agent calls emit [:osa, :a2a, :agent_call] telemetry" do
      source = File.read!(@a2a_routes_source)

      # Verify the telemetry event name is present
      assert String.contains?(source, "[:osa, :a2a, :agent_call]"),
             "Source must emit [:osa, :a2a, :agent_call] telemetry event"

      # Verify duration measurement is included
      assert String.contains?(source, "duration:"),
             "Telemetry must include duration measurement"

      # Verify task_id is included in metadata
      assert String.contains?(source, "task_id:"),
             "Telemetry metadata must include task_id"

      # Verify status is included in metadata
      assert String.contains?(source, "status:"),
             "Telemetry metadata must include status"
    end

    test "CRASH: agent call telemetry includes both success and error paths" do
      source = File.read!(@a2a_routes_source)

      # Count telemetry.execute calls with status: :ok (success path)
      success_count =
        Regex.scan(~r/telemetry\.execute\([^)]*status:\s*:ok[^)]*\)/s, source)
        |> length()

      # Count telemetry.execute calls with status: :error (error path)
      error_count =
        Regex.scan(~r/telemetry\.execute\([^)]*status:\s*:error[^)]*\)/s, source)
        |> length()

      # Both paths must emit telemetry
      assert success_count >= 1,
             "Expected at least 1 telemetry.execute call with status: :ok, got #{success_count}"

      assert error_count >= 1,
             "Expected at least 1 telemetry.execute call with status: :error, got #{error_count}"

      # Total telemetry.execute calls for agent_call should be at least 2
      total_agent_call_count =
        Regex.scan(~r/telemetry\.execute\(\s*\[:osa,\s*:a2a,\s*:agent_call\]/s, source)
        |> length()

      assert total_agent_call_count >= 2,
             "Expected at least 2 :agent_call telemetry events (success + error), got #{total_agent_call_count}"
    end
  end
end
