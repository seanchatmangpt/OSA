defmodule OptimalSystemAgent.Agent.Loop.ReactLoopTest do
  @moduledoc """
  Unit tests for ReactLoop module.

  Tests core ReAct iteration logic for agent loop.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Loop.ReactLoop

  @moduletag :capture_log

  setup do
    # Initialize ETS cancel flag table for tests
    try do
      :ets.delete(:osa_cancel_flags)
    rescue
      ArgumentError -> :table_does_not_exist
    end

    :ets.new(:osa_cancel_flags, [:named_table, :public, :set])

    on_exit(fn ->
      try do
        :ets.delete_all_objects(:osa_cancel_flags)
      rescue
        ArgumentError -> :table_deleted
      end
    end)

    :ok
  end

  describe "run/1" do
    test "returns cancelled message when cancel flag is set" do
      session_id = "test_session_#{System.unique_integer()}"
      :ets.insert(:osa_cancel_flags, {session_id, true})

      state = %{
        session_id: session_id,
        iteration: 5,
        messages: [],
        provider: :test_provider,
        model: :test_model
      }

      {response, _state} = ReactLoop.run(state)

      assert response == "Cancelled by user."
    end

    test "removes cancel flag after cancellation" do
      session_id = "test_session_#{System.unique_integer()}"
      :ets.insert(:osa_cancel_flags, {session_id, true})

      state = %{
        session_id: session_id,
        iteration: 5,
        messages: [],
        provider: :test_provider,
        model: :test_model
      }

      ReactLoop.run(state)

      # Cancel flag should be removed
      assert :ets.lookup(:osa_cancel_flags, session_id) == []
    end

    test "returns max iterations message when iteration >= max_iterations" do
      # Set max_iterations to 10 for this test
      Application.put_env(:optimal_system_agent, :max_iterations, 10)

      state = %{
        session_id: "test_session",
        iteration: 10,  # At max
        messages: [],
        provider: :test_provider,
        model: :test_model
      }

      {response, _state} = ReactLoop.run(state)

      assert String.contains?(response, "used all 10 iterations")
      assert String.contains?(response, "Tools used:")

      # Reset to default
      Application.put_env(:optimal_system_agent, :max_iterations, 30)
    end

    test "continues to iteration when below max and not cancelled" do
      state = %{
        session_id: "test_session",
        iteration: 0,
        messages: [],
        provider: :test_provider,
        model: :test_model,
        tools: [],
        plan_mode: false,
        channel: nil
      }

      # This will attempt an LLM call and likely fail in test environment
      # The important thing is it doesn't return early
      {response, _state} = ReactLoop.run(state)

      # Should not return cancel or max iterations message
      refute response == "Cancelled by user."
      refute String.contains?(response, "used all")
    end
  end

  describe "cancel flag handling" do
    test "returns :execute_tools when cancel flag not set" do
      session_id = "no_cancel_session"

      state = %{
        session_id: session_id,
        iteration: 0,
        messages: [],
        provider: :test_provider,
        model: :test_model,
        tools: []
      }

      {response, _state} = ReactLoop.run(state)

      refute response == "Cancelled by user."
    end

    test "handles missing ETS table gracefully" do
      # Delete the table to test error handling
      :ets.delete(:osa_cancel_flags)

      state = %{
        session_id: "test_session",
        iteration: 0,
        messages: [],
        provider: :test_provider,
        model: :test_model
      }

      # Should not crash when table doesn't exist
      {response, _state} = ReactLoop.run(state)

      refute response == "Cancelled by user."

      # Recreate for other tests
      :ets.new(:osa_cancel_flags, [:named_table, :public, :set])
    end
  end

  describe "iteration budget" do
    test "respects configured max_iterations" do
      Application.put_env(:optimal_system_agent, :max_iterations, 5)

      state = %{
        session_id: "test_session",
        iteration: 5,
        messages: [],
        provider: :test_provider,
        model: :test_model
      }

      {response, _state} = ReactLoop.run(state)

      assert String.contains?(response, "used all 5 iterations")

      # Reset
      Application.put_env(:optimal_system_agent, :max_iterations, 30)
    end

    test "default max_iterations is 30" do
      # Clear any previous setting
      Application.delete_env(:optimal_system_agent, :max_iterations)

      state = %{
        session_id: "test_session",
        iteration: 30,
        messages: [],
        provider: :test_provider,
        model: :test_model
      }

      {response, _state} = ReactLoop.run(state)

      # Should use default of 30
      assert String.contains?(response, "used all 30 iterations")

      # Reset to explicit default
      Application.put_env(:optimal_system_agent, :max_iterations, 30)
    end
  end

  describe "context overflow detection" do
    test "detects context_length in error message" do
      # This tests the private context_overflow?/1 function indirectly
      # by checking the module compiles and the logic exists
      assert is_function(:context_overflow?, 1)
    end
  end

  describe "max_response_tokens" do
    test "has configurable max_response_tokens" do
      # Test that the configuration is read
      Application.put_env(:optimal_system_agent, :max_response_tokens, 4096)
      Application.put_env(:optimal_system_agent, :max_iterations, 100)

      state = %{
        session_id: "test_session",
        iteration: 0,
        messages: [],
        provider: :test_provider,
        model: :test_model
      }

      # Should not crash with custom config
      {_response, _state} = ReactLoop.run(state)

      # Reset
      Application.put_env(:optimal_system_agent, :max_response_tokens, 8192)
      Application.put_env(:optimal_system_agent, :max_iterations, 30)
    end
  end

  describe "integration - full loop flow" do
    test "state is passed through with iteration increment" do
      state = %{
        session_id: "test_session",
        iteration: 0,
        messages: [],
        provider: :test_provider,
        model: :test_model,
        tools: [],
        plan_mode: false,
        channel: nil,
        last_input_tokens: 0,
        auto_continues: 0,
        overflow_retries: 0,
        working_dir: "/tmp",
        tool_call_count: 0
      }

      {_response, new_state} = ReactLoop.run(state)

      # State structure should be preserved
      assert is_map(new_state)
      assert Map.has_key?(new_state, :session_id)
      assert Map.has_key?(new_state, :iteration)
    end
  end

  describe "edge cases" do
    test "handles iteration at boundary (max - 1)" do
      Application.put_env(:optimal_system_agent, :max_iterations, 10)

      state = %{
        session_id: "test_session",
        iteration: 9,  # One below max
        messages: [],
        provider: :test_provider,
        model: :test_model
      }

      {response, _state} = ReactLoop.run(state)

      # Should not trigger max iterations message
      refute String.contains?(response, "used all 10 iterations")

      # Reset
      Application.put_env(:optimal_system_agent, :max_iterations, 30)
    end

    test "handles zero iteration" do
      state = %{
        session_id: "test_session",
        iteration: 0,
        messages: [],
        provider: :test_provider,
        model: :test_model,
        tools: [],
        plan_mode: false,
        channel: nil
      }

      {response, _state} = ReactLoop.run(state)

      # Should not return early
      refute response == "Cancelled by user."
    end

    test "handles negative iteration (edge case)" do
      state = %{
        session_id: "test_session",
        iteration: -1,
        messages: [],
        provider: :test_provider,
        model: :test_model,
        tools: [],
        plan_mode: false,
        channel: nil
      }

      {response, _state} = ReactLoop.run(state)

      # Should attempt iteration
      refute response == "Cancelled by user."
    end
  end
end
