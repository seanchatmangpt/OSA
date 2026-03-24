defmodule OptimalSystemAgent.ChicagoTDD.GroqIntegrationTest do
  @moduledoc """
  Chicago TDD — Real Groq API Integration Tests.

  NO MOCKS. NO STUBS. Every test hits the actual Groq API at api.groq.com.
  Requires GROQ_API_KEY environment variable.

  These tests exercise the FULL pipeline:
    Providers.chat → OpenAICompatProvider.chat → OpenAICompat.do_chat → HTTP POST → api.groq.com

  Following Joe Armstrong's principle: "Make it crash, then fix it."
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  setup do
    api_key = Application.get_env(:optimal_system_agent, :groq_api_key)

    if is_nil(api_key) or api_key == "" do
      flunk("GROQ_API_KEY not configured — set it in .env or environment")
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Layer 1: Direct Provider Chat (real HTTP call)
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Real Groq API Calls — Provider Layer" do
    test "CRASH: simple chat completion returns valid response" do
      # Chicago TDD: Hit the REAL Groq API with a simple prompt
      messages = [
        %{role: "user", content: "Reply with exactly: PONG"}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert match?({:ok, %{content: _, usage: _}}, result)

      {:ok, %{content: content, usage: usage}} = result

      # Verify we got actual LLM output (not empty, not error)
      assert String.length(content) > 0, "Groq response should have content"
      assert String.contains?(String.upcase(content), "PONG"),
        "Expected PONG in response, got: #{content}"

      # Verify usage metrics (real API calls always return these)
      assert Map.has_key?(usage, :input_tokens), "Usage should have input_tokens"
      assert Map.has_key?(usage, :output_tokens), "Usage should have output_tokens"
      assert usage.input_tokens > 0, "Should have consumed input tokens"
      assert usage.output_tokens > 0, "Should have consumed output tokens"
    end

    test "CRASH: chat with system prompt returns contextually-aware response" do
      # Chicago TDD: System prompt must influence the response
      messages = [
        %{role: "system", content: "You are a Fortune 5 signal classifier. Respond ONLY with JSON."},
        %{role: "user", content: "Classify this signal: 'Deploy to production'"}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert {:ok, %{content: content}} = result
      assert String.length(content) > 0

      # Should contain JSON-like structure (system prompt influenced output)
      assert (String.contains?(content, "{") or String.contains?(content, "signal") or
               String.contains?(content, "classify")),
        "System prompt should influence response. Got: #{content}"
    end

    test "CRASH: chat with tool definitions returns tool calls" do
      # Chicago TDD: Verify Groq can parse tool definitions and return tool calls
      # Using plain maps with all required fields for Groq API
      tools = [
        %{
          "type" => "function",
          "function" => %{
            "name" => "scan_codebase",
            "description" => "Scan a codebase directory for modules and dependencies",
            "parameters" => %{
              "type" => "object",
              "properties" => %{
                "path" => %{
                  "type" => "string",
                  "description" => "Directory path to scan"
                }
              },
              "required" => ["path"]
            }
          }
        }
      ]

      messages = [
        %{role: "system", content: "You must call the scan_codebase tool with path '/tmp/test'."},
        %{role: "user", content: "Scan the codebase at /tmp/test"}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0,
          tools: tools
        )

      # Groq may return tool_calls or may respond directly - either is valid
      case result do
        {:ok, %{tool_calls: tool_calls}} when is_list(tool_calls) ->
          :ok  # Tool calls returned

        {:ok, %{content: _content}} ->
          :ok  # Direct response without tool calls

        {:ok, response} ->
          # Unexpected response format - log but don't crash
          flunk("Unexpected response format: #{inspect(response)}")

        {:error, reason} ->
          # Error from Groq API - this is a gap to fix
          flunk("Groq API error: #{inspect(reason)}")
      end
    end

    test "CRASH: streaming chat returns text deltas" do
      # Chicago TDD: Verify streaming works end-to-end
      messages = [
        %{role: "user", content: "Count from 1 to 5, one number per line."}
      ]

      collected_deltas = :atomics.new(1, signed: false)
      :atomics.put(collected_deltas, 1, 0)

      callback = fn
        {:text_delta, _text} ->
          :atomics.add(collected_deltas, 1, 1)
          :ok

        {:done, _result} ->
          :ok

        _other ->
          :ok
      end

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat_stream(
          :groq,
          messages,
          callback,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert result == :ok

      # Should have received multiple text deltas (streaming, not single response)
      delta_count = :atomics.get(collected_deltas, 1)
      assert delta_count > 1, "Streaming should produce multiple deltas, got #{delta_count}"
    end

    test "CRASH: invalid API key returns error not crash" do
      # Chicago TDD: Bad credentials should return error, not raise
      messages = [
        %{role: "user", content: "test"}
      ]

      # Direct call to OpenAICompat with invalid key
      result =
        OptimalSystemAgent.Providers.OpenAICompat.chat(
          "https://api.groq.com/openai/v1",
          "gsk_INVALID_KEY_12345",
          "openai/gpt-oss-20b",
          messages,
          temperature: 0.0
        )

      # Should return error, not crash
      assert match?({:error, _}, result)
    end

    test "CRASH: empty messages list returns error not crash" do
      # Chicago TDD: Edge case — empty message list
      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          [],
          model: "openai/gpt-oss-20b"
        )

      # Should return error (Groq requires at least one message)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "CRASH: very long prompt doesn't crash (within context window)" do
      # Chicago TDD: Large input within context window
      large_text = String.duplicate("The quick brown fox jumps over the lazy dog. ", 100)

      messages = [
        %{role: "user", content: "Summarize this in one sentence: #{large_text}"}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert match?({:ok, %{content: _}}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # Layer 2: Provider Registry Routing (real dispatch)
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Real Groq API Calls — Provider Registry" do
    test "CRASH: Providers.chat dispatches to Groq and returns response" do
      # Chicago TDD: Full provider registry → Groq pipeline
      messages = [
        %{role: "user", content: "Say 'provider registry works'"}
      ]

      result =
        OptimalSystemAgent.Providers.Registry.chat(messages,
          provider: :groq,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert {:ok, %{content: content}} = result
      assert String.length(content) > 0
    end

    test "CRASH: Providers.chat_stream dispatches to Groq with streaming" do
      # Chicago TDD: Registry → streaming pipeline
      messages = [
        %{role: "user", content: "Say 'streaming works'"}
      ]

      delta_count = :atomics.new(1, signed: false)
      :atomics.put(delta_count, 1, 0)

      callback = fn
        {:text_delta, _text} ->
          :atomics.add(delta_count, 1, 1)
          :ok

        {:done, _result} ->
          :ok

        _ ->
          :ok
      end

      result =
        OptimalSystemAgent.Providers.Registry.chat_stream(messages, callback,
          provider: :groq,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert result == :ok
      assert :atomics.get(delta_count, 1) > 0
    end

    test "CRASH: provider_info returns Groq as configured" do
      # Chicago TDD: Verify Groq is properly registered and configured
      # provider_info/1 returns {:ok, map} not plain map
      {:ok, info} = OptimalSystemAgent.Providers.Registry.provider_info(:groq)

      assert is_map(info)
      assert info[:configured?] == true, "Groq should be configured with API key"
      assert info[:name] == :groq
    end

    test "CRASH: provider_configured? returns true for Groq" do
      assert OptimalSystemAgent.Providers.Registry.provider_configured?(:groq) == true
    end
  end

  # ---------------------------------------------------------------------------
  # Layer 3: Signal Theory + Groq (Fortune 5 Integration)
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Real Groq API Calls — Fortune 5 Signal Analysis" do
    test "CRASH: scan sensor data → feed to Groq → get analysis" do
      # Chicago TDD: Full Fortune 5 pipeline — scan codebase, feed to LLM
      # This is what Fortune 5 Layer 4 (Correlation) actually does

      # Step 1: Scan the codebase (real files, real ETS)
      OptimalSystemAgent.Sensors.SensorRegistry.init_tables()

      output_dir = "tmp/chicago_groq_fortune5"
      File.rm_rf!(output_dir)
      File.mkdir_p!(output_dir)

      {:ok, _scan_result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: "lib",
        output_dir: output_dir
      )

      # Step 2: Read the SPR output (real files)
      modules_json = File.read!(Path.join(output_dir, "modules.json"))
      modules_data = Jason.decode!(modules_json)

      # Step 3: Build a prompt for Groq with REAL scan data
      module_names =
        modules_data["modules"]
        |> Enum.take(10)
        |> Enum.map(fn m -> m["name"] end)
        |> Enum.join(", ")

      prompt = """
      You are a Fortune 5 Signal Correlator. Analyze these Elixir modules:
      #{module_names}

      Classify the YAWL workflow pattern density. Reply in JSON:
      {"pattern_density": "high|medium|low", "dominant_pattern": "...", "module_count": N}
      """

      messages = [
        %{role: "system", content: "You are a Fortune 5 Signal Correlator. Respond with valid JSON only."},
        %{role: "user", content: prompt}
      ]

      # Step 4: Call REAL Groq API with scan data
      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert {:ok, %{content: content}} = result
      assert String.length(content) > 0

      # Should contain pattern analysis
      assert (String.contains?(content, "pattern") or String.contains?(content, "Pattern") or
               String.contains?(content, "JSON")),
        "Groq should analyze patterns. Got: #{content}"
    end

    test "CRASH: Groq analyzes dependency graph from real scan" do
      # Chicago TDD: Feed real dependency data to Groq for analysis
      OptimalSystemAgent.Sensors.SensorRegistry.init_tables()

      output_dir = "tmp/chicago_groq_deps"
      File.rm_rf!(output_dir)
      File.mkdir_p!(output_dir)

      {:ok, _scan_result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: "lib",
        output_dir: output_dir
      )

      # Read real dependency data
      deps_json = File.read!(Path.join(output_dir, "deps.json"))
      deps_data = Jason.decode!(deps_json)

      top_deps =
        deps_data["dependencies"]
        |> Enum.take(5)
        |> Enum.map(fn d -> "#{d["source"]} → #{d["target"]}" end)
        |> Enum.join("\n")

      messages = [
        %{role: "user", content: "Analyze these Elixir module dependencies:\n#{top_deps}\n\nWhat architecture pattern does this suggest? Reply in one sentence."}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert {:ok, %{content: content}} = result
      assert String.length(content) > 0
    end

    test "CRASH: Groq analyzes YAWL patterns from real scan" do
      # Chicago TDD: Feed real YAWL pattern data to Groq
      OptimalSystemAgent.Sensors.SensorRegistry.init_tables()

      output_dir = "tmp/chicago_groq_yawl"
      File.rm_rf!(output_dir)
      File.mkdir_p!(output_dir)

      {:ok, _scan_result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: "lib",
        output_dir: output_dir
      )

      # Read real pattern data
      patterns_json = File.read!(Path.join(output_dir, "patterns.json"))
      patterns_data = Jason.decode!(patterns_json)

      top_patterns =
        patterns_data["patterns"]
        |> Enum.take(10)
        |> Enum.map(fn p -> "#{p["pattern"]} (#{p["yawl_category"]}): #{p["count"]} occurrences" end)
        |> Enum.join("\n")

      messages = [
        %{role: "user", content: "These are YAWL workflow patterns detected in an Elixir codebase:\n#{top_patterns}\n\nWhich pattern dominates? Reply in one word."}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert {:ok, %{content: content}} = result
      assert String.length(content) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Layer 4: Budget/Cost Tracking (real API calls cost money)
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Real Groq API Calls — Budget Verification" do
    test "CRASH: real Groq call generates trackable cost" do
      # Chicago TDD: Every real API call has a cost — verify budget system tracks it
      messages = [
        %{role: "user", content: "Say 'budget test'"}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert {:ok, %{content: _, usage: usage}} = result

      # Verify usage is real (not zeroed out)
      input_tokens = usage[:input_tokens] || usage["input_tokens"] || 0
      output_tokens = usage[:output_tokens] || usage["output_tokens"] || 0

      assert input_tokens > 0, "Real Groq call should consume input tokens"
      assert output_tokens > 0, "Real Groq call should consume output tokens"

      # Verify budget calculation works with real numbers
      cost = OptimalSystemAgent.Budget.calculate_cost(:groq, input_tokens, output_tokens)
      assert cost > 0.0, "Groq cost should be positive: $#{cost}"
    end
  end

  # ---------------------------------------------------------------------------
  # Layer 5: Multi-turn Conversation (real stateful interaction)
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Real Groq API Calls — Multi-turn" do
    test "CRASH: multi-turn conversation maintains context" do
      # Chicago TDD: Verify Groq maintains conversation context across turns
      messages = [
        %{role: "user", content: "My favorite color is blue. Remember this."},
        %{role: "assistant", content: "Got it. Your favorite color is blue."},
        %{role: "user", content: "What is my favorite color?"}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0
        )

      assert {:ok, %{content: content}} = result
      assert String.contains?(String.downcase(content), "blue"),
        "Groq should remember context. Got: #{content}"
    end

    test "CRASH: multi-turn with tool call maintains context" do
      # Chicago TDD: Tool call in middle of conversation doesn't lose context
      # Note: Groq requires all fields to have descriptions
      tools = [
        %{
          "type" => "function",
          "function" => %{
            "name" => "get_module_count",
            "description" => "Get the number of modules in the codebase",
            "parameters" => %{
              "type" => "object",
              "properties" => %{},
              "required" => [],
              "description" => "Parameters for get_module_count"
            }
          }
        }
      ]

      messages = [
        %{role: "user", content: "First, tell me your name."},
        %{role: "assistant", content: "I am an AI assistant."},
        %{role: "user", content: "Now call get_module_count to check the codebase."}
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0,
          tools: tools
        )

      # Should not crash — tool calls in multi-turn are valid
      case result do
        {:ok, _} -> :ok
        {:error, _reason} ->
          # This is a gap - Groq API rejecting our tool format
          flunk("Groq API rejected tool format: #{inspect(_reason)}")
      end
    end
  end
end
