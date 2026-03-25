defmodule OptimalSystemAgent.Agent.Loop.ToolExecutorTest do
  @moduledoc """
  Unit tests for the ToolExecutor module.

  Tests permission tier enforcement, subagent tool allowlists,
  and read-before-write nudge injection. These are pure-logic
  functions that require no running GenServer or external services.

  Functions covered:
    - permission_tier_allows?/2  — four-tier permission gate
    - subagent_tool_allowed?/2   — per-agent allowlist/denylist
    - inject_read_nudges/2       — read-before-write nudge injection
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Loop.ToolExecutor

  # ---------------------------------------------------------------------------
  # permission_tier_allows?/2
  # ---------------------------------------------------------------------------

  describe "permission_tier_allows?/2 — :full tier" do
    test "allows all tools in :full mode" do
      assert ToolExecutor.permission_tier_allows?(:full, "file_write")
      assert ToolExecutor.permission_tier_allows?(:full, "file_read")
      assert ToolExecutor.permission_tier_allows?(:full, "shell_execute")
      assert ToolExecutor.permission_tier_allows?(:full, "delegate")
      assert ToolExecutor.permission_tier_allows?(:full, "ask_user")
      assert ToolExecutor.permission_tier_allows?(:full, "memory_save")
    end
  end

  describe "permission_tier_allows?/2 — :read_only tier" do
    test "allows read-only tools" do
      read_tools = ~w(
        file_read file_glob dir_list file_grep file_search
        memory_recall session_search semantic_search
        code_symbols web_fetch web_search list_skills
        list_dir read_file grep_search
        a2a_call list_agents businessos_api
      )

      for tool <- read_tools do
        assert ToolExecutor.permission_tier_allows?(:read_only, tool),
               "Expected #{tool} to be allowed in :read_only tier"
      end
    end

    test "blocks write tools in :read_only mode" do
      write_tools = ~w(file_write file_edit multi_file_edit file_create file_delete file_move
                        git task_write memory_write memory_save download create_skill)

      for tool <- write_tools do
        refute ToolExecutor.permission_tier_allows?(:read_only, tool),
               "Expected #{tool} to be blocked in :read_only tier"
      end
    end

    test "blocks delegate and ask_user in :read_only mode" do
      refute ToolExecutor.permission_tier_allows?(:read_only, "delegate")
      refute ToolExecutor.permission_tier_allows?(:read_only, "ask_user")
    end

    test "blocks shell_execute in :read_only mode" do
      refute ToolExecutor.permission_tier_allows?(:read_only, "shell_execute")
    end
  end

  describe "permission_tier_allows?/2 — :workspace tier" do
    test "allows all read-only tools" do
      read_tools = ~w(file_read file_glob dir_list file_grep memory_recall web_search)

      for tool <- read_tools do
        assert ToolExecutor.permission_tier_allows?(:workspace, tool),
               "Expected #{tool} to be allowed in :workspace tier"
      end
    end

    test "allows workspace write tools" do
      workspace_tools = ~w(file_write file_edit multi_file_edit file_create file_delete file_move
                            git task_write memory_write memory_save download create_skill)

      for tool <- workspace_tools do
        assert ToolExecutor.permission_tier_allows?(:workspace, tool),
               "Expected #{tool} to be allowed in :workspace tier"
      end
    end

    test "blocks user-facing tools in :workspace mode" do
      refute ToolExecutor.permission_tier_allows?(:workspace, "delegate")
      refute ToolExecutor.permission_tier_allows?(:workspace, "ask_user")
    end
  end

  describe "permission_tier_allows?/2 — :subagent tier" do
    test "allows normal tools for subagents" do
      assert ToolExecutor.permission_tier_allows?(:subagent, "file_read")
      assert ToolExecutor.permission_tier_allows?(:subagent, "file_write")
      assert ToolExecutor.permission_tier_allows?(:subagent, "file_edit")
      assert ToolExecutor.permission_tier_allows?(:subagent, "shell_execute")
      assert ToolExecutor.permission_tier_allows?(:subagent, "memory_recall")
      assert ToolExecutor.permission_tier_allows?(:subagent, "web_search")
    end

    test "blocks delegate for subagents (prevents recursion)" do
      refute ToolExecutor.permission_tier_allows?(:subagent, "delegate")
    end

    test "blocks ask_user for subagents (not user-facing)" do
      refute ToolExecutor.permission_tier_allows?(:subagent, "ask_user")
    end

    test "blocks create_skill for subagents" do
      refute ToolExecutor.permission_tier_allows?(:subagent, "create_skill")
    end

    test "blocks create_agent for subagents (prevents agent spawning)" do
      refute ToolExecutor.permission_tier_allows?(:subagent, "create_agent")
    end

    test "blocks memory_save for subagents (prevents shared state corruption)" do
      refute ToolExecutor.permission_tier_allows?(:subagent, "memory_save")
    end
  end

  describe "permission_tier_allows?/2 — unknown tier" do
    test "unknown tier allows everything (fail-open)" do
      assert ToolExecutor.permission_tier_allows?(:unknown, "file_write")
      assert ToolExecutor.permission_tier_allows?(:unknown, "delegate")
      assert ToolExecutor.permission_tier_allows?(:unknown, "shell_execute")
    end
  end

  # ---------------------------------------------------------------------------
  # subagent_tool_allowed?/2
  # ---------------------------------------------------------------------------

  describe "subagent_tool_allowed?/2 — always-blocked tools take precedence" do
    test "delegate is always blocked regardless of allowlist" do
      state = %{allowed_tools: ["delegate", "file_read"]}
      refute ToolExecutor.subagent_tool_allowed?("delegate", state)
    end

    test "ask_user is always blocked regardless of allowlist" do
      state = %{allowed_tools: ["ask_user", "file_read"]}
      refute ToolExecutor.subagent_tool_allowed?("ask_user", state)
    end

    test "create_skill is always blocked regardless of allowlist" do
      state = %{allowed_tools: ["create_skill"]}
      refute ToolExecutor.subagent_tool_allowed?("create_skill", state)
    end

    test "create_agent is always blocked regardless of allowlist" do
      state = %{allowed_tools: ["create_agent"]}
      refute ToolExecutor.subagent_tool_allowed?("create_agent", state)
    end

    test "memory_save is always blocked regardless of allowlist" do
      state = %{allowed_tools: ["memory_save"]}
      refute ToolExecutor.subagent_tool_allowed?("memory_save", state)
    end
  end

  describe "subagent_tool_allowed?/2 — per-agent denylist" do
    test "tool in blocked_tools list is denied" do
      state = %{blocked_tools: ["shell_execute"]}
      refute ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end

    test "tool not in blocked_tools is allowed" do
      state = %{blocked_tools: ["shell_execute"]}
      assert ToolExecutor.subagent_tool_allowed?("file_read", state)
    end

    test "always-blocked tools still blocked even when not in denylist" do
      state = %{blocked_tools: ["file_write"]}
      refute ToolExecutor.subagent_tool_allowed?("delegate", state)
    end

    test "empty blocked_tools list does not block anything" do
      state = %{blocked_tools: []}
      assert ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end
  end

  describe "subagent_tool_allowed?/2 — per-agent allowlist" do
    test "tool in allowed_tools is permitted" do
      state = %{allowed_tools: ["file_read", "file_write"]}
      assert ToolExecutor.subagent_tool_allowed?("file_read", state)
    end

    test "tool NOT in allowed_tools is blocked when allowlist is set" do
      state = %{allowed_tools: ["file_read"]}
      refute ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end

    test "nil allowed_tools means all tools are allowed (default open)" do
      state = %{allowed_tools: nil}
      assert ToolExecutor.subagent_tool_allowed?("shell_execute", state)
      assert ToolExecutor.subagent_tool_allowed?("file_write", state)
    end

    test "empty allowed_tools list means all tools are allowed" do
      state = %{allowed_tools: []}
      assert ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end
  end

  describe "subagent_tool_allowed?/2 — denylist takes precedence over allowlist" do
    test "tool in both allowed and blocked is denied (denylist wins)" do
      state = %{allowed_tools: ["shell_execute"], blocked_tools: ["shell_execute"]}
      refute ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end

    test "tool in allowlist but not denylist is allowed" do
      state = %{allowed_tools: ["file_read", "shell_execute"], blocked_tools: ["git"]}
      assert ToolExecutor.subagent_tool_allowed?("file_read", state)
    end
  end

  describe "subagent_tool_allowed?/2 — default behavior (no overrides)" do
    test "no allowed_tools or blocked_tools: all non-blocked tools allowed" do
      state = %{}
      assert ToolExecutor.subagent_tool_allowed?("file_read", state)
      assert ToolExecutor.subagent_tool_allowed?("file_write", state)
      assert ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end

    test "default still blocks always-blocked tools" do
      state = %{}
      refute ToolExecutor.subagent_tool_allowed?("delegate", state)
      refute ToolExecutor.subagent_tool_allowed?("ask_user", state)
      refute ToolExecutor.subagent_tool_allowed?("create_agent", state)
      refute ToolExecutor.subagent_tool_allowed?("memory_save", state)
    end
  end

  # ---------------------------------------------------------------------------
  # inject_read_nudges/2
  # ---------------------------------------------------------------------------

  describe "inject_read_nudges/2 — no write tools" do
    test "returns state unchanged when no write tools in tool_calls" do
      state = %{messages: [], session_id: "test-session"}
      tool_calls = [%{name: "file_read", arguments: %{"path" => "/tmp/test.ex"}}]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      assert result == state
    end

    test "returns state unchanged for empty tool_calls" do
      state = %{messages: [], session_id: "test-session"}
      result = ToolExecutor.inject_read_nudges(state, [])
      assert result == state
    end
  end

  describe "inject_read_nudges/2 — new files (do not exist on disk)" do
    test "does not nudge for file_write to a path that does not exist" do
      state = %{messages: [], session_id: "test-session"}
      nonexistent = System.tmp_dir!() |> Path.join("nonexistent_#{:erlang.unique_integer([:positive])}.txt")

      tool_calls = [%{name: "file_write", arguments: %{"path" => nonexistent}}]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      # File does not exist, so no nudge is injected
      assert result == state
    end
  end

  describe "inject_read_nudges/2 — files that were read first" do
    setup do
      # Create a temp file that we'll read and then write
      tmp_dir = System.tmp_dir!()
      tmp_file = Path.join(tmp_dir, "nudge_test_#{:erlang.unique_integer([:positive])}.ex")

      File.write!(tmp_file, "original content")

      # Ensure the ETS table exists so file_was_read? can find our mark
      try do
        :ets.new(:osa_files_read, [:named_table, :public, :set])
      rescue
        ArgumentError -> :ok  # table already exists
      end

      on_exit(fn ->
        File.rm(tmp_file)
        try do
          :ets.delete(:osa_files_read, {:nudge_test, tmp_file})
        rescue
          ArgumentError -> :ok
        end
      end)

      {:ok, tmp_file: tmp_file}
    end

    test "does not nudge when file was previously read (ETS marks it)", context do
      session_id = "nudge-session-#{:erlang.unique_integer([:positive])}"

      # Mark the file as read in ETS
      :ets.insert(:osa_files_read, {{session_id, context.tmp_file}, true})

      state = %{messages: [], session_id: session_id}
      tool_calls = [%{name: "file_edit", arguments: %{"path" => context.tmp_file}}]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      # File was marked as read, so no nudge
      assert result == state
    end
  end

  describe "inject_read_nudges/2 — files NOT read before and exist on disk" do
    setup do
      tmp_dir = System.tmp_dir!()
      tmp_file = Path.join(tmp_dir, "nudge_unread_#{:erlang.unique_integer([:positive])}.ex")

      File.write!(tmp_file, "some existing content")

      on_exit(fn -> File.rm(tmp_file) end)

      {:ok, tmp_file: tmp_file}
    end

    test "injects a system nudge when file exists but was not read first", context do
      session_id = "nudge-unread-#{:erlang.unique_integer([:positive])}"

      state = %{messages: [], session_id: session_id}
      tool_calls = [%{name: "file_edit", arguments: %{"path" => context.tmp_file}}]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)

      # Should have added a system nudge message
      assert length(result.messages) == 1
      nudge = hd(result.messages)
      assert nudge.role == "system"
      assert String.contains?(nudge.content, "without reading")
      assert String.contains?(nudge.content, context.tmp_file)
      assert String.contains?(nudge.content, "file_read before file_edit")
    end

    test "nudge uses singular pronoun for single file", context do
      session_id = "nudge-single-#{:erlang.unique_integer([:positive])}"

      state = %{messages: [], session_id: session_id}
      tool_calls = [%{name: "file_write", arguments: %{"path" => context.tmp_file}}]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)

      nudge = hd(result.messages)
      assert String.contains?(nudge.content, "without reading it first")
    end
  end

  describe "inject_read_nudges/2 — nudge count limit (max 2 per session per file)" do
    setup do
      tmp_dir = System.tmp_dir!()
      tmp_file = Path.join(tmp_dir, "nudge_limit_#{:erlang.unique_integer([:positive])}.ex")

      File.write!(tmp_file, "content")

      # Ensure the ETS table exists
      try do
        :ets.new(:osa_files_read, [:named_table, :public, :set])
      rescue
        ArgumentError -> :ok
      end

      on_exit(fn ->
        File.rm(tmp_file)
      end)

      {:ok, tmp_file: tmp_file}
    end

    test "stops nudging after 2 nudges for the same session+file", context do
      session_id = "nudge-limit-#{:erlang.unique_integer([:positive])}"

      nudge_key = {session_id, :nudge_count, context.tmp_file}
      :ets.insert(:osa_files_read, {nudge_key, 2})

      state = %{messages: [], session_id: session_id}
      tool_calls = [%{name: "file_edit", arguments: %{"path" => context.tmp_file}}]

      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      # Nudge count is 2 (>= 2), so no more nudges
      assert result == state
    end
  end

  describe "inject_read_nudges/2 — resilience" do
    test "returns state unchanged on error (rescue clause)" do
      state = %{messages: [], session_id: "test-session"}
      # Pass malformed tool_calls (not a list) to trigger potential errors
      tool_calls = [%{name: "file_edit", arguments: nil}]

      # Should not crash — the rescue clause returns state
      result = ToolExecutor.inject_read_nudges(state, tool_calls)
      assert result == state
    end
  end
end
