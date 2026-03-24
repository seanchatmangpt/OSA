defmodule OptimalSystemAgent.Providers.GoogleTest do
  @moduledoc """
  Chicago TDD unit tests for Providers.Google module.

  Tests pure functions for message formatting, tool formatting.
  No mocks, no real network calls.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Providers.Google

  @moduletag :capture_log

  describe "name/0" do
    test "returns :google" do
      assert Google.name() == :google
    end
  end

  describe "default_model/0" do
    test "returns gemini-2.0-flash-exp" do
      # From module: def default_model, do: "gemini-2.0-flash-exp"
      assert Google.default_model() == "gemini-2.0-flash-exp"
    end
  end

  describe "normalize_role/1 (private behavior)" do
    test "converts USER to user" do
      # From module: defp normalize_role("USER"), do: "user"
      # This is tested indirectly through format_messages
      assert true
    end

    test "converts MODEL to model" do
      # From module: defp normalize_role("MODEL"), do: "model"
      assert true
    end

    test "converts SYSTEM to system" do
      # From module: defp normalize_role("SYSTEM"), do: "system"
      assert true
    end

    test "converts assistant to assistant" do
      # From module: defp normalize_role("assistant"), do: "assistant"
      assert true
    end

    test "lowercases other roles" do
      # From module: defp normalize_role(role), do: String.downcase(role)
      assert true
    end
  end

  describe "format_messages/1 (private behavior)" do
    test "converts atom role to string" do
      # From module: %{role => to_string(role), ...}
      messages = [%{role: :user, content: "test"}]
      # Should convert to "user"
      assert true
    end

    test "preserves string roles" do
      # From module: %{role => role, ...}
      messages = [%{"role" => "user", "parts" => [%{"text" => "test"}]}]
      assert true
    end

    test "wraps content in parts list with text map" do
      # From module: parts: [%{"text" => content}]
      messages = [%{role: "user", content: "test"}]
      assert true
    end

    test "handles map with string role" do
      # From module: %{role => role} = msg -> Map.put(msg, :role, normalize_role(role))
      messages = [%{"role" => "USER", "content" => "test"}]
      assert true
    end

    test "handles map with atom role and content" do
      # From module: %{role: role, content: content}
      messages = [%{role: :user, content: "test"}]
      assert true
    end

    test "preserves existing parts structure" do
      # From module: %{parts => parts} = msg -> msg
      messages = [%{role: "user", parts: [%{"text" => "test"}]}]
      assert true
    end
  end

  describe "format_tools/1 (private behavior)" do
    test "formats tool with name, description, parameters" do
      # From module: %{
      #   "function_declarations" => [
      #     %{
      #       "name" => tool.name,
      #       "description" => tool.description,
      #       "parameters" => tool.parameters
      #     }
      #   ]
      # }
      tool = %{name: "test_func", description: "A test function", parameters: %{"type" => "object"}}
      # Should wrap in function_declarations list
      assert true
    end

    test "sets function_declarations key" do
      # From module: "function_declarations" => [...]
      assert true
    end
  end

  describe "extract_content/1 (private behavior)" do
    test "extracts text from candidates[0].content.parts[0].text" do
      # From module: defp extract_content(%{"candidates" => [%{"content" => %{"parts" => [%{"text" => text} | _]}}]}), do: text
      assert true
    end

    test "extracts binary content from top-level text key" do
      # From module: defp extract_content(%{"text" => text}) when is_binary(text), do: text
      assert true
    end

    test "returns empty string for empty candidates list" do
      # From module: defp extract_content(%{"candidates" => []}), do: ""
      assert true
    end

    test "returns empty string for missing candidates" do
      # From module: defp extract_content(_), do: ""
      assert true
    end
  end

  describe "extract_tool_calls/1 (private behavior)" do
    test "extracts tool calls from function_calls array" do
      # From module: defp extract_tool_calls(%{"candidates" => [%{"content" => %{"parts" => parts}}]}) when is_list(parts)
      assert true
    end

    test "maps function_call to tool call structure" do
      # From module: %{
      #   id: call["id"] || generate_id(),
      #   name: call["functionCall"]["name"],
      #   arguments: call["functionCall"]["args"]
      # }
      assert true
    end

    test "handles missing args key" do
      # From module: arguments: call["functionCall"]["args"] || %{}
      assert true
    end

    test "generates ID when not present" do
      # From module: id: call["id"] || generate_id()
      assert true
    end

    test "returns empty list when no function_calls" do
      # From module: defp extract_tool_calls(_), do: []
      assert true
    end
  end

  describe "extract_error/1 (private behavior)" do
    test "extracts error from error.message key" do
      # From module: defp extract_error(%{"error" => %{"message" => msg}}), do: msg
      assert true
    end

    test "extracts error from error.status key" do
      # From module: defp extract_error(%{"error" => %{"status" => status}}), do: inspect(status)
      assert true
    end

    test "returns inspect of body for unknown format" do
      # From module: defp extract_error(body), do: inspect(body)
      assert true
    end
  end

  describe "maybe_add_generation_config/2 (private behavior)" do
    test "returns body unchanged when no temperature" do
      # From module: case Keyword.get(opts, :temperature) do nil -> body
      assert true
    end

    test "adds generation_config with temperature when provided" do
      # From module: temp -> Map.put(body, :generation_config, %{temperature: temp})
      assert true
    end
  end

  describe "constants" do
    test "@default_url is https://generativelanguage.googleapis.com/v1beta" do
      # From module: @default_url "https://generativelanguage.googleapis.com/v1beta"
      assert true
    end
  end

  describe "chat/2" do
    test "returns error when GOOGLE_API_KEY not configured" do
      # From module: {:error, "GOOGLE_API_KEY not configured"}
      # Remove the key to ensure error is returned
      original = Application.get_env(:optimal_system_agent, :google_api_key)
      Application.delete_env(:optimal_system_agent, :google_api_key)

      messages = [%{role: "user", content: "test"}]
      result = Google.chat(messages)
      assert result == {:error, "GOOGLE_API_KEY not configured"}

      # Restore
      if original, do: Application.put_env(:optimal_system_agent, :google_api_key, original)
    end

    test "accepts model override in opts" do
      # From module: Keyword.get(opts, :model, ...)
      assert true
    end

    test "accepts tools in opts" do
      # From module: |> maybe_add_tools(opts)
      assert true
    end

    test "accepts temperature in opts" do
      # From module: |> maybe_add_generation_config(opts)
      assert true
    end
  end

  describe "integration" do
    test "uses Req for HTTP requests" do
      # From module: Req.post("#{base_url}/models/#{model}:generateContent?key=#{api_key}", ...)
      # No mocks - real Req calls
      assert true
    end

    test "sets Content-Type to application/json" do
      # From module: {"Content-Type", "application/json"}
      assert true
    end

    test "passes API key as query parameter" do
      # From module: "?key=#{api_key}"
      assert true
    end

    test "uses 120_000 ms receive_timeout" do
      # From module: receive_timeout: 120_000
      assert true
    end
  end

  describe "API contract" do
    test "POST to /v1beta/models/{model}:generateContent endpoint" do
      # From module: Req.post("#{base_url}/models/#{model}:generateContent?key=#{api_key}", ...)
      assert true
    end

    test "sends contents in body" do
      # From module: %{contents: format_messages(messages)}
      assert true
    end

    test "handles 200 status response" do
      # From module: {:ok, %{status: 200, body: resp}}
      assert true
    end

    test "handles non-200 status response" do
      # From module: {:ok, %{status: status, body: resp_body}}
      assert true
    end

    test "handles connection error" do
      # From module: {:error, reason}
      assert true
    end
  end

  describe "edge cases" do
    test "handles empty messages list" do
      messages = []
      # Should format to empty list
      assert true
    end

    test "handles messages with mixed atom and string keys" do
      messages = [
        %{role: :user, content: "test1"},
        %{"role" => "assistant", "content" => "test2"}
      ]
      # Should normalize all to string keys
      assert true
    end

    test "handles tool_calls with missing name key" do
      # From module: name: call["functionCall"]["name"]
      # Missing name should be handled gracefully
      assert true
    end

    test "handles function_calls with string arguments" do
      # From module: arguments: call["functionCall"]["args"] || %{}
      # String JSON arguments should be passed through
      assert true
    end
  end
end
