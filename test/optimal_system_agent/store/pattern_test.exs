defmodule OptimalSystemAgent.Store.PatternTest do
  @moduledoc """
  Unit tests for Store.Pattern module.

  Tests Ecto schema for SICA patterns.
  Real Ecto changesets, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Store.Pattern

  @moduletag :capture_log

  describe "changeset/2" do
    test "validates required fields" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "requires id field" do
      attrs = %{
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      refute changeset.valid?
    end

    test "requires description field" do
      attrs = %{
        id: "pattern_1",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      refute changeset.valid?
    end

    test "requires created_at field" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        last_seen: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      refute changeset.valid?
    end

    test "requires last_seen field" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      refute changeset.valid?
    end

    test "validates occurrences is at least 1" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        occurrences: 5
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "rejects occurrences less than 1" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        occurrences: 0
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      refute changeset.valid?
    end

    test "defaults occurrences to 1" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :occurrences) == 1
    end

    test "validates success_rate is between 0.0 and 1.0" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        success_rate: 0.75
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "rejects success_rate greater than 1.0" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        success_rate: 1.5
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      refute changeset.valid?
    end

    test "rejects negative success_rate" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        success_rate: -0.1
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      refute changeset.valid?
    end

    test "defaults success_rate to 1.0" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :success_rate) == 1.0
    end

    test "accepts 0.0 for success_rate" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        success_rate: 0.0
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "accepts 1.0 for success_rate" do
      attrs = %{
        id: "pattern_1",
        description: "Test pattern",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        success_rate: 1.0
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end
  end

  describe "struct fields" do
    test "has id field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "now", last_seen: "now"}
      assert pattern.id == "test"
    end

    test "has description field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "now", last_seen: "now"}
      assert pattern.description == "test"
    end

    test "has trigger field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "now", last_seen: "now", trigger: "test_trigger"}
      assert pattern.trigger == "test_trigger"
    end

    test "has response field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "now", last_seen: "now", response: "test_response"}
      assert pattern.response == "test_response"
    end

    test "has category field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "now", last_seen: "now", category: "decision"}
      assert pattern.category == "decision"
    end

    test "has occurrences field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "now", last_seen: "now", occurrences: 5}
      assert pattern.occurrences == 5
    end

    test "has success_rate field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "now", last_seen: "now", success_rate: 0.8}
      assert pattern.success_rate == 0.8
    end

    test "has tags field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "now", last_seen: "now", tags: "tag1,tag2"}
      assert pattern.tags == "tag1,tag2"
    end

    test "has created_at field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "2026-03-24T12:00:00Z", last_seen: "2026-03-24T12:00:00Z"}
      assert pattern.created_at == "2026-03-24T12:00:00Z"
    end

    test "has last_seen field" do
      pattern = %Pattern{id: "test", description: "test", created_at: "2026-03-24T12:00:00Z", last_seen: "2026-03-24T12:00:00Z"}
      assert pattern.last_seen == "2026-03-24T12:00:00Z"
    end
  end

  describe "edge cases" do
    test "handles empty description" do
      attrs = %{
        id: "pattern_1",
        description: "",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      # Empty strings pass validation (Ecto doesn't validate emptiness by default)
      assert changeset.valid?
    end

    test "handles unicode in description" do
      attrs = %{
        id: "pattern_1",
        description: "测试模式描述",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "handles unicode in trigger" do
      attrs = %{
        id: "pattern_1",
        description: "test",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        trigger: "测试触发器"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "handles unicode in response" do
      attrs = %{
        id: "pattern_1",
        description: "test",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        response: "测试响应"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "handles unicode in tags" do
      attrs = %{
        id: "pattern_1",
        description: "test",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        tags: "标签1,标签2"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "handles very large occurrences count" do
      attrs = %{
        id: "pattern_1",
        description: "test",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        occurrences: 1_000_000
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end

    test "handles nil optional fields" do
      attrs = %{
        id: "pattern_1",
        description: "test",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T12:00:00Z",
        trigger: nil,
        response: nil,
        category: nil,
        tags: nil
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?
    end
  end

  describe "integration" do
    test "full pattern changeset lifecycle" do
      attrs = %{
        id: "pattern_1",
        description: "User authentication flow",
        trigger: "user_logs_in",
        response: "create_session",
        category: "auth",
        occurrences: 10,
        success_rate: 0.9,
        tags: "auth,session,user",
        created_at: "2026-03-24T12:00:00Z",
        last_seen: "2026-03-24T13:00:00Z"
      }
      changeset = Pattern.changeset(%Pattern{}, attrs)
      assert changeset.valid?

      # Apply changeset
      pattern = Ecto.Changeset.apply_changes(changeset)
      assert pattern.id == "pattern_1"
      assert pattern.description == "User authentication flow"
      assert pattern.trigger == "user_logs_in"
      assert pattern.response == "create_session"
      assert pattern.category == "auth"
      assert pattern.occurrences == 10
      assert pattern.success_rate == 0.9
      assert pattern.tags == "auth,session,user"
    end
  end
end
