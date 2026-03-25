defmodule OptimalSystemAgent.Healing.ErrorClassifierRealTest do
  @moduledoc """
  Chicago TDD integration tests for Healing.ErrorClassifier.

  NO MOCKS. Tests real error classification logic — pattern matching, string analysis.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Healing.ErrorClassifier

  describe "ErrorClassifier.classify/1 — atom inputs" do
    test "CRASH: :budget_exceeded classifies correctly" do
      assert {:budget_exceeded, :high, false} == ErrorClassifier.classify(:budget_exceeded)
    end

    test "CRASH: :over_limit classifies as budget" do
      assert {:budget_exceeded, :high, false} == ErrorClassifier.classify(:over_limit)
    end

    test "CRASH: :timeout classifies as retryable" do
      assert {:timeout, :medium, true} == ErrorClassifier.classify(:timeout)
    end

    test "CRASH: :eacces classifies as permission" do
      assert {:permission_denied, :medium, false} == ErrorClassifier.classify(:eacces)
    end

    test "CRASH: :eperm classifies as permission high" do
      assert {:permission_denied, :high, false} == ErrorClassifier.classify(:eperm)
    end

    test "CRASH: :rate_limited classifies as LLM error retryable" do
      assert {:llm_error, :medium, true} == ErrorClassifier.classify(:rate_limited)
    end

    test "CRASH: :unauthorized classifies as LLM error critical" do
      assert {:llm_error, :critical, false} == ErrorClassifier.classify(:unauthorized)
    end

    test "CRASH: :file_conflict classifies as retryable" do
      assert {:file_conflict, :medium, true} == ErrorClassifier.classify(:file_conflict)
    end

    test "CRASH: :assertion_failed classifies correctly" do
      assert {:assertion_failure, :medium, true} == ErrorClassifier.classify(:assertion_failed)
    end
  end

  describe "ErrorClassifier.classify/1 — map inputs" do
    test "CRASH: %{error: :budget_exceeded}" do
      assert {:budget_exceeded, :high, false} == ErrorClassifier.classify(%{error: :budget_exceeded})
    end

    test "CRASH: %{error: :timeout}" do
      assert {:timeout, :medium, true} == ErrorClassifier.classify(%{error: :timeout})
    end

    test "CRASH: %{error: :permission_denied}" do
      assert {:permission_denied, :high, false} == ErrorClassifier.classify(%{error: :permission_denied})
    end

    test "CRASH: %{error: :deadline_exceeded}" do
      assert {:timeout, :medium, true} == ErrorClassifier.classify(%{error: :deadline_exceeded})
    end

    test "CRASH: %{error: :sandbox_violation}" do
      assert {:permission_denied, :high, false} == ErrorClassifier.classify(%{error: :sandbox_violation})
    end

    test "CRASH: %{error: :file_conflict}" do
      assert {:file_conflict, :medium, true} == ErrorClassifier.classify(%{error: :file_conflict})
    end

    test "CRASH: %{error: :write_before_read} is low severity" do
      assert {:file_conflict, :low, true} == ErrorClassifier.classify(%{error: :write_before_read})
    end

    test "CRASH: %{reason: :rate_limited}" do
      assert {:llm_error, :medium, true} == ErrorClassifier.classify(%{reason: :rate_limited})
    end

    test "CRASH: %{reason: :not_found}" do
      assert {:tool_failure, :medium, true} == ErrorClassifier.classify(%{reason: :not_found})
    end

    test "CRASH: %{reason: :tool_error}" do
      assert {:tool_failure, :medium, true} == ErrorClassifier.classify(%{reason: :tool_error})
    end

    test "CRASH: %{reason: :nxdomain} is high severity" do
      assert {:llm_error, :high, true} == ErrorClassifier.classify(%{reason: :nxdomain})
    end

    test "CRASH: %{reason: :unauthorized} is critical" do
      assert {:llm_error, :critical, false} == ErrorClassifier.classify(%{reason: :unauthorized})
    end

    test "CRASH: %{error: message} with binary message" do
      result = ErrorClassifier.classify(%{error: "rate limit exceeded"})
      assert {:llm_error, :medium, true} == result
    end

    test "CRASH: %{message: msg} with binary message" do
      result = ErrorClassifier.classify(%{message: "permission denied"})
      assert {:permission_denied, :high, false} == result
    end
  end

  describe "ErrorClassifier.classify/1 — string inputs" do
    test "CRASH: budget exceeded string" do
      assert {:budget_exceeded, :high, false} == ErrorClassifier.classify("budget exceeded")
    end

    test "CRASH: rate limit string" do
      assert {:llm_error, :medium, true} == ErrorClassifier.classify("rate limit exceeded")
    end

    test "CRASH: 429 status code string" do
      assert {:llm_error, :medium, true} == ErrorClassifier.classify("HTTP 429 Too Many Requests")
    end

    test "CRASH: unauthorized string" do
      assert {:llm_error, :critical, false} == ErrorClassifier.classify("unauthorized access")
    end

    test "CRASH: timeout string" do
      assert {:timeout, :medium, true} == ErrorClassifier.classify("request timed out")
    end

    test "CRASH: permission denied string" do
      assert {:permission_denied, :high, false} == ErrorClassifier.classify("permission denied")
    end

    test "CRASH: file conflict string" do
      assert {:file_conflict, :medium, true} == ErrorClassifier.classify("file conflict detected")
    end

    test "CRASH: assertion failure string" do
      assert {:assertion_failure, :medium, true} == ErrorClassifier.classify("assertion failed")
    end

    test "CRASH: tool error string" do
      assert {:tool_failure, :medium, true} == ErrorClassifier.classify("tool error: bad input")
    end

    test "CRASH: unknown string returns unknown category" do
      assert {:unknown, :medium, true} == ErrorClassifier.classify("something completely unexpected")
    end

    test "CRASH: case insensitive matching" do
      assert {:budget_exceeded, :high, false} == ErrorClassifier.classify("BUDGET EXCEEDED")
      assert {:budget_exceeded, :high, false} == ErrorClassifier.classify("Budget Exceeded")
    end

    test "CRASH: provider-related string classifies as LLM" do
      result = ErrorClassifier.classify("openai provider error")
      assert elem(result, 0) == :llm_error
    end

    test "CRASH: 403 in string classifies as unauthorized" do
      assert {:llm_error, :critical, false} == ErrorClassifier.classify("got 403 forbidden")
    end

    test "CRASH: 'expected' without 'unexpected' classifies as assertion" do
      result = ErrorClassifier.classify("expected 200 got 500")
      assert {:assertion_failure, :medium, true} == result
    end
  end

  describe "ErrorClassifier.classify/1 — struct inputs" do
    test "CRASH: exception struct with BudgetExceededError name" do
      error = %RuntimeError{message: "budget exceeded"}
      # RuntimeError is "RuntimeError" — not a budget error, but tests the struct path
      result = ErrorClassifier.classify(error)
      assert is_tuple(result)
      assert tuple_size(result) == 3
    end
  end

  describe "ErrorClassifier.classify/1 — catch-all" do
    test "CRASH: unknown input returns unknown category" do
      assert {:unknown, :medium, true} == ErrorClassifier.classify(%{weird: :data})
    end

    test "CRASH: integer input returns unknown" do
      assert {:unknown, :medium, true} == ErrorClassifier.classify(42)
    end

    test "CRASH: empty string returns unknown" do
      assert {:unknown, :medium, true} == ErrorClassifier.classify("")
    end

    test "CRASH: unknown reason atom returns unknown" do
      assert {:unknown, :medium, true} == ErrorClassifier.classify(%{reason: :something_unknown})
    end
  end
end
