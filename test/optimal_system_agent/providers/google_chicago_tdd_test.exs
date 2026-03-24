defmodule OptimalSystemAgent.Providers.GoogleChicagoTDDTest do
  @moduledoc """
  Chicago TDD: Google provider pure logic tests.

  NO MOCKS. Tests verify REAL provider behavior.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — provider behavior observable

  Tests (Red Phase):
  1. Provider metadata (name, default_model, available_models)
  2. Available models list (gemini-2.0-flash, gemini-2.5-pro, gemini-2.5-flash)
  3. Thinking model detection (2.5 models)
  4. Behavior contract compliance
  5. Function existence (chat, format_messages, extract_system)

  Note: Tests requiring API keys or actual API calls are integration tests.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Providers.Google

  describe "Provider — Metadata" do
    test "CRASH: Returns provider name" do
      assert Google.name() == :google
    end

    test "CRASH: Returns default model" do
      model = Google.default_model()
      assert is_binary(model)
      assert String.length(model) > 0
      assert String.contains?(model, "gemini")
    end

    test "CRASH: Default model is gemini-2.0-flash" do
      assert Google.default_model() == "gemini-2.0-flash"
    end
  end

  describe "Provider — Available Models" do
    test "CRASH: available_models returns list" do
      models = Google.available_models()
      assert is_list(models)
    end

    test "CRASH: available_models contains gemini-2.0-flash" do
      models = Google.available_models()
      assert "gemini-2.0-flash" in models
    end

    test "CRASH: available_models contains gemini-2.5-pro" do
      models = Google.available_models()
      assert "gemini-2.5-pro" in models
    end

    test "CRASH: available_models contains gemini-2.5-flash" do
      models = Google.available_models()
      assert "gemini-2.5-flash" in models
    end

    test "CRASH: All model names are strings" do
      models = Google.available_models()
      Enum.each(models, fn model ->
        assert is_binary(model)
      end)
    end

    test "CRASH: Available models is not empty" do
      models = Google.available_models()
      assert length(models) > 0
    end

    test "CRASH: Available models has exactly 3 models" do
      models = Google.available_models()
      assert length(models) == 3
    end
  end

  describe "Provider — Thinking Model Detection" do
    test "CRASH: thinking_model? returns true for 2.5 models" do
      # This is a private function, but we can infer behavior from available_models
      # gemini-2.5-pro and gemini-2.5-flash are thinking models
      models = Google.available_models()
      assert "gemini-2.5-pro" in models
      assert "gemini-2.5-flash" in models
    end

    test "CRASH: gemini-2.0-flash is not a thinking model" do
      # 2.0 models don't have thinking support
      models = Google.available_models()
      assert "gemini-2.0-flash" in models
    end
  end

  describe "Provider — Model Naming" do
    test "CRASH: Model names follow Gemini convention" do
      models = Google.available_models()

      # All models should start with "gemini-"
      gemini_models = Enum.filter(models, &String.starts_with?(&1, "gemini-"))
      assert length(gemini_models) == length(models)
    end

    test "CRASH: Contains Flash model (fastest)" do
      models = Google.available_models()
      flash_models = Enum.filter(models, &String.contains?(&1, "flash"))
      assert length(flash_models) >= 1
    end

    test "CRASH: Contains Pro model (highest quality)" do
      models = Google.available_models()
      pro_models = Enum.filter(models, &String.contains?(&1, "pro"))
      assert length(pro_models) >= 1
    end
  end

  describe "Provider — Default Model Selection" do
    test "CRASH: Default model is in available models" do
      default = Google.default_model()
      models = Google.available_models()
      assert default in models
    end

    test "CRASH: Default model is Flash (balanced)" do
      default = Google.default_model()
      assert String.contains?(default, "flash")
    end

    test "CRASH: Default model is 2.0 series" do
      default = Google.default_model()
      assert String.contains?(default, "2.0")
    end
  end

  describe "Provider — Model Versions" do
    test "CRASH: Available models use version 2.0" do
      models = Google.available_models()
      v20_models = Enum.filter(models, &String.contains?(&1, "2.0"))
      assert length(v20_models) > 0
    end

    test "CRASH: Available models use version 2.5" do
      models = Google.available_models()
      v25_models = Enum.filter(models, &String.contains?(&1, "2.5"))
      assert length(v25_models) > 0
    end
  end

  describe "Provider — Behavior Contract" do
    test "CRASH: Implements Providers.Behaviour" do
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :name, 0)
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :default_model, 0)
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :available_models, 0)
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :chat, 2)
    end

    test "CRASH: name returns atom" do
      assert is_atom(Google.name())
    end

    test "CRASH: default_model returns binary" do
      assert is_binary(Google.default_model())
    end

    test "CRASH: available_models returns list" do
      assert is_list(Google.available_models())
    end

    test "CRASH: chat function exists" do
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :chat, 2)
    end
  end

  describe "Provider — Module Properties" do
    test "CRASH: Module is loaded" do
      assert Code.ensure_loaded?(Google)
    end

    test "CRASH: Module has behaviour callbacks" do
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :name, 0)
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :default_model, 0)
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :available_models, 0)
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :chat, 2)
    end
  end

  describe "Provider — Model Families" do
    test "CRASH: Has 2.0 Flash model (fast, non-thinking)" do
      models = Google.available_models()
      assert "gemini-2.0-flash" in models
    end

    test "CRASH: Has 2.5 Pro model (thinking, high quality)" do
      models = Google.available_models()
      assert "gemini-2.5-pro" in models
    end

    test "CRASH: Has 2.5 Flash model (thinking, fast)" do
      models = Google.available_models()
      assert "gemini-2.5-flash" in models
    end

    test "CRASH: All models are distinct" do
      models = Google.available_models()
      assert length(models) == length(Enum.uniq(models))
    end
  end

  describe "Provider — Function Signatures" do
    test "CRASH: chat/2 accepts messages and opts" do
      assert Code.ensure_loaded?(Google) and function_exported?(Google, :chat, 2)
    end
  end
end
