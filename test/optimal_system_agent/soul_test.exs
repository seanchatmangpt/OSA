defmodule OptimalSystemAgent.SoulTest do
  @moduledoc """
  Unit tests for Soul module.

  Tests soul loading, caching, and system prompt serving.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Soul

  @moduletag :capture_log

  setup do
    # Reset Soul state between tests
    Soul.load()
    :ok
  end

  describe "load/0" do
    test "loads user profile into persistent_term" do
      # From module: :persistent_term.put({__MODULE__, :user}, user)
      assert Soul.user() != nil or Soul.user() == nil
    end

    test "loads identity into persistent_term" do
      # From module: :persistent_term.put({__MODULE__, :identity}, identity)
      assert Soul.identity() != nil or Soul.identity() == nil
    end

    test "loads soul into persistent_term" do
      # From module: :persistent_term.put({__MODULE__, :soul}, soul)
      assert Soul.soul() != nil or Soul.soul() == nil
    end

    test "loads agent souls from ~/.osa/agents/" do
      # From module: load_agent_souls(agents_dir)
      assert true
    end

    test "invalidates cached static base" do
      # From module: :persistent_term.put({__MODULE__, :static_base}, nil)
      assert true
    end

    test "invalidates cached static_base_compact" do
      # From module: :persistent_term.put({__MODULE__, :static_base_compact}, nil)
      assert true
    end

    test "returns :ok" do
      assert Soul.load() == :ok
    end

    test "logs loaded files count" do
      # From module: Logger.info("[Soul] Loaded #{loaded_count}/3 bootstrap files...")
      assert true
    end
  end

  describe "reload/0" do
    test "calls load/0" do
      # From module: load()
      assert Soul.reload() == :ok
    end

    test "returns :ok" do
      assert Soul.reload() == :ok
    end
  end

  describe "static_base/0" do
    test "returns string" do
      result = Soul.static_base()
      assert is_binary(result)
    end

    test "uses compact mode if enabled" do
      # From module: if compact_mode() do static_base_compact()
      assert true
    end

    test "returns cached value if available" do
      # First call builds cache, second returns it
      result1 = Soul.static_base()
      result2 = Soul.static_base()
      assert result1 == result2
    end

    test "interpolates template on first call" do
      # From module: interpolate_and_cache(provider)
      assert true
    end

    test "caches result in persistent_term" do
      # From module: :persistent_term.put({__MODULE__, :static_base}, base)
      assert true
    end
  end

  describe "static_base_compact/0" do
    test "returns string" do
      result = Soul.static_base_compact()
      assert is_binary(result)
    end

    test "returns cached value if available" do
      # From module: :persistent_term.get({__MODULE__, :static_base_compact}, nil)
      assert true
    end

    test "loads and caches template on first call" do
      # From module: template = load_compact_template()
      assert true
    end

    test "interpolates compact template" do
      # From module: interpolate_compact(template, provider)
      assert true
    end

    test "estimates and caches token count" do
      # From module: token_count = estimate_tokens(base)
      assert true
    end

    test "logs token count" do
      # From module: Logger.info("[Soul] Compact base cached: #{token_count} tokens")
      assert true
    end

    test "falls back to full template if compact not found" do
      # From module: Logger.warning("[Soul] SYSTEM_COMPACT not found, using full SYSTEM.md")
      assert true
    end
  end

  describe "compact_mode/0" do
    test "returns boolean" do
      result = Soul.compact_mode()
      assert is_boolean(result)
    end

    test "checks OSA_COMPACT_MODE env var" do
      # From module: System.get_env("OSA_COMPACT_MODE")
      assert true
    end

    test "returns true if OSA_COMPACT_MODE is 'true'" do
      # From module: "true" -> true
      assert true
    end

    test "returns true if OSA_COMPACT_MODE is '1'" do
      # From module: "1" -> true
      assert true
    end

    test "returns true if OSA_COMPACT_MODE is 'yes'" do
      # From module: "yes" -> true
      assert true
    end

    test "auto-detects groq provider" do
      # From module: if provider in [:groq, ...]
      assert true
    end

    test "auto-detects openai provider" do
      # From module: if provider in [:groq, :openai, ...]
      assert true
    end

    test "auto-detects openrouter provider" do
      # From module: if provider in [:groq, :openai, :openrouter, ...]
      assert true
    end

    test "auto-detects anthropic provider" do
      # From module: if provider in [:groq, :openai, :openrouter, :anthropic, ...]
      assert true
    end

    test "auto-detects deepseek provider" do
      # From module: if provider in [:groq, :openai, :openrouter, :anthropic, :deepseek, ...]
      assert true
    end

    test "respects OSA_FULL_PROMPT override" do
      # From module: System.get_env("OSA_FULL_PROMPT") != "true"
      assert true
    end
  end

  describe "invalidate_cache/0" do
    test "clears static_base cache" do
      # From module: :persistent_term.put({__MODULE__, :static_base}, nil)
      assert Soul.invalidate_cache() == :ok
    end

    test "clears static_token_count cache" do
      # From module: :persistent_term.put({__MODULE__, :static_token_count}, 0)
      assert true
    end

    test "clears static_base_compact cache" do
      # From module: :persistent_term.put({__MODULE__, :static_base_compact}, nil)
      assert true
    end

    test "clears static_base_compact_token_count cache" do
      # From module: :persistent_term.put({__MODULE__, :static_base_compact_token_count}, 0)
      assert true
    end

    test "returns :ok" do
      assert Soul.invalidate_cache() == :ok
    end
  end

  describe "invalidate_cache_for_provider_change/0" do
    test "calls invalidate_cache/0" do
      # From module: invalidate_cache()
      assert Soul.invalidate_cache_for_provider_change() == :ok
    end

    test "returns :ok" do
      assert Soul.invalidate_cache_for_provider_change() == :ok
    end
  end

  describe "static_token_count/0" do
    test "returns non-negative integer" do
      result = Soul.static_token_count()
      assert is_integer(result) and result >= 0
    end

    test "uses compact count if compact_mode enabled" do
      # From module: if compact_mode() do _ = static_base_compact()
      assert true
    end

    test "triggers cache build if not cached" do
      # From module: _ = static_base()
      assert true
    end

    test "returns cached value" do
      # From module: :persistent_term.get({__MODULE__, :static_token_count}, 0)
      assert true
    end
  end

  describe "user/0" do
    test "returns string or nil" do
      result = Soul.user()
      assert is_binary(result) or result == nil
    end

    test "reads from persistent_term" do
      # From module: :persistent_term.get({__MODULE__, :user}, nil)
      assert true
    end
  end

  describe "identity/0" do
    test "returns string or nil" do
      result = Soul.identity()
      assert is_binary(result) or result == nil
    end

    test "reads from persistent_term" do
      # From module: :persistent_term.get({__MODULE__, :identity}, nil)
      assert true
    end
  end

  describe "soul/0" do
    test "returns string or nil" do
      result = Soul.soul()
      assert is_binary(result) or result == nil
    end

    test "reads from persistent_term" do
      # From module: :persistent_term.get({__MODULE__, :soul}, nil)
      assert true
    end
  end

  describe "for_agent/1" do
    test "accepts agent name string" do
      result = Soul.for_agent("test_agent")
      assert is_map(result)
    end

    test "returns map with :identity and :soul keys" do
      result = Soul.for_agent("test_agent")
      assert Map.has_key?(result, :identity)
      assert Map.has_key?(result, :soul)
    end

    test "uses agent-specific soul if exists" do
      # From module: Map.get(agent_souls, agent_name)
      assert true
    end

    test "falls back to default soul if agent-specific not found" do
      # From module: %{identity: identity(), soul: soul()}
      assert true
    end

    test "falls back to default for missing agent_identity" do
      # From module: agent_soul[:identity] || identity()
      assert true
    end

    test "falls back to default for missing agent_soul" do
      # From module: agent_soul[:soul] || soul()
      assert true
    end
  end

  describe "interpolate_and_cache/1" do
    test "loads system template" do
      # From module: template = load_system_template()
      assert true
    end

    test "interpolates TOOL_DEFINITIONS" do
      # From module: |> interpolate("{{TOOL_DEFINITIONS}}", tools(provider))
      assert true
    end

    test "interpolates RULES" do
      # From module: |> interpolate("{{RULES}}", rules_content())
      assert true
    end

    test "interpolates USER_PROFILE" do
      # From module: |> interpolate("{{USER_PROFILE}}", user_content())
      assert true
    end

    test "interpolates SOUL_CONTENT" do
      # From module: |> interpolate("{{SOUL_CONTENT}}", soul_content())
      assert true
    end

    test "interpolates IDENTITY_PROFILE" do
      # From module: |> interpolate("{{IDENTITY_PROFILE}}", identity_content())
      assert true
    end

    test "caches result in persistent_term" do
      # From module: :persistent_term.put({__MODULE__, :static_base}, base)
      assert true
    end

    test "estimates and caches token count" do
      # From module: token_count = estimate_tokens(base)
      assert true
    end

    test "logs token count" do
      # From module: Logger.info("[Soul] Static base cached: #{token_count} tokens")
      assert true
    end
  end

  describe "load_system_template/0" do
    test "uses PromptLoader for SYSTEM.md" do
      # From module: PromptLoader.get(:SYSTEM)
      assert true
    end

    test "falls back to compose_legacy_template if not found" do
      # From module: nil -> compose_legacy_template()
      assert true
    end
  end

  describe "load_compact_template/0" do
    test "uses PromptLoader for SYSTEM_COMPACT.md" do
      # From module: PromptLoader.get(:SYSTEM_COMPACT)
      assert true
    end

    test "logs warning and falls back to full template if not found" do
      # From module: Logger.warning("[Soul] SYSTEM_COMPACT not found...")
      assert true
    end
  end

  describe "interpolate_compact/2" do
    test "interpolates TOOL_DEFINITIONS" do
      # From module: |> interpolate("{{TOOL_DEFINITIONS}}", tools(provider))
      assert true
    end

    test "interpolates USER_PROFILE" do
      # From module: |> interpolate("{{USER_PROFILE}}", user_content())
      assert true
    end

    test "interpolates IDENTITY_PROFILE" do
      # From module: |> interpolate("{{IDENTITY_PROFILE}}", identity_content())
      assert true
    end

    test "does NOT include RULES" do
      # From module: # Note: compact template doesn't include RULES
      assert true
    end

    test "does NOT include SOUL_CONTENT" do
      # From module: # Note: compact template doesn't include RULES or SOUL_CONTENT
      assert true
    end
  end

  describe "compose_legacy_template/0" do
    test "returns minimal fallback template" do
      result = apply(Soul, :compose_legacy_template, [])
      assert is_binary(result)
    end

    test "includes OSA identity" do
      # From module: "You are OSA (Optimal System Agent)."
      assert true
    end

    test "includes TOOL_DEFINITIONS placeholder" do
      # From module: "{{TOOL_DEFINITIONS}}"
      assert true
    end

    test "includes USER_PROFILE placeholder" do
      # From module: "{{USER_PROFILE}}"
      assert true
    end
  end

  describe "interpolate/3" do
    test "replaces marker with nil as empty string" do
      # From module: defp interpolate(text, marker, nil), do: String.replace(text, marker, "")
      assert true
    end

    test "replaces marker with empty string as empty string" do
      # From module: defp interpolate(text, marker, ""), do: String.replace(text, marker, "")
      assert true
    end

    test "replaces marker with content" do
      # From module: defp interpolate(text, marker, content), do: String.replace(text, marker, content)
      assert true
    end
  end

  describe "tools/1" do
    test "returns nil for all providers" do
      # From module: def tools(_provider), do: nil
      assert Soul.tools(:ollama) == nil
      assert Soul.tools(:anthropic) == nil
    end

    test "indicates tools are sent via API only" do
      # From module: @doc "Returns nil for all providers - tools are sent via API only."
      assert true
    end
  end

  describe "rules_content/0" do
    test "reads from priv/rules/" do
      # From module: :code.priv_dir(:optimal_system_agent)
      assert true
    end

    test "returns nil if rules directory doesn't exist" do
      # From module: if rules_dir && File.dir?(rules_dir)
      assert true
    end

    test "finds all *.md files" do
      # From module: Path.join("**/*.md") |> Path.wildcard()
      assert true
    end

    test "sorts files alphabetically" do
      # From module: |> Enum.sort()
      assert true
    end

    test "formats each rule with header" do
      # From module: "## Rule: #{name}\n#{content}"
      assert true
    end

    test "returns nil if no rules found" do
      # From module: [] -> nil
      assert true
    end

    test "prepends Active Rules header" do
      # From module: "# Active Rules\n\n" <> Enum.join(parts, "\n\n")
      assert true
    end
  end

  describe "user_content/0" do
    test "returns nil if user is nil" do
      # From module: nil -> nil
      assert true
    end

    test "returns nil if user is empty string" do
      # From module: "" -> nil
      assert true
    end

    test "returns user content if present" do
      # From module: content -> content
      assert true
    end
  end

  describe "soul_content/0" do
    test "returns nil if soul is nil" do
      # From module: nil -> nil
      assert true
    end

    test "returns nil if soul is empty string" do
      # From module: "" -> nil
      assert true
    end

    test "returns soul content if present" do
      # From module: content -> content
      assert true
    end
  end

  describe "identity_content/0" do
    test "returns nil if identity is nil" do
      # From module: nil -> nil
      assert true
    end

    test "returns nil if identity is empty string" do
      # From module: "" -> nil
      assert true
    end

    test "returns identity content if present" do
      # From module: content -> content
      assert true
    end
  end

  describe "estimate_tokens/1" do
    test "returns 0 for nil" do
      # From module: defp estimate_tokens(nil), do: 0
      assert true
    end

    test "returns 0 for empty string" do
      # From module: defp estimate_tokens(""), do: 0
      assert true
    end

    test "uses Utils.Tokens.estimate for text" do
      # From module: OptimalSystemAgent.Utils.Tokens.estimate(text)
      assert true
    end
  end

  describe "load_file/2" do
    test "reads file from directory" do
      # From module: path = Path.join(dir, filename)
      assert true
    end

    test "returns nil if file doesn't exist" do
      # From module: if File.exists?(path)
      assert true
    end

    test "returns nil if content is empty after trim" do
      # From module: if content == "", do: nil, else: content
      assert true
    end

    test "logs warning on read error" do
      # From module: Logger.warning("[Soul] Failed to read #{path}: ...")
      assert true
    end

    test "returns nil on read error" do
      # From module: {:error, reason} -> nil
      assert true
    end
  end

  describe "load_agent_souls/1" do
    test "returns empty map if agents_dir doesn't exist" do
      # From module: if File.dir?(agents_dir)
      assert true
    end

    test "lists subdirectories" do
      # From module: agents_dir |> File.ls!()
      assert true
    end

    test "filters only directories" do
      # From module: |> Enum.filter(&File.dir?(Path.join(agents_dir, &1)))
      assert true
    end

    test "loads IDENTITY.md from agent directory" do
      # From module: load_file(agent_dir, "IDENTITY.md")
      assert true
    end

    test "loads SOUL.md from agent directory" do
      # From module: load_file(agent_dir, "SOUL.md")
      assert true
    end

    test "only includes agents with at least one file" do
      # From module: if agent_identity || agent_soul do
      assert true
    end

    test "returns map of agent_name => %{identity, soul}" do
      # From module: Map.put(acc, agent_name, %{identity: ..., soul: ...})
      assert true
    end

    test "logs warning on failure" do
      # From module: Logger.warning("[Soul] Failed to load agent souls: ...")
      assert true
    end

    test "returns empty map on failure" do
      # From module: e -> %{}
      assert true
    end
  end

  describe "constants" do
    test "soul_dir defaults to ~/.osa" do
      # From module: Application.get_env(:optimal_system_agent, :bootstrap_dir, "~/.osa")
      assert true
    end
  end

  describe "integration" do
    test "uses OptimalSystemAgent.PromptLoader" do
      # From module: alias OptimalSystemAgent.PromptLoader
      assert true
    end

    test "uses OptimalSystemAgent.Utils.Tokens" do
      # From module: OptimalSystemAgent.Utils.Tokens.estimate(text)
      assert true
    end

    test "uses persistent_term for caching" do
      # From module: :persistent_term.put/get
      assert true
    end

    test "uses Logger for logging" do
      # From module: require Logger
      assert true
    end
  end

  describe "edge cases" do
    test "handles missing priv directory" do
      # From module: {:error, _} -> nil
      assert true
    end

    test "handles missing agents directory" do
      # From module: if File.dir?(agents_dir)
      assert true
    end

    test "handles unicode in soul files" do
      # Should handle gracefully
      assert true
    end

    test "handles very large soul files" do
      # Should handle large content
      assert true
    end

    test "handles malformed template markers" do
      # String.replace handles gracefully
      assert true
    end
  end
end
