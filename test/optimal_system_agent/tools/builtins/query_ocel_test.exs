defmodule OptimalSystemAgent.Tools.Builtins.QueryOcelTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.QueryOcel

  # Chicago TDD: behaviour verification via black-box tests.
  # No mocks — real module calls, no external service needed (pm4py gracefully offline).

  test "query_ocel tool has correct name" do
    assert QueryOcel.name() == "query_ocel"
  end

  test "query_ocel parameters_schema requires question field" do
    assert "question" in QueryOcel.parameters()["required"]
  end

  test "query_ocel returns ok tuple even when pm4py unavailable" do
    result = QueryOcel.execute(%{"question" => "What activities were performed?"})
    assert match?({:ok, %{"answer" => _, "grounded" => _, "context_used" => _}}, result)
  end

  test "query_ocel accepts session_id parameter" do
    result = QueryOcel.execute(%{"question" => "test", "session_id" => "sess_123"})
    assert match?({:ok, %{"answer" => _, "grounded" => _, "context_used" => _}}, result)
  end

  test "query_ocel returns error tuple when question is missing" do
    result = QueryOcel.execute(%{})
    assert match?({:error, _}, result)
  end

  test "query_ocel description is a non-empty string" do
    desc = QueryOcel.description()
    assert is_binary(desc)
    assert String.length(desc) > 0
  end

  test "query_ocel safety is :sandboxed" do
    assert QueryOcel.safety() == :sandboxed
  end

  test "query_ocel parameters schema has question and session_id properties" do
    schema = QueryOcel.parameters()
    props = schema["properties"]
    assert Map.has_key?(props, "question")
    assert Map.has_key?(props, "session_id")
  end
end
