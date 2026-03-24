defmodule OptimalSystemAgent.Healing.SessionRealTest do
  @moduledoc """
  Chicago TDD integration tests for Healing.Session.

  NO MOCKS. Tests real state machine transitions, budget calculation, duration tracking.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Healing.Session

  describe "Session.new/2" do
    test "CRASH: creates session with defaults" do
      session = Session.new("agent-1", %{category: :timeout})

      assert session.agent_id == "agent-1"
      assert session.status == :pending
      assert session.budget_usd == 0.50
      assert session.timeout_ms == 300_000
      assert session.max_attempts == 1
      assert session.attempt_count == 0
      assert %DateTime{} = session.started_at
      assert is_binary(session.id)
      assert String.starts_with?(session.id, "heal_")
    end

    test "CRASH: custom budget and timeout" do
      session = Session.new("agent-2", %{category: :llm_error},
        budget_usd: 1.0, timeout_ms: 600_000, max_attempts: 3
      )

      assert session.budget_usd == 1.0
      assert session.timeout_ms == 600_000
      assert session.max_attempts == 3
    end

    test "CRASH: each session gets unique ID" do
      s1 = Session.new("a", %{})
      s2 = Session.new("a", %{})
      assert s1.id != s2.id
    end

    test "CRASH: classification is stored" do
      classification = %{category: :timeout, severity: :medium, retryable: true}
      session = Session.new("agent-1", classification)
      assert session.classification == classification
    end
  end

  describe "Session.transition/2 — valid transitions" do
    test "CRASH: pending → diagnosing" do
      session = Session.new("agent-1", %{})
      assert {:ok, updated} = Session.transition(session, :diagnosing)
      assert updated.status == :diagnosing
    end

    test "CRASH: diagnosing → fixing" do
      session = Session.new("agent-1", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      assert {:ok, updated} = Session.transition(session, :fixing)
      assert updated.status == :fixing
    end

    test "CRASH: fixing → completed" do
      session = Session.new("agent-1", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :fixing)
      assert {:ok, updated} = Session.transition(session, :completed)
      assert updated.status == :completed
    end

    test "CRASH: fixing → failed" do
      session = Session.new("agent-1", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :fixing)
      assert {:ok, updated} = Session.transition(session, :failed)
      assert updated.status == :failed
    end

    test "CRASH: pending → failed" do
      session = Session.new("agent-1", %{})
      assert {:ok, updated} = Session.transition(session, :failed)
      assert updated.status == :failed
    end

    test "CRASH: pending → escalated" do
      session = Session.new("agent-1", %{})
      assert {:ok, updated} = Session.transition(session, :escalated)
      assert updated.status == :escalated
    end

    test "CRASH: diagnosing → escalated" do
      session = Session.new("agent-1", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      assert {:ok, updated} = Session.transition(session, :escalated)
      assert updated.status == :escalated
    end

    test "CRASH: failed → diagnosing (retry path)" do
      session = Session.new("agent-1", %{})
      {:ok, session} = Session.transition(session, :failed)
      assert {:ok, updated} = Session.transition(session, :diagnosing)
      assert updated.status == :diagnosing
    end
  end

  describe "Session.transition/2 — invalid transitions" do
    test "CRASH: pending → completed is invalid" do
      session = Session.new("agent-1", %{})
      assert {:error, :invalid_transition} = Session.transition(session, :completed)
    end

    test "CRASH: pending → fixing is invalid" do
      session = Session.new("agent-1", %{})
      assert {:error, :invalid_transition} = Session.transition(session, :fixing)
    end

    test "CRASH: completed → diagnosing is invalid" do
      session = Session.new("agent-1", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :fixing)
      {:ok, session} = Session.transition(session, :completed)
      assert {:error, :invalid_transition} = Session.transition(session, :diagnosing)
    end

    test "CRASH: escalated → diagnosing is invalid" do
      session = Session.new("agent-1", %{})
      {:ok, session} = Session.transition(session, :escalated)
      assert {:error, :invalid_transition} = Session.transition(session, :diagnosing)
    end

    test "CRASH: completed → any is invalid" do
      session = Session.new("agent-1", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :fixing)
      {:ok, session} = Session.transition(session, :completed)

      for target <- [:pending, :diagnosing, :fixing, :failed, :escalated, :completed] do
        assert {:error, :invalid_transition} = Session.transition(session, target)
      end
    end
  end

  describe "Session.terminal?/1" do
    test "CRASH: completed is terminal" do
      session = %{Session.new("a", %{}) | status: :completed}
      assert Session.terminal?(session)
    end

    test "CRASH: failed is terminal" do
      session = Session.new("a", %{})
      session = %{session | status: :failed}
      assert Session.terminal?(session)
    end

    test "CRASH: escalated is terminal" do
      session = Session.new("a", %{})
      session = %{session | status: :escalated}
      assert Session.terminal?(session)
    end

    test "CRASH: pending is not terminal" do
      session = Session.new("a", %{})
      refute Session.terminal?(session)
    end

    test "CRASH: diagnosing is not terminal" do
      session = Session.new("a", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      refute Session.terminal?(session)
    end

    test "CRASH: fixing is not terminal" do
      session = Session.new("a", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :fixing)
      refute Session.terminal?(session)
    end
  end

  describe "Session.retryable?/1" do
    test "CRASH: failed with count < max is retryable" do
      session = Session.new("a", %{}, max_attempts: 3)
      {:ok, session} = Session.transition(session, :failed)
      assert session.attempt_count == 1
      assert Session.retryable?(session)
    end

    test "CRASH: transition to :failed increments attempt_count" do
      session = Session.new("a", %{})
      assert session.attempt_count == 0
      {:ok, session} = Session.transition(session, :failed)
      assert session.attempt_count == 1
    end

    test "CRASH: retry path increments on each failure" do
      session = Session.new("a", %{}, max_attempts: 3)
      {:ok, session} = Session.transition(session, :failed)
      assert session.attempt_count == 1
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :failed)
      assert session.attempt_count == 2
      assert Session.retryable?(session)
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :failed)
      assert session.attempt_count == 3
      refute Session.retryable?(session)
    end

    test "CRASH: failed with count >= max is not retryable" do
      session = Session.new("a", %{}, max_attempts: 1)
      {:ok, session} = Session.transition(session, :failed)
      # attempt_count was incremented by transition to :failed
      # max_attempts: 1, attempt_count: 1, 1 < 1 = false
      refute Session.retryable?(session)
    end

    test "CRASH: pending is not retryable" do
      session = Session.new("a", %{})
      refute Session.retryable?(session)
    end

    test "CRASH: completed is not retryable" do
      session = Session.new("a", %{})
      session = %{session | status: :completed, completed_at: DateTime.utc_now()}
      refute Session.retryable?(session)
    end
  end

  describe "Session.duration_ms/1" do
    test "CRASH: completed session has duration" do
      session = Session.new("a", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :fixing)
      {:ok, session} = Session.transition(session, :completed)

      assert Session.duration_ms(session) != nil
      assert Session.duration_ms(session) >= 0
    end

    test "CRASH: pending session has nil duration" do
      session = Session.new("a", %{})
      assert Session.duration_ms(session) == nil
    end

    test "CRASH: failed session has duration" do
      session = Session.new("a", %{})
      {:ok, session} = Session.transition(session, :failed)
      assert Session.duration_ms(session) != nil
    end
  end

  describe "Session — budget calculation" do
    test "CRASH: diagnosis_budget is 40% of total" do
      session = Session.new("a", %{}, budget_usd: 1.0)
      assert Session.diagnosis_budget(session) == 0.4
    end

    test "CRASH: fix_budget is 60% of total" do
      session = Session.new("a", %{}, budget_usd: 1.0)
      assert Session.fix_budget(session) == 0.6
    end

    test "CRASH: budgets sum to total" do
      session = Session.new("a", %{}, budget_usd: 1.0)
      assert Float.round(Session.diagnosis_budget(session) + Session.fix_budget(session), 4) == 1.0
    end

    test "CRASH: default budget 0.50 splits correctly" do
      session = Session.new("a", %{})
      assert Session.diagnosis_budget(session) == 0.2
      assert Session.fix_budget(session) == 0.3
    end
  end

  describe "Session — completed_at is set on terminal transition" do
    test "CRASH: completed transition sets completed_at" do
      session = Session.new("a", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      {:ok, session} = Session.transition(session, :fixing)
      {:ok, session} = Session.transition(session, :completed)

      assert session.completed_at != nil
      assert %DateTime{} = session.completed_at
    end

    test "CRASH: failed transition sets completed_at" do
      session = Session.new("a", %{})
      {:ok, session} = Session.transition(session, :failed)
      assert session.completed_at != nil
    end

    test "CRASH: escalated transition sets completed_at" do
      session = Session.new("a", %{})
      {:ok, session} = Session.transition(session, :escalated)
      assert session.completed_at != nil
    end

    test "CRASH: non-terminal transition does NOT set completed_at" do
      session = Session.new("a", %{})
      {:ok, session} = Session.transition(session, :diagnosing)
      assert session.completed_at == nil
    end
  end
end
