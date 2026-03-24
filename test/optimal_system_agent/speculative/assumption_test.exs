defmodule OptimalSystemAgent.Speculative.AssumptionTest do
  @moduledoc """
  Chicago TDD unit tests for Speculative.Assumption module.

  Tests assumption tracking for speculative execution.
  Pure functions with DateTime side effects, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Speculative.Assumption

  @moduletag :capture_log

  describe "new/2" do
    test "creates new assumption with :pending status" do
      assumption = Assumption.new("test_id", "Test description")
      assert assumption.id == "test_id"
      assert assumption.description == "Test description"
      assert assumption.status == :pending
    end

    test "sets checked_at to nil" do
      assumption = Assumption.new("test_id", "Test description")
      assert assumption.checked_at == nil
    end

    test "sets invalidation_reason to nil" do
      assumption = Assumption.new("test_id", "Test description")
      assert assumption.invalidation_reason == nil
    end

    test "accepts binary id and description" do
      assumption = Assumption.new("id123", "description")
      assert is_binary(assumption.id)
      assert is_binary(assumption.description)
    end
  end

  describe "from_descriptions/1" do
    test "creates assumptions from list of descriptions" do
      descriptions = ["First assumption", "Second assumption"]
      assumptions = Assumption.from_descriptions(descriptions)
      assert length(assumptions) == 2
    end

    test "auto-generates IDs with index" do
      descriptions = ["A", "B", "C"]
      assumptions = Assumption.from_descriptions(descriptions)
      assert Enum.at(assumptions, 0).id == "assumption_1"
      assert Enum.at(assumptions, 1).id == "assumption_2"
      assert Enum.at(assumptions, 2).id == "assumption_3"
    end

    test "sets all assumptions to :pending status" do
      assumptions = Assumption.from_descriptions(["test"])
      assert hd(assumptions).status == :pending
    end

    test "handles empty list" do
      assumptions = Assumption.from_descriptions([])
      assert assumptions == []
    end

    test "handles single description" do
      assumptions = Assumption.from_descriptions(["Single"])
      assert length(assumptions) == 1
    end
  end

  describe "confirm/1" do
    test "marks assumption as :confirmed" do
      assumption = Assumption.new("test_id", "test")
      confirmed = Assumption.confirm(assumption)
      assert confirmed.status == :confirmed
    end

    test "sets checked_at to current time" do
      assumption = Assumption.new("test_id", "test")
      confirmed = Assumption.confirm(assumption)
      assert confirmed.checked_at != nil
      assert %DateTime{} = confirmed.checked_at
    end

    test "preserves id and description" do
      assumption = Assumption.new("test_id", "test description")
      confirmed = Assumption.confirm(assumption)
      assert confirmed.id == "test_id"
      assert confirmed.description == "test description"
    end

    test "clears invalidation_reason" do
      final_assumption = Assumption.new("test_id", "test")
        |> Assumption.invalidate("reason")
        |> Assumption.confirm()
      assert final_assumption.status == :confirmed
      assert final_assumption.invalidation_reason == nil
    end
  end

  describe "invalidate/2" do
    test "marks assumption as :invalidated" do
      assumption = Assumption.new("test_id", "test")
      invalidated = Assumption.invalidate(assumption, "test reason")
      assert invalidated.status == :invalidated
    end

    test "sets checked_at to current time" do
      assumption = Assumption.new("test_id", "test")
      invalidated = Assumption.invalidate(assumption, "reason")
      assert invalidated.checked_at != nil
    end

    test "sets invalidation_reason" do
      assumption = Assumption.new("test_id", "test")
      invalidated = Assumption.invalidate(assumption, "test reason")
      assert invalidated.invalidation_reason == "test reason"
    end

    test "uses default reason when not provided" do
      assumption = Assumption.new("test_id", "test")
      invalidated = Assumption.invalidate(assumption)
      assert invalidated.invalidation_reason == "invalidated"
    end

    test "preserves id and description" do
      assumption = Assumption.new("test_id", "test description")
      invalidated = Assumption.invalidate(assumption, "reason")
      assert invalidated.id == "test_id"
      assert invalidated.description == "test description"
    end
  end

  describe "struct fields" do
    test "has id field" do
      assumption = %Assumption{id: "test", description: "test"}
      assert assumption.id == "test"
    end

    test "has description field" do
      assumption = %Assumption{id: "test", description: "test"}
      assert assumption.description == "test"
    end

    test "has status field" do
      assumption = %Assumption{id: "test", description: "test", status: :pending}
      assert assumption.status == :pending
    end

    test "has checked_at field" do
      now = DateTime.utc_now()
      assumption = %Assumption{id: "test", description: "test", checked_at: now}
      assert assumption.checked_at == now
    end

    test "has invalidation_reason field" do
      assumption = %Assumption{id: "test", description: "test", invalidation_reason: "test"}
      assert assumption.invalidation_reason == "test"
    end
  end

  describe "status values" do
    test "accepts :pending status" do
      assumption = %Assumption{id: "test", description: "test", status: :pending}
      assert assumption.status == :pending
    end

    test "accepts :confirmed status" do
      assumption = %Assumption{id: "test", description: "test", status: :confirmed}
      assert assumption.status == :confirmed
    end

    test "accepts :invalidated status" do
      assumption = %Assumption{id: "test", description: "test", status: :invalidated}
      assert assumption.status == :invalidated
    end
  end

  describe "edge cases" do
    test "handles empty description" do
      assumption = Assumption.new("test_id", "")
      assert assumption.description == ""
    end

    test "handles very long description" do
      long_desc = String.duplicate("word ", 1000)
      assumption = Assumption.new("test_id", long_desc)
      assert String.length(assumption.description) > 1000
    end

    test "handles unicode in description" do
      assumption = Assumption.new("test_id", "测试描述")
      assert assumption.description == "测试描述"
    end

    test "handles unicode in id" do
      assumption = Assumption.new("测试_id", "description")
      assert assumption.id == "测试_id"
    end

    test "handles very long invalidation reason" do
      long_reason = String.duplicate("reason ", 1000)
      assumption = Assumption.new("test_id", "test")
      invalidated = Assumption.invalidate(assumption, long_reason)
      assert String.length(invalidated.invalidation_reason) > 1000
    end
  end

  describe "integration" do
    test "full assumption lifecycle" do
      # Create
      assumption = Assumption.new("test_id", "User is working on auth")
      assert assumption.status == :pending

      # Confirm
      confirmed = Assumption.confirm(assumption)
      assert confirmed.status == :confirmed
      assert confirmed.checked_at != nil

      # Create another and invalidate
      assumption2 = Assumption.new("test_id2", "API is available")
      invalidated = Assumption.invalidate(assumption2, "API returned 503")
      assert invalidated.status == :invalidated
      assert invalidated.invalidation_reason == "API returned 503"
    end

    test "bulk assumption creation and validation" do
      descriptions = [
        "User hasn't changed intent",
        "Context is still valid",
        "No conflicting edits"
      ]

      assumptions = Assumption.from_descriptions(descriptions)
      assert length(assumptions) == 3

      # Confirm all
      confirmed = Enum.map(assumptions, &Assumption.confirm/1)
      assert Enum.all?(confirmed, fn a -> a.status == :confirmed end)
    end
  end
end
