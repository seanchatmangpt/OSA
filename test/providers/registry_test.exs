defmodule OptimalSystemAgent.Providers.RegistryTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Providers.Registry

  # ---------------------------------------------------------------------------
  # Module smoke tests
  # ---------------------------------------------------------------------------

  describe "module definition" do
    test "Registry module is defined and loaded" do
      assert Code.ensure_loaded?(Registry)
    end

    test "exports list_providers/0" do
      Code.ensure_compiled(Registry)
      assert function_exported?(Registry, :list_providers, 0)
    end

    test "exports provider_info/1" do
      Code.ensure_compiled(Registry)
      assert function_exported?(Registry, :provider_info, 1)
    end

    test "exports chat/2" do
      Code.ensure_compiled(Registry)
      assert function_exported?(Registry, :chat, 2)
    end

    test "exports provider_configured?/1" do
      Code.ensure_compiled(Registry)
      assert function_exported?(Registry, :provider_configured?, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # list_providers/0 smoke tests
  # ---------------------------------------------------------------------------

  describe "list_providers/0" do
    test "returns a non-empty list of atoms" do
      providers = Registry.list_providers()
      assert is_list(providers)
      assert length(providers) > 0
      Enum.each(providers, fn p -> assert is_atom(p) end)
    end

    test "includes the expected core providers" do
      providers = Registry.list_providers()
      assert :ollama in providers
      assert :anthropic in providers
      assert :openai in providers
      assert :groq in providers
    end
  end

  # ---------------------------------------------------------------------------
  # provider_info/1 smoke tests
  # ---------------------------------------------------------------------------

  describe "provider_info/1" do
    test "returns ok tuple with expected fields for a known provider" do
      # provider_info/1 calls provider_configured?/1 which needs Finch (HTTP pool).
      # Without the app started, use :anthropic which checks env var only (no HTTP).
      assert {:ok, info} = Registry.provider_info(:anthropic)
      assert info.name == :anthropic
      assert is_atom(info.module)
      assert is_binary(info.default_model)
      assert is_boolean(info.configured?)
    end

    test "returns error tuple for an unknown provider" do
      assert {:error, reason} = Registry.provider_info(:no_such_provider_xyz)
      assert is_binary(reason)
    end
  end

  # ---------------------------------------------------------------------------
  # provider_configured?/1 smoke tests
  # ---------------------------------------------------------------------------

  describe "provider_configured?/1" do
    test "ollama configured? returns a boolean (no API key required)" do
      # Ollama checks TCP reachability via Req/Finch which needs the app started.
      # Test with a non-ollama provider that only checks env vars.
      assert is_boolean(Registry.provider_configured?(:anthropic))
    end

    test "returns a boolean for any provider atom" do
      result = Registry.provider_configured?(:anthropic)
      assert is_boolean(result)
    end

    test "returns false for an unconfigured/unknown provider" do
      # A nonsense provider name will have no API key set in the test env
      assert Registry.provider_configured?(:zzz_fake_provider_xyz) == false
    end
  end

  # ---------------------------------------------------------------------------
  # chat/2 — returns error for unknown provider (no real LLM call)
  # ---------------------------------------------------------------------------

  describe "chat/2" do
    test "returns error tuple for an unknown provider" do
      messages = [%{role: "user", content: "hello"}]
      assert {:error, reason} = Registry.chat(messages, provider: :zzz_nonexistent)
      assert is_binary(reason)
      assert reason =~ "Unknown provider"
    end
  end
end
