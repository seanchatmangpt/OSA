defmodule OptimalSystemAgent.Events.ClassifierRealTest do
  @moduledoc """
  Chicago TDD integration tests for Events.Classifier.

  NO MOCKS. Tests real Signal Theory 5-tuple classification, scoring, inference.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Events.Classifier
  alias OptimalSystemAgent.Events.Event

  describe "Classifier.classify/1" do
    test "CRASH: returns map with all 5 dimensions" do
      event = Event.new("test", "src", "hello")
      result = Classifier.classify(event)
      assert is_map(result)
      assert Map.has_key?(result, :mode)
      assert Map.has_key?(result, :genre)
      assert Map.has_key?(result, :type)
      assert Map.has_key?(result, :format)
      assert Map.has_key?(result, :structure)
    end

    test "CRASH: map data infers :code mode" do
      event = Event.new("test", "src", %{key: 1})
      result = Classifier.classify(event)
      assert result.mode == :code
    end

    test "CRASH: list data infers :code mode" do
      event = Event.new("test", "src", [1, 2, 3])
      result = Classifier.classify(event)
      assert result.mode == :code
    end

    test "CRASH: binary data infers :linguistic mode" do
      event = Event.new("test", "src", "plain text")
      result = Classifier.classify(event)
      assert result.mode == :linguistic
    end

    test "CRASH: nil/empty data infers :linguistic mode" do
      event = Event.new("test", "src")
      result = Classifier.classify(event)
      assert result.mode == :linguistic
    end
  end

  describe "Classifier.infer_mode/1" do
    test "CRASH: code-like string returns :code" do
      event = Event.new("test", "src", "defmodule Foo do\n  def bar, do: :ok\nend")
      assert Classifier.infer_mode(event) == :code
    end

    test "CRASH: non-code string returns :linguistic" do
      event = Event.new("test", "src", "just a message")
      assert Classifier.infer_mode(event) == :linguistic
    end
  end

  describe "Classifier.infer_genre/1" do
    test "CRASH: error type returns :error" do
      event = Event.new("error_occurred", "src")
      assert Classifier.infer_genre(event) == :error
    end

    test "CRASH: failure type returns :error" do
      event = Event.new("task_failure", "src")
      assert Classifier.infer_genre(event) == :error
    end

    test "CRASH: alert type returns :alert" do
      event = Event.new("algedonic_alert", "src")
      assert Classifier.infer_genre(event) == :alert
    end

    test "CRASH: task type returns :brief" do
      event = Event.new("agent_task", "src")
      assert Classifier.infer_genre(event) == :brief
    end

    test "CRASH: spec type returns :spec" do
      event = Event.new("tool_spec", "src")
      assert Classifier.infer_genre(event) == :spec
    end

    test "CRASH: report type returns :report" do
      event = Event.new("status_report", "src")
      assert Classifier.infer_genre(event) == :report
    end

    test "CRASH: unknown type returns :chat" do
      event = Event.new("regular_message", "src")
      assert Classifier.infer_genre(event) == :chat
    end
  end

  describe "Classifier.infer_type/1" do
    test "CRASH: _completed suffix returns :inform" do
      event = Event.new("task_completed", "src")
      assert Classifier.infer_type(event) == :inform
    end

    test "CRASH: _done suffix returns :inform" do
      event = Event.new("task_done", "src")
      assert Classifier.infer_type(event) == :inform
    end

    test "CRASH: _request suffix returns :direct" do
      event = Event.new("tool_request", "src")
      assert Classifier.infer_type(event) == :direct
    end

    test "CRASH: _dispatch suffix returns :direct" do
      event = Event.new("agent_dispatch", "src")
      assert Classifier.infer_type(event) == :direct
    end

    test "CRASH: _approved suffix returns :commit" do
      event = Event.new("plan_approved", "src")
      assert Classifier.infer_type(event) == :commit
    end

    test "CRASH: _decided suffix returns :decide" do
      event = Event.new("decision_decided", "src")
      assert Classifier.infer_type(event) == :decide
    end

    test "CRASH: _rejected suffix returns :decide" do
      event = Event.new("proposal_rejected", "src")
      assert Classifier.infer_type(event) == :decide
    end

    test "CRASH: unknown suffix returns :inform" do
      event = Event.new("just_something", "src")
      assert Classifier.infer_type(event) == :inform
    end
  end

  describe "Classifier.infer_format/1" do
    test "CRASH: map data returns :json" do
      event = Event.new("test", "src", %{a: 1})
      assert Classifier.infer_format(event) == :json
    end

    test "CRASH: list data returns :json" do
      event = Event.new("test", "src", [1, 2])
      assert Classifier.infer_format(event) == :json
    end

    test "CRASH: code-like string returns :code" do
      event = Event.new("test", "src", "def foo do :ok end")
      assert Classifier.infer_format(event) == :code
    end

    test "CRASH: markdown string returns :markdown" do
      event = Event.new("test", "src", "# Heading\n\nparagraph text")
      assert Classifier.infer_format(event) == :markdown
    end

    test "CRASH: plain string returns :cli" do
      event = Event.new("test", "src", "no special formatting")
      assert Classifier.infer_format(event) == :cli
    end
  end

  describe "Classifier.infer_structure/1" do
    test "CRASH: error type returns :error_report" do
      event = Event.new("error_event", "src")
      assert Classifier.infer_structure(event) == :error_report
    end

    test "CRASH: alert type returns :alert_report" do
      event = Event.new("alert_event", "src")
      assert Classifier.infer_structure(event) == :alert_report
    end

    test "CRASH: task type returns :brief" do
      event = Event.new("agent_task", "src")
      assert Classifier.infer_structure(event) == :brief
    end

    test "CRASH: unknown type returns :default" do
      event = Event.new("misc_event", "src")
      assert Classifier.infer_structure(event) == :default
    end
  end

  describe "Classifier — scoring" do
    test "CRASH: dimension_score 0.0 when no dimensions set" do
      event = Event.new("test", "src")
      assert Classifier.dimension_score(event) == 0.0
    end

    test "CRASH: dimension_score 1.0 when all 5 dimensions set" do
      event = Event.new("test", "src", %{},
        signal_mode: :execute, signal_genre: :inform,
        signal_type: :request, signal_format: :text, signal_structure: :default
      )
      assert Classifier.dimension_score(event) == 1.0
    end

    test "CRASH: dimension_score partial is proportional" do
      event = Event.new("test", "src", %{}, signal_mode: :execute, signal_genre: :inform)
      score = Classifier.dimension_score(event)
      assert score > 0.0
      assert score < 1.0
    end

    test "CRASH: data_score 0.0 when nil data" do
      event = Event.new("test", "src")
      assert Classifier.data_score(event) == 0.0
    end

    test "CRASH: data_score 0.0 when empty string data" do
      event = Event.new("test", "src", "")
      assert Classifier.data_score(event) == 0.0
    end

    test "CRASH: data_score for map data increases with size" do
      small = Event.new("test", "src", %{a: 1})
      large = Event.new("test", "src", Map.new(1..10, fn i -> {"k#{i}", i} end))
      assert Classifier.data_score(large) > Classifier.data_score(small)
    end

    test "CRASH: context_score 0.0 when no context fields" do
      event = Event.new("test", "src")
      assert Classifier.context_score(event) == 0.0
    end

    test "CRASH: context_score increases with context fields" do
      none = Event.new("test", "src")
      one = Event.new("test", "src", nil, session_id: "s1")
      assert Classifier.context_score(one) > Classifier.context_score(none)
    end

    test "CRASH: sn_ratio is weighted combination" do
      event = Event.new("test", "src", %{},
        signal_mode: :execute, signal_genre: :inform,
        signal_type: :request, signal_format: :text, signal_structure: :default,
        correlation_id: "c1", session_id: "s1"
      )
      score = Classifier.sn_ratio(event)
      assert score > 0.0
      assert score <= 1.0
    end
  end

  describe "Classifier.auto_classify/1" do
    test "CRASH: fills nil signal fields on event" do
      event = Event.new("test", "src")
      result = Classifier.auto_classify(event)
      assert result.signal_mode != nil
      assert result.signal_genre != nil
      assert result.signal_type != nil
      assert result.signal_format != nil
      assert result.signal_structure != nil
    end

    test "CRASH: preserves existing non-nil fields" do
      event = Event.new("test", "src", nil, signal_mode: :execute, signal_genre: :commit)
      result = Classifier.auto_classify(event)
      assert result.signal_mode == :execute
      assert result.signal_genre == :commit
    end
  end

  describe "Classifier.code_like?/1" do
    test "CRASH: Elixir code returns true" do
      assert Classifier.code_like?("defmodule Foo do\n  def bar, do: :ok\nend")
    end

    test "CRASH: Python code returns true" do
      assert Classifier.code_like?("def foo():\n    return True")
    end

    test "CRASH: JavaScript code returns true" do
      assert Classifier.code_like?("const x = () => 42;")
    end

    test "CRASH: plain text returns false" do
      refute Classifier.code_like?("just a regular message")
    end

    test "CRASH: non-string returns false" do
      refute Classifier.code_like?(nil)
    end
  end
end
