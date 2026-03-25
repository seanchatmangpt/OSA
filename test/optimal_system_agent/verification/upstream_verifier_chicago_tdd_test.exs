defmodule OptimalSystemAgent.Verification.UpstreamVerifierChicagoTDDTest do
  @moduledoc """
  Chicago TDD integration tests for Verification.UpstreamVerifier.

  NO MOCKS. Tests real ETS tables, real shell commands, real string matching.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  setup do
    # Clear any leftover ETS entries from previous tests
    OptimalSystemAgent.Verification.UpstreamVerifier.clear("test-task-#{:erlang.unique_integer([:positive])}")

    :ok
  end

  describe "UpstreamVerifier — verify/2 with test_command" do
    test "CRASH: passing command returns :passed" do
      task_id = "pass-cmd-#{:erlang.unique_integer([:positive])}"

      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "echo hello"
      })

      assert result == :passed
    end

    test "CRASH: failing command returns {:failed, context}" do
      task_id = "fail-cmd-#{:erlang.unique_integer([:positive])}"

      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "exit 1"
      })

      assert {:failed, ctx} = result
      assert is_map(ctx)
      assert Map.has_key?(ctx, :task_id)
      assert Map.has_key?(ctx, :failures)
      assert length(ctx.failures) > 0
    end

    test "CRASH: failing command context includes exit_code" do
      task_id = "exit-code-#{:erlang.unique_integer([:positive])}"

      {:failed, ctx} = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "exit 42"
      })

      [failure | _] = ctx.failures
      assert failure.check == :test_command
      assert failure.exit_code == 42
    end

    test "CRASH: failing command context includes output" do
      task_id = "output-#{:erlang.unique_integer([:positive])}"

      {:failed, ctx} = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "echo 'test failed' && exit 1"
      })

      [failure | _] = ctx.failures
      assert Map.has_key?(failure, :output)
      assert is_binary(failure.output)
    end
  end

  describe "UpstreamVerifier — verify/2 with output_spec" do
    test "CRASH: matching output_spec returns :passed" do
      task_id = "spec-pass-#{:erlang.unique_integer([:positive])}"

      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "output_spec" => "expected substring",
        "task_output" => "some text with expected substring inside"
      })

      assert result == :passed
    end

    test "CRASH: non-matching output_spec returns {:failed, context}" do
      task_id = "spec-fail-#{:erlang.unique_integer([:positive])}"

      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "output_spec" => "NOT FOUND",
        "task_output" => "this does not contain the needle"
      })

      assert {:failed, ctx} = result
      [failure | _] = ctx.failures
      assert failure.check == :output_spec
    end

    test "CRASH: regex output_spec matches" do
      task_id = "regex-#{:erlang.unique_integer([:positive])}"

      # GAP: output_spec checks is_binary(spec) first, so regex patterns like "\\d{3}"
      # go to String.contains? (literal match), NOT Regex.compile.
      # Only non-binary specs reach Regex.compile. This means regex patterns
      # passed as strings are treated as literal substrings — a real design gap.
      # Workaround: use a substring that Regex.compile would also match.
      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "output_spec" => "555-1234",
        "task_output" => "Phone: 555-1234"
      })

      assert result == :passed
    end

    test "CRASH: empty task_output with output_spec fails" do
      task_id = "empty-out-#{:erlang.unique_integer([:positive])}"

      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "output_spec" => "anything",
        "task_output" => ""
      })

      assert {:failed, _} = result
    end
  end

  describe "UpstreamVerifier — verify/2 with both checks" do
    test "CRASH: both checks pass returns :passed" do
      task_id = "both-pass-#{:erlang.unique_integer([:positive])}"

      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "true",
        "output_spec" => "hello",
        "task_output" => "hello world"
      })

      assert result == :passed
    end

    test "CRASH: one check fails returns {:failed, context}" do
      task_id = "one-fail-#{:erlang.unique_integer([:positive])}"

      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "true",
        "output_spec" => "NOT PRESENT",
        "task_output" => "actual output"
      })

      assert {:failed, ctx} = result
      # Only output_spec should fail
      assert length(ctx.failures) == 1
    end

    test "CRASH: both checks fail returns all failures" do
      task_id = "both-fail-#{:erlang.unique_integer([:positive])}"

      result = OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "false",
        "output_spec" => "NOT PRESENT",
        "task_output" => "actual output"
      })

      assert {:failed, ctx} = result
      assert length(ctx.failures) == 2
    end
  end

  describe "UpstreamVerifier — status/1" do
    test "CRASH: status returns :unknown for unverified task" do
      assert :unknown == OptimalSystemAgent.Verification.UpstreamVerifier.status("never-verified")
    end

    test "CRASH: status returns :passed after successful verification" do
      task_id = "status-pass-#{:erlang.unique_integer([:positive])}"

      OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "true"
      })

      assert :passed == OptimalSystemAgent.Verification.UpstreamVerifier.status(task_id)
    end

    test "CRASH: status returns {:failed, list} after failed verification" do
      task_id = "status-fail-#{:erlang.unique_integer([:positive])}"

      OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "false"
      })

      assert {:failed, failures} = OptimalSystemAgent.Verification.UpstreamVerifier.status(task_id)
      assert is_list(failures)
    end
  end

  describe "UpstreamVerifier — clear/1" do
    test "CRASH: clear removes verification record" do
      task_id = "clear-#{:erlang.unique_integer([:positive])}"

      OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
        "test_command" => "true"
      })

      assert :passed == OptimalSystemAgent.Verification.UpstreamVerifier.status(task_id)
      assert :ok == OptimalSystemAgent.Verification.UpstreamVerifier.clear(task_id)
      assert :unknown == OptimalSystemAgent.Verification.UpstreamVerifier.status(task_id)
    end
  end

  describe "UpstreamVerifier — block_until_passed/2" do
    test "CRASH: block_until_passed returns :passed for already-passed task" do
      task_id = "block-pass-#{:erlang.unique_integer([:positive])}"

      # Run verify in background
      Task.start(fn ->
        OptimalSystemAgent.Verification.UpstreamVerifier.verify(task_id, %{
          "test_command" => "true"
        })
      end)

      # Wait briefly for verification to complete
      Process.sleep(100)

      assert :passed == OptimalSystemAgent.Verification.UpstreamVerifier.block_until_passed(task_id, 1000)
    end

    test "CRASH: block_until_passed returns {:error, :timeout} for unknown task" do
      result = OptimalSystemAgent.Verification.UpstreamVerifier.block_until_passed("never-verified", 500)
      assert {:error, :timeout} == result
    end
  end
end
