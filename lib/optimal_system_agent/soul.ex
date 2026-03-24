defmodule OptimalSystemAgent.Soul do
  @moduledoc """
  Soul — loads, caches, and serves the cohesive system prompt.

  ## Architecture (v2 — Two-Tier)

  The Soul module manages a cacheable static base prompt:

      Static Base — SYSTEM.md interpolated with boot-time vars, cached in persistent_term
      Dynamic Context — assembled per-request by Agent.Context (not managed here)

  ## Static Base Assembly

  1. Load SYSTEM.md template (PromptLoader handles user override + bundled)
  2. On first call to `static_base/0`, interpolate boot-time variables:
     - `{{TOOL_DEFINITIONS}}` — tool schemas from Tools.Registry
     - `{{RULES}}` — project rules from priv/rules/
     - `{{USER_PROFILE}}` — USER.md content
  3. Cache the interpolated result + token count in persistent_term

  Lazy interpolation ensures Tools.Registry is available (it starts after Soul.load).

  ## Backward Compatibility

  If no SYSTEM.md exists but IDENTITY.md + SOUL.md do (old format),
  the module composes them with the security guardrail into a base prompt.

  ## File Locations

      priv/prompts/SYSTEM.md           — bundled cohesive system prompt (primary)
      ~/.osa/prompts/SYSTEM.md         — user override (takes precedence)
      ~/.osa/IDENTITY.md               — legacy identity (backward compat)
      ~/.osa/SOUL.md                   — legacy soul (backward compat)
      ~/.osa/USER.md                   — user profile
      ~/.osa/agents/<name>/            — per-agent overrides

  ## Caching

  Content is cached in `:persistent_term` for lock-free reads from any process.
  Files are re-read on explicit `reload/0` or at application boot.
  """

  require Logger

  alias OptimalSystemAgent.PromptLoader

  defp soul_dir, do: Application.get_env(:optimal_system_agent, :bootstrap_dir, "~/.osa")

  # ── Public API ─────────────────────────────────────────────────────

  @doc """
  Load soul files from disk and cache in persistent_term.
  Called at application boot and on explicit reload.

  Does NOT interpolate the static base — that happens lazily on first
  call to `static_base/0` (after Tools.Registry is available).
  """
  def load do
    dir = Path.expand(soul_dir())

    # Load user profile
    user = load_file(dir, "USER.md")
    :persistent_term.put({__MODULE__, :user}, user)

    # Load legacy files (backward compat + for_agent/1)
    identity = load_file(dir, "IDENTITY.md")
    soul = load_file(dir, "SOUL.md")
    :persistent_term.put({__MODULE__, :identity}, identity)
    :persistent_term.put({__MODULE__, :soul}, soul)

    # Discover per-agent souls
    agents_dir = Path.join(dir, "agents")
    agent_souls = load_agent_souls(agents_dir)
    :persistent_term.put({__MODULE__, :agent_souls}, agent_souls)

    # Invalidate cached static base (rebuilt lazily on next static_base/0 call)
    :persistent_term.put({__MODULE__, :static_base}, nil)
    :persistent_term.put({__MODULE__, :static_token_count}, 0)
    :persistent_term.put({__MODULE__, :static_base_compact}, nil)
    :persistent_term.put({__MODULE__, :static_base_compact_token_count}, 0)

    loaded_count = Enum.count([identity, soul, user], &(&1 != nil))
    agent_count = map_size(agent_souls)

    Logger.info("[Soul] Loaded #{loaded_count}/3 bootstrap files, #{agent_count} agent soul(s)")
    :ok
  end

  @doc "Force reload all soul files from disk and invalidate cache."
  def reload do
    load()
    :ok
  end

  @doc """
  Returns the cached, interpolated static base prompt.

  On first call after boot or reload, reads the SYSTEM.md template,
  interpolates boot-time variables, caches the result, and returns it.
  Subsequent calls return the cached value (~0 cost).

  Use `compact_mode/0` to check if compact mode is enabled.
  """
  @spec static_base() :: String.t()
  def static_base do
    if compact_mode() do
      static_base_compact()
    else
      case :persistent_term.get({__MODULE__, :static_base}, nil) do
        nil ->
          provider = Application.get_env(:optimal_system_agent, :default_provider, :ollama)
          interpolate_and_cache(provider)
        cached -> cached
      end
    end
  end

  @doc """
  Returns the compact system prompt for cloud providers.

  Uses SYSTEM_COMPACT.md which is ~2k tokens instead of ~16k.
  Useful for Groq, OpenAI, and other providers with strict guardrails.
  """
  @spec static_base_compact() :: String.t()
  def static_base_compact do
    case :persistent_term.get({__MODULE__, :static_base_compact}, nil) do
      nil ->
        provider = Application.get_env(:optimal_system_agent, :default_provider, :ollama)
        template = load_compact_template()
        base = interpolate_compact(template, provider)
        token_count = estimate_tokens(base)
        :persistent_term.put({__MODULE__, :static_base_compact}, base)
        :persistent_term.put({__MODULE__, :static_base_compact_token_count}, token_count)
        Logger.info("[Soul] Compact base cached: #{token_count} tokens")
        base

      cached ->
        cached
    end
  end

  @doc """
  Check if compact mode is enabled.

  Compact mode uses the shorter SYSTEM_COMPACT.md prompt (~2k tokens)
  instead of the full SYSTEM.md (~16k tokens).

  Controlled by:
  1. OSA_COMPACT_MODE env var ("true"/"1" enables compact mode)
  2. Provider auto-detection (groq, openai, openrouter use compact)
  3. Application config :compact_mode
  """
  @spec compact_mode() :: boolean()
  def compact_mode do
    # Env var takes highest priority
    case System.get_env("OSA_COMPACT_MODE") do
      "true" ->
        true

      "1" ->
        true

      "yes" ->
        true

      _ ->
        # Check provider-based auto-detection
        provider = Application.get_env(:optimal_system_agent, :default_provider, :ollama)

        if provider in [:groq, :openai, :openrouter, :anthropic, :deepseek, :openai_compat] do
          # Cloud providers use compact mode by default
          # Can override with OSA_FULL_PROMPT=true to use full prompt
          System.get_env("OSA_FULL_PROMPT") != "true"
        else
          # Local providers (ollama, lmstudio) use full prompt
          false
        end
    end
  end

  @doc """
  Invalidate all cached prompts and force reload on next access.
  """
  @spec invalidate_cache() :: :ok
  def invalidate_cache do
    :persistent_term.put({__MODULE__, :static_base}, nil)
    :persistent_term.put({__MODULE__, :static_base_token_count}, 0)
    :persistent_term.put({__MODULE__, :static_base_compact}, nil)
    :persistent_term.put({__MODULE__, :static_base_compact_token_count}, 0)
    :ok
  end

  @doc """
  Invalidate cached prompts when provider changes at runtime.

  Called by the hot-swap API to ensure the correct provider-aware
  prompt is used after a provider change.
  """
  @spec invalidate_cache_for_provider_change() :: :ok
  def invalidate_cache_for_provider_change do
    invalidate_cache()
  end

  @doc "Returns the token count of the cached static base."
  @spec static_token_count() :: non_neg_integer()
  def static_token_count do
    if compact_mode() do
      _ = static_base_compact()
      :persistent_term.get({__MODULE__, :static_base_compact_token_count}, 0)
    else
      _ = static_base()
      :persistent_term.get({__MODULE__, :static_token_count}, 0)
    end
  end

  @doc "Get the user profile content (USER.md)."
  @spec user() :: String.t() | nil
  def user do
    :persistent_term.get({__MODULE__, :user}, nil)
  end

  @doc """
  Get the soul for a specific named agent.
  Falls back to the default soul if no agent-specific soul exists.
  """
  @spec for_agent(String.t()) :: %{identity: String.t() | nil, soul: String.t() | nil}
  def for_agent(agent_name) do
    agent_souls = :persistent_term.get({__MODULE__, :agent_souls}, %{})

    case Map.get(agent_souls, agent_name) do
      nil ->
        %{identity: identity(), soul: soul()}

      agent_soul ->
        %{
          identity: agent_soul[:identity] || identity(),
          soul: agent_soul[:soul] || soul()
        }
    end
  end

  # ── Backward Compat Accessors ──────────────────────────────────────
  # Still used by commands.ex and cli.ex for status display.

  @doc "Get the identity content (IDENTITY.md)."
  @spec identity() :: String.t() | nil
  def identity do
    :persistent_term.get({__MODULE__, :identity}, nil)
  end

  @doc "Get the soul content (SOUL.md)."
  @spec soul() :: String.t() | nil
  def soul do
    :persistent_term.get({__MODULE__, :soul}, nil)
  end

  # ── Static Base Assembly ───────────────────────────────────────────

  defp interpolate_and_cache(provider) do
    template = load_system_template()

    # Interpolate boot-time variables
    base =
      template
      |> interpolate("{{TOOL_DEFINITIONS}}", tools(provider))
      |> interpolate("{{RULES}}", rules_content())
      |> interpolate("{{USER_PROFILE}}", user_content())
      |> interpolate("{{SOUL_CONTENT}}", soul_content())
      |> interpolate("{{IDENTITY_PROFILE}}", identity_content())

    # Cache result + token count
    token_count = estimate_tokens(base)
    :persistent_term.put({__MODULE__, :static_base}, base)
    :persistent_term.put({__MODULE__, :static_token_count}, token_count)

    Logger.info("[Soul] Static base cached: #{token_count} tokens")
    base
  end

  defp load_system_template do
    # Priority: PromptLoader (handles ~/.osa/prompts/ override + priv/prompts/ bundled)
    case PromptLoader.get(:SYSTEM) do
      nil -> compose_legacy_template()
      content -> content
    end
  end

  defp load_compact_template do
    # Priority: PromptLoader (handles ~/.osa/prompts/ override + priv/prompts/ bundled)
    case PromptLoader.get(:SYSTEM_COMPACT) do
      nil ->
        # Fallback to full template if compact not available
        Logger.warning("[Soul] SYSTEM_COMPACT not found, using full SYSTEM.md")
        load_system_template()

      content ->
        content
    end
  end

  defp interpolate_compact(template, provider) do
    # Compact template uses the same interpolation variables
    template
    |> interpolate("{{TOOL_DEFINITIONS}}", tools(provider))
    |> interpolate("{{USER_PROFILE}}", user_content())
    |> interpolate("{{IDENTITY_PROFILE}}", identity_content())

    # Note: compact template doesn't include RULES or SOUL_CONTENT
  end

  @doc false
  def compose_legacy_template do
    # Legacy path removed — SYSTEM.md is the only template.
    # If SYSTEM.md is missing, return a minimal fallback.
    """
    You are OSA (Optimal System Agent). Respond helpfully and concisely.

    {{TOOL_DEFINITIONS}}

    {{USER_PROFILE}}
    """
    |> String.trim()
  end

  defp interpolate(text, marker, nil), do: String.replace(text, marker, "")
  defp interpolate(text, marker, ""), do: String.replace(text, marker, "")
  defp interpolate(text, marker, content), do: String.replace(text, marker, content)

  # ── Boot-Time Content Generators ───────────────────────────────────

  @doc """
  Provider-aware tool content generator.

  The structured tool schema sent via the API `tools` parameter is sufficient.
  Including duplicate tool documentation in the system prompt causes some models
  to fall back to XML-style text output instead of using the structured `tool_calls`
  field.

  Returns `nil` for all providers - tools are sent via API only.
  """
  @spec tools(atom()) :: nil
  def tools(_provider), do: nil

  defp rules_content do
    rules_dir =
      case :code.priv_dir(:optimal_system_agent) do
        {:error, _} -> nil
        dir -> Path.join(to_string(dir), "rules")
      end

    if rules_dir && File.dir?(rules_dir) do
      rules_dir
      |> Path.join("**/*.md")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(fn path ->
        name = Path.relative_to(path, rules_dir) |> String.replace_suffix(".md", "")
        content = File.read!(path)
        "## Rule: #{name}\n#{content}"
      end)
      |> case do
        [] -> nil
        parts -> "# Active Rules\n\n" <> Enum.join(parts, "\n\n")
      end
    else
      nil
    end
  rescue
    _ -> nil
  end

  defp user_content do
    case user() do
      nil -> nil
      "" -> nil
      content -> content
    end
  end

  defp soul_content do
    case soul() do
      nil -> nil
      "" -> nil
      content -> content
    end
  end

  defp identity_content do
    case identity() do
      nil -> nil
      "" -> nil
      content -> content
    end
  end

  # ── Token Estimation ───────────────────────────────────────────────

  defp estimate_tokens(nil), do: 0
  defp estimate_tokens(""), do: 0

  defp estimate_tokens(text) when is_binary(text) do
    OptimalSystemAgent.Utils.Tokens.estimate(text)
  end

  # ── File Loading ───────────────────────────────────────────────────

  defp load_file(dir, filename) do
    path = Path.join(dir, filename)

    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} ->
          content = String.trim(content)
          if content == "", do: nil, else: content

        {:error, reason} ->
          Logger.warning("[Soul] Failed to read #{path}: #{inspect(reason)}")
          nil
      end
    else
      nil
    end
  end

  defp load_agent_souls(agents_dir) do
    if File.dir?(agents_dir) do
      agents_dir
      |> File.ls!()
      |> Enum.filter(&File.dir?(Path.join(agents_dir, &1)))
      |> Enum.reduce(%{}, fn agent_name, acc ->
        agent_dir = Path.join(agents_dir, agent_name)
        agent_identity = load_file(agent_dir, "IDENTITY.md")
        agent_soul = load_file(agent_dir, "SOUL.md")

        if agent_identity || agent_soul do
          Map.put(acc, agent_name, %{identity: agent_identity, soul: agent_soul})
        else
          acc
        end
      end)
    else
      %{}
    end
  rescue
    e ->
      Logger.warning("[Soul] Failed to load agent souls: #{Exception.message(e)}")
      %{}
  end
end
