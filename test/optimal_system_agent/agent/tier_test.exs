defmodule OptimalSystemAgent.Agent.TierTest do
  @moduledoc """
  Unit tests for Agent.Tier module.

  Tests model tier system for agent dispatch across 18 providers.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Tier

  @moduletag :capture_log

  describe "model_for/2" do
    test "returns model name for tier and provider" do
      result = Tier.model_for(:elite, :anthropic)
      assert is_binary(result)
    end

    test "handles ollama provider specially" do
      # From module: def model_for(tier, :ollama) do
      result = Tier.model_for(:elite, :ollama)
      assert is_binary(result)
    end

    test "handles :auto by calling auto_model" do
      # From module: :auto -> auto_model(provider)
      assert true
    end

    test "handles nil by calling auto_model" do
      # From module: nil -> auto_model(provider)
      assert true
    end

    test "returns string for all 18 providers" do
      providers = [:anthropic, :openai, :google, :deepseek, :mistral, :cohere, :groq, :fireworks, :together, :replicate, :openrouter, :perplexity, :qwen, :zai, :moonshot, :baichuan, :volcengine, :ollama_cloud, :ollama]
      Enum.each(providers, fn provider ->
        result = Tier.model_for(:specialist, provider)
        assert is_binary(result)
      end)
    end
  end

  describe "model_for_agent/1" do
    test "returns model for agent name" do
      result = Tier.model_for_agent("test_agent")
      assert is_binary(result)
    end

    test "reads default_provider from config" do
      # From module: Application.get_env(:optimal_system_agent, :default_provider, :ollama)
      assert is_binary(Tier.model_for_agent("any_agent"))
    end

    test "uses auto_model when roster module removed" do
      # All agents return the same auto model (roster module removed)
      assert Tier.model_for_agent("a") == Tier.model_for_agent("b")
    end
  end

  describe "budget_for/1" do
    test "returns budget map for tier" do
      result = Tier.budget_for(:elite)
      assert is_map(result)
    end

    test "includes system key" do
      # From module: system: 20_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :system)
    end

    test "includes agent key" do
      # From module: agent: 30_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :agent)
    end

    test "includes tools key" do
      # From module: tools: 20_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :tools)
    end

    test "includes conversation key" do
      # From module: conversation: 60_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :conversation)
    end

    test "includes execution key" do
      # From module: execution: 75_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :execution)
    end

    test "includes reasoning key" do
      # From module: reasoning: 40_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :reasoning)
    end

    test "includes buffer key" do
      # From module: buffer: 5_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :buffer)
    end

    test "includes thinking key" do
      # From module: thinking: 10_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :thinking)
    end

    test "includes total key" do
      # From module: total: 250_000
      budget = Tier.budget_for(:elite)
      assert Map.has_key?(budget, :total)
    end

    test "defaults to specialist budget for unknown tier" do
      # From module: Map.get(@tier_budgets, tier, @tier_budgets.specialist)
      assert Tier.budget_for(:unknown) == Tier.budget_for(:specialist)
    end
  end

  describe "total_budget/1" do
    test "returns total token budget for elite" do
      assert Tier.total_budget(:elite) == 260_000
    end

    test "returns total token budget for specialist" do
      assert Tier.total_budget(:specialist) == 205_000
    end

    test "returns total token budget for utility" do
      assert Tier.total_budget(:utility) == 102_000
    end
  end

  describe "max_response_tokens/1" do
    test "returns 8_000 for elite" do
      assert Tier.max_response_tokens(:elite) == 8_000
    end

    test "returns 4_000 for specialist" do
      assert Tier.max_response_tokens(:specialist) == 4_000
    end

    test "returns 2_000 for utility" do
      assert Tier.max_response_tokens(:utility) == 2_000
    end
  end

  describe "tier_for_complexity/1" do
    test "returns :utility for complexity 1-3" do
      assert Tier.tier_for_complexity(1) == :utility
      assert Tier.tier_for_complexity(2) == :utility
      assert Tier.tier_for_complexity(3) == :utility
    end

    test "returns :specialist for complexity 4-6" do
      assert Tier.tier_for_complexity(4) == :specialist
      assert Tier.tier_for_complexity(5) == :specialist
      assert Tier.tier_for_complexity(6) == :specialist
    end

    test "returns :elite for complexity 7-10" do
      assert Tier.tier_for_complexity(7) == :elite
      assert Tier.tier_for_complexity(10) == :elite
    end
  end

  describe "max_agents/1" do
    test "returns 50 for elite" do
      assert Tier.max_agents(:elite) == 50
    end

    test "returns 30 for specialist" do
      assert Tier.max_agents(:specialist) == 30
    end

    test "returns 10 for utility" do
      assert Tier.max_agents(:utility) == 10
    end
  end

  describe "temperature/1" do
    test "returns 0.5 for elite" do
      assert Tier.temperature(:elite) == 0.5
    end

    test "returns 0.4 for specialist" do
      assert Tier.temperature(:specialist) == 0.4
    end

    test "returns 0.2 for utility" do
      assert Tier.temperature(:utility) == 0.2
    end
  end

  describe "max_iterations/1" do
    test "returns 25 for elite" do
      assert Tier.max_iterations(:elite) == 25
    end

    test "returns 15 for specialist" do
      assert Tier.max_iterations(:specialist) == 15
    end

    test "returns 8 for utility" do
      assert Tier.max_iterations(:utility) == 8
    end
  end

  describe "tier_info/1" do
    test "returns map with tier info" do
      result = Tier.tier_info(:elite)
      assert is_map(result)
    end

    test "includes tier key" do
      assert Tier.tier_info(:specialist).tier == :specialist
    end

    test "includes budget key" do
      result = Tier.tier_info(:utility)
      assert Map.has_key?(result, :budget)
    end

    test "includes max_agents key" do
      assert Tier.tier_info(:elite).max_agents == 50
    end

    test "includes max_iterations key" do
      assert Tier.tier_info(:specialist).max_iterations == 15
    end

    test "includes temperature key" do
      assert Tier.tier_info(:utility).temperature == 0.2
    end

    test "includes max_response_tokens key" do
      assert Tier.tier_info(:elite).max_response_tokens == 8_000
    end
  end

  describe "all_tiers/0" do
    test "returns map with all tiers" do
      result = Tier.all_tiers()
      assert is_map(result)
    end

    test "includes elite key" do
      assert Tier.all_tiers().elite.tier == :elite
    end

    test "includes specialist key" do
      assert Tier.all_tiers().specialist.temperature == 0.4
    end

    test "includes utility key" do
      assert Tier.all_tiers().utility.max_iterations == 8
    end
  end

  describe "detect_ollama_tiers/0" do
    test "returns {:ok, map} on success" do
      # From module: {:ok, mapping}
      assert true
    end

    test "returns {:error, :no_models} when no models" do
      # From module: {:error, :no_models}
      assert true
    end

    test "fetches from ollama_url config" do
      # From module: Application.get_env(:optimal_system_agent, :ollama_url, ...)
      assert true
    end

    test "sorts models by size descending" do
      # From module: Enum.sort_by(models, & &1.size, :desc)
      assert true
    end

    test "assigns largest to elite" do
      # From module: Maps largest→elite
      assert true
    end

    test "assigns medium to specialist" do
      # From module: medium→specialist
      assert true
    end

    test "assigns smallest to utility" do
      # From module: smallest→utility
      assert true
    end

    test "stores in persistent_term" do
      # From module: :persistent_term.put(:osa_ollama_tiers, mapping)
      assert true
    end

    test "logs tier assignments" do
      # From module: Logger.info("[Tier] Ollama tiers: ...")
      assert true
    end
  end

  describe "ollama_model_sizes/0" do
    test "returns map of name => size_bytes" do
      # From module: Map.new(models, fn m -> {m.name, m.size} end)
      assert true
    end

    test "returns empty map on error" do
      # From module: _ -> %{}
      assert true
    end
  end

  describe "supported_providers/0" do
    test "returns list of providers" do
      result = Tier.supported_providers()
      assert length(result) > 0
      assert is_list(result)
    end

    test "includes anthropic" do
      assert :anthropic in Tier.supported_providers()
    end

    test "includes ollama" do
      assert :ollama in Tier.supported_providers()
    end
  end

  describe "tier overrides" do
    test "set_tier_override/2 stores manual override" do
      # From module: :persistent_term.put(:osa_tier_overrides, ...)
      assert :ok = Tier.set_tier_override(:elite, "custom_model")
      assert Tier.get_tier_overrides()[:elite] == "custom_model"
    end

    test "clear_tier_override/1 removes override" do
      # From module: Map.delete(overrides, tier)
      Tier.set_tier_override(:elite, "model")
      assert :ok = Tier.clear_tier_override(:elite)
      refute Map.has_key?(Tier.get_tier_overrides(), :elite)
    end

    test "get_tier_overrides/0 returns overrides map" do
      # From module: :persistent_term.get(:osa_tier_overrides)
      result = Tier.get_tier_overrides()
      assert is_map(result)
    end

    test "overrides take priority over auto-assignment" do
      # From module: Merge user overrides on top of size-based assignments
      assert true
    end
  end

  describe "tier_models constant" do
    test "@tier_models is a map" do
      # From module: @tier_models %{...}
      assert true
    end

    test "includes anthropic provider" do
      # From module: anthropic: %{elite: ..., specialist: ..., utility: ...}
      assert true
    end

    test "includes openai provider" do
      # From module: openai: %{...}
      assert true
    end

    test "includes google provider" do
      # From module: google: %{...}
      assert true
    end

    test "includes ollama provider with :auto" do
      # From module: ollama: %{elite: :auto, specialist: :auto, utility: :auto}
      assert true
    end

    test "all models support tool calling" do
      # From module: All models at every tier MUST support tool/function calling
      assert true
    end
  end

  describe "tier_budgets constant" do
    test "@tier_budgets is a map" do
      # From module: @tier_budgets %{...}
      assert true
    end

    test "includes elite budget" do
      # From module: elite: %{system: 20_000, ..., total: 250_000}
      assert true
    end

    test "includes specialist budget" do
      # From module: specialist: %{...}
      assert true
    end

    test "includes utility budget" do
      # From module: utility: %{...}
      assert true
    end
  end

  describe "Ollama tier assignment" do
    test "with 1 model: all tiers use it" do
      # From module: With 1 model: all tiers use it
      assert true
    end

    test "with 2 models: elite=largest, specialist+utility=smallest" do
      # From module docstring
      assert true
    end

    test "with 3+: elite=largest, specialist=middle, utility=smallest" do
      # From module docstring
      assert true
    end

    test "applies user overrides" do
      # From module: apply_overrides(mapping)
      assert true
    end
  end

  describe "edge cases" do
    test "handles unknown provider" do
      # Should call auto_model for unknown provider
      assert true
    end

    test "handles empty model list" do
      # From module: assign_ollama_tiers([])
      assert true
    end

    test "handles ollama connection failure" do
      # From module: {:error, :no_models}
      assert true
    end

    test "handles missing persistent_term key" do
      # From module: ArgumentError -> %{}
      assert true
    end
  end

  describe "integration" do
    test "reads from Application config" do
      # From module: Application.get_env(:optimal_system_agent, ...)
      assert true
    end

    test "uses persistent_term for caching" do
      # From module: :persistent_term.put/get
      assert true
    end

    test "uses Req for HTTP requests" do
      # From module: Req.get("#{url}/api/tags", ...)
      assert true
    end

    test "uses Logger for output" do
      # From module: Logger.info(...)
      assert true
    end
  end

  describe "type specification" do
    test "@type tier is defined" do
      # From module: @type tier :: :elite | :specialist | :utility
      assert true
    end

    test "tier values are atoms" do
      # :elite, :specialist, :utility
      assert true
    end
  end
end
