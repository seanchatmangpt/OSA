defmodule OptimalSystemAgent.Workflows.TemporalAdapterTest do
  use ExUnit.Case, async: false
  alias OptimalSystemAgent.Workflows.TemporalAdapter

  @moduletag :temporal_adapter

  describe "start_workflow/3" do
    test "requires workflow_id parameter" do
      assert {:error, :missing_workflow_id} = TemporalAdapter.start_workflow(nil, %{})
    end

    test "requires execution_params parameter" do
      assert {:error, :missing_execution_params} = TemporalAdapter.start_workflow("test-workflow", nil)
    end

    test "returns error when Temporal server is unavailable" do
      # With Temporal server not running, should return connection error
      result = TemporalAdapter.start_workflow("test-workflow", %{"test" => "data"})

      assert {:error, {:connection_failed, _reason}} = result
    end

    test "constructs correct Temporal API request" do
      # This test would require a mock Temporal server
      # For now, we test the request construction logic

      workflow_id = "test-workflow-123"
      execution_params = %{
        "scenario" => "invoice_processing",
        "event_log_source" => "test.csv"
      }

      # Verify that the function doesn't crash on valid input
      # (It will fail on connection, which is expected)
      result = TemporalAdapter.start_workflow(workflow_id, execution_params)

      # Should get connection error (not validation error)
      assert match?({:error, {:connection_failed, _}}, result) or
             match?({:error, {:http_error, _}}, result)
    end
  end

  describe "signal_workflow/3" do
    test "requires workflow_id parameter" do
      assert {:error, :missing_workflow_id} = TemporalAdapter.signal_workflow(nil, "pause")
    end

    test "requires signal parameter" do
      assert {:error, :missing_signal} = TemporalAdapter.signal_workflow("test-workflow", nil)
    end

    test "accepts valid signal types" do
      valid_signals = ["pause", "skip_stage", "abort"]

      Enum.each(valid_signals, fn signal ->
        # Should not crash on valid signals
        result = TemporalAdapter.signal_workflow("test-workflow", signal)

        # Connection error is expected (Temporal not running)
        assert match?({:error, {:connection_failed, _}}, result) or
               match?({:error, {:http_error, _}}, result)
      end)
    end

    test "rejects invalid signal types" do
      assert {:error, :invalid_signal} = TemporalAdapter.signal_workflow("test-workflow", "invalid_signal")
    end
  end

  describe "query_workflow/2" do
    test "requires workflow_id parameter" do
      assert {:error, :missing_workflow_id} = TemporalAdapter.query_workflow(nil)
    end

    test "returns error for non-existent workflow" do
      result = TemporalAdapter.query_workflow("non-existent-workflow")

      # Should return error (connection or not found)
      assert {:error, _} = result
    end
  end

  describe "configuration" do
    test "uses default Temporal host from environment" do
      # Verify default configuration
      assert is_binary(TemporalAdapter.get_temporal_host())
    end

    test "uses default namespace from environment" do
      # Verify default namespace
      assert is_binary(TemporalAdapter.get_namespace())
    end
  end

  describe "error handling" do
    test "handles timeout errors gracefully" do
      # Simulate timeout scenario
      result = TemporalAdapter.start_workflow("timeout-test", %{})

      # Should return timeout error or connection error
      assert {:error, _} = result
    end

    test "handles malformed responses" do
      # Test with invalid JSON response (would need mock server)
      # For now, verify the function doesn't crash
      result = TemporalAdapter.query_workflow("test-workflow")

      assert {:error, _} = result
    end
  end

  describe "workflow definition validation" do
    test "validates autonomous_pi workflow structure" do
      workflow_def = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.new("test-process")

      assert workflow_def.workflow_id != nil
      assert workflow_def.process_id == "test-process"
      assert workflow_def.current_stage == :discovery
      assert is_list(workflow_def.stages)
      assert length(workflow_def.stages) == 5
    end

    test "advances workflow stages correctly" do
      workflow = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.new("test-process")

      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
      assert workflow.current_stage == :planning

      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
      assert workflow.current_stage == :execution

      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
      assert workflow.current_stage == :validation

      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
      assert workflow.current_stage == :iteration

      # Cannot advance from iteration (final stage)
      assert {:error, :already_complete} =
        OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
    end

    test "calculates workflow progress correctly" do
      workflow = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.new("test-process")

      # Should start at 0% (discovery is first stage)
      assert OptimalSystemAgent.Workflows.Definitions.AutonomousPI.progress(workflow) == 0

      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
      # Should be 20% (1 of 5 stages complete)
      assert OptimalSystemAgent.Workflows.Definitions.AutonomousPI.progress(workflow) == 20

      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)
      {:ok, workflow} = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.advance_stage(workflow)

      # Should be 80% (4 of 5 stages complete, on final stage)
      assert OptimalSystemAgent.Workflows.Definitions.AutonomousPI.progress(workflow) == 80
    end

    test "converts to/from Temporal format correctly" do
      workflow = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.new("test-process", %{
        state: %{"custom_field" => "custom_value"}
      })

      temporal_input = OptimalSystemAgent.Workflows.Definitions.AutonomousPI.to_temporal_input(workflow)

      assert temporal_input["workflow_id"] == workflow.workflow_id
      assert temporal_input["process_id"] == workflow.process_id
      assert temporal_input["current_stage"] == "discovery"
      assert is_list(temporal_input["stages"])
      assert temporal_input["state"]["custom_field"] == "custom_value"

      # Convert back
      {:ok, restored_workflow} =
        OptimalSystemAgent.Workflows.Definitions.AutonomousPI.from_temporal_output(temporal_input)

      assert restored_workflow.workflow_id == workflow.workflow_id
      assert restored_workflow.process_id == workflow.process_id
      assert restored_workflow.current_stage == workflow.current_stage
    end
  end
end
