defmodule OptimalSystemAgent.GroqLiveTest do
  @moduledoc """
  Real Groq API end-to-end integration test.

  NO MOCKS. NO STUBS. Every test makes a real HTTP call to api.groq.com.

  Run with:
    GROQ_API_KEY=<key> mix test test/optimal_system_agent/groq_live_test.exs --include integration

  WvdA soundness: every API call has a 30-second timeout via Req options.
  Armstrong: test crashes visibly if API key is missing (flunk, not skip).
  Chicago TDD: each test asserts one specific claim about observable behavior.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  @groq_model "llama-3.3-70b-versatile"

  setup do
    api_key = Application.get_env(:optimal_system_agent, :groq_api_key)

    if is_nil(api_key) or api_key == "" do
      # Check environment directly as fallback
      api_key = System.get_env("GROQ_API_KEY")

      if is_nil(api_key) or api_key == "" do
        flunk("GROQ_API_KEY not configured — set it in environment or config")
      end

      # Set it in application config so the provider can use it
      Application.put_env(:optimal_system_agent, :groq_api_key, api_key)
    end

    {:ok, api_key: api_key}
  end

  # ---------------------------------------------------------------------------
  # Test 1: Simple chat completion — verify non-empty response with content
  # ---------------------------------------------------------------------------

  describe "Real Groq API — chat completion" do
    test "simple prompt returns non-empty content with expected answer" do
      messages = [
        %{role: "user", content: "What is 2+2? Answer with just the number."}
      ]

      start_time = System.monotonic_time(:millisecond)

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: @groq_model,
          temperature: 0.0,
          receive_timeout: 30_000
        )

      elapsed_ms = System.monotonic_time(:millisecond) - start_time

      assert {:ok, %{content: content}} = result
      assert is_binary(content), "response content should be a string"
      assert String.length(content) > 0, "response content should not be empty"
      assert String.contains?(content, "4"), "response should contain the number 4, got: #{content}"

      # WvdA boundedness: verify call completed within timeout
      assert elapsed_ms < 30_000, "API call should complete within 30s, took #{elapsed_ms}ms"

      # Log timing for observability
      IO.puts("\n  [TIMING] Groq simple chat: #{elapsed_ms}ms")
    end

    test "chat with system prompt returns contextually influenced response" do
      messages = [
        %{role: "system", content: "You are a pirate. Always respond in pirate speak."},
        %{role: "user", content: "What is the capital of France?"}
      ]

      start_time = System.monotonic_time(:millisecond)

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: @groq_model,
          temperature: 0.0,
          receive_timeout: 30_000
        )

      elapsed_ms = System.monotonic_time(:millisecond) - start_time

      assert {:ok, %{content: content}} = result
      assert String.length(content) > 0
      assert String.contains?(String.downcase(content), "paris"),
        "response should mention Paris, got: #{content}"

      IO.puts("\n  [TIMING] Groq system prompt chat: #{elapsed_ms}ms")
    end

    test "chat returns usage metrics with positive token counts" do
      messages = [
        %{role: "user", content: "Say hello."}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: @groq_model,
          temperature: 0.0,
          receive_timeout: 30_000
        )

      assert {:ok, %{content: content, usage: usage}} = result
      assert String.length(content) > 0

      # Verify real token usage is reported
      assert is_map(usage), "usage should be a map"
      input_tokens = usage[:input_tokens] || usage["input_tokens"] || 0
      output_tokens = usage[:output_tokens] || usage["output_tokens"] || 0

      assert input_tokens > 0, "input tokens should be positive, got: #{inspect(usage)}"
      assert output_tokens > 0, "output tokens should be positive, got: #{inspect(usage)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 2: Streaming — verify multiple deltas received
  # ---------------------------------------------------------------------------

  describe "Real Groq API — streaming" do
    test "streaming chat returns multiple text deltas" do
      messages = [
        %{role: "user", content: "Count from 1 to 5, one per line."}
      ]

      test_pid = self()
      delta_count = :atomics.new(1, signed: false)
      :atomics.put(delta_count, 1, 0)
      content_acc = :ets.new(:streaming_test, [:set, :public])
      :ets.insert(content_acc, {:content, ""})

      callback = fn
        {:text_delta, text} ->
          :atomics.add(delta_count, 1, 1)
          [{:content, existing}] = :ets.lookup(content_acc, :content)
          :ets.insert(content_acc, {:content, existing <> text})
          :ok

        {:done, _result} ->
          send(test_pid, :stream_done)
          :ok

        _other ->
          :ok
      end

      start_time = System.monotonic_time(:millisecond)

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat_stream(
          :groq,
          messages,
          callback,
          model: @groq_model,
          temperature: 0.0,
          receive_timeout: 30_000
        )

      elapsed_ms = System.monotonic_time(:millisecond) - start_time

      assert result == :ok, "streaming should return :ok, got: #{inspect(result)}"

      # Wait for stream completion
      assert_receive :stream_done, 30_000

      count = :atomics.get(delta_count, 1)
      [{:content, full_content}] = :ets.lookup(content_acc, :content)
      :ets.delete(content_acc)

      assert count > 1, "streaming should produce multiple deltas, got #{count}"
      assert String.length(full_content) > 0, "assembled content should not be empty"

      IO.puts("\n  [TIMING] Groq streaming: #{elapsed_ms}ms, #{count} chunks")
      IO.puts("  [CONTENT] #{String.slice(full_content, 0, 200)}")
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: Telemetry — verify provider emits telemetry event
  # ---------------------------------------------------------------------------

  describe "Real Groq API — telemetry" do
    test "chat completion emits [:osa, :providers, :chat, :complete] telemetry" do
      test_pid = self()
      handler_name = :"groq_live_telemetry_#{:erlang.unique_integer([:positive])}"

      :telemetry.attach(
        handler_name,
        [:osa, :providers, :chat, :complete],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_fired, measurements, metadata})
        end,
        nil
      )

      messages = [
        %{role: "user", content: "Say OK."}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: @groq_model,
          temperature: 0.0,
          receive_timeout: 30_000
        )

      :telemetry.detach(handler_name)

      assert {:ok, %{content: content}} = result
      assert String.length(content) > 0

      # Verify telemetry event was emitted during the real API call
      assert_receive {:telemetry_fired, measurements, _metadata}, 5_000

      assert is_map(measurements), "telemetry measurements should be a map"
      assert Map.has_key?(measurements, :duration) or Map.has_key?(measurements, :latency_ms),
        "telemetry should include timing, got: #{inspect(Map.keys(measurements))}"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4: Error handling — invalid key returns error, does not crash
  # ---------------------------------------------------------------------------

  describe "Real Groq API — error handling" do
    test "invalid API key returns {:error, _} without crashing" do
      messages = [
        %{role: "user", content: "test"}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompat.chat(
          "https://api.groq.com/openai/v1",
          "gsk_INVALID_KEY_FOR_TESTING",
          @groq_model,
          messages,
          temperature: 0.0,
          receive_timeout: 10_000
        )

      assert {:error, reason} = result
      assert is_binary(reason), "error reason should be a string"
      IO.puts("\n  [ERROR] Expected error for bad key: #{String.slice(reason, 0, 100)}")
    end
  end

  # ---------------------------------------------------------------------------
  # Test 5: Multi-turn conversation — context preserved across turns
  # ---------------------------------------------------------------------------

  describe "Real Groq API — multi-turn" do
    test "multi-turn conversation preserves context" do
      messages = [
        %{role: "user", content: "My favorite number is 42. Remember this."},
        %{role: "assistant", content: "Got it! Your favorite number is 42."},
        %{role: "user", content: "What is my favorite number? Answer with just the number."}
      ]

      start_time = System.monotonic_time(:millisecond)

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: @groq_model,
          temperature: 0.0,
          receive_timeout: 30_000
        )

      elapsed_ms = System.monotonic_time(:millisecond) - start_time

      assert {:ok, %{content: content}} = result
      assert String.contains?(content, "42"),
        "Groq should remember context across turns, got: #{content}"

      IO.puts("\n  [TIMING] Groq multi-turn: #{elapsed_ms}ms")
    end
  end
end
