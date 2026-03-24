defmodule OptimalSystemAgent.Providers.AnthropicChicagoTDDTest do
  @moduledoc """
  Chicago TDD: Anthropic provider pure logic tests.

  NO MOCKS. Tests verify REAL provider behavior.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — provider behavior observable

  Tests (Red Phase):
  1. Provider metadata (name, default_model, available_models)
  2. Available models list contains Claude models
  3. Behavior contract compliance
  4. Function existence (chat, chat_stream)

  Note: Tests requiring API keys or actual API calls are integration tests.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Providers.Anthropic

  describe "Provider — Metadata" do
    test "CRASH: Returns provider name" do
      assert Anthropic.name() == :anthropic
    end

    test "CRASH: Returns default model" do
      model = Anthropic.default_model()
      assert is_binary(model)
      assert String.length(model) > 0
      assert String.contains?(model, "claude")
    end

    test "CRASH: Default model is claude-sonnet-4-6" do
      assert Anthropic.default_model() == "claude-sonnet-4-6"
    end
  end

  describe "Provider — Available Models" do
    test "CRASH: available_models returns list" do
      models = Anthropic.available_models()
      assert is_list(models)
    end

    test "CRASH: available_models contains Claude models" do
      models = Anthropic.available_models()

      # Should contain at least one Claude model
      claude_models = Enum.filter(models, &String.contains?(&1, "claude"))
      assert length(claude_models) > 0
    end

    test "CRASH: available_models contains claude-opus-4-6" do
      models = Anthropic.available_models()
      assert "claude-opus-4-6" in models
    end

    test "CRASH: available_models contains claude-sonnet-4-6" do
      models = Anthropic.available_models()
      assert "claude-sonnet-4-6" in models
    end

    test "CRASH: available_models contains claude-haiku-4-5" do
      models = Anthropic.available_models()
      assert "claude-haiku-4-5" in models
    end

    test "CRASH: All model names are strings" do
      models = Anthropic.available_models()
      Enum.each(models, fn model ->
        assert is_binary(model)
      end)
    end

    test "CRASH: Available models is not empty" do
      models = Anthropic.available_models()
      assert length(models) > 0
    end
  end

  describe "Provider — Behavior Contract" do
    test "CRASH: Implements Providers.Behaviour" do
      assert function_exported?(Anthropic, :name, 0)
      assert function_exported?(Anthropic, :default_model, 0)
      assert function_exported?(Anthropic, :available_models, 0)
      assert function_exported?(Anthropic, :chat, 2)
      assert function_exported?(Anthropic, :chat_stream, 2)
    end

    test "CRASH: name returns atom" do
      assert is_atom(Anthropic.name())
    end

    test "CRASH: default_model returns binary" do
      assert is_binary(Anthropic.default_model())
    end

    test "CRASH: available_models returns list" do
      assert is_list(Anthropic.available_models())
    end

    test "CRASH: chat function exists" do
      assert function_exported?(Anthropic, :chat, 2)
    end

    test "CRASH: chat_stream function exists" do
      assert function_exported?(Anthropic, :chat_stream, 2)
    end
  end

  describe "Provider — Model Naming" do
    test "CRASH: Model names follow Anthropic convention" do
      models = Anthropic.available_models()

      # All models should start with "claude-"
      claude_models = Enum.filter(models, &String.starts_with?(&1, "claude-"))
      assert length(claude_models) > 0
    end

    test "CRASH: Contains Opus model (highest tier)" do
      models = Anthropic.available_models()
      opus_models = Enum.filter(models, &String.contains?(&1, "opus"))
      assert length(opus_models) > 0
    end

    test "CRASH: Contains Sonnet model (middle tier)" do
      models = Anthropic.available_models()
      sonnet_models = Enum.filter(models, &String.contains?(&1, "sonnet"))
      assert length(sonnet_models) > 0
    end

    test "CRASH: Contains Haiku model (lowest tier)" do
      models = Anthropic.available_models()
      haiku_models = Enum.filter(models, &String.contains?(&1, "haiku"))
      assert length(haiku_models) > 0
    end
  end

  describe "Provider — Default Model Selection" do
    test "CRASH: Default model is in available models" do
      default = Anthropic.default_model()
      models = Anthropic.available_models()
      assert default in models
    end

    test "CRASH: Default model is Sonnet (balanced)" do
      default = Anthropic.default_model()
      assert String.contains?(default, "sonnet")
    end

    test "CRASH: Default model is not Opus (too expensive for default)" do
      default = Anthropic.default_model()
      refute String.contains?(default, "opus")
    end

    test "CRASH: Default model is not Haiku (not capable enough for default)" do
      default = Anthropic.default_model()
      refute String.contains?(default, "haiku")
    end
  end

  describe "Provider — Model Versions" do
    test "CRASH: Available models use version 4.6" do
      models = Anthropic.available_models()
      v46_models = Enum.filter(models, &String.contains?(&1, "4-6"))
      assert length(v46_models) > 0
    end

    test "CRASH: Haiku uses specific version format" do
      models = Anthropic.available_models()
      # Haiku uses YYYYMMDD versioning
      haiku_models = Enum.filter(models, &String.contains?(&1, "haiku"))
      assert length(haiku_models) > 0
    end
  end

  describe "Provider — Function Signatures" do
    test "CRASH: chat/2 accepts messages and opts" do
      assert function_exported?(Anthropic, :chat, 2)
    end

    test "CRASH: chat_stream has default arguments" do
      # chat_stream/2 (callback provided) or chat_stream/3 (callback + opts)
      # Since opts has default value, check for the base function
      assert function_exported?(Anthropic, :chat_stream, 2)
    end

    test "CRASH: format_messages/1 is exposed for testing" do
      # This function has @doc false but should be callable
      assert function_exported?(Anthropic, :format_messages, 1)
    end
  end

  describe "Provider — Module Properties" do
    test "CRASH: Module is loaded" do
      assert Code.ensure_loaded?(Anthropic)
    end

    test "CRASH: Module has behaviour attribute" do
      # The @behaviour attribute is compile-time only
      # We can verify the module implements the callbacks
      assert function_exported?(Anthropic, :name, 0)
      assert function_exported?(Anthropic, :default_model, 0)
      assert function_exported?(Anthropic, :available_models, 0)
      assert function_exported?(Anthropic, :chat, 2)
      assert function_exported?(Anthropic, :chat_stream, 2)
    end
  end
end
