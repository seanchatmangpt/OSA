defmodule OptimalSystemAgent.Healing.ErrorClassifierTest do
  @moduledoc """
  Unit tests for ErrorClassifier — verifies classification of various error shapes
  into {category, severity, retryable?} tuples.
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Healing.ErrorClassifier

  # Fake exception structs for testing struct-based classification
  defmodule FakeTimeoutError do
    defexception [:message]
  end

  defmodule FakeAPIError do
    defexception [:message]
  end

  defmodule FakeAPIErrorAuth do
    defexception [:message]
  end

  defmodule FakeBudgetExceededError do
    defexception [:message]
  end

  # Note: classify_by_name/2 extracts the last segment via Module.split/1.
  # For classifiers matching "PermissionDeniedError", the module's last
  # segment must be exactly that string.
  defmodule Fake.PermissionDeniedError do
    defexception [:message]
  end

  describe "classify/1 with atoms" do
    @tag :unit
    test "classifies :budget_exceeded" do
      assert {:budget_exceeded, :high, false} = ErrorClassifier.classify(:budget_exceeded)
    end

    @tag :unit
    test "classifies :over_limit" do
      assert {:budget_exceeded, :high, false} = ErrorClassifier.classify(:over_limit)
    end

    @tag :unit
    test "classifies :timeout" do
      assert {:timeout, :medium, true} = ErrorClassifier.classify(:timeout)
    end

    @tag :unit
    test "classifies :eacces" do
      assert {:permission_denied, :medium, false} = ErrorClassifier.classify(:eacces)
    end

    @tag :unit
    test "classifies :eperm" do
      assert {:permission_denied, :high, false} = ErrorClassifier.classify(:eperm)
    end

    @tag :unit
    test "classifies :file_conflict" do
      assert {:file_conflict, :medium, true} = ErrorClassifier.classify(:file_conflict)
    end

    @tag :unit
    test "classifies :write_before_read" do
      assert {:file_conflict, :low, true} = ErrorClassifier.classify(:write_before_read)
    end

    @tag :unit
    test "classifies :rate_limited" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify(:rate_limited)
    end

    @tag :unit
    test "classifies :unauthorized" do
      assert {:llm_error, :critical, false} = ErrorClassifier.classify(:unauthorized)
    end

    @tag :unit
    test "classifies :assertion_failed" do
      assert {:assertion_failure, :medium, true} = ErrorClassifier.classify(:assertion_failed)
    end
  end

  describe "classify/1 with maps (atom error keys)" do
    @tag :unit
    test "classifies %{error: :budget_exceeded}" do
      assert {:budget_exceeded, :high, false} = ErrorClassifier.classify(%{error: :budget_exceeded})
    end

    @tag :unit
    test "classifies %{error: :over_limit}" do
      assert {:budget_exceeded, :high, false} = ErrorClassifier.classify(%{error: :over_limit})
    end

    @tag :unit
    test "classifies %{error: :permission_denied}" do
      assert {:permission_denied, :high, false} = ErrorClassifier.classify(%{error: :permission_denied})
    end

    @tag :unit
    test "classifies %{error: :eacces}" do
      assert {:permission_denied, :medium, false} = ErrorClassifier.classify(%{error: :eacces})
    end

    @tag :unit
    test "classifies %{error: :sandbox_violation}" do
      assert {:permission_denied, :high, false} = ErrorClassifier.classify(%{error: :sandbox_violation})
    end

    @tag :unit
    test "classifies %{error: :timeout}" do
      assert {:timeout, :medium, true} = ErrorClassifier.classify(%{error: :timeout})
    end

    @tag :unit
    test "classifies %{error: :deadline_exceeded}" do
      assert {:timeout, :medium, true} = ErrorClassifier.classify(%{error: :deadline_exceeded})
    end

    @tag :unit
    test "classifies %{error: :file_conflict}" do
      assert {:file_conflict, :medium, true} = ErrorClassifier.classify(%{error: :file_conflict})
    end

    @tag :unit
    test "classifies %{error: :write_before_read}" do
      assert {:file_conflict, :low, true} = ErrorClassifier.classify(%{error: :write_before_read})
    end

    @tag :unit
    test "classifies %{error: :rate_limited} as LLM error with retry" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify(%{error: :rate_limited})
    end

    @tag :unit
    test "classifies %{error: :service_unavailable} as LLM error" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify(%{error: :service_unavailable})
    end

    @tag :unit
    test "classifies %{error: :bad_gateway} as LLM error" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify(%{error: :bad_gateway})
    end

    @tag :unit
    test "classifies %{error: :unauthorized} as LLM error critical" do
      assert {:llm_error, :critical, false} = ErrorClassifier.classify(%{error: :unauthorized})
    end

    @tag :unit
    test "classifies %{error: :forbidden} as LLM error critical" do
      assert {:llm_error, :critical, false} = ErrorClassifier.classify(%{error: :forbidden})
    end

    @tag :unit
    test "classifies %{error: :invalid_api_key} as LLM error critical" do
      assert {:llm_error, :critical, false} = ErrorClassifier.classify(%{error: :invalid_api_key})
    end

    @tag :unit
    test "classifies %{error: :not_found} as tool failure" do
      assert {:tool_failure, :medium, true} = ErrorClassifier.classify(%{error: :not_found})
    end

    @tag :unit
    test "classifies %{error: :tool_not_found} as tool failure" do
      assert {:tool_failure, :medium, true} = ErrorClassifier.classify(%{error: :tool_not_found})
    end

    @tag :unit
    test "classifies %{error: :tool_error} as tool failure" do
      assert {:tool_failure, :medium, true} = ErrorClassifier.classify(%{error: :tool_error})
    end

    @tag :unit
    test "classifies %{error: :nxdomain} as LLM error high" do
      assert {:llm_error, :high, true} = ErrorClassifier.classify(%{error: :nxdomain})
    end

    @tag :unit
    test "classifies %{error: :econnrefused} as LLM error high" do
      assert {:llm_error, :high, true} = ErrorClassifier.classify(%{error: :econnrefused})
    end

    @tag :unit
    test "classifies %{error: :closed} as LLM error high" do
      assert {:llm_error, :high, true} = ErrorClassifier.classify(%{error: :closed})
    end
  end

  describe "classify/1 with maps (reason key)" do
    @tag :unit
    test "classifies %{reason: :rate_limited}" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify(%{reason: :rate_limited})
    end

    @tag :unit
    test "classifies %{reason: :forbidden}" do
      assert {:llm_error, :critical, false} = ErrorClassifier.classify(%{reason: :forbidden})
    end
  end

  describe "classify/1 with maps (binary message keys)" do
    @tag :unit
    test "classifies %{error: \"rate limit exceeded\"}" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify(%{error: "rate limit exceeded"})
    end

    @tag :unit
    test "classifies %{message: \"timeout after 30s\"}" do
      assert {:timeout, :medium, true} = ErrorClassifier.classify(%{message: "timeout after 30s"})
    end

    @tag :unit
    test "classifies %{message: \"unauthorized: invalid API key\"}" do
      assert {:llm_error, :critical, false} = ErrorClassifier.classify(%{message: "unauthorized: invalid API key"})
    end
  end

  describe "classify/1 with strings" do
    @tag :unit
    test "classifies budget exceeded strings" do
      assert {:budget_exceeded, :high, false} = ErrorClassifier.classify("budget exceeded")
      assert {:budget_exceeded, :high, false} = ErrorClassifier.classify("OVER LIMIT reached")
      assert {:budget_exceeded, :high, false} = ErrorClassifier.classify("cost limit hit")
    end

    @tag :unit
    test "classifies rate limit strings" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify("rate limit exceeded")
      assert {:llm_error, :medium, true} = ErrorClassifier.classify("too many requests")
      assert {:llm_error, :medium, true} = ErrorClassifier.classify("HTTP 429")
    end

    @tag :unit
    test "classifies auth error strings" do
      assert {:llm_error, :critical, false} = ErrorClassifier.classify("unauthorized access")
      assert {:llm_error, :critical, false} = ErrorClassifier.classify("invalid api key")
      assert {:llm_error, :critical, false} = ErrorClassifier.classify("HTTP 403 forbidden")
      assert {:llm_error, :critical, false} = ErrorClassifier.classify("authentication failed")
    end

    @tag :unit
    test "classifies timeout strings" do
      assert {:timeout, :medium, true} = ErrorClassifier.classify("request timeout")
      assert {:timeout, :medium, true} = ErrorClassifier.classify("timed out after 30s")
      assert {:timeout, :medium, true} = ErrorClassifier.classify("deadline exceeded")
      assert {:timeout, :medium, true} = ErrorClassifier.classify("operation took too long")
    end

    @tag :unit
    test "classifies permission denied strings" do
      assert {:permission_denied, :high, false} = ErrorClassifier.classify("permission denied")
      assert {:permission_denied, :high, false} = ErrorClassifier.classify("eacces: permission denied")
      assert {:permission_denied, :high, false} = ErrorClassifier.classify("sandbox violation")
      assert {:permission_denied, :high, false} = ErrorClassifier.classify("not allowed")
    end

    @tag :unit
    test "classifies file conflict strings" do
      assert {:file_conflict, :medium, true} = ErrorClassifier.classify("file conflict detected")
      assert {:file_conflict, :medium, true} = ErrorClassifier.classify("write before read violation")
      assert {:file_conflict, :medium, true} = ErrorClassifier.classify("merge conflict in file.txt")
      assert {:file_conflict, :medium, true} = ErrorClassifier.classify("already modified")
    end

    @tag :unit
    test "classifies assertion failure strings" do
      assert {:assertion_failure, :medium, true} = ErrorClassifier.classify("assertion failed")
      assert {:assertion_failure, :medium, true} = ErrorClassifier.classify("expected 200 got 500")
      assert {:assertion_failure, :medium, true} = ErrorClassifier.classify("test failed: wrong value")
    end

    @tag :unit
    test "classifies tool failure strings" do
      assert {:tool_failure, :medium, true} = ErrorClassifier.classify("tool error: file not found")
      assert {:tool_failure, :medium, true} = ErrorClassifier.classify("function call failed")
      assert {:tool_failure, :medium, true} = ErrorClassifier.classify("tool_call_format_failed")
    end

    @tag :unit
    test "classifies LLM provider strings" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify("openai provider error")
      assert {:llm_error, :medium, true} = ErrorClassifier.classify("anthropic model error")
      assert {:llm_error, :medium, true} = ErrorClassifier.classify("ollama connection issue")
    end

    @tag :unit
    test "classifies LLM provider strings with rate limit" do
      assert {:llm_error, :medium, true} = ErrorClassifier.classify("openai rate limit hit")
    end

    @tag :unit
    test "classifies LLM provider strings with auth error" do
      assert {:llm_error, :critical, false} = ErrorClassifier.classify("anthropic unauthorized")
    end

    @tag :unit
    test "classifies unknown strings" do
      # Avoid trigger words: "expected" matches assertion_failure, etc.
      assert {:unknown, :medium, true} = ErrorClassifier.classify("xyzzy nothing matches this")
      assert {:unknown, :medium, true} = ErrorClassifier.classify("")
    end
  end

  describe "classify/1 with exception structs" do
    @tag :unit
    test "classifies %RuntimeError{} as assertion_failure" do
      error = %RuntimeError{message: "oops"}
      assert {:assertion_failure, :medium, true} = ErrorClassifier.classify(error)
    end

    @tag :unit
    test "classifies custom exception structs by name" do
      error = %FakeTimeoutError{message: "took too long"}
      assert {:timeout, :medium, true} = ErrorClassifier.classify(error)
    end

    @tag :unit
    test "classifies custom APIError struct" do
      error = %FakeAPIError{message: "rate limit exceeded"}
      assert {:llm_error, :medium, true} = ErrorClassifier.classify(error)
    end

    @tag :unit
    test "classifies custom APIError struct with auth message" do
      error = %FakeAPIErrorAuth{message: "401 unauthorized"}
      assert {:llm_error, :critical, false} = ErrorClassifier.classify(error)
    end

    @tag :unit
    test "classifies custom BudgetExceededError struct" do
      error = %FakeBudgetExceededError{message: "budget exceeded"}
      assert {:budget_exceeded, :high, false} = ErrorClassifier.classify(error)
    end

    @tag :unit
    test "classifies custom PermissionDeniedError struct" do
      error = %Fake.PermissionDeniedError{message: "no access"}
      assert {:permission_denied, :high, false} = ErrorClassifier.classify(error)
    end
  end

  describe "classify/1 catch-all" do
    @tag :unit
    test "classifies nil as unknown" do
      assert {:unknown, :medium, true} = ErrorClassifier.classify(nil)
    end

    @tag :unit
    test "classifies integers as unknown" do
      assert {:unknown, :medium, true} = ErrorClassifier.classify(42)
    end

    @tag :unit
    test "classifies empty list as unknown" do
      assert {:unknown, :medium, true} = ErrorClassifier.classify([])
    end
  end
end
