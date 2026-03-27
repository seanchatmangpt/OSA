defmodule OptimalSystemAgent.Agent.Loop.ToolExecutorNudgeTest do
  @moduledoc """
  Tests for ToolExecutor inject_read_nudges/2.

  Tests the read-before-write nudge logic with full OTP startup.
  inject_read_nudges depends on ETS tables that are created during
  OTP application initialization.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Loop.ToolExecutor

  setup do
    # Create the ETS table if it doesn't exist so tests can exercise real logic
    table = :osa_files_read

    try do
      :ets.new(table, [:named_table, :public, :set])
    rescue
      ArgumentError -> :ok
    end

    on_exit(fn ->
      try do
        :ets.delete(table)
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  describe "inject_read_nudges/2" do
    test "returns state unchanged when no write tool calls" do
      state = %{
        session_id: "test-session-1",
        messages: [%{role: "user", content: "hello"}]
      }

      tool_calls = [
        %{name: "file_read", arguments: %{"path" => "/tmp/test.txt"}}
      ]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      assert result == state
    end

    test "returns state unchanged when tool_calls list is empty" do
      state = %{
        session_id: "test-session-2",
        messages: []
      }

      result = ToolExecutor.inject_read_nudges(state, [])
      assert result == state
    end

    test "returns state unchanged when write targets non-existent files" do
      state = %{
        session_id: "test-session-3",
        messages: []
      }

      tool_calls = [
        %{name: "file_write", arguments: %{"path" => "/tmp/nonexistent_osa_test_file.txt"}}
      ]

      # File doesn't exist, so no nudge should be injected
      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      assert result == state
    end

    test "returns state unchanged when file was already read" do
      session_id = "test-session-4"
      path = System.tmp_dir!() |> Path.join("osa_nudge_test_read.txt")
      File.write!(path, "content")

      try do
        :ets.insert(:osa_files_read, {{session_id, path}, true})
      rescue
        ArgumentError -> :ok
      end

      state = %{
        session_id: session_id,
        messages: []
      }

      tool_calls = [
        %{name: "file_edit", arguments: %{"path" => path}}
      ]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      assert result == state

      File.rm(path)
    end

    test "injects nudge message when write targets existing file not yet read" do
      session_id = "test-session-5"
      path = System.tmp_dir!() |> Path.join("osa_nudge_test_unread.txt")
      File.write!(path, "content")

      state = %{
        session_id: session_id,
        messages: []
      }

      tool_calls = [
        %{name: "file_write", arguments: %{"path" => path}}
      ]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)

      # Should have injected a system nudge message
      assert length(result.messages) == 1
      [nudge] = result.messages
      assert nudge.role == "system"
      assert String.contains?(nudge.content, "without reading")
      assert String.contains?(nudge.content, path)

      File.rm(path)
    end

    test "uses singular pronoun for single file nudge" do
      session_id = "test-session-6"
      path = System.tmp_dir!() |> Path.join("osa_nudge_single.txt")
      File.write!(path, "data")

      state = %{session_id: session_id, messages: []}

      tool_calls = [
        %{name: "file_edit", arguments: %{"path" => path}}
      ]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      [nudge] = result.messages
      # Singular: "without reading it"
      assert String.contains?(nudge.content, "without reading it")

      File.rm(path)
    end

    test "uses plural pronoun for multiple file nudges" do
      session_id = "test-session-7"
      path1 = System.tmp_dir!() |> Path.join("osa_nudge_multi_1.txt")
      path2 = System.tmp_dir!() |> Path.join("osa_nudge_multi_2.txt")
      File.write!(path1, "data1")
      File.write!(path2, "data2")

      state = %{session_id: session_id, messages: []}

      tool_calls = [
        %{name: "file_write", arguments: %{"path" => path1}},
        %{name: "file_edit", arguments: %{"path" => path2}}
      ]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      [nudge] = result.messages
      # Plural: "without reading them"
      assert String.contains?(nudge.content, "without reading them")

      File.rm(path1)
      File.rm(path2)
    end

    test "deduplicates nudges for same file across multiple tool calls" do
      session_id = "test-session-8"
      path = System.tmp_dir!() |> Path.join("osa_nudge_dedup.txt")
      File.write!(path, "data")

      state = %{session_id: session_id, messages: []}

      tool_calls = [
        %{name: "file_write", arguments: %{"path" => path}},
        %{name: "file_write", arguments: %{"path" => path}}
      ]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      # Should only inject one nudge despite two calls for same path
      assert length(result.messages) == 1

      File.rm(path)
    end

    test "does not nudge when nudge count for path has reached limit" do
      session_id = "test-session-9"
      path = System.tmp_dir!() |> Path.join("osa_nudge_limit.txt")
      File.write!(path, "data")

      # Set nudge count to 2 (the limit)
      try do
        :ets.insert(:osa_files_read, {{session_id, :nudge_count, path}, 2})
      rescue
        ArgumentError -> :ok
      end

      state = %{session_id: session_id, messages: []}

      tool_calls = [
        %{name: "file_write", arguments: %{"path" => path}}
      ]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      assert result == state

      File.rm(path)
    end

    test "preserves existing messages and appends nudge" do
      session_id = "test-session-10"
      path = System.tmp_dir!() |> Path.join("osa_nudge_preserve.txt")
      File.write!(path, "data")

      existing_messages = [
        %{role: "system", content: "You are helpful."},
        %{role: "user", content: "Edit the file."},
        %{role: "assistant", content: "I'll do that."}
      ]

      state = %{session_id: session_id, messages: existing_messages}

      tool_calls = [
        %{name: "file_edit", arguments: %{"path" => path}}
      ]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      assert length(result.messages) == 4
      # First 3 messages preserved
      assert Enum.take(result.messages, 3) == existing_messages
      # Nudge appended
      nudge = List.last(result.messages)
      assert nudge.role == "system"

      File.rm(path)
    end
  end
end
