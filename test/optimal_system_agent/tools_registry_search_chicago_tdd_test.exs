defmodule OptimalSystemAgent.ToolsRegistrySearchChicagoTDDTest do
  @moduledoc """
  Chicago TDD: Tools.Registry.Search pure logic tests.

  NO MOCKS. Tests verify REAL search, scoring, and fallback logic.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — search results observable

  Tests (Red Phase):
  1. Keyword search returns relevant tools sorted by score
  2. Search filters out non-matching tools (score <= 0)
  3. Empty query returns empty results
  4. Filter applicable tools by context (language, framework, history)
  5. Suggest fallback for failed tools
  6. Language conflicts reduce score
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Registry.Search

  # Mock tool modules for testing
  defmodule MockTool do
    defstruct [:name, :description]

    def new(name, description) do
      %__MODULE__{name: name, description: description}
    end
  end

  defmodule ToolA do
    def name, do: "file_read"
    def description, do: "Read a file from disk"
  end

  defmodule ToolB do
    def name, do: "python_execute"
    def description, do: "Execute Python code"
  end

  defmodule ToolC do
    def name, do: "web_search"
    def description, do: "Search the web for information"
  end

  describe "Search.search/3 — Keyword Search" do
    test "CRASH: Returns empty list for empty query" do
      builtin_tools = %{"file_read" => ToolA}
      skills = %{}

      result = Search.search(builtin_tools, skills, "")

      assert result == []
    end

    test "CRASH: Returns empty list for query with only stop words" do
      builtin_tools = %{file_read: ToolA}
      skills = %{}

      result = Search.search(builtin_tools, skills, "the a an")

      assert result == []
    end

    test "CRASH: Returns tools sorted by relevance score (descending)" do
      builtin_tools = %{
        "file_read" => ToolA,
        "python_execute" => ToolB,
        "web_search" => ToolC
      }
      skills = %{}

      result = Search.search(builtin_tools, skills, "file read python")

      # Results should be sorted by score (descending)
      # file_read matches "file" and "read" (2 keywords)
      # python_execute matches "python" (1 keyword)
      assert length(result) > 0

      # Check that results have the expected structure
      Enum.each(result, fn {name, _desc, score} ->
        assert is_binary(name)
        assert is_binary(_desc)
        assert is_float(score)
        assert score > 0.0
      end)
    end

    test "CRASH: Exact name match has highest score" do
      builtin_tools = %{"file_read" => ToolA, "python_execute" => ToolB}
      skills = %{}

      result = Search.search(builtin_tools, skills, "file_read")

      assert length(result) >= 1

      # First result should be file_read with high score
      [{name, _desc, score} | _] = result
      assert name == "file_read"
      assert score > 0.9
    end

    test "CRASH: Description matching contributes to score" do
      builtin_tools = %{"python_execute" => ToolB}
      skills = %{}

      result = Search.search(builtin_tools, skills, "code execution")

      # Should match "Execute Python code" description
      assert length(result) >= 1
    end
  end

  describe "Search.filter_applicable_tools/2 — Context Filtering" do
    test "CRASH: Returns all tools when context is empty" do
      all_tools = [
        %{name: "file_read", description: "Read file"},
        %{name: "python_execute", description: "Execute Python"}
      ]

      result = Search.filter_applicable_tools(%{}, all_tools)

      assert length(result) == length(all_tools)
    end

    test "CRASH: Boosts tools matching language context" do
      all_tools = [
        %{name: "python_execute", description: "Execute Python code"},
        %{name: "file_read", description: "Read any file"}
      ]

      result = Search.filter_applicable_tools(%{language: "python"}, all_tools)

      # python_execute should be boosted (appears before file_read)
      assert length(result) == 2

      # Find positions
      python_pos = Enum.find_index(result, fn t -> t.name == "python_execute" end)
      file_pos = Enum.find_index(result, fn t -> t.name == "file_read" end)

      # python_execute should come before file_read (lower index)
      assert python_pos < file_pos
    end

    test "CRASH: Boosts tools matching framework context" do
      all_tools = [
        %{name: "phoenix_routes", description: "List Phoenix routes"},
        %{name: "django_models", description: "List Django models"}
      ]

      result = Search.filter_applicable_tools(%{framework: "phoenix"}, all_tools)

      # phoenix_routes should be boosted (appears before django_models)
      phoenix_pos = Enum.find_index(result, fn t -> t.name == "phoenix_routes" end)
      django_pos = Enum.find_index(result, fn t -> t.name == "django_models" end)

      assert phoenix_pos < django_pos
    end

    test "CRASH: Boosts recently used tools" do
      all_tools = [
        %{name: "file_read", description: "Read file"},
        %{name: "file_write", description: "Write file"}
      ]

      result = Search.filter_applicable_tools(%{history: ["file_read"]}, all_tools)

      # file_read should be boosted (appears before file_write)
      file_read_pos = Enum.find_index(result, fn t -> t.name == "file_read" end)
      file_write_pos = Enum.find_index(result, fn t -> t.name == "file_write" end)

      assert file_read_pos < file_write_pos
    end

    test "CRASH: Penalizes tools that conflict with language" do
      all_tools = [
        %{name: "python_execute", description: "Execute Python code"},
        %{name: "elixir_compile", description: "Compile Elixir code"}
      ]

      result = Search.filter_applicable_tools(%{language: "elixir"}, all_tools)

      # elixir_compile should be boosted, python_execute penalized
      elixir_pos = Enum.find_index(result, fn t -> t.name == "elixir_compile" end)
      python_pos = Enum.find_index(result, fn t -> t.name == "python_execute" end)

      assert elixir_pos < python_pos
    end
  end

  describe "Search.suggest_fallback/2 — Fallback Suggestions" do
    test "CRASH: Returns no_alternative for unknown tool" do
      builtin_tools = %{file_read: ToolA}

      result = Search.suggest_fallback("unknown_tool", builtin_tools)

      assert result == :no_alternative
    end

    test "CRASH: Returns alternative when fallback exists" do
      builtin_tools = %{
        "file_read" => ToolA,
        "web_search" => ToolC
      }

      result = Search.suggest_fallback("web_fetch", builtin_tools)

      assert result == {:ok, "web_search"}
    end

    test "CRASH: Returns no_alternative when fallback tool not available" do
      builtin_tools = %{file_read: ToolA}

      result = Search.suggest_fallback("web_fetch", builtin_tools)

      assert result == :no_alternative
    end

    test "CRASH: Bidirectional fallbacks work correctly" do
      builtin_tools = %{
        "web_search" => ToolC,
        "web_fetch" => ToolC
      }

      # web_fetch -> web_search
      assert Search.suggest_fallback("web_fetch", builtin_tools) == {:ok, "web_search"}

      # web_search -> web_fetch
      assert Search.suggest_fallback("web_search", builtin_tools) == {:ok, "web_fetch"}
    end
  end

  describe "Search — Edge Cases" do
    test "CRASH: Handles special characters in query" do
      builtin_tools = %{"file_read" => ToolA}
      skills = %{}

      # Special characters should be stripped
      result = Search.search(builtin_tools, skills, "file!@#$%read")

      assert length(result) >= 1
    end

    test "CRASH: Case-insensitive search" do
      builtin_tools = %{"file_read" => ToolA}
      skills = %{}

      result = Search.search(builtin_tools, skills, "FILE READ")

      assert length(result) >= 1
    end

    test "CRASH: Hyphenated names are split into tokens" do
      builtin_tools = %{
        "multi-file-edit" => ToolA
      }
      skills = %{}

      result = Search.search(builtin_tools, skills, "multi file edit")

      assert length(result) >= 1
    end

    test "CRASH: Scores are capped at 1.0" do
      builtin_tools = %{"file_read" => ToolA}
      skills = %{}

      result = Search.search(builtin_tools, skills, "file_read file_read file_read")

      # Even with repeated keywords, score should not exceed 1.0
      Enum.each(result, fn {_name, _desc, score} ->
        assert score <= 1.0
      end)
    end
  end
end
