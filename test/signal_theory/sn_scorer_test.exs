defmodule OptimalSystemAgent.SignalTheory.SNScorerTest do
  @moduledoc """
  Unit tests for SignalTheory.SNScorer — validates Signal-to-Noise quality scoring
  and governance tier routing.

  Scoring logic:
  - Information completeness: +0.3
  - Error-free execution: +0.3
  - State consistency: +0.2
  - Timing compliance: +0.2

  Governance tiers:
  - S/N > 0.8: autonomous (auto-approve)
  - 0.7 ≤ S/N ≤ 0.8: human review (manager approval)
  - S/N < 0.7: board escalation (C-level approval)
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.SignalTheory.SNScorer

  describe "score/2 — output quality scoring" do
    @tag :unit
    test "score_high_quality_output: perfect output scores > 0.8" do
      output = %{
        "status" => "success",
        "result" => "completed",
        "timestamp" => :os.system_time(:second),
        "duration_ms" => 100,
        "errors" => [],
        "warnings" => [],
        "fields_present" => true,
        "data" => %{"processed" => 50, "valid" => true}
      }

      context = %{
        "deadline_ms" => 5000,
        "expected_fields" => ["status", "result", "data"]
      }

      score = SNScorer.score(output, context)

      assert is_float(score)
      assert score > 0.8
      assert score <= 1.0
    end

    @tag :unit
    test "score_medium_quality_output: partial output scores 0.7-0.8" do
      output = %{
        "status" => "completed",
        "result" => "partial_data",
        "timestamp" => :os.system_time(:second),
        "duration_ms" => 2400,
        "errors" => ["partial_failure"],
        "warnings" => ["retry_needed"],
        "fields_present" => true,
        "data" => %{"processed" => 40}
      }

      context = %{
        "deadline_ms" => 5000,
        "expected_fields" => ["status", "result", "data"]
      }

      score = SNScorer.score(output, context)

      assert is_float(score)
      assert score >= 0.65
      assert score <= 0.85
    end

    @tag :unit
    test "score_low_quality_output: degraded output scores < 0.7" do
      output = %{
        "status" => "failed",
        "result" => nil,
        "timestamp" => :os.system_time(:second),
        "duration_ms" => 4900,
        "errors" => ["timeout", "incomplete_data"],
        "warnings" => ["retry_attempted", "fallback_used"],
        "fields_present" => false
      }

      context = %{
        "deadline_ms" => 5000,
        "expected_fields" => ["status", "result", "data"]
      }

      score = SNScorer.score(output, context)

      assert is_float(score)
      assert score < 0.7
      assert score >= 0.0
    end

    @tag :unit
    test "score_with_default_context: uses default when context omitted" do
      output = %{
        "status" => "success",
        "errors" => [],
        "warnings" => []
      }

      score = SNScorer.score(output)

      assert is_float(score)
      assert score >= 0.0
      assert score <= 1.0
    end
  end

  describe "information_completeness/2" do
    @tag :unit
    test "completeness_all_fields_present: returns 0.3 when all expected fields exist" do
      output = %{"field_a" => "value_a", "field_b" => "value_b"}
      expected_fields = ["field_a", "field_b"]

      score = SNScorer.information_completeness(output, expected_fields)

      assert score == 0.3
    end

    @tag :unit
    test "completeness_missing_fields: returns proportional score when fields missing" do
      output = %{"field_a" => "value_a"}
      expected_fields = ["field_a", "field_b", "field_c"]

      score = SNScorer.information_completeness(output, expected_fields)

      assert is_float(score)
      assert score > 0.0
      assert score < 0.3
    end

    @tag :unit
    test "completeness_no_fields: returns 0 when output is empty" do
      output = %{}
      expected_fields = ["field_a", "field_b"]

      score = SNScorer.information_completeness(output, expected_fields)

      assert score == 0.0
    end

    @tag :unit
    test "completeness_extra_fields_ok: returns 0.3 when output has extra fields" do
      output = %{"field_a" => "value_a", "field_b" => "value_b", "extra" => "value_c"}
      expected_fields = ["field_a", "field_b"]

      score = SNScorer.information_completeness(output, expected_fields)

      assert score == 0.3
    end
  end

  describe "error_free_execution/1" do
    @tag :unit
    test "error_free_no_errors: returns 0.3 when no errors present" do
      output = %{"errors" => [], "warnings" => []}

      score = SNScorer.error_free_execution(output)

      assert score == 0.3
    end

    @tag :unit
    test "error_free_with_warnings: returns reduced score when warnings present" do
      output = %{"errors" => [], "warnings" => ["deprecated_api"]}

      score = SNScorer.error_free_execution(output)

      assert is_float(score)
      assert score < 0.3
      assert score > 0.0
    end

    @tag :unit
    test "error_free_with_errors: returns low score when errors present" do
      output = %{"errors" => ["timeout", "validation_failed"], "warnings" => []}

      score = SNScorer.error_free_execution(output)

      assert is_float(score)
      assert score >= 0.0
      assert score < 0.25
    end

    @tag :unit
    test "error_free_missing_keys: treats missing keys as no errors" do
      output = %{"status" => "ok"}

      score = SNScorer.error_free_execution(output)

      assert score == 0.3
    end
  end

  describe "state_consistency/1" do
    @tag :unit
    test "consistency_valid_state: returns 0.2 for consistent state" do
      output = %{"status" => "success", "data" => %{"valid" => true}}

      score = SNScorer.state_consistency(output)

      assert score == 0.2
    end

    @tag :unit
    test "consistency_inconsistent_state: returns reduced score for inconsistency" do
      output = %{
        "status" => "failed",
        "result" => "completed",
        "data" => %{"valid" => true}
      }

      score = SNScorer.state_consistency(output)

      assert is_float(score)
      assert score >= 0.0
      assert score < 0.2
    end

    @tag :unit
    test "consistency_missing_status: penalizes missing status field" do
      output = %{"data" => %{"value" => 42}}

      score = SNScorer.state_consistency(output)

      assert is_float(score)
      assert score >= 0.0
    end
  end

  describe "timing_compliance/2" do
    @tag :unit
    test "timing_within_budget: returns 0.2 when execution time within deadline" do
      output = %{"duration_ms" => 100}
      deadline_ms = 5000

      score = SNScorer.timing_compliance(output, deadline_ms)

      assert score == 0.2
    end

    @tag :unit
    test "timing_exceed_budget_slightly: returns partial score when slightly over" do
      output = %{"duration_ms" => 4800}
      deadline_ms = 5000

      score = SNScorer.timing_compliance(output, deadline_ms)

      assert is_float(score)
      assert score > 0.0
      assert score <= 0.2
    end

    @tag :unit
    test "timing_exceed_budget_significantly: returns 0 when far over deadline" do
      output = %{"duration_ms" => 10000}
      deadline_ms = 5000

      score = SNScorer.timing_compliance(output, deadline_ms)

      assert score == 0.0
    end

    @tag :unit
    test "timing_missing_duration: treats as 0 penalty" do
      output = %{"status" => "ok"}
      deadline_ms = 5000

      score = SNScorer.timing_compliance(output, deadline_ms)

      assert is_float(score)
    end
  end

  describe "failure_mode_classification/1" do
    @tag :unit
    test "classify_no_errors: returns :ok" do
      output = %{"errors" => []}

      classification = SNScorer.failure_mode_classification(output)

      assert classification == :ok
    end

    @tag :unit
    test "classify_timeout_failure: returns :timeout" do
      output = %{"errors" => ["operation_timeout"]}

      classification = SNScorer.failure_mode_classification(output)

      assert classification == :timeout
    end

    @tag :unit
    test "classify_validation_failure: returns :validation_error" do
      output = %{"errors" => ["validation_failed"]}

      classification = SNScorer.failure_mode_classification(output)

      assert classification == :validation_error
    end

    @tag :unit
    test "classify_resource_failure: returns :resource_error" do
      output = %{"errors" => ["out_of_memory"]}

      classification = SNScorer.failure_mode_classification(output)

      assert classification == :resource_error
    end

    @tag :unit
    test "classify_multiple_errors: returns most severe" do
      output = %{"errors" => ["validation_failed", "retry_failed"]}

      classification = SNScorer.failure_mode_classification(output)

      assert is_atom(classification)
    end
  end

  describe "governance_tier_routing/1" do
    @tag :unit
    test "governance_autonomous: S/N > 0.8 routes to auto-approve" do
      score = 0.85

      tier = SNScorer.governance_tier_routing(score)

      assert tier == :autonomous
    end

    @tag :unit
    test "governance_human_review: 0.7 ≤ S/N ≤ 0.8 routes to human" do
      score_low = 0.70
      score_mid = 0.75
      score_high = 0.80

      tier_low = SNScorer.governance_tier_routing(score_low)
      tier_mid = SNScorer.governance_tier_routing(score_mid)
      tier_high = SNScorer.governance_tier_routing(score_high)

      assert tier_low == :human_review
      assert tier_mid == :human_review
      assert tier_high == :human_review
    end

    @tag :unit
    test "governance_board_escalation: S/N < 0.7 routes to board" do
      score = 0.65

      tier = SNScorer.governance_tier_routing(score)

      assert tier == :board_escalation
    end

    @tag :unit
    test "governance_exact_thresholds: boundary values correct" do
      tier_just_above_autonomous = SNScorer.governance_tier_routing(0.801)
      tier_just_below_autonomous = SNScorer.governance_tier_routing(0.799)
      tier_just_above_human = SNScorer.governance_tier_routing(0.701)
      tier_just_below_human = SNScorer.governance_tier_routing(0.699)

      assert tier_just_above_autonomous == :autonomous
      assert tier_just_below_autonomous == :human_review
      assert tier_just_above_human == :human_review
      assert tier_just_below_human == :board_escalation
    end
  end

  describe "score_with_governance/2" do
    @tag :unit
    test "score_and_tier: returns both score and governance tier" do
      output = %{
        "status" => "success",
        "errors" => [],
        "warnings" => [],
        "duration_ms" => 100,
        "data" => %{"valid" => true}
      }

      context = %{
        "deadline_ms" => 5000,
        "expected_fields" => ["status", "data"]
      }

      {score, tier} = SNScorer.score_with_governance(output, context)

      assert is_float(score)
      assert is_atom(tier)
      assert tier in [:autonomous, :human_review, :board_escalation]
    end

    @tag :unit
    test "score_and_tier_high_quality: excellent output auto-approves" do
      output = %{
        "status" => "success",
        "errors" => [],
        "warnings" => [],
        "duration_ms" => 50,
        "data" => %{"count" => 100, "valid" => true}
      }

      context = %{"deadline_ms" => 5000}

      {score, tier} = SNScorer.score_with_governance(output, context)

      assert score > 0.8
      assert tier == :autonomous
    end

    @tag :unit
    test "score_and_tier_degraded: degraded output escalates to board" do
      output = %{
        "status" => "failed",
        "errors" => ["timeout", "validation_failed"],
        "warnings" => ["retry_attempted"],
        "duration_ms" => 4950,
        "data" => nil
      }

      context = %{"deadline_ms" => 5000}

      {score, tier} = SNScorer.score_with_governance(output, context)

      assert score < 0.7
      assert tier == :board_escalation
    end
  end

  describe "integration: full S/N scoring flow" do
    @tag :unit
    test "full_scoring_pipeline: end-to-end quality assessment" do
      # High-quality output
      good_output = %{
        "status" => "success",
        "result" => "processed",
        "errors" => [],
        "warnings" => [],
        "duration_ms" => 150,
        "data" => %{"items" => 50, "valid" => true}
      }

      good_context = %{
        "deadline_ms" => 5000,
        "expected_fields" => ["status", "result", "data"]
      }

      good_score = SNScorer.score(good_output, good_context)
      good_tier = SNScorer.governance_tier_routing(good_score)

      assert good_score > 0.8
      assert good_tier == :autonomous

      # Degraded output
      bad_output = %{
        "status" => "failed",
        "result" => nil,
        "errors" => ["validation_failed", "timeout"],
        "warnings" => ["fallback_used"],
        "duration_ms" => 4900
      }

      bad_context = %{
        "deadline_ms" => 5000,
        "expected_fields" => ["status", "result", "data"]
      }

      bad_score = SNScorer.score(bad_output, bad_context)
      bad_tier = SNScorer.governance_tier_routing(bad_score)

      assert bad_score < 0.7
      assert bad_tier == :board_escalation
    end
  end
end
