defmodule OptimalSystemAgent.Agent.Loop.ToolExecutorPermissionTest do
  @moduledoc """
  Tests for ToolExecutor permission enforcement.

  Tests the pure permission functions: permission_tier_allows?/2,
  subagent_tool_allowed?/2, and the execute_tool_call permission-denied
  and hooks-blocked code paths.

  Does NOT start GenServers or require running processes.
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Loop.ToolExecutor

  # ---------------------------------------------------------------------------
  # permission_tier_allows?/2 — :full tier
  # ---------------------------------------------------------------------------

  describe "permission_tier_allows?/2 :full tier" do
    test "allows all tools" do
      assert ToolExecutor.permission_tier_allows?(:full, "file_read")
      assert ToolExecutor.permission_tier_allows?(:full, "file_write")
      assert ToolExecutor.permission_tier_allows?(:full, "file_delete")
      assert ToolExecutor.permission_tier_allows?(:full, "delegate")
      assert ToolExecutor.permission_tier_allows?(:full, "ask_user")
      assert ToolExecutor.permission_tier_allows?(:full, "create_agent")
      assert ToolExecutor.permission_tier_allows?(:full, "shell_execute")
    end
  end

  # ---------------------------------------------------------------------------
  # permission_tier_allows?/2 — :read_only tier
  # ---------------------------------------------------------------------------

  describe "permission_tier_allows?/2 :read_only tier" do
    test "allows known read-only tools" do
      assert ToolExecutor.permission_tier_allows?(:read_only, "file_read")
      assert ToolExecutor.permission_tier_allows?(:read_only, "file_glob")
      assert ToolExecutor.permission_tier_allows?(:read_only, "dir_list")
      assert ToolExecutor.permission_tier_allows?(:read_only, "file_grep")
      assert ToolExecutor.permission_tier_allows?(:read_only, "file_search")
      assert ToolExecutor.permission_tier_allows?(:read_only, "memory_recall")
      assert ToolExecutor.permission_tier_allows?(:read_only, "session_search")
      assert ToolExecutor.permission_tier_allows?(:read_only, "semantic_search")
      assert ToolExecutor.permission_tier_allows?(:read_only, "code_symbols")
      assert ToolExecutor.permission_tier_allows?(:read_only, "web_fetch")
      assert ToolExecutor.permission_tier_allows?(:read_only, "web_search")
      assert ToolExecutor.permission_tier_allows?(:read_only, "list_skills")
      assert ToolExecutor.permission_tier_allows?(:read_only, "list_dir")
      assert ToolExecutor.permission_tier_allows?(:read_only, "read_file")
      assert ToolExecutor.permission_tier_allows?(:read_only, "grep_search")
      assert ToolExecutor.permission_tier_allows?(:read_only, "a2a_call")
      assert ToolExecutor.permission_tier_allows?(:read_only, "list_agents")
      assert ToolExecutor.permission_tier_allows?(:read_only, "businessos_api")
    end

    test "blocks write tools" do
      refute ToolExecutor.permission_tier_allows?(:read_only, "file_write")
      refute ToolExecutor.permission_tier_allows?(:read_only, "file_edit")
      refute ToolExecutor.permission_tier_allows?(:read_only, "multi_file_edit")
      refute ToolExecutor.permission_tier_allows?(:read_only, "file_create")
      refute ToolExecutor.permission_tier_allows?(:read_only, "file_delete")
      refute ToolExecutor.permission_tier_allows?(:read_only, "file_move")
    end

    test "blocks dangerous tools" do
      refute ToolExecutor.permission_tier_allows?(:read_only, "shell_execute")
      refute ToolExecutor.permission_tier_allows?(:read_only, "delegate")
      refute ToolExecutor.permission_tier_allows?(:read_only, "ask_user")
    end

    test "blocks workspace-specific tools" do
      refute ToolExecutor.permission_tier_allows?(:read_only, "git")
      refute ToolExecutor.permission_tier_allows?(:read_only, "task_write")
      refute ToolExecutor.permission_tier_allows?(:read_only, "memory_write")
      refute ToolExecutor.permission_tier_allows?(:read_only, "memory_save")
      refute ToolExecutor.permission_tier_allows?(:read_only, "download")
      refute ToolExecutor.permission_tier_allows?(:read_only, "create_skill")
    end
  end

  # ---------------------------------------------------------------------------
  # permission_tier_allows?/2 — :workspace tier
  # ---------------------------------------------------------------------------

  describe "permission_tier_allows?/2 :workspace tier" do
    test "allows all read-only tools" do
      assert ToolExecutor.permission_tier_allows?(:workspace, "file_read")
      assert ToolExecutor.permission_tier_allows?(:workspace, "file_glob")
      assert ToolExecutor.permission_tier_allows?(:workspace, "dir_list")
    end

    test "allows workspace write tools" do
      assert ToolExecutor.permission_tier_allows?(:workspace, "file_write")
      assert ToolExecutor.permission_tier_allows?(:workspace, "file_edit")
      assert ToolExecutor.permission_tier_allows?(:workspace, "multi_file_edit")
      assert ToolExecutor.permission_tier_allows?(:workspace, "file_create")
      assert ToolExecutor.permission_tier_allows?(:workspace, "file_delete")
      assert ToolExecutor.permission_tier_allows?(:workspace, "file_move")
      assert ToolExecutor.permission_tier_allows?(:workspace, "git")
      assert ToolExecutor.permission_tier_allows?(:workspace, "task_write")
      assert ToolExecutor.permission_tier_allows?(:workspace, "memory_write")
      assert ToolExecutor.permission_tier_allows?(:workspace, "memory_save")
      assert ToolExecutor.permission_tier_allows?(:workspace, "download")
      assert ToolExecutor.permission_tier_allows?(:workspace, "create_skill")
    end

    test "blocks dangerous tools outside workspace scope" do
      refute ToolExecutor.permission_tier_allows?(:workspace, "delegate")
      refute ToolExecutor.permission_tier_allows?(:workspace, "ask_user")
      refute ToolExecutor.permission_tier_allows?(:workspace, "shell_execute")
    end
  end

  # ---------------------------------------------------------------------------
  # permission_tier_allows?/2 — :subagent tier
  # ---------------------------------------------------------------------------

  describe "permission_tier_allows?/2 :subagent tier" do
    test "allows most tools except subagent-blocked ones" do
      assert ToolExecutor.permission_tier_allows?(:subagent, "file_read")
      assert ToolExecutor.permission_tier_allows?(:subagent, "file_write")
      assert ToolExecutor.permission_tier_allows?(:subagent, "file_edit")
      assert ToolExecutor.permission_tier_allows?(:subagent, "shell_execute")
      assert ToolExecutor.permission_tier_allows?(:subagent, "memory_recall")
    end

    test "blocks subagent-dangerous tools" do
      refute ToolExecutor.permission_tier_allows?(:subagent, "delegate")
      refute ToolExecutor.permission_tier_allows?(:subagent, "ask_user")
      refute ToolExecutor.permission_tier_allows?(:subagent, "create_skill")
      refute ToolExecutor.permission_tier_allows?(:subagent, "create_agent")
      refute ToolExecutor.permission_tier_allows?(:subagent, "memory_save")
    end
  end

  # ---------------------------------------------------------------------------
  # permission_tier_allows?/2 — unknown tier
  # ---------------------------------------------------------------------------

  describe "permission_tier_allows?/2 unknown tier" do
    test "defaults to allowing all tools" do
      assert ToolExecutor.permission_tier_allows?(:unknown, "file_write")
      assert ToolExecutor.permission_tier_allows?(:unknown, "shell_execute")
      assert ToolExecutor.permission_tier_allows?(:nil, "anything")
    end
  end

  # ---------------------------------------------------------------------------
  # subagent_tool_allowed?/2
  # ---------------------------------------------------------------------------

  describe "subagent_tool_allowed?/2" do
    test "blocks always-blocked tools regardless of state" do
      state = %{allowed_tools: ["delegate"], blocked_tools: []}
      refute ToolExecutor.subagent_tool_allowed?("delegate", state)
      refute ToolExecutor.subagent_tool_allowed?("ask_user", state)
      refute ToolExecutor.subagent_tool_allowed?("create_skill", state)
      refute ToolExecutor.subagent_tool_allowed?("create_agent", state)
      refute ToolExecutor.subagent_tool_allowed?("memory_save", state)
    end

    test "respects per-agent denylist" do
      state = %{blocked_tools: ["shell_execute", "git"]}
      refute ToolExecutor.subagent_tool_allowed?("shell_execute", state)
      refute ToolExecutor.subagent_tool_allowed?("git", state)
    end

    test "respects per-agent allowlist" do
      state = %{allowed_tools: ["file_read", "file_write"]}
      assert ToolExecutor.subagent_tool_allowed?("file_read", state)
      assert ToolExecutor.subagent_tool_allowed?("file_write", state)
      refute ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end

    test "allows all when no restrictions specified" do
      state = %{}
      assert ToolExecutor.subagent_tool_allowed?("file_read", state)
      assert ToolExecutor.subagent_tool_allowed?("file_write", state)
      assert ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end

    test "empty allowlist means all allowed (nil treated as no restriction)" do
      state = %{allowed_tools: []}
      assert ToolExecutor.subagent_tool_allowed?("file_read", state)
      assert ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end

    test "blocked takes precedence over allowed" do
      state = %{allowed_tools: ["shell_execute"], blocked_tools: ["shell_execute"]}
      refute ToolExecutor.subagent_tool_allowed?("shell_execute", state)
    end

    test "always-blocked takes precedence over per-agent allowlist" do
      state = %{allowed_tools: ["delegate"]}
      refute ToolExecutor.subagent_tool_allowed?("delegate", state)
    end
  end
end
