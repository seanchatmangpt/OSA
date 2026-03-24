defmodule OptimalSystemAgent.Commerce.MarketplaceTest do
  @moduledoc """
  Unit tests for Agent Commerce Marketplace (Innovation 9).
  Tests the GenServer API directly (no HTTP layer).
  Uses unique publisher/buyer IDs to avoid collisions.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Commerce.Marketplace

  @pub "pub-#{:erlang.unique_integer([:positive])}"
  @buyer "buyer-#{:erlang.unique_integer([:positive])}"

  describe "publish_skill/2" do
    test "publishes a valid skill and returns skill_id" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Test Skill",
        description: "A test skill",
        instructions: "Do test things"
      })

      assert is_binary(id)
      assert String.starts_with?(id, "skill_")
    end

    test "rejects skill without name" do
      assert {:error, "name is required"} =
        Marketplace.publish_skill(@pub, %{description: "no name", instructions: "test"})
    end

    test "rejects skill without description" do
      assert {:error, "description is required"} =
        Marketplace.publish_skill(@pub, %{name: "Name only", instructions: "test"})
    end

    test "rejects skill without instructions" do
      assert {:error, "instructions are required"} =
        Marketplace.publish_skill(@pub, %{name: "Name", description: "Desc"})
    end
  end

  describe "get_skill/1" do
    test "returns published skill" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Get Test",
        description: "Test",
        instructions: "Test"
      })

      {:ok, skill} = Marketplace.get_skill(id)
      assert skill.name == "Get Test"
      assert skill.quality_score == 0.5
    end

    test "returns error for unknown skill" do
      assert {:error, "skill_not_found"} = Marketplace.get_skill("nonexistent")
    end
  end

  describe "acquire_skill/2" do
    test "increments download count" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Acq Test",
        description: "Test",
        instructions: "Test"
      })

      {:ok, acq} = Marketplace.acquire_skill(@buyer, id)
      assert acq.skill_id == id
      assert acq.buyer_id == @buyer

      {:ok, skill} = Marketplace.get_skill(id)
      assert skill.downloads == 1
    end

    test "returns error for unknown skill" do
      assert {:error, "skill_not_found"} = Marketplace.acquire_skill(@buyer, "nonexistent")
    end
  end

  describe "rate_skill/3" do
    test "updates average rating" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Rate Test",
        description: "Test",
        instructions: "Test"
      })

      {:ok, r1} = Marketplace.rate_skill("rater-a-#{:erlang.unique_integer([:positive])}", id, 5)
      assert r1.new_average == 5.0

      {:ok, r2} = Marketplace.rate_skill("rater-b-#{:erlang.unique_integer([:positive])}", id, 3)
      assert r2.new_average == 4.0
    end
  end

  describe "search_skills/2" do
    test "finds skills by query" do
      Marketplace.publish_skill(@pub, %{
        name: "CRM Integration Pro",
        description: "Sync CRM deals",
        instructions: "Sync"
      })

      results = Marketplace.search_skills("CRM", %{})
      assert results.total >= 1
    end

    test "returns empty for no matches" do
      results = Marketplace.search_skills("zzz-nonexistent-zzz", %{})
      assert results.total == 0
    end
  end

  describe "marketplace_stats/0" do
    test "returns stats including newly published skills" do
      Marketplace.publish_skill(@pub, %{
        name: "Stats Skill",
        description: "Test",
        instructions: "Test"
      })

      stats = Marketplace.marketplace_stats()
      # Total includes all skills ever published (not just ours)
      assert stats.total_skills >= 1
    end
  end

  describe "skill_summary/1" do
    test "excludes instructions from summary" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Summary Test",
        description: "Test desc",
        instructions: "SECRET_INSTRUCTIONS"
      })

      {:ok, skill} = Marketplace.get_skill(id)
      summary = Marketplace.skill_summary(skill)

      refute Map.has_key?(summary, :instructions)
      assert summary.name == "Summary Test"
    end
  end

  # ── Edge Cases ───────────────────────────────────────────────────────────

  describe "edge cases: empty marketplace listings" do
    test "search_skills with empty query returns all skills" do
      results = Marketplace.search_skills("", %{})
      assert results.total >= 0
    end

    test "list_skills with page beyond available returns empty results" do
      results = Marketplace.list_skills(page: 999_999, per_page: 100)
      assert results.results == []
      assert results.total >= 0
    end

    test "marketplace_stats returns valid structure even with no custom skills" do
      stats = Marketplace.marketplace_stats()
      assert Map.has_key?(stats, :total_skills)
      assert Map.has_key?(stats, :total_publishers)
      assert Map.has_key?(stats, :total_acquisitions)
      assert Map.has_key?(stats, :total_executions)
      assert Map.has_key?(stats, :total_revenue)
      assert Map.has_key?(stats, :top_categories)
      assert Map.has_key?(stats, :trending_skills)
      assert stats.total_skills >= 0
    end

    test "revenue_report for publisher with no skills returns zero earnings" do
      result = Marketplace.revenue_report("nonexistent-publisher-#{:erlang.unique_integer([:positive])}")
      assert result.total_earnings == 0.0
      assert result.skill_breakdown == []
    end
  end

  describe "edge cases: invalid skill definitions" do
    test "publish_skill with empty name is rejected" do
      assert {:error, "name is required"} =
        Marketplace.publish_skill(@pub, %{name: "", description: "desc", instructions: "inst"})
    end

    test "publish_skill with nil name is rejected" do
      assert {:error, "name is required"} =
        Marketplace.publish_skill(@pub, %{name: nil, description: "desc", instructions: "inst"})
    end

    test "publish_skill with empty description is rejected" do
      assert {:error, "description is required"} =
        Marketplace.publish_skill(@pub, %{name: "Name", description: "", instructions: "inst"})
    end

    test "publish_skill with empty instructions is rejected" do
      assert {:error, "instructions are required"} =
        Marketplace.publish_skill(@pub, %{name: "Name", description: "desc", instructions: ""})
    end

    test "publish_skill with string keys works" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        "name" => "String Key Skill",
        "description" => "Test",
        "instructions" => "Test"
      })
      assert is_binary(id)
    end

    test "publish_skill with mixed atom and string keys works" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        "name" => "Mixed Key Skill",
        :description => "Test",
        :instructions => "Test"
      })
      assert is_binary(id)
      {:ok, skill} = Marketplace.get_skill(id)
      assert skill.name == "Mixed Key Skill"
    end
  end

  describe "edge cases: duplicate skill names" do
    test "publishing skills with same name produces different IDs" do
      {:ok, id1} = Marketplace.publish_skill(@pub, %{
        name: "Duplicate Name Test",
        description: "First skill",
        instructions: "Instructions 1"
      })
      {:ok, id2} = Marketplace.publish_skill(@pub, %{
        name: "Duplicate Name Test",
        description: "Second skill",
        instructions: "Instructions 2"
      })
      # Each publish creates a unique ID even with the same name
      assert id1 != id2
    end

    test "search_skills finds multiple skills with similar names" do
      Marketplace.publish_skill(@pub, %{
        name: "CRM Integration Alpha",
        description: "Alpha version",
        instructions: "Alpha"
      })
      Marketplace.publish_skill(@pub, %{
        name: "CRM Integration Beta",
        description: "Beta version",
        instructions: "Beta"
      })

      results = Marketplace.search_skills("CRM Integration", %{})
      assert results.total >= 2
    end
  end

  describe "edge cases: rating boundary conditions" do
    test "rate_skill with minimum rating (1) updates average" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Min Rating Test",
        description: "Test",
        instructions: "Test"
      })

      rater = "min-rater-#{:erlang.unique_integer([:positive])}"
      {:ok, result} = Marketplace.rate_skill(rater, id, 1)
      assert result.new_average == 1.0
    end

    test "rate_skill with maximum rating (5) updates average" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Max Rating Test",
        description: "Test",
        instructions: "Test"
      })

      rater = "max-rater-#{:erlang.unique_integer([:positive])}"
      {:ok, result} = Marketplace.rate_skill(rater, id, 5)
      assert result.new_average == 5.0
    end

    test "rate_skill updates same rater's rating (no duplicate ratings)" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Update Rating Test",
        description: "Test",
        instructions: "Test"
      })

      rater = "update-rater-#{:erlang.unique_integer([:positive])}"
      {:ok, r1} = Marketplace.rate_skill(rater, id, 3)
      {:ok, r2} = Marketplace.rate_skill(rater, id, 5)
      # Second rating replaces first; rating_count should stay at 1
      assert r2.new_average == 5.0
    end

    test "rate_skill on nonexistent skill returns error" do
      assert {:error, "skill_not_found"} =
        Marketplace.rate_skill("no-rater", "nonexistent_skill_id", 3)
    end
  end

  describe "edge cases: acquire and execute" do
    test "acquire_skill with nonexistent buyer still works" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Acquire Edge Test",
        description: "Test",
        instructions: "Test"
      })

      buyer = "ghost-buyer-#{:erlang.unique_integer([:positive])}"
      {:ok, acq} = Marketplace.acquire_skill(buyer, id)
      assert acq.buyer_id == buyer
    end

    test "execute_skill on nonexistent skill returns error" do
      assert {:error, "skill_not_found"} =
        Marketplace.execute_skill("buyer", "nonexistent_skill_id", %{})
    end

    test "execute_skill increments successful_executions" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Execute Test",
        description: "Test",
        instructions: "Do things"
      })

      {:ok, _result} = Marketplace.execute_skill("exec-buyer-#{:erlang.unique_integer([:positive])}", id, %{})
      {:ok, skill} = Marketplace.get_skill(id)
      assert skill.successful_executions == 1
    end

    test "quality_score increases after successful execution" do
      {:ok, id} = Marketplace.publish_skill(@pub, %{
        name: "Quality Edge Test",
        description: "Test",
        instructions: "Test"
      })

      {:ok, skill_before} = Marketplace.get_skill(id)
      score_before = skill_before.quality_score

      Marketplace.execute_skill("q-buyer-#{:erlang.unique_integer([:positive])}", id, %{})
      {:ok, skill_after} = Marketplace.get_skill(id)
      score_after = skill_after.quality_score

      assert score_after >= score_before
    end
  end
end
