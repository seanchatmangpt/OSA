defmodule OptimalSystemAgent.Healing.PromptsRealTest do
  @moduledoc """
  Chicago TDD integration tests for Healing.Prompts.

  NO MOCKS. Tests real prompt construction logic.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Healing.Prompts

  describe "Prompts.diagnostic_prompt/1" do
    test "CRASH: returns a string" do
      context = %{agent_id: "test-1", error: "boom"}
      result = Prompts.diagnostic_prompt(context)
      assert is_binary(result)
    end

    test "CRASH: contains agent_id" do
      context = %{agent_id: "agent-42", error: "err"}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "agent-42")
    end

    test "CRASH: contains error details" do
      context = %{agent_id: "a1", error: "FileNotFoundError: /tmp/missing"}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "FileNotFoundError")
    end

    test "CRASH: contains category" do
      context = %{agent_id: "a1", error: "err", category: :tool_failure}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "tool_failure")
    end

    test "CRASH: contains severity" do
      context = %{agent_id: "a1", error: "err", severity: :high}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "high")
    end

    test "CRASH: contains retryable status" do
      context = %{agent_id: "a1", error: "err", retryable: false}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "false")
    end

    test "CRASH: shows healing attempt number" do
      context = %{agent_id: "a1", error: "err", attempt_count: 2}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "Healing Attempt: 3")
    end

    test "CRASH: defaults missing fields" do
      result = Prompts.diagnostic_prompt(%{})
      assert String.contains?(result, "unknown")
      assert String.contains?(result, "medium")  # default severity
      assert String.contains?(result, "true")    # default retryable
    end

    test "CRASH: includes tool history" do
      context = %{
        agent_id: "a1",
        error: "err",
        tool_history: [%{tool: "file_read", result: "content here"}]
      }
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "file_read")
    end

    test "CRASH: includes messages" do
      context = %{
        agent_id: "a1",
        error: "err",
        messages: [%{role: "user", content: "hello world"}]
      }
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "hello world")
    end

    test "CRASH: truncates long error" do
      long_error = String.duplicate("x", 5000)
      context = %{agent_id: "a1", error: long_error}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "truncated")
    end

    test "CRASH: handles non-string error via inspect" do
      context = %{agent_id: "a1", error: {:tuple, "error"}}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "tuple")
    end

    test "CRASH: contains JSON format contract" do
      context = %{agent_id: "a1", error: "err"}
      result = Prompts.diagnostic_prompt(context)
      assert String.contains?(result, "root_cause")
      assert String.contains?(result, "confidence")
      assert String.contains?(result, "remediation_strategy")
    end
  end

  describe "Prompts.fix_prompt/2" do
    test "CRASH: returns a string" do
      diagnosis = %{"root_cause" => "bad code"}
      context = %{agent_id: "a1"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert is_binary(result)
    end

    test "CRASH: contains root_cause from diagnosis" do
      diagnosis = %{"root_cause" => "syntax error in module"}
      context = %{agent_id: "a1"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert String.contains?(result, "syntax error in module")
    end

    test "CRASH: contains strategy from diagnosis" do
      diagnosis = %{"remediation_strategy" => "fix_file"}
      context = %{agent_id: "a1"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert String.contains?(result, "fix_file")
    end

    test "CRASH: works with atom keys" do
      diagnosis = %{root_cause: "atom key issue", remediation_strategy: "retry"}
      context = %{agent_id: "a1"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert String.contains?(result, "atom key issue")
    end

    test "CRASH: contains agent_id from context" do
      diagnosis = %{}
      context = %{agent_id: "session-99"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert String.contains?(result, "session-99")
    end

    test "CRASH: contains files to inspect" do
      diagnosis = %{"files_to_inspect" => ["lib/foo.ex", "test/foo_test.exs"]}
      context = %{agent_id: "a1"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert String.contains?(result, "lib/foo.ex")
      assert String.contains?(result, "test/foo_test.exs")
    end

    test "CRASH: empty files_to_inspect shows none" do
      diagnosis = %{"files_to_inspect" => []}
      context = %{agent_id: "a1"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert String.contains?(result, "none identified")
    end

    test "CRASH: defaults missing diagnosis fields" do
      diagnosis = %{}
      context = %{agent_id: "a1"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert String.contains?(result, "unknown")   # root_cause default
      assert String.contains?(result, "retry")      # strategy default
    end

    test "CRASH: contains JSON format contract" do
      diagnosis = %{}
      context = %{agent_id: "a1"}
      result = Prompts.fix_prompt(diagnosis, context)
      assert String.contains?(result, "fix_applied")
      assert String.contains?(result, "description")
      assert String.contains?(result, "file_changes")
    end
  end
end
