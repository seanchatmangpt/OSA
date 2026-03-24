defmodule OptimalSystemAgent.AgentTierChicagoTDDTest do
  @moduledoc """
  Chicago TDD: Agent.Tier pure logic tests.

  NO MOCKS. Tests verify REAL tier selection logic.

  Following Toyota Code Production System principles:
    - Build Quality In (Jidoka) — tests verify at the source
    - Visual Management — tier mappings observable

  Tests (Red Phase):
  1. model_for/2 returns correct model for tier+provider
  2. budget_for/1 returns correct budget map
  3. tier_for_complexity/1 maps complexity to tier
  4. max_response_tokens/1 returns correct limits
  5. temperature/1 returns correct values
  6. max_iterations/1 returns correct limits
  7. max_agents/1 returns correct concurrency
  8. tier_info/1 aggregates all tier info
  9. all_tiers/0 returns complete tier map
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Tier

  describe "Tier.model_for/2 — Model Selection" do
    test "CRASH: Returns elite Anthropic model" do
      assert Tier.model_for(:elite, :anthropic) == "claude-opus-4-6"
    end

    test "CRASH: Returns specialist Anthropic model" do
      assert Tier.model_for(:specialist, :anthropic) == "claude-sonnet-4-6"
    end

    test "CRASH: Returns utility Anthropic model" do
      assert Tier.model_for(:utility, :anthropic) == "claude-haiku-4-5-20251001"
    end

    test "CRASH: Returns elite OpenAI model" do
      assert Tier.model_for(:elite, :openai) == "gpt-4o"
    end

    test "CRASH: Returns elite Google model" do
      assert Tier.model_for(:elite, :google) == "gemini-2.5-pro"
    end

    test "CRASH: Returns elite Groq model" do
      assert Tier.model_for(:elite, :groq) == "openai/gpt-oss-20b"
    end

    test "CRASH: Returns specialist Groq model" do
      assert Tier.model_for(:specialist, :groq) == "openai/gpt-oss-20b"
    end

    test "CRASH: Returns utility Groq model" do
      assert Tier.model_for(:utility, :groq) == "qwen-qwq-32b"
    end

    test "CRASH: Returns detected model for Ollama (dynamic)" do
      # Ollama models are detected at boot and cached
      # If cache is populated, returns the cached model name
      # If cache is empty, would call auto_model(:ollama)
      elite_model = Tier.model_for(:elite, :ollama)
      specialist_model = Tier.model_for(:specialist, :ollama)
      utility_model = Tier.model_for(:utility, :ollama)

      # All should return strings (either cached or auto-detected)
      assert is_binary(elite_model) or elite_model == :auto
      assert is_binary(specialist_model) or specialist_model == :auto
      assert is_binary(utility_model) or utility_model == :auto
    end

    test "CRASH: Falls back to auto_model for unknown provider" do
      # Should not crash, returns default model from config
      result = Tier.model_for(:elite, :unknown_provider)
      # Result should be a string (from Application.get_env or default)
      # or could be nil if Application.get_env returns nil and no default is set
      # The important thing is it doesn't crash
      assert is_binary(result) or is_nil(result) or result == :auto
    end
  end

  describe "Tier.budget_for/1 — Budget Allocation" do
    test "CRASH: Returns elite budget map" do
      budget = Tier.budget_for(:elite)

      assert budget.system == 20_000
      assert budget.agent == 30_000
      assert budget.tools == 20_000
      assert budget.total == 260_000
    end

    test "CRASH: Returns specialist budget map" do
      budget = Tier.budget_for(:specialist)

      assert budget.system == 15_000
      assert budget.agent == 25_000
      assert budget.total == 205_000
    end

    test "CRASH: Returns utility budget map" do
      budget = Tier.budget_for(:utility)

      assert budget.system == 8_000
      assert budget.agent == 12_000
      assert budget.total == 102_000
    end

    test "CRASH: Falls back to specialist for unknown tier" do
      budget = Tier.budget_for(:unknown_tier)

      # Should default to specialist budget
      assert budget.total == 205_000
    end
  end

  describe "Tier.total_budget/1 — Total Budget" do
    test "CRASH: Returns elite total budget" do
      assert Tier.total_budget(:elite) == 260_000
    end

    test "CRASH: Returns specialist total budget" do
      assert Tier.total_budget(:specialist) == 205_000
    end

    test "CRASH: Returns utility total budget" do
      assert Tier.total_budget(:utility) == 102_000
    end
  end

  describe "Tier.max_response_tokens/1 — Response Limits" do
    test "CRASH: Elite gets 8000 tokens" do
      assert Tier.max_response_tokens(:elite) == 8_000
    end

    test "CRASH: Specialist gets 4000 tokens" do
      assert Tier.max_response_tokens(:specialist) == 4_000
    end

    test "CRASH: Utility gets 2000 tokens" do
      assert Tier.max_response_tokens(:utility) == 2_000
    end
  end

  describe "Tier.temperature/1 — Temperature Settings" do
    test "CRASH: Elite is most creative (0.5)" do
      assert Tier.temperature(:elite) == 0.5
    end

    test "CRASH: Specialist is balanced (0.4)" do
      assert Tier.temperature(:specialist) == 0.4
    end

    test "CRASH: Utility is most deterministic (0.2)" do
      assert Tier.temperature(:utility) == 0.2
    end
  end

  describe "Tier.max_iterations/1 — Iteration Limits" do
    test "CRASH: Elite gets 25 iterations" do
      assert Tier.max_iterations(:elite) == 25
    end

    test "CRASH: Specialist gets 15 iterations" do
      assert Tier.max_iterations(:specialist) == 15
    end

    test "CRASH: Utility gets 8 iterations" do
      assert Tier.max_iterations(:utility) == 8
    end
  end

  describe "Tier.max_agents/1 — Concurrency Limits" do
    test "CRASH: Elite can run 50 concurrent agents" do
      assert Tier.max_agents(:elite) == 50
    end

    test "CRASH: Specialist can run 30 concurrent agents" do
      assert Tier.max_agents(:specialist) == 30
    end

    test "CRASH: Utility can run 10 concurrent agents" do
      assert Tier.max_agents(:utility) == 10
    end
  end

  describe "Tier.tier_for_complexity/1 — Complexity Mapping" do
    test "CRASH: Low complexity (1-3) maps to utility" do
      assert Tier.tier_for_complexity(1) == :utility
      assert Tier.tier_for_complexity(2) == :utility
      assert Tier.tier_for_complexity(3) == :utility
    end

    test "CRASH: Medium complexity (4-6) maps to specialist" do
      assert Tier.tier_for_complexity(4) == :specialist
      assert Tier.tier_for_complexity(5) == :specialist
      assert Tier.tier_for_complexity(6) == :specialist
    end

    test "CRASH: High complexity (7-10) maps to elite" do
      assert Tier.tier_for_complexity(7) == :elite
      assert Tier.tier_for_complexity(8) == :elite
      assert Tier.tier_for_complexity(9) == :elite
      assert Tier.tier_for_complexity(10) == :elite
    end

    test "CRASH: Very high complexity (11+) maps to elite" do
      assert Tier.tier_for_complexity(11) == :elite
      assert Tier.tier_for_complexity(100) == :elite
    end

    test "CRASH: Zero complexity maps to utility" do
      assert Tier.tier_for_complexity(0) == :utility
    end

    test "CRASH: Negative complexity maps to utility (edge case)" do
      # Negative values are <= 3, so they map to utility
      assert Tier.tier_for_complexity(-1) == :utility
      assert Tier.tier_for_complexity(-100) == :utility
    end
  end

  describe "Tier.tier_info/1 — Tier Aggregation" do
    test "CRASH: Returns complete elite tier info" do
      info = Tier.tier_info(:elite)

      assert info.tier == :elite
      assert info.max_agents == 50
      assert info.max_iterations == 25
      assert info.temperature == 0.5
      assert info.max_response_tokens == 8_000
      assert is_map(info.budget)
    end

    test "CRASH: Returns complete specialist tier info" do
      info = Tier.tier_info(:specialist)

      assert info.tier == :specialist
      assert info.max_agents == 30
      assert info.max_iterations == 15
      assert info.temperature == 0.4
      assert info.max_response_tokens == 4_000
    end

    test "CRASH: Returns complete utility tier info" do
      info = Tier.tier_info(:utility)

      assert info.tier == :utility
      assert info.max_agents == 10
      assert info.max_iterations == 8
      assert info.temperature == 0.2
      assert info.max_response_tokens == 2_000
    end
  end

  describe "Tier.all_tiers/0 — Complete Tier Map" do
    test "CRASH: Returns map with all three tiers" do
      all = Tier.all_tiers()

      assert Map.has_key?(all, :elite)
      assert Map.has_key?(all, :specialist)
      assert Map.has_key?(all, :utility)
    end

    test "CRASH: Each tier has complete info" do
      all = Tier.all_tiers()

      Enum.each([:elite, :specialist, :utility], fn tier ->
        info = Map.get(all, tier)
        assert Map.has_key?(info, :tier)
        assert Map.has_key?(info, :budget)
        assert Map.has_key?(info, :max_agents)
        assert Map.has_key?(info, :max_iterations)
        assert Map.has_key?(info, :temperature)
        assert Map.has_key?(info, :max_response_tokens)
      end)
    end
  end

  describe "Tier.supported_providers/0 — Provider List" do
    test "CRASH: Returns list of all configured providers" do
      providers = Tier.supported_providers()

      # Should include all providers from @tier_models
      assert :anthropic in providers
      assert :openai in providers
      assert :google in providers
      assert :ollama in providers
    end

    test "CRASH: Returns at least 18 providers" do
      providers = Tier.supported_providers()

      assert length(providers) >= 18
    end
  end

  describe "Tier — Edge Cases" do
    test "CRASH: model_for_agent/1 returns a model" do
      # model_for_agent always returns auto_model since Roster was removed
      result = Tier.model_for_agent("test_agent")

      assert is_binary(result)
      assert String.length(result) > 0
    end

    test "CRASH: Handles all 18 providers consistently" do
      # All providers should return a model (not crash) for all tiers
      providers = Tier.supported_providers()

      Enum.each(providers, fn provider ->
        elite_model = Tier.model_for(:elite, provider)
        specialist_model = Tier.model_for(:specialist, provider)
        utility_model = Tier.model_for(:utility, provider)

        # All should return strings (either from config, cached, or default)
        assert is_binary(elite_model)
        assert is_binary(specialist_model)
        assert is_binary(utility_model)
      end)
    end
  end
end
