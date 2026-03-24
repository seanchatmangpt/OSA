defmodule OptimalSystemAgent.Commerce.MarketplaceRealTest do
  @moduledoc """
  Chicago TDD integration tests for Commerce.Marketplace (skill_summary/1 only).

  NO MOCKS. Tests real skill summary computation.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Commerce.Marketplace

  # Helper: minimal valid skill map for skill_summary/1
  defp valid_skill(overrides \\ %{}) do
    Map.merge(%{
      skill_id: "sha256_test_id",
      name: "test-skill",
      description: "A test skill",
      author: "agent_1",
      version: "1.0.0",
      category: "utility",
      tags: ["elixir", "tool"],
      triggers: [],
      pricing: %{type: :free, amount: 0.0},
      rating_count: 0,
      rating_sum: 0,
      downloads: 0,
      quality_score: 0.5,
      published_at: ~U[2026-01-01 00:00:00Z]
    }, overrides)
  end

  describe "Marketplace.skill_summary/1" do
    test "CRASH: returns map with expected keys" do
      skill = valid_skill()
      summary = Marketplace.skill_summary(skill)
      assert is_map(summary)
      assert Map.has_key?(summary, :name)
      assert Map.has_key?(summary, :rating)
      assert Map.has_key?(summary, :downloads)
    end

    test "CRASH: computes average_rating correctly" do
      skill = valid_skill(%{rating_count: 4, rating_sum: 20})
      summary = Marketplace.skill_summary(skill)
      assert summary.rating == 5.0
    end

    test "CRASH: average_rating is nil when no ratings" do
      skill = valid_skill(%{rating_count: 0, rating_sum: 0})
      summary = Marketplace.skill_summary(skill)
      assert summary.rating == nil
    end

    test "CRASH: nil rating_count returns nil (gap fixed)" do
      # GAP FIXED: is_integer guard prevents ArithmeticError on nil
      skill = valid_skill(%{rating_count: nil, rating_sum: nil})
      summary = Marketplace.skill_summary(skill)
      assert summary.rating == nil
    end

    test "CRASH: converts pricing to map" do
      skill = valid_skill(%{pricing: %{type: :paid, amount: 9.99}})
      summary = Marketplace.skill_summary(skill)
      assert summary.pricing == %{type: :paid, amount: 9.99}
    end

    test "CRASH: published_at converted to ISO8601 string" do
      dt = ~U[2026-03-15 12:30:00Z]
      skill = valid_skill(%{published_at: dt})
      summary = Marketplace.skill_summary(skill)
      assert summary.published_at == "2026-03-15T12:30:00Z"
    end
  end
end
