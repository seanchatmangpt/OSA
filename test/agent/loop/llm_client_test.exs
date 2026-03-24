defmodule OptimalSystemAgent.Agent.Loop.LLMClientTest do
  @moduledoc """
  Unit tests for LLMClient module.

  Tests LLM provider interaction, response parsing, and error handling.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Loop.LLMClient

  describe "llm_chat/3" do
    test "returns ok tuple with content on successful call" do
      state = %{
        session_id: "test-123",
        provider: :mock,
        model: "test-model",
        messages: [%{role: "user", content: "hello"}]
      }

      assert {:ok, response} = LLMClient.llm_chat(state, state.messages, [])
      assert Map.has_key?(response, :content)
    end
  end
end
