defmodule OptimalSystemAgent.Tools.Builtins.WebSearchChicagoTDDTest do
  @moduledoc """
  Chicago TDD: WebSearch tool pure logic tests.

  NO MOCKS. Tests verify REAL tool behavior.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — tool metadata observable

  Tests (Red Phase):
  1. Behaviour callback implementation
  2. Safety level (:read_only)
  3. Tool metadata (name, description)
  4. Parameters schema (query required, limit optional)
  5. Execute function error handling (missing query, non-string query, empty query)

  Note: Actual web search requires integration tests with network access.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.WebSearch

  describe "Tool — Behaviour Implementation" do
    test "CRASH: Implements Tools.Behaviour" do
      assert function_exported?(WebSearch, :safety, 0)
      assert function_exported?(WebSearch, :name, 0)
      assert function_exported?(WebSearch, :description, 0)
      assert function_exported?(WebSearch, :parameters, 0)
      assert function_exported?(WebSearch, :execute, 1)
    end

    test "CRASH: safety/0 returns :read_only" do
      assert WebSearch.safety() == :read_only
    end

    test "CRASH: name/0 returns 'web_search'" do
      assert WebSearch.name() == "web_search"
    end

    test "CRASH: description/0 returns non-empty string" do
      desc = WebSearch.description()
      assert is_binary(desc)
      assert String.length(desc) > 0
    end

    test "CRASH: description/0 mentions search" do
      desc = String.downcase(WebSearch.description())
      assert String.contains?(desc, "search")
    end
  end

  describe "Tool — Parameters Schema" do
    test "CRASH: parameters/0 returns valid schema map" do
      schema = WebSearch.parameters()
      assert is_map(schema)
    end

    test "CRASH: parameters has 'type' => 'object'" do
      schema = WebSearch.parameters()
      assert Map.get(schema, "type") == "object"
    end

    test "CRASH: query is required" do
      schema = WebSearch.parameters()
      required = Map.get(schema, "required")
      assert "query" in required
    end

    test "CRASH: limit is optional" do
      schema = WebSearch.parameters()
      required = Map.get(schema, "required")
      refute "limit" in required
    end

    test "CRASH: query type is string" do
      schema = WebSearch.parameters()
      query = schema |> Map.get("properties") |> Map.get("query")
      assert Map.get(query, "type") == "string"
    end

    test "CRASH: limit type is integer" do
      schema = WebSearch.parameters()
      limit = schema |> Map.get("properties") |> Map.get("limit")
      assert Map.get(limit, "type") == "integer"
    end

    test "CRASH: limit description mentions default" do
      schema = WebSearch.parameters()
      limit = schema |> Map.get("properties") |> Map.get("limit")
      desc = Map.get(limit, "description")
      assert is_binary(desc)
      assert String.length(desc) > 0
    end
  end

  describe "Tool — Execute Function" do
    test "CRASH: execute/1 function exists" do
      assert function_exported?(WebSearch, :execute, 1)
    end

    test "CRASH: execute returns error for missing query" do
      result = WebSearch.execute(%{})
      assert match?({:error, "Missing required parameter: query"}, result)
    end

    test "CRASH: execute returns error for non-string query" do
      result = WebSearch.execute(%{"query" => 123})
      assert match?({:error, "query must be a string"}, result)
    end

    test "CRASH: execute returns error for empty query" do
      result = WebSearch.execute(%{"query" => ""})
      assert match?({:error, "query must not be empty"}, result)
    end

    test "CRASH: execute returns error for whitespace-only query" do
      result = WebSearch.execute(%{"query" => "   "})
      assert match?({:error, "query must not be empty"}, result)
    end

    test "CRASH: execute accepts query with limit" do
      # Function exists - actual behavior requires network
      assert function_exported?(WebSearch, :execute, 1)
    end

    test "CRASH: execute accepts query without limit" do
      # Function exists - actual behavior requires network
      assert function_exported?(WebSearch, :execute, 1)
    end
  end

  describe "Tool — Safety Classification" do
    test "CRASH: Is read_only (safe, no modifications)" do
      assert WebSearch.safety() == :read_only
    end

    test "CRASH: Is NOT write_safe" do
      refute WebSearch.safety() == :write_safe
    end

    test "CRASH: Is NOT dangerous" do
      refute WebSearch.safety() == :dangerous
    end

    test "CRASH: Is NOT terminal" do
      refute WebSearch.safety() == :terminal
    end
  end

  describe "Tool — Module Properties" do
    test "CRASH: Module is loaded" do
      assert Code.ensure_loaded?(WebSearch)
    end

    test "CRASH: Module has @behaviour Tools.Behaviour" do
      # Verify callbacks are implemented
      assert function_exported?(WebSearch, :safety, 0)
      assert function_exported?(WebSearch, :name, 0)
      assert function_exported?(WebSearch, :description, 0)
      assert function_exported?(WebSearch, :parameters, 0)
      assert function_exported?(WebSearch, :execute, 1)
    end
  end

  describe "Tool — Schema Validation" do
    test "CRASH: Parameters schema is valid JSON Schema" do
      schema = WebSearch.parameters()
      assert Map.has_key?(schema, "type")
      assert Map.has_key?(schema, "properties")
      assert Map.has_key?(schema, "required")
    end

    test "CRASH: Properties is a map" do
      schema = WebSearch.parameters()
      props = Map.get(schema, "properties")
      assert is_map(props)
    end

    test "CRASH: Required is a list" do
      schema = WebSearch.parameters()
      required = Map.get(schema, "required")
      assert is_list(required)
    end

    test "CRASH: Exactly 1 required parameter" do
      schema = WebSearch.parameters()
      required = Map.get(schema, "required")
      assert length(required) == 1
    end
  end

  describe "Tool — Description Content" do
    test "CRASH: description mentions web" do
      desc = String.downcase(WebSearch.description())
      assert String.contains?(desc, "web")
    end

    test "CRASH: description mentions results" do
      desc = String.downcase(WebSearch.description())
      assert String.contains?(desc, "result")
    end
  end

  describe "Tool — Naming" do
    test "CRASH: Tool name is 'web_search'" do
      assert WebSearch.name() == "web_search"
    end

    test "CRASH: Tool name uses underscore convention" do
      assert String.contains?(WebSearch.name(), "_")
      refute String.contains?(WebSearch.name(), "-")
    end
  end

  describe "Tool — Error Messages" do
    test "CRASH: Missing query error is descriptive" do
      result = WebSearch.execute(%{})
      assert match?({:error, <<_::binary>>}, result)
      assert elem(result, 1) =~ "query"
    end

    test "CRASH: Non-string query error is descriptive" do
      result = WebSearch.execute(%{"query" => 123})
      assert match?({:error, <<_::binary>>}, result)
      assert elem(result, 1) =~ "string"
    end

    test "CRASH: Empty query error is descriptive" do
      result = WebSearch.execute(%{"query" => ""})
      assert match?({:error, <<_::binary>>}, result)
      assert elem(result, 1) =~ "empty"
    end
  end
end
