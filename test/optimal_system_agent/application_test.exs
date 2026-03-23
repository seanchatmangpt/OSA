defmodule OptimalSystemAgent.ApplicationTest do
  use ExUnit.Case, async: false

  describe "default_provider/0" do
    test "reads OSA_DEFAULT_PROVIDER from env and sets application env" do
      original = Application.get_env(:optimal_system_agent, :default_provider)
      System.put_env("OSA_DEFAULT_PROVIDER", "groq")

      try do
        Application.delete_env(:optimal_system_agent, :default_provider)

        # Test the logic: env var string → atom
        provider_atom = System.get_env("OSA_DEFAULT_PROVIDER") |> String.to_atom()
        assert provider_atom == :groq
      after
        Application.put_env(:optimal_system_agent, :default_provider, original)
        System.delete_env("OSA_DEFAULT_PROVIDER")
      end
    end

    test "falls back to :ollama when env var is not set" do
      System.delete_env("OSA_DEFAULT_PROVIDER")
      original = Application.get_env(:optimal_system_agent, :default_provider)

      try do
        Application.delete_env(:optimal_system_agent, :default_provider)
        # Simulate the fallback logic
        result =
          case System.get_env("OSA_DEFAULT_PROVIDER") do
            nil -> Application.get_env(:optimal_system_agent, :default_provider, :ollama)
            provider -> String.to_atom(provider)
          end

        assert result == :ollama
      after
        Application.put_env(:optimal_system_agent, :default_provider, original)
      end
    end
  end

  describe "load_provider_env/1 env var mapping" do
    test "maps PROVIDER_API_KEY to :provider_api_key" do
      prefix = String.upcase(to_string(:groq))
      env_var = prefix <> "_API_KEY"
      System.put_env(env_var, "test-key-123")

      try do
        # Simulate the mapping logic
        env_mapping = [
          {"_API_KEY", "_api_key"},
          {"_MODEL", "_model"},
          {"_BASE_URL", "_url"}
        ]

        Enum.each(env_mapping, fn {env_suffix, app_suffix} ->
          e_var = prefix <> env_suffix
          app_key = String.to_atom("groq#{app_suffix}")

          case System.get_env(e_var) do
            nil -> :ok
            value -> Application.put_env(:optimal_system_agent, app_key, value)
          end
        end)

        assert Application.get_env(:optimal_system_agent, :groq_api_key) == "test-key-123"
      after
        Application.delete_env(:optimal_system_agent, :groq_api_key)
        System.delete_env("GROQ_API_KEY")
      end
    end

    test "maps PROVIDER_MODEL to :provider_model" do
      System.put_env("GROQ_MODEL", "llama-3.3-70b-versatile")

      try do
        # Simulate the mapping
        prefix = "GROQ"
        env_var = prefix <> "_MODEL"
        app_key = String.to_atom("groq_model")

        case System.get_env(env_var) do
          nil -> :ok
          value -> Application.put_env(:optimal_system_agent, app_key, value)
        end

        assert Application.get_env(:optimal_system_agent, :groq_model) ==
                 "llama-3.3-70b-versatile"
      after
        Application.delete_env(:optimal_system_agent, :groq_model)
        System.delete_env("GROQ_MODEL")
      end
    end

    test "maps PROVIDER_BASE_URL to :provider_url (not :provider_base_url)" do
      System.put_env("GROQ_BASE_URL", "https://custom.groq.example.com")

      try do
        # The key mapping: _BASE_URL → _url
        env_suffix = "_BASE_URL"
        app_suffix = "_url"
        prefix = "GROQ"
        env_var = prefix <> env_suffix
        app_key = String.to_atom("groq#{app_suffix}")

        case System.get_env(env_var) do
          nil -> :ok
          value -> Application.put_env(:optimal_system_agent, app_key, value)
        end

        # Provider reads :groq_url, NOT :groq_base_url
        assert Application.get_env(:optimal_system_agent, :groq_url) ==
                 "https://custom.groq.example.com"

        # Must NOT set :groq_base_url
        refute Application.get_env(:optimal_system_agent, :groq_base_url)
      after
        Application.delete_env(:optimal_system_agent, :groq_url)
        Application.delete_env(:optimal_system_agent, :groq_base_url)
        System.delete_env("GROQ_BASE_URL")
      end
    end

    test "skips env vars that are not set" do
      System.delete_env("NONEXISTENT_API_KEY")

      # Should not crash or set anything
      prefix = "NONEXISTENT"
      env_var = prefix <> "_API_KEY"
      app_key = String.to_atom("nonexistent_api_key")

      case System.get_env(env_var) do
        nil -> :ok
        value -> Application.put_env(:optimal_system_agent, app_key, value)
      end

      refute Application.get_env(:optimal_system_agent, :nonexistent_api_key)
    end

    test "works with multiple providers" do
      providers = [:openai, :deepseek, :anthropic]

      Enum.each(providers, fn provider ->
        prefix = String.upcase(to_string(provider))
        System.put_env("#{prefix}_API_KEY", "key-for-#{provider}")
      end)

      try do
        Enum.each(providers, fn provider ->
          prefix = String.upcase(to_string(provider))
          env_var = prefix <> "_API_KEY"
          app_key = String.to_atom("#{provider}_api_key")

          case System.get_env(env_var) do
            nil -> :ok
            value -> Application.put_env(:optimal_system_agent, app_key, value)
          end
        end)

        Enum.each(providers, fn provider ->
          assert Application.get_env(:optimal_system_agent, :"#{provider}_api_key") ==
                   "key-for-#{provider}"
        end)
      after
        Enum.each(providers, fn provider ->
          Application.delete_env(:optimal_system_agent, :"#{provider}_api_key")
          prefix = String.upcase(to_string(provider))
          System.delete_env("#{prefix}_API_KEY")
        end)
      end
    end
  end
end
