defmodule OptimalSystemAgent.Tools.RegistryTest do
  @moduledoc """
  Unit tests for Tools.Registry — list_tools_direct/0, execute/2, suggest_fallback_tool/1.
  Tests the :persistent_term-based direct API (no GenServer needed).
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Tools.Registry
  alias OptimalSystemAgent.Tools.Registry.Search

  setup_all do
    # Ensure :persistent_term keys exist so direct API calls do not crash.
    :persistent_term.put({Registry, :builtin_tools}, %{})
    :persistent_term.put({Registry, :skills}, %{})
    :persistent_term.put({Registry, :mcp_tools}, %{})
    :persistent_term.put({Registry, :tools}, [])
    :ok
  end

  describe "list_tools_direct/0" do
    @tag :unit
    test "returns empty list when no tools are registered" do
      :persistent_term.put({Registry, :builtin_tools}, %{})
      :persistent_term.put({Registry, :mcp_tools}, %{})

      tools = Registry.list_tools_direct()
      assert tools == []
    end

    @tag :unit
    test "returns MCP tools from persistent_term" do
      :persistent_term.put({Registry, :builtin_tools}, %{})
      :persistent_term.put({Registry, :mcp_tools}, %{
        :"mcp_test_server_read_file" => %{
          original_name: "read_file",
          description: "Read a file from disk",
          input_schema: %{"type" => "object", "properties" => %{"path" => %{"type" => "string"}}},
          server_name: "test_server"
        }
      })

      tools = Registry.list_tools_direct()
      assert length(tools) == 1

      [tool] = tools
      assert tool.name == :"mcp_test_server_read_file"
      assert tool.description == "Read a file from disk"
      assert is_map(tool.parameters)
    end
  end

  describe "execute/2" do
    @tag :unit
    test "returns error for unknown tool" do
      :persistent_term.put({Registry, :builtin_tools}, %{})
      :persistent_term.put({Registry, :mcp_tools}, %{})

      assert {:error, msg} = Registry.execute("nonexistent_tool", %{})
      assert is_binary(msg)
      assert String.contains?(msg, "Unknown tool")
    end

    @tag :unit
    test "returns error for unknown tool even when MCP tools exist" do
      :persistent_term.put({Registry, :builtin_tools}, %{})
      :persistent_term.put({Registry, :mcp_tools}, %{
        :"mcp_other_tool" => %{
          original_name: "other",
          description: "Other tool",
          input_schema: %{},
          server_name: "server"
        }
      })

      assert {:error, _} = Registry.execute("still_unknown", %{})
    end
  end

  describe "suggest_fallback_tool/1" do
    @tag :unit
    test "returns :no_alternative for unknown tool" do
      :persistent_term.put({Registry, :builtin_tools}, %{})
      assert :no_alternative = Registry.suggest_fallback_tool("nonexistent")
    end

    @tag :unit
    test "suggests file_read as fallback for shell_execute" do
      :persistent_term.put({Registry, :builtin_tools}, %{"file_read" => SomeFakeModule})

      assert {:ok, "file_read"} = Registry.suggest_fallback_tool("shell_execute")
    end

    @tag :unit
    test "suggests web_fetch as fallback for web_search" do
      :persistent_term.put({Registry, :builtin_tools}, %{"web_fetch" => SomeFakeModule})

      assert {:ok, "web_fetch"} = Registry.suggest_fallback_tool("web_search")
    end

    @tag :unit
    test "suggests web_search as fallback for web_fetch" do
      :persistent_term.put({Registry, :builtin_tools}, %{"web_search" => SomeFakeModule})

      assert {:ok, "web_search"} = Registry.suggest_fallback_tool("web_fetch")
    end

    @tag :unit
    test "suggests multi_file_edit as fallback for file_write" do
      :persistent_term.put({Registry, :builtin_tools}, %{"multi_file_edit" => SomeFakeModule})

      assert {:ok, "multi_file_edit"} = Registry.suggest_fallback_tool("file_write")
    end

    @tag :unit
    test "suggests file_write as fallback for multi_file_edit" do
      :persistent_term.put({Registry, :builtin_tools}, %{"file_write" => SomeFakeModule})

      assert {:ok, "file_write"} = Registry.suggest_fallback_tool("multi_file_edit")
    end

    @tag :unit
    test "suggests multi_file_edit as fallback for file_edit" do
      :persistent_term.put({Registry, :builtin_tools}, %{"multi_file_edit" => SomeFakeModule})

      assert {:ok, "multi_file_edit"} = Registry.suggest_fallback_tool("file_edit")
    end

    @tag :unit
    test "suggests session_search as fallback for semantic_search" do
      :persistent_term.put({Registry, :builtin_tools}, %{"session_search" => SomeFakeModule})

      assert {:ok, "session_search"} = Registry.suggest_fallback_tool("semantic_search")
    end

    @tag :unit
    test "suggests memory_recall as fallback for session_search" do
      :persistent_term.put({Registry, :builtin_tools}, %{"memory_recall" => SomeFakeModule})

      assert {:ok, "memory_recall"} = Registry.suggest_fallback_tool("session_search")
    end

    @tag :unit
    test "returns :no_alternative when fallback target is not in builtin_tools" do
      :persistent_term.put({Registry, :builtin_tools}, %{})

      # shell_execute -> file_read, but file_read is not registered
      assert :no_alternative = Registry.suggest_fallback_tool("shell_execute")
    end
  end

  describe "list_docs_direct/0" do
    @tag :unit
    test "returns empty list when nothing registered" do
      :persistent_term.put({Registry, :builtin_tools}, %{})
      :persistent_term.put({Registry, :skills}, %{})

      assert Registry.list_docs_direct() == []
    end
  end

  describe "active_skills_context/0" do
    @tag :unit
    test "returns nil when no skills are loaded" do
      :persistent_term.put({Registry, :skills}, %{})
      assert Registry.active_skills_context() == nil
    end
  end

  describe "match_skill_triggers/1" do
    @tag :unit
    test "returns empty list when no skills loaded" do
      :persistent_term.put({Registry, :skills}, %{})
      assert Registry.match_skill_triggers("deploy to production") == []
    end

    @tag :unit
    test "matches skills with trigger keywords" do
      :persistent_term.put({Registry, :skills}, %{
        "deploy" => %{name: "deploy", description: "Deploy skills", triggers: ["deploy", "release"]},
        "test" => %{name: "test", description: "Test skills", triggers: ["test", "spec"]}
      })

      results = Registry.match_skill_triggers("please deploy to staging")
      assert length(results) == 1
      [{name, _skill}] = results
      assert name == "deploy"
    end

    @tag :unit
    test "matches case-insensitively" do
      :persistent_term.put({Registry, :skills}, %{
        "deploy" => %{name: "deploy", description: "Deploy skills", triggers: ["deploy"]}
      })

      results = Registry.match_skill_triggers("DEPLOY NOW")
      assert length(results) == 1
    end

    @tag :unit
    test "skips wildcard triggers" do
      :persistent_term.put({Registry, :skills}, %{
        "catch_all" => %{name: "catch_all", description: "Catch all", triggers: ["*"]}
      })

      assert Registry.match_skill_triggers("anything at all") == []
    end
  end

  describe "Search.suggest_fallback/2 (direct)" do
    @tag :unit
    test "delegates correctly" do
      builtin_tools = %{"file_read" => FileRead, "web_fetch" => WebFetch}

      assert {:ok, "file_read"} = Search.suggest_fallback("shell_execute", builtin_tools)
      assert {:ok, "web_fetch"} = Search.suggest_fallback("web_search", builtin_tools)
      assert :no_alternative = Search.suggest_fallback("unknown_tool", builtin_tools)
    end
  end
end

# Dummy module for persistent_term testing
defmodule SomeFakeModule, do: nil
