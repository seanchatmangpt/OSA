defmodule OptimalSystemAgent.Agent.Loop.CheckpointTest do
  @moduledoc """
  Chicago TDD unit tests for the Checkpoint module.

  Tests loop state persistence for crash recovery. Checkpoints are
  written as JSON files to a configurable directory so that a
  crash-restarted Loop can resume without losing conversation context.

  Functions covered:
    - checkpoint_dir/0         — returns the checkpoint directory path
    - checkpoint_path/1        — returns the full path for a session's checkpoint
    - checkpoint_state/1       — writes a checkpoint file
    - restore_checkpoint/1     — reads and restores a checkpoint
    - clear_checkpoint/1       — deletes a checkpoint file
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Loop.Checkpoint

  # Use a unique temp directory per test to avoid conflicts
  setup do
    tmp_dir = System.tmp_dir!() |> Path.join("osa_checkpoint_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    original_dir = Application.get_env(:optimal_system_agent, :checkpoint_dir)

    Application.put_env(:optimal_system_agent, :checkpoint_dir, tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)

      if original_dir do
        Application.put_env(:optimal_system_agent, :checkpoint_dir, original_dir)
      else
        Application.delete_env(:optimal_system_agent, :checkpoint_dir)
      end
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  # ---------------------------------------------------------------------------
  # checkpoint_dir/0
  # ---------------------------------------------------------------------------

  describe "checkpoint_dir/0" do
    test "returns an expanded absolute path" do
      dir = Checkpoint.checkpoint_dir()
      assert is_binary(dir)
      assert Path.type(dir) == :absolute
    end

    test "returns the configured checkpoint directory" do
      dir = Checkpoint.checkpoint_dir()
      assert String.contains?(dir, "osa_checkpoint_test_")
    end
  end

  # ---------------------------------------------------------------------------
  # checkpoint_path/1
  # ---------------------------------------------------------------------------

  describe "checkpoint_path/1" do
    test "returns a path ending with session_id.json" do
      path = Checkpoint.checkpoint_path("my-session-123")
      assert String.ends_with?(path, "my-session-123.json")
    end

    test "returns a path within the checkpoint directory" do
      dir = Checkpoint.checkpoint_dir()
      path = Checkpoint.checkpoint_path("test-session")
      assert String.starts_with?(path, dir)
    end
  end

  # ---------------------------------------------------------------------------
  # checkpoint_state/1
  # ---------------------------------------------------------------------------

  describe "checkpoint_state/1" do
    test "creates the checkpoint directory if it does not exist" do
      nested_dir = System.tmp_dir!() |> Path.join("osa_nested_#{:erlang.unique_integer([:positive])}/deep")
      Application.put_env(:optimal_system_agent, :checkpoint_dir, nested_dir)

      state = %{
        session_id: "mkdir-test",
        messages: [%{role: "user", content: "hello"}],
        iteration: 1,
        plan_mode: false,
        turn_count: 1
      }

      Checkpoint.checkpoint_state(state)

      assert File.exists?(nested_dir)
      File.rm_rf!(nested_dir)
    end

    test "writes a valid JSON checkpoint file" do
      session_id = "json-test-#{:erlang.unique_integer([:positive])}"
      state = %{
        session_id: session_id,
        messages: [%{role: "user", content: "hello world"}],
        iteration: 3,
        plan_mode: true,
        turn_count: 2
      }

      Checkpoint.checkpoint_state(state)

      path = Checkpoint.checkpoint_path(session_id)
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      assert {:ok, data} = Jason.decode(content)
      assert data["session_id"] == session_id
      assert data["iteration"] == 3
      assert data["plan_mode"] == true
      assert data["turn_count"] == 2
      assert length(data["messages"]) == 1
    end

    test "checkpoint includes timestamp" do
      session_id = "ts-test-#{:erlang.unique_integer([:positive])}"
      state = %{
        session_id: session_id,
        messages: [],
        iteration: 0,
        plan_mode: false,
        turn_count: 0
      }

      Checkpoint.checkpoint_state(state)

      path = Checkpoint.checkpoint_path(session_id)
      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)

      assert Map.has_key?(data, "checkpointed_at")
      assert is_binary(data["checkpointed_at"])
      # Should be a valid ISO8601 datetime (returns 3-tuple: {:ok, datetime, offset})
      result = DateTime.from_iso8601(data["checkpointed_at"])
      assert match?({:ok, %DateTime{}, _}, result)
    end

    test "sanitizes non-UTF-8 content in messages" do
      session_id = "sanitize-test-#{:erlang.unique_integer([:positive])}"

      # Inject invalid UTF-8 bytes into content
      invalid_content = "hello" <> <<0xFF, 0xFE>> <> "world"

      state = %{
        session_id: session_id,
        messages: [%{role: "user", content: invalid_content}],
        iteration: 1,
        plan_mode: false,
        turn_count: 1
      }

      # Should not crash
      Checkpoint.checkpoint_state(state)

      path = Checkpoint.checkpoint_path(session_id)
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      # JSON should be valid UTF-8
      assert String.valid?(content)
      assert {:ok, _data} = Jason.decode(content)
    end

    test "handles messages with atom keys" do
      session_id = "atom-key-test-#{:erlang.unique_integer([:positive])}"
      state = %{
        session_id: session_id,
        messages: [%{role: "assistant", content: "I'll help you.", tool_calls: []}],
        iteration: 2,
        plan_mode: false,
        turn_count: 1
      }

      Checkpoint.checkpoint_state(state)

      path = Checkpoint.checkpoint_path(session_id)
      {:ok, content} = File.read(path)
      assert {:ok, data} = Jason.decode(content)

      [msg] = data["messages"]
      assert msg["role"] == "assistant"
    end

    test "overwrites previous checkpoint for the same session" do
      session_id = "overwrite-test-#{:erlang.unique_integer([:positive])}"

      state_v1 = %{
        session_id: session_id,
        messages: [%{role: "user", content: "first message"}],
        iteration: 1,
        plan_mode: false,
        turn_count: 1
      }

      Checkpoint.checkpoint_state(state_v1)

      state_v2 = %{state_v1 | iteration: 5, turn_count: 3}
      Checkpoint.checkpoint_state(state_v2)

      path = Checkpoint.checkpoint_path(session_id)
      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)

      assert data["iteration"] == 5
      assert data["turn_count"] == 3
    end
  end

  # ---------------------------------------------------------------------------
  # restore_checkpoint/1
  # ---------------------------------------------------------------------------

  describe "restore_checkpoint/1" do
    test "returns empty map when no checkpoint exists" do
      result = Checkpoint.restore_checkpoint("nonexistent-session-#{:erlang.unique_integer([:positive])}")
      assert result == %{}
    end

    test "restores state from a valid checkpoint" do
      session_id = "restore-test-#{:erlang.unique_integer([:positive])}"

      original_state = %{
        session_id: session_id,
        messages: [
          %{role: "user", content: "fix the bug"},
          %{role: "assistant", content: "I'll look at it."},
          %{role: "tool", content: "file contents here"}
        ],
        iteration: 4,
        plan_mode: true,
        turn_count: 2
      }

      Checkpoint.checkpoint_state(original_state)

      restored = Checkpoint.restore_checkpoint(session_id)

      assert is_map(restored)
      assert restored.messages != nil
      assert length(restored.messages) == 3
      assert restored.iteration == 4
      assert restored.plan_mode == true
      assert restored.turn_count == 2
    end

    test "restored messages have atom keys" do
      session_id = "atom-restore-#{:erlang.unique_integer([:positive])}"

      state = %{
        session_id: session_id,
        messages: [%{role: "user", content: "hello"}],
        iteration: 1,
        plan_mode: false,
        turn_count: 1
      }

      Checkpoint.checkpoint_state(state)

      restored = Checkpoint.restore_checkpoint(session_id)
      [msg | _] = restored.messages

      # Keys should be atoms (converted from JSON string keys)
      assert Map.has_key?(msg, :role)
      assert Map.has_key?(msg, :content)
      assert msg.role == "user"
    end

    test "returns empty map for corrupted JSON" do
      session_id = "corrupt-test-#{:erlang.unique_integer([:positive])}"
      path = Checkpoint.checkpoint_path(session_id)

      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "not valid json {{{")

      result = Checkpoint.restore_checkpoint(session_id)
      assert result == %{}
    end

    test "handles missing fields gracefully (defaults to 0/false)" do
      session_id = "partial-test-#{:erlang.unique_integer([:positive])}"
      path = Checkpoint.checkpoint_path(session_id)

      # Write a checkpoint with minimal fields
      File.mkdir_p!(Path.dirname(path))
      partial_data = %{session_id: session_id, messages: []}
      File.write!(path, Jason.encode!(partial_data))

      restored = Checkpoint.restore_checkpoint(session_id)

      assert restored.iteration == 0
      assert restored.plan_mode == false
      assert restored.turn_count == 0
      assert restored.messages == []
    end
  end

  # ---------------------------------------------------------------------------
  # clear_checkpoint/1
  # ---------------------------------------------------------------------------

  describe "clear_checkpoint/1" do
    test "deletes an existing checkpoint file" do
      session_id = "clear-test-#{:erlang.unique_integer([:positive])}"

      state = %{
        session_id: session_id,
        messages: [],
        iteration: 0,
        plan_mode: false,
        turn_count: 0
      }

      Checkpoint.checkpoint_state(state)
      path = Checkpoint.checkpoint_path(session_id)
      assert File.exists?(path)

      assert :ok = Checkpoint.clear_checkpoint(session_id)
      refute File.exists?(path)
    end

    test "returns :ok for nonexistent checkpoint (no crash)" do
      result = Checkpoint.clear_checkpoint("nonexistent-#{:erlang.unique_integer([:positive])}")
      assert result == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Round-trip: checkpoint -> restore
  # ---------------------------------------------------------------------------

  describe "round-trip: checkpoint_state then restore_checkpoint" do
    test "preserves messages, iteration, plan_mode, and turn_count" do
      session_id = "roundtrip-#{:erlang.unique_integer([:positive])}"

      original = %{
        session_id: session_id,
        messages: [
          %{role: "user", content: "create a new module"},
          %{role: "assistant", content: "I'll create it now.", tool_calls: [%{id: "tc1", name: "file_write", arguments: %{"path" => "/tmp/test.ex"}}]},
          %{role: "tool", tool_call_id: "tc1", name: "file_write", content: "File created successfully"}
        ],
        iteration: 7,
        plan_mode: false,
        turn_count: 3
      }

      Checkpoint.checkpoint_state(original)
      restored = Checkpoint.restore_checkpoint(session_id)

      assert restored.iteration == original.iteration
      assert restored.plan_mode == original.plan_mode
      assert restored.turn_count == original.turn_count
      assert length(restored.messages) == length(original.messages)

      # Verify message content is preserved
      [user_msg, asst_msg, tool_msg] = restored.messages
      assert user_msg.role == "user"
      assert user_msg.content == "create a new module"
      assert asst_msg.role == "assistant"
      assert tool_msg.role == "tool"
    end

    test "round-trip with empty messages" do
      session_id = "empty-rt-#{:erlang.unique_integer([:positive])}"

      original = %{
        session_id: session_id,
        messages: [],
        iteration: 0,
        plan_mode: true,
        turn_count: 0
      }

      Checkpoint.checkpoint_state(original)
      restored = Checkpoint.restore_checkpoint(session_id)

      assert restored.messages == []
      assert restored.iteration == 0
      assert restored.plan_mode == true
    end
  end
end
