defmodule OptimalSystemAgent.Tools.Registry.SearchRealTest do
  @moduledoc """
  Chicago TDD integration tests for Tools.Registry.Search.

  NO MOCKS. Tests real search, filtering, and fallback logic with injected data.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Tools.Registry.Search

  # Minimal module stub that responds to description/0
  defmodule FakeTool do
    def description, do: "A fake tool for testing"
  end

  defmodule FileTool do
    def description, do: "Read and write files from disk"
  end

  defmodule PythonTool do
    def description, do: "Execute python code snippets"
  end

  describe "Search.search/3" do
    test "CRASH: empty query returns empty list" do
      result = Search.search(%{}, %{}, "the is a")
      assert result == []
    end

    test "CRASH: single stop word returns empty" do
      result = Search.search(%{}, %{}, "the")
      assert result == []
    end

    test "CRASH: matching tool name returns result with score" do
      builtin = %{"fake_tool" => FakeTool}
      result = Search.search(builtin, %{}, "fake tool")
      assert length(result) > 0
      {name, _desc, score} = hd(result)
      assert name == "fake_tool"
      assert score > 0.0
    end

    test "CRASH: matching description returns result" do
      builtin = %{"file_tool" => FileTool}
      result = Search.search(builtin, %{}, "disk files")
      assert length(result) > 0
    end

    test "CRASH: no match returns empty" do
      builtin = %{"fake_tool" => FakeTool}
      result = Search.search(builtin, %{}, "quantum physics")
      assert result == []
    end

    test "CRASH: results sorted by score descending" do
      builtin = %{
        "fake_tool" => FakeTool,
        "file_tool" => FileTool
      }
      result = Search.search(builtin, %{}, "fake tool files disk")
      scores = Enum.map(result, fn {_, _, score} -> score end)
      # Each subsequent score should be <= previous
      assert scores == Enum.sort(scores, :desc)
    end

    test "CRASH: skill search works" do
      skills = %{"my_skill" => %{description: "A skill for elixir development"}}
      result = Search.search(%{}, skills, "elixir skill")
      assert length(result) > 0
    end

    test "CRASH: empty maps return empty" do
      result = Search.search(%{}, %{}, "anything")
      assert result == []
    end
  end

  describe "Search.filter_applicable_tools/2" do
    test "CRASH: empty tools returns empty" do
      result = Search.filter_applicable_tools(%{}, [])
      assert result == []
    end

    test "CRASH: nil context returns all tools unsorted" do
      tools = [%{name: "a", description: "tool a"}, %{name: "b", description: "tool b"}]
      result = Search.filter_applicable_tools(%{}, tools)
      assert length(result) == 2
    end

    test "CRASH: language match boosts python tool" do
      tools = [
        %{name: "python_tool", description: "A python tool"},
        %{name: "elixir_tool", description: "An elixir tool"}
      ]
      result = Search.filter_applicable_tools(%{language: "python"}, tools)
      assert hd(result).name == "python_tool"
    end

    test "CRASH: framework match boosts relevant tool" do
      tools = [
        %{name: "phoenix_tool", description: "Phoenix framework tool"},
        %{name: "django_tool", description: "Django framework tool"}
      ]
      result = Search.filter_applicable_tools(%{framework: "phoenix"}, tools)
      assert hd(result).name == "phoenix_tool"
    end

    test "CRASH: recent history boosts recently used tool" do
      tools = [
        %{name: "file_read", description: "Read files"},
        %{name: "shell", description: "Execute shell commands"}
      ]
      result = Search.filter_applicable_tools(%{history: ["shell"]}, tools)
      assert hd(result).name == "shell"
    end

    test "CRASH: language conflict penalizes tool" do
      tools = [
        %{name: "elixir_tool", description: "elixir stuff"},
        %{name: "python_tool", description: "python stuff"}
      ]
      result = Search.filter_applicable_tools(%{language: "python"}, tools)
      # python_tool should be first (positive match), elixir_tool last (negative)
      assert List.last(result).name == "elixir_tool"
    end
  end

  describe "Search.suggest_fallback/2" do
    test "CRASH: shell_execute falls back to file_read" do
      builtin = %{"file_read" => FakeTool}
      assert {:ok, "file_read"} = Search.suggest_fallback("shell_execute", builtin)
    end

    test "CRASH: web_search falls back to web_fetch" do
      builtin = %{"web_fetch" => FakeTool}
      assert {:ok, "web_fetch"} = Search.suggest_fallback("web_search", builtin)
    end

    test "CRASH: unknown tool returns no_alternative" do
      assert :no_alternative = Search.suggest_fallback("nonexistent_tool", %{})
    end

    test "CRASH: fallback not in builtin returns no_alternative" do
      # shell_execute -> file_read, but file_read not in builtin
      assert :no_alternative = Search.suggest_fallback("shell_execute", %{})
    end

    test "CRASH: file_write falls back to multi_file_edit" do
      builtin = %{"multi_file_edit" => FakeTool}
      assert {:ok, "multi_file_edit"} = Search.suggest_fallback("file_write", builtin)
    end

    test "CRASH: bidirectional fallback" do
      # file_edit -> multi_file_edit
      builtin = %{"multi_file_edit" => FakeTool}
      assert {:ok, "multi_file_edit"} = Search.suggest_fallback("file_edit", builtin)
      # multi_file_edit -> file_write (not in builtin)
      assert :no_alternative = Search.suggest_fallback("multi_file_edit", builtin)
    end
  end
end
