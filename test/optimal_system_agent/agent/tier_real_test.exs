defmodule OptimalSystemAgent.Agent.TierRealTest do
  @moduledoc """
  Chicago TDD integration tests for Agent.Tier.

  NO MOCKS. Tests real tier selection, budget calculation, complexity mapping.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Agent.Tier

  describe "Tier.model_for/2 — known providers" do
    test "CRASH: anthropic elite returns opus" do
      assert Tier.model_for(:elite, :anthropic) == "claude-opus-4-6"
    end

    test "CRASH: anthropic specialist returns sonnet" do
      assert Tier.model_for(:specialist, :anthropic) == "claude-sonnet-4-6"
    end

    test "CRASH: anthropic utility returns haiku" do
      assert Tier.model_for(:utility, :anthropic) == "claude-haiku-4-5-20251001"
    end

    test "CRASH: google elite returns gemini-2.5-pro" do
      assert Tier.model_for(:elite, :google) == "gemini-2.5-pro"
    end

    test "CRASH: google specialist returns gemini-2.5-flash" do
      assert Tier.model_for(:specialist, :google) == "gemini-2.5-flash"
    end

    test "CRASH: openai elite returns gpt-4o" do
      assert Tier.model_for(:elite, :openai) == "gpt-4o"
    end

    test "CRASH: openai specialist returns gpt-4o-mini" do
      assert Tier.model_for(:specialist, :openai) == "gpt-4o-mini"
    end

    test "CRASH: deepseek elite returns deepseek-reasoner" do
      assert Tier.model_for(:elite, :deepseek) == "deepseek-reasoner"
    end

    test "CRASH: mistral elite returns mistral-large-latest" do
      assert Tier.model_for(:elite, :mistral) == "mistral-large-latest"
    end

    test "CRASH: groq elite returns openai/gpt-oss-20b" do
      assert Tier.model_for(:elite, :groq) == "openai/gpt-oss-20b"
    end

    test "CRASH: openrouter elite returns anthropic/claude-opus-4-6" do
      assert Tier.model_for(:elite, :openrouter) == "anthropic/claude-opus-4-6"
    end

    test "CRASH: all providers return binary strings" do
      for provider <- Tier.supported_providers(), tier <- [:elite, :specialist, :utility] do
        result = Tier.model_for(tier, provider)
        assert is_binary(result), "model_for(#{tier}, #{provider}) returned non-binary: #{inspect(result)}"
      end
    end
  end

  describe "Tier.budget_for/1" do
    test "CRASH: elite has 260k total budget" do
      budget = Tier.budget_for(:elite)
      assert budget.total == 260_000
    end

    test "CRASH: specialist has 205k total budget" do
      budget = Tier.budget_for(:specialist)
      assert budget.total == 205_000
    end

    test "CRASH: utility has 102k total budget" do
      budget = Tier.budget_for(:utility)
      assert budget.total == 102_000
    end

    test "CRASH: elite budget has all 8 sub-budgets" do
      budget = Tier.budget_for(:elite)
      for key <- [:system, :agent, :tools, :conversation, :execution, :reasoning, :buffer, :thinking] do
        assert Map.has_key?(budget, key), "elite budget missing key: #{key}"
        assert is_integer(budget[key]), "elite budget.#{key} not integer"
        assert budget[key] > 0, "elite budget.#{key} not positive"
      end
    end

    test "CRASH: unknown tier defaults to specialist" do
      budget = Tier.budget_for(:unknown)
      assert budget == Tier.budget_for(:specialist)
    end
  end

  describe "Tier.total_budget/1" do
    test "CRASH: elite returns 260000" do
      assert Tier.total_budget(:elite) == 260_000
    end

    test "CRASH: specialist returns 205000" do
      assert Tier.total_budget(:specialist) == 205_000
    end

    test "CRASH: utility returns 102000" do
      assert Tier.total_budget(:utility) == 102_000
    end

    test "CRASH: sub-budgets sum to total for elite" do
      budget = Tier.budget_for(:elite)
      sub_sum = budget.system + budget.agent + budget.tools + budget.conversation +
                budget.execution + budget.reasoning + budget.buffer + budget.thinking
      assert sub_sum == budget.total
    end

    test "CRASH: sub-budgets sum to total for utility" do
      budget = Tier.budget_for(:utility)
      sub_sum = budget.system + budget.agent + budget.tools + budget.conversation +
                budget.execution + budget.reasoning + budget.buffer + budget.thinking
      assert sub_sum == budget.total
    end

    test "CRASH: sub-budgets sum to total for specialist" do
      budget = Tier.budget_for(:specialist)
      sub_sum = budget.system + budget.agent + budget.tools + budget.conversation +
                budget.execution + budget.reasoning + budget.buffer + budget.thinking
      assert sub_sum == budget.total
    end
  end

  describe "Tier.max_response_tokens/1" do
    test "CRASH: elite = 8000" do
      assert Tier.max_response_tokens(:elite) == 8_000
    end

    test "CRASH: specialist = 4000" do
      assert Tier.max_response_tokens(:specialist) == 4_000
    end

    test "CRASH: utility = 2000" do
      assert Tier.max_response_tokens(:utility) == 2_000
    end

    test "CRASH: elite > specialist > utility" do
      assert Tier.max_response_tokens(:elite) > Tier.max_response_tokens(:specialist)
      assert Tier.max_response_tokens(:specialist) > Tier.max_response_tokens(:utility)
    end
  end

  describe "Tier.tier_for_complexity/1" do
    test "CRASH: complexity 1 = utility" do
      assert Tier.tier_for_complexity(1) == :utility
    end

    test "CRASH: complexity 3 = utility (boundary)" do
      assert Tier.tier_for_complexity(3) == :utility
    end

    test "CRASH: complexity 4 = specialist" do
      assert Tier.tier_for_complexity(4) == :specialist
    end

    test "CRASH: complexity 6 = specialist (boundary)" do
      assert Tier.tier_for_complexity(6) == :specialist
    end

    test "CRASH: complexity 7 = elite" do
      assert Tier.tier_for_complexity(7) == :elite
    end

    test "CRASH: complexity 10 = elite" do
      assert Tier.tier_for_complexity(10) == :elite
    end

    test "CRASH: complexity 100 = elite (high values)" do
      assert Tier.tier_for_complexity(100) == :elite
    end
  end

  describe "Tier.max_agents/1" do
    test "CRASH: elite = 50" do
      assert Tier.max_agents(:elite) == 50
    end

    test "CRASH: specialist = 30" do
      assert Tier.max_agents(:specialist) == 30
    end

    test "CRASH: utility = 10" do
      assert Tier.max_agents(:utility) == 10
    end
  end

  describe "Tier.temperature/1" do
    test "CRASH: elite = 0.5" do
      assert Tier.temperature(:elite) == 0.5
    end

    test "CRASH: specialist = 0.4" do
      assert Tier.temperature(:specialist) == 0.4
    end

    test "CRASH: utility = 0.2" do
      assert Tier.temperature(:utility) == 0.2
    end
  end

  describe "Tier.max_iterations/1" do
    test "CRASH: elite = 25" do
      assert Tier.max_iterations(:elite) == 25
    end

    test "CRASH: specialist = 15" do
      assert Tier.max_iterations(:specialist) == 15
    end

    test "CRASH: utility = 8" do
      assert Tier.max_iterations(:utility) == 8
    end
  end

  describe "Tier.tier_info/1" do
    test "CRASH: returns composite map with all keys" do
      info = Tier.tier_info(:elite)
      assert info.tier == :elite
      assert Map.has_key?(info, :budget)
      assert Map.has_key?(info, :max_agents)
      assert Map.has_key?(info, :max_iterations)
      assert Map.has_key?(info, :temperature)
      assert Map.has_key?(info, :max_response_tokens)
    end

    test "CRASH: budget matches budget_for" do
      info = Tier.tier_info(:specialist)
      assert info.budget == Tier.budget_for(:specialist)
    end
  end

  describe "Tier.all_tiers/0" do
    test "CRASH: returns map with all 3 tiers" do
      tiers = Tier.all_tiers()
      assert Map.has_key?(tiers, :elite)
      assert Map.has_key?(tiers, :specialist)
      assert Map.has_key?(tiers, :utility)
    end

    test "CRASH: each tier has complete info" do
      tiers = Tier.all_tiers()
      for {tier, info} <- tiers do
        assert info.tier == tier
        assert info.max_agents > 0
        assert info.max_iterations > 0
        assert info.temperature > 0
        assert info.max_response_tokens > 0
      end
    end
  end

  describe "Tier.supported_providers/0" do
    test "CRASH: returns list of atoms" do
      providers = Tier.supported_providers()
      assert is_list(providers)
      assert length(providers) > 0
      Enum.each(providers, fn p -> assert is_atom(p) end)
    end

    test "CRASH: includes all major providers" do
      providers = Tier.supported_providers()
      for expected <- [:anthropic, :openai, :google, :ollama, :groq, :openrouter] do
        assert expected in providers, "Missing provider: #{expected}"
      end
    end
  end

  describe "Tier — tier override via persistent_term" do
    setup do
      # Clear any existing overrides
      Tier.clear_tier_override(:elite)
      Tier.clear_tier_override(:specialist)
      Tier.clear_tier_override(:utility)
      :ok
    end

    test "CRASH: set_tier_override stores value" do
      assert :ok == Tier.set_tier_override(:elite, "my-custom-model")
      overrides = Tier.get_tier_overrides()
      assert overrides[:elite] == "my-custom-model"
    end

    test "CRASH: clear_tier_override removes value" do
      Tier.set_tier_override(:specialist, "temp-model")
      assert Tier.get_tier_overrides()[:specialist] == "temp-model"
      Tier.clear_tier_override(:specialist)
      refute Map.has_key?(Tier.get_tier_overrides(), :specialist)
    end

    test "CRASH: get_tier_overrides returns empty map when no overrides" do
      Tier.clear_tier_override(:elite)
      Tier.clear_tier_override(:specialist)
      Tier.clear_tier_override(:utility)
      assert Tier.get_tier_overrides() == %{}
    end

    test "CRASH: override for invalid tier is ignored" do
      # The function guards on tier in [:elite, :specialist, :utility]
      # so calling with :unknown will raise FunctionClauseError
      assert_raise FunctionClauseError, fn ->
        Tier.set_tier_override(:unknown, "model")
      end
    end
  end
end
