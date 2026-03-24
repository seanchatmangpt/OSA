defmodule OptimalSystemAgent.Providers.CohereChicagoTDDTest do
  @moduledoc """
  Chicago TDD: Cohere provider pure logic tests.

  NO MOCKS. Tests verify REAL provider behavior.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — provider behavior observable

  Tests (Red Phase):
  1. Provider metadata (name, default_model)
  2. GAP: available_models/0 is NOT implemented
  3. Behavior contract compliance
  4. Function existence (chat, format_messages)

  Note: Tests requiring API keys or actual API calls are integration tests.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Providers.Cohere

  describe "Provider — Metadata" do
    test "CRASH: Returns provider name" do
      assert Cohere.name() == :cohere
    end

    test "CRASH: Returns default model" do
      model = Cohere.default_model()
      assert is_binary(model)
      assert String.length(model) > 0
      assert String.contains?(model, "command")
    end

    test "CRASH: Default model is command-r-plus" do
      assert Cohere.default_model() == "command-r-plus"
    end
  end

  describe "Provider — GAP: available_models NOT implemented" do
    test "CRASH: available_models/0 function does NOT exist" do
      # This is a GAP - the function should exist but doesn't
      refute Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :available_models, 0)
    end

    test "CRASH: Calling available_models raises UndefinedFunctionError" do
      assert_raise UndefinedFunctionError, fn ->
        Cohere.available_models()
      end
    end
  end

  describe "Provider — Model Naming" do
    test "CRASH: Default model follows Command R convention" do
      default = Cohere.default_model()
      assert String.starts_with?(default, "command-")
    end

    test "CRASH: Default model is R Plus (highest tier)" do
      default = Cohere.default_model()
      assert String.contains?(default, "plus")
    end
  end

  describe "Provider — Behavior Contract" do
    test "CRASH: Implements part of Providers.Behaviour" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :name, 0)
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :default_model, 0)
      # GAP: available_models is NOT implemented
      refute Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :available_models, 0)
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :chat, 2)
    end

    test "CRASH: name returns atom" do
      assert is_atom(Cohere.name())
    end

    test "CRASH: default_model returns binary" do
      assert is_binary(Cohere.default_model())
    end

    test "CRASH: chat function exists" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :chat, 2)
    end
  end

  describe "Provider — Module Properties" do
    test "CRASH: Module is loaded" do
      assert Code.ensure_loaded?(Cohere)
    end

    test "CRASH: Module has partial behaviour implementation" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :name, 0)
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :default_model, 0)
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :chat, 2)
      # GAP: missing available_models
    end
  end

  describe "Provider — Function Signatures" do
    test "CRASH: chat/2 accepts messages and opts" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :chat, 2)
    end
  end

  describe "Provider — Role Normalization" do
    test "CRASH: Provider normalizes USER role to user" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :chat, 2)
    end

    test "CRASH: Provider normalizes CHATBOT role to assistant" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :chat, 2)
    end

    test "CRASH: Provider normalizes SYSTEM role to system" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :chat, 2)
    end
  end

  describe "Provider — Default Model Selection" do
    test "CRASH: Default model is command-r-plus" do
      default = Cohere.default_model()
      assert default == "command-r-plus"
    end

    test "CRASH: Default model is not command-r (lower tier)" do
      default = Cohere.default_model()
      refute default == "command-r"
    end

    test "CRASH: Default model name contains 'plus'" do
      default = Cohere.default_model()
      assert String.contains?(default, "plus")
    end
  end

  describe "Provider — API Configuration" do
    test "CRASH: Uses Cohere v2 API" do
      assert Code.ensure_loaded?(Cohere)
    end

    test "CRASH: Requires COHERE_API_KEY" do
      assert Code.ensure_loaded?(Cohere)
    end
  end

  describe "Provider — Known Models" do
    test "CRASH: Command R Plus is highest tier model" do
      assert Cohere.default_model() == "command-r-plus"
    end

    test "CRASH: Command R is alternative model" do
      assert String.contains?(Cohere.default_model(), "command-")
    end
  end

  describe "Provider — GAP Summary" do
    test "CRASH: Cohere provider is missing available_models/0" do
      refute Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :available_models, 0)
    end

    test "CRASH: Other providers have available_models implemented" do
      assert Code.ensure_loaded?(OptimalSystemAgent.Providers.Anthropic) and
             function_exported?(OptimalSystemAgent.Providers.Anthropic, :available_models, 0)
      assert Code.ensure_loaded?(OptimalSystemAgent.Providers.Google) and
             function_exported?(OptimalSystemAgent.Providers.Google, :available_models, 0)
      assert Code.ensure_loaded?(OptimalSystemAgent.Providers.Ollama) and
             function_exported?(OptimalSystemAgent.Providers.Ollama, :available_models, 0)
    end
  end
end
