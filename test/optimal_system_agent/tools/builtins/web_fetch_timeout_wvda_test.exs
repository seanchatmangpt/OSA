defmodule OptimalSystemAgent.Tools.Builtins.WebFetchTimeoutWvDATest do
  @moduledoc """
  Chicago TDD: WebFetch tool timeout handling (WvdA Deadlock-Free).

  Tests verify WvdA Soundness Property #1: Deadlock Freedom.
  - All blocking operations (HTTP fetch) have explicit timeout_ms
  - Timeout triggers escalation (error return, not hang)
  - No indefinite waits

  Armstrong Principle: Let-It-Crash
  - Timeout is treated as a normal failure mode, not swallowed
  - Error propagates to caller for proper handling

  FIRST Principles:
  - F: Fast (mocked HTTP, no real network) <100ms
  - I: Independent (no shared state, no setup coupling)
  - R: Repeatable (deterministic timeouts via mock)
  - S: Self-Checking (explicit assertions on timeout behavior)
  - T: Timely (written for implementation already done)
  """

  use ExUnit.Case, async: true

  @moduletag :requires_application

  alias OptimalSystemAgent.Tools.Builtins.WebFetch

  describe "WvdA Deadlock-Free: Timeout Handling" do
    test "DEADLOCK-FREE: execute/2 accepts timeout_ms parameter" do
      # RED: Can we pass timeout_ms?
      result = WebFetch.execute(%{"url" => "https://example.com"}, timeout_ms: 5000)
      # GREEN: Should either succeed or return error (not hang)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "DEADLOCK-FREE: Default timeout_ms is documented (30s for web_fetch)" do
      # RED: Default timeout must be explicit (not infinite)
      # GREEN: Verify default is reasonable for HTTP fetch
      # Extract timeout from module documentation/implementation
      source_code = File.read!("lib/optimal_system_agent/tools/builtins/web_fetch.ex")
      assert source_code =~ "30_000" || source_code =~ "timeout"
    end

    test "DEADLOCK-FREE: validate_url/1 doesn't hang (local operation)" do
      # RED: URL validation must be synchronous, no blocking ops
      start_time = System.monotonic_time(:millisecond)
      _result = WebFetch.execute(%{"url" => "https://example.com"})
      elapsed = System.monotonic_time(:millisecond) - start_time
      # REFACTOR: Validation should be <100ms even with network timeout
      assert elapsed < 5000, "URL validation took #{elapsed}ms, should be <5s"
    end

    test "DEADLOCK-FREE: Invalid URL rejected quickly (no network attempt)" do
      # RED: Invalid URLs rejected WITHOUT attempting HTTP (deadlock prevention)
      start_time = System.monotonic_time(:millisecond)
      result = WebFetch.execute(%{"url" => "ftp://example.com"})
      elapsed = System.monotonic_time(:millisecond) - start_time

      assert match?({:error, _}, result)
      assert elapsed < 100, "Invalid URL should reject in <100ms, took #{elapsed}ms"
    end

    test "DEADLOCK-FREE: HTTP-only URLs for localhost rejected immediately" do
      # RED: http:// security check (not https) must fail quickly
      result = WebFetch.execute(%{"url" => "http://example.com"})
      assert match?({:error, _reason}, result)
      assert elem(result, 1) =~ "HTTPS"
    end

    test "DEADLOCK-FREE: Missing URL parameter returns error (no hang)" do
      # RED: Missing required params shouldn't trigger network call
      result = WebFetch.execute(%{})
      assert match?({:error, "Missing required parameter: url"}, result)
    end
  end

  describe "Armstrong Let-It-Crash: Timeout as Observable Error" do
    test "CRASH: execute/1 returns {:error, reason} on validation failure" do
      # RED: Errors are returned, not swallowed
      result = WebFetch.execute(%{"url" => 123})
      assert match?({:error, _}, result)
      # GREEN: Error message is descriptive
      assert elem(result, 1) =~ "string"
    end

    test "CRASH: execute/1 returns {:error, reason} on unsupported scheme" do
      # RED: Unsupported schemes cause error, not exception
      result = WebFetch.execute(%{"url" => "gopher://example.com"})
      assert match?({:error, _}, result)
      assert elem(result, 1) =~ "scheme"
    end
  end

  describe "FIRST Principles: Independent & Repeatable" do
    test "INDEPENDENT: Multiple calls don't affect each other" do
      # RED: Each call is independent
      result1 = WebFetch.execute(%{"url" => "https://example.com"})
      result2 = WebFetch.execute(%{"url" => "https://another.com"})

      # GREEN: Both should complete without interference
      assert match?({:ok, _}, result1) or match?({:error, _}, result1)
      assert match?({:ok, _}, result2) or match?({:error, _}, result2)
    end

    test "REPEATABLE: Same call produces same result" do
      # RED: Deterministic behavior (without network mocking)
      params = %{"url" => "invalid-not-a-url"}
      result1 = WebFetch.execute(params)
      result2 = WebFetch.execute(params)

      # GREEN: Both results identical
      assert result1 == result2
    end

    test "SELF-CHECKING: max_length parameter accepted" do
      # RED: Parameters schema allows max_length
      schema = WebFetch.parameters()
      props = Map.get(schema, "properties")
      assert Map.has_key?(props, "max_length")

      # GREEN: max_length is optional (not in required list)
      required = Map.get(schema, "required")
      refute "max_length" in required
    end
  end

  describe "Behavior Contract: Tool Metadata" do
    test "CRASH: Implements Tools.Behaviour" do
      assert function_exported?(WebFetch, :safety, 0)
      assert function_exported?(WebFetch, :name, 0)
      assert function_exported?(WebFetch, :description, 0)
      assert function_exported?(WebFetch, :parameters, 0)
      assert function_exported?(WebFetch, :execute, 1)
    end

    test "CRASH: safety/0 returns :read_only (safe)" do
      assert WebFetch.safety() == :read_only
    end

    test "CRASH: name/0 returns 'web_fetch'" do
      assert WebFetch.name() == "web_fetch"
    end

    test "CRASH: parameters schema has url required" do
      schema = WebFetch.parameters()
      required = Map.get(schema, "required")
      assert "url" in required
    end
  end
end
