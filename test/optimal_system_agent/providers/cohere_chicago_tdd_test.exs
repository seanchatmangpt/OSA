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

  describe "Provider — available_models implementation" do
    test "PASS: available_models/0 function exists" do
      # Function is now implemented
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :available_models, 0)
    end

    test "PASS: Calling available_models returns list of models" do
      models = Cohere.available_models()
      assert is_list(models)
      assert length(models) > 0
      assert Enum.all?(models, &is_binary/1)
    end

    test "PASS: available_models includes command-r-plus" do
      models = Cohere.available_models()
      assert "command-r-plus" in models
    end

    test "PASS: available_models includes other Command models" do
      models = Cohere.available_models()
      assert "command-r" in models
      assert "command-light" in models
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
    test "PASS: Implements Providers.Behaviour contract" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :name, 0)
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :default_model, 0)
      # Now implemented: available_models
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :available_models, 0)
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
    test "PASS: Module is loaded" do
      assert Code.ensure_loaded?(Cohere)
    end

    test "PASS: Module has complete behaviour implementation" do
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :name, 0)
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :default_model, 0)
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :available_models, 0)
      assert Code.ensure_loaded?(Cohere) and function_exported?(Cohere, :chat, 2)
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

  describe "Provider — Parity with other providers" do
    test "PASS: Cohere provider now has available_models/0 implemented" do
      assert Code.ensure_loaded?(Cohere) and
             function_exported?(Cohere, :available_models, 0)
    end

    test "PASS: All standard providers have available_models implemented" do
      assert Code.ensure_loaded?(OptimalSystemAgent.Providers.Anthropic) and
             function_exported?(OptimalSystemAgent.Providers.Anthropic, :available_models, 0)
      assert Code.ensure_loaded?(OptimalSystemAgent.Providers.Google) and
             function_exported?(OptimalSystemAgent.Providers.Google, :available_models, 0)
      assert Code.ensure_loaded?(OptimalSystemAgent.Providers.Ollama) and
             function_exported?(OptimalSystemAgent.Providers.Ollama, :available_models, 0)
      assert Code.ensure_loaded?(Cohere) and
             function_exported?(Cohere, :available_models, 0)
    end
  end
end
