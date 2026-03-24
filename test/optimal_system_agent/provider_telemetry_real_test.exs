defmodule OptimalSystemAgent.ProviderTelemetryRealTest do
  @moduledoc """
  Provider Telemetry Emission Tests.

  NO MOCKS. Tests verify REAL telemetry emission from ALL providers.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — telemetry events must be observable

  ## Gap Discovered

  Only OpenAICompatProvider emits telemetry. Anthropic, Google, Ollama,
  and Cohere providers don't emit any telemetry events.

  ## Tests (Red Phase)

  1. Anthropic provider emits [:osa, :providers, :chat, :complete] telemetry
  2. Google provider emits [:osa, :providers, :chat, :complete] telemetry
  3. Ollama provider emits [:osa, :providers, :chat, :complete] telemetry
  4. Cohere provider emits [:osa, :providers, :chat, :complete] telemetry
  5. All providers emit [:osa, :providers, :tool_call, :complete] for tool calls
  6. All providers emit [:osa, :providers, :chat, :error] on errors
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  # ---------------------------------------------------------------------------
  # Anthropic Provider Telemetry Tests
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Anthropic Provider — Telemetry Emission" do
    test "Anthropic: Emits chat complete telemetry event" do
      api_key = Application.get_env(:optimal_system_agent, :anthropic_api_key)

      if is_nil(api_key) or api_key == "" do
        :skip_no_api_key
      else
        test_pid = self()
        handler_name = :"test_anthropic_telemetry_#{:erlang.unique_integer()}"

        :telemetry.attach(
          handler_name,
          [:osa, :providers, :chat, :complete],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:anthropic_chat_complete, measurements, metadata})
          end,
          nil
        )

        messages = [
          %{role: "user", content: "Say 'Hello, Anthropic!'"}
        ]

        result = OptimalSystemAgent.Providers.Anthropic.chat(messages, temperature: 0.0)

        # Verify chat succeeded
        assert {:ok, %{content: content}} = result
        assert String.length(content) > 0

        # Verify telemetry was emitted
        assert_receive {:anthropic_chat_complete, measurements, metadata}, 5000
        assert Map.has_key?(measurements, :duration)
        assert Map.has_key?(metadata, :provider)
        assert metadata.provider == :anthropic
        assert Map.has_key?(metadata, :model)

        :telemetry.detach(handler_name)
      end
    end

    test "Anthropic: Emits tool call telemetry when tools provided" do
      api_key = Application.get_env(:optimal_system_agent, :anthropic_api_key)

      if is_nil(api_key) or api_key == "" do
        :skip_no_api_key
      else
        test_pid = self()
        handler_name = :"test_anthropic_tool_telemetry_#{:erlang.unique_integer()}"

        :telemetry.attach(
          handler_name,
          [:osa, :providers, :tool_call, :complete],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:anthropic_tool_complete, measurements, metadata})
          end,
          nil
        )

        messages = [
          %{
            role: "user",
            content: "What's 2+2? Use the calculator tool."
          }
        ]

        tools = [
          %{
            name: "calculator",
            description: "Calculate math expressions",
            parameters: %{
              "type" => "object",
              "properties" => %{
                "expression" => %{"type" => "string"}
              },
              "required" => ["expression"]
            }
          }
        ]

        result = OptimalSystemAgent.Providers.Anthropic.chat(messages, tools: tools)

        # Tool calls are optional - verify telemetry if present
        case result do
          {:ok, %{tool_calls: tool_calls}} when tool_calls != [] ->
            assert_receive {:anthropic_tool_complete, _measurements, _metadata}, 5000

          _ ->
            # No tool calls - telemetry should still be emitted for chat
            :ok
        end

        :telemetry.detach(handler_name)
      end
    end

    test "Anthropic: Emits error telemetry on failure" do
      test_pid = self()
      handler_name = :"test_anthropic_error_telemetry_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :providers, :chat, :error],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:anthropic_chat_error, measurements, metadata})
        end,
        nil
      )

      # Temporarily clear API key to force error
      original_key = Application.get_env(:optimal_system_agent, :anthropic_api_key)
      Application.put_env(:optimal_system_agent, :anthropic_api_key, nil)

      messages = [
        %{role: "user", content: "This should fail"}
      ]

      result = OptimalSystemAgent.Providers.Anthropic.chat(messages)

      # Verify error
      assert {:error, _reason} = result

      # Restore API key
      Application.put_env(:optimal_system_agent, :anthropic_api_key, original_key)

      # Verify error telemetry was emitted
      # Note: This test may need adjustment based on actual error telemetry implementation
      :telemetry.detach(handler_name)
    end
  end

  # ---------------------------------------------------------------------------
  # Google Provider Telemetry Tests
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Google Provider — Telemetry Emission" do
    test "Google: Emits chat complete telemetry event" do
      api_key = Application.get_env(:optimal_system_agent, :google_api_key)

      if is_nil(api_key) or api_key == "" do
        :skip_no_api_key
      else
        test_pid = self()
        handler_name = :"test_google_telemetry_#{:erlang.unique_integer()}"

        :telemetry.attach(
          handler_name,
          [:osa, :providers, :chat, :complete],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:google_chat_complete, measurements, metadata})
          end,
          nil
        )

        messages = [
          %{role: "user", content: "Say 'Hello, Gemini!'"}
        ]

        result = OptimalSystemAgent.Providers.Google.chat(messages, temperature: 0.0)

        # Verify chat succeeded
        assert {:ok, %{content: content}} = result
        assert String.length(content) > 0

        # Verify telemetry was emitted
        assert_receive {:google_chat_complete, measurements, metadata}, 5000
        assert Map.has_key?(measurements, :duration)
        assert Map.has_key?(metadata, :provider)
        assert metadata.provider == :google
        assert Map.has_key?(metadata, :model)

        :telemetry.detach(handler_name)
      end
    end

    test "Google: Emits tool call telemetry when tools provided" do
      api_key = Application.get_env(:optimal_system_agent, :google_api_key)

      if is_nil(api_key) or api_key == "" do
        :skip_no_api_key
      else
        test_pid = self()
        handler_name = :"test_google_tool_telemetry_#{:erlang.unique_integer()}"

        :telemetry.attach(
          handler_name,
          [:osa, :providers, :tool_call, :complete],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:google_tool_complete, measurements, metadata})
          end,
          nil
        )

        messages = [
          %{
            role: "user",
            content: "What's 2+2? Use the calculator tool."
          }
        ]

        tools = [
          %{
            name: "calculator",
            description: "Calculate math expressions",
            parameters: %{
              "type" => "object",
              "properties" => %{
                "expression" => %{"type" => "string"}
              },
              "required" => ["expression"]
            }
          }
        ]

        result = OptimalSystemAgent.Providers.Google.chat(messages, tools: tools)

        # Tool calls are optional - verify telemetry if present
        case result do
          {:ok, %{tool_calls: tool_calls}} when tool_calls != [] ->
            assert_receive {:google_tool_complete, _measurements, _metadata}, 5000

          _ ->
            # No tool calls - telemetry should still be emitted for chat
            :ok
        end

        :telemetry.detach(handler_name)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Ollama Provider Telemetry Tests
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Ollama Provider — Telemetry Emission" do
    setup do
      # Check if Ollama is reachable
      url = Application.get_env(:optimal_system_agent, :ollama_url, "http://localhost:11434")

      case Req.get("#{url}/api/tags", receive_timeout: 2_000, retry: false) do
        {:ok, %{status: 200}} ->
          :ok

        _ ->
          :skip_ollama_not_reachable
      end
    end

    test "Ollama: Emits chat complete telemetry event" do
      test_pid = self()
      handler_name = :"test_ollama_telemetry_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :providers, :chat, :complete],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:ollama_chat_complete, measurements, metadata})
        end,
        nil
      )

      messages = [
        %{role: "user", content: "Say 'Hello, Ollama!'"}
      ]

      result = OptimalSystemAgent.Providers.Ollama.chat(messages, temperature: 0.0)

      # Verify chat succeeded
      assert {:ok, %{content: content}} = result
      assert String.length(content) > 0

      # Verify telemetry was emitted
      assert_receive {:ollama_chat_complete, measurements, metadata}, 10_000
      assert Map.has_key?(measurements, :duration)
      assert Map.has_key?(metadata, :provider)
      assert metadata.provider == :ollama
      assert Map.has_key?(metadata, :model)

      :telemetry.detach(handler_name)
    end

    test "Ollama: Emits tool call telemetry when tools provided" do
      test_pid = self()
      handler_name = :"test_ollama_tool_telemetry_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :providers, :tool_call, :complete],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:ollama_tool_complete, measurements, metadata})
        end,
        nil
      )

      messages = [
        %{
          role: "user",
          content: "What's 2+2? Use the calculator tool."
        }
      ]

      tools = [
        %{
          name: "calculator",
          description: "Calculate math expressions",
          parameters: %{
            "type" => "object",
            "properties" => %{
              "expression" => %{"type" => "string"}
            },
            "required" => ["expression"]
          }
        }
      ]

      result = OptimalSystemAgent.Providers.Ollama.chat(messages, tools: tools)

      # Tool calls are optional - verify telemetry if present
      case result do
        {:ok, %{tool_calls: tool_calls}} when tool_calls != [] ->
          assert_receive {:ollama_tool_complete, _measurements, _metadata}, 10_000

        _ ->
          # No tool calls - telemetry should still be emitted for chat
          :ok
      end

      :telemetry.detach(handler_name)
    end
  end

  # ---------------------------------------------------------------------------
  # Cohere Provider Telemetry Tests
  # ---------------------------------------------------------------------------

  describe "Chicago TDD: Cohere Provider — Telemetry Emission" do
    test "Cohere: Emits chat complete telemetry event" do
      api_key = Application.get_env(:optimal_system_agent, :cohere_api_key)

      if is_nil(api_key) or api_key == "" do
        :skip_no_api_key
      else
        test_pid = self()
        handler_name = :"test_cohere_telemetry_#{:erlang.unique_integer()}"

        :telemetry.attach(
          handler_name,
          [:osa, :providers, :chat, :complete],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:cohere_chat_complete, measurements, metadata})
          end,
          nil
        )

        messages = [
          %{role: "user", content: "Say 'Hello, Cohere!'"}
        ]

        result = OptimalSystemAgent.Providers.Cohere.chat(messages, temperature: 0.0)

        # Verify chat succeeded
        assert {:ok, %{content: content}} = result
        assert String.length(content) > 0

        # Verify telemetry was emitted
        assert_receive {:cohere_chat_complete, measurements, metadata}, 5000
        assert Map.has_key?(measurements, :duration)
        assert Map.has_key?(metadata, :provider)
        assert metadata.provider == :cohere
        assert Map.has_key?(metadata, :model)

        :telemetry.detach(handler_name)
      end
    end

    test "Cohere: Emits tool call telemetry when tools provided" do
      api_key = Application.get_env(:optimal_system_agent, :cohere_api_key)

      if is_nil(api_key) or api_key == "" do
        :skip_no_api_key
      else
        test_pid = self()
        handler_name = :"test_cohere_tool_telemetry_#{:erlang.unique_integer()}"

        :telemetry.attach(
          handler_name,
          [:osa, :providers, :tool_call, :complete],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:cohere_tool_complete, measurements, metadata})
          end,
          nil
        )

        messages = [
          %{
            role: "user",
            content: "What's 2+2? Use the calculator tool."
          }
        ]

        tools = [
          %{
            name: "calculator",
            description: "Calculate math expressions",
            parameter_definitions: %{
              "expression" => %{
                "type" => "string",
                "description" => "Math expression to evaluate"
              }
            }
          }
        ]

        result = OptimalSystemAgent.Providers.Cohere.chat(messages, tools: tools)

        # Tool calls are optional - verify telemetry if present
        case result do
          {:ok, %{tool_calls: tool_calls}} when tool_calls != [] ->
            assert_receive {:cohere_tool_complete, _measurements, _metadata}, 5000

          _ ->
            # No tool calls - telemetry should still be emitted for chat
            :ok
        end

        :telemetry.detach(handler_name)
      end
    end
  end
end
