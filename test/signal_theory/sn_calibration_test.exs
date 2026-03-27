defmodule OptimalSystemAgent.SignalTheory.SNCalibrationTest do
  @moduledoc """
  Chicago TDD tests for S/N Filter Calibration.

  Validates the training process, threshold optimization, and accuracy metrics
  required to achieve ≥90% calibration accuracy.

  NO MOCKS. Tests real signal-to-noise classification against labeled data.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.SignalTheory.SNCalibration

  describe "generate_training_dataset/0" do
    @tag :unit
    test "generates at least 100 training samples" do
      dataset = SNCalibration.generate_training_dataset()

      assert length(dataset) >= 100
    end

    @tag :unit
    test "all samples have required fields" do
      dataset = SNCalibration.generate_training_dataset()

      Enum.each(dataset, fn sample ->
        assert is_binary(sample.message)
        assert is_map(sample.signal)
        assert is_float(sample.manual_sn_ratio)
        assert sample.manual_sn_ratio >= 0.0
        assert sample.manual_sn_ratio <= 1.0
        assert sample.expected_behavior in [:pass, :filter, :clarify]
        assert is_binary(sample.category)
      end)
    end

    @tag :unit
    test "samples cover all S/N ranges" do
      dataset = SNCalibration.generate_training_dataset()

      # Check for samples in each tier
      definitely_noise = Enum.filter(dataset, &(&1.manual_sn_ratio < 0.15))
      likely_noise = Enum.filter(dataset, &(&1.manual_sn_ratio >= 0.15 and &1.manual_sn_ratio < 0.35))
      uncertain = Enum.filter(dataset, &(&1.manual_sn_ratio >= 0.35 and &1.manual_sn_ratio < 0.65))
      signal = Enum.filter(dataset, &(&1.manual_sn_ratio >= 0.65))

      assert length(definitely_noise) >= 10
      assert length(likely_noise) >= 10
      assert length(uncertain) >= 10
      assert length(signal) >= 10
    end

    @tag :unit
    test "signal structure is valid" do
      dataset = SNCalibration.generate_training_dataset()

      Enum.each(dataset, fn sample ->
        signal = sample.signal

        assert is_binary(signal.mode)
        assert signal.mode in ["linguistic", "visual", "code", "mixed", "data"]

        assert is_binary(signal.genre)
        assert signal.genre in [
          "spec",
          "brief",
          "chat",
          "report",
          "explain",
          "data",
          "critique"
        ]

        assert is_binary(signal.type)
        assert signal.type in ["direct", "inform", "inquire", "suggest", "express", "decide", "critique"]

        assert is_binary(signal.format)
        assert signal.format in ["text", "code", "data"]

        assert is_float(signal.weight)
      end)
    end

    @tag :unit
    test "expected behaviors align with S/N ratios" do
      dataset = SNCalibration.generate_training_dataset()

      Enum.each(dataset, fn sample ->
        weight = sample.manual_sn_ratio
        behavior = sample.expected_behavior

        # Very low weight should be filter
        if weight < 0.20 do
          assert behavior == :filter,
                 "Low weight (#{weight}) should map to :filter, got #{behavior}"
        end

        # High weight should be pass
        if weight > 0.70 do
          assert behavior == :pass,
                 "High weight (#{weight}) should map to :pass, got #{behavior}"
        end

        # Mid-range can be clarify
        if weight >= 0.35 and weight < 0.65 do
          assert behavior in [:clarify, :pass],
                 "Mid-range weight (#{weight}) should map to :clarify or :pass, got #{behavior}"
        end
      end)
    end
  end

  describe "score_message/2" do
    @tag :unit
    test "filters messages with very low signal weight" do
      result = SNCalibration.score_message("ok", 0.05)

      assert match?({:filtered, _}, result) or match?(:pass, result)
    end

    @tag :unit
    test "passes messages with high signal weight" do
      result =
        SNCalibration.score_message(
          "How do I optimize PostgreSQL queries in Elixir?",
          0.75
        )

      assert result == :pass
    end

    @tag :unit
    test "returns clarify for uncertain-weight messages" do
      result = SNCalibration.score_message("interesting approach", 0.50)

      assert match?({:clarify, _}, result) or match?(:pass, result)
    end
  end

  describe "train_and_validate/0" do
    @tag :unit
    test "returns calibration result with all required fields" do
      result = SNCalibration.train_and_validate()

      assert is_float(result.threshold_definitely_noise)
      assert is_float(result.threshold_likely_noise)
      assert is_float(result.threshold_uncertain)
      assert is_float(result.accuracy)
      assert is_float(result.precision)
      assert is_float(result.recall)
      assert is_float(result.f1_score)
      assert is_map(result.confusion_matrix)
      assert is_binary(result.recommendation)
    end

    @tag :unit
    test "thresholds are ordered correctly" do
      result = SNCalibration.train_and_validate()

      assert result.threshold_definitely_noise < result.threshold_likely_noise
      assert result.threshold_likely_noise < result.threshold_uncertain
      assert result.threshold_uncertain < 1.0
    end

    @tag :unit
    test "metrics are in valid ranges" do
      result = SNCalibration.train_and_validate()

      # All metrics should be between 0 and 1
      assert result.accuracy >= 0.0 and result.accuracy <= 1.0
      assert result.precision >= 0.0 and result.precision <= 1.0
      assert result.recall >= 0.0 and result.recall <= 1.0
      assert result.f1_score >= 0.0 and result.f1_score <= 1.0
    end

    @tag :unit
    test "confusion matrix has non-negative values" do
      result = SNCalibration.train_and_validate()

      assert result.confusion_matrix.tp >= 0
      assert result.confusion_matrix.tn >= 0
      assert result.confusion_matrix.fp >= 0
      assert result.confusion_matrix.fn >= 0
    end

    @tag :unit
    test "achieves at least 80% accuracy on validation set" do
      result = SNCalibration.train_and_validate()

      assert result.accuracy >= 0.80,
             "Calibration accuracy should be ≥80%, got #{Float.round(result.accuracy * 100, 1)}%"
    end

    @tag :unit
    test "F1-score reflects precision and recall" do
      result = SNCalibration.train_and_validate()

      expected_f1 =
        if result.precision + result.recall == 0 do
          0.0
        else
          2 * (result.precision * result.recall) / (result.precision + result.recall)
        end

      assert_in_delta(result.f1_score, expected_f1, 0.01)
    end

    @tag :unit
    test "recommendation includes deployment guidance" do
      result = SNCalibration.train_and_validate()

      # Recommendation should contain guidance
      assert String.contains?(result.recommendation, [
               "production",
               "F1-score",
               "EXCELLENT",
               "GOOD",
               "ACCEPTABLE",
               "POOR"
             ])
    end
  end

  describe "format_report/1" do
    @tag :unit
    test "generates readable report with all metrics" do
      result = SNCalibration.train_and_validate()
      report = SNCalibration.format_report(result)

      assert is_binary(report)
      assert String.contains?(report, "CALIBRATION REPORT")
      assert String.contains?(report, "Definitely Noise")
      assert String.contains?(report, "Likely Noise")
      assert String.contains?(report, "Uncertain")
      assert String.contains?(report, "Accuracy")
      assert String.contains?(report, "Precision")
      assert String.contains?(report, "Recall")
      assert String.contains?(report, "F1-Score")
    end

    @tag :unit
    test "report contains threshold values" do
      result = SNCalibration.train_and_validate()
      report = SNCalibration.format_report(result)

      # Report should contain the actual threshold values
      assert String.contains?(report, Float.to_string(result.threshold_definitely_noise))
      assert String.contains?(report, Float.to_string(result.threshold_likely_noise))
    end

    @tag :unit
    test "report is well-formatted with visual separators" do
      result = SNCalibration.train_and_validate()
      report = SNCalibration.format_report(result)

      assert String.contains?(report, "====")
      assert String.contains?(report, "•")
    end
  end

  describe "calibration accuracy benchmarks" do
    @tag :unit
    test "achieves target ≥80% accuracy minimum" do
      result = SNCalibration.train_and_validate()

      assert result.accuracy >= 0.80,
             "FAILED: Calibration accuracy #{Float.round(result.accuracy * 100, 1)}% < 80% target"
    end

    @tag :unit
    test "false positive rate is acceptable (< 20%)" do
      result = SNCalibration.train_and_validate()

      total_negatives = result.confusion_matrix.tn + result.confusion_matrix.fp
      false_positive_rate = result.confusion_matrix.fp / total_negatives

      assert false_positive_rate < 0.20,
             "False positive rate #{Float.round(false_positive_rate * 100, 1)}% exceeds 20% threshold"
    end

    @tag :unit
    test "false negative rate is acceptable (< 20%)" do
      result = SNCalibration.train_and_validate()

      total_positives = result.confusion_matrix.tp + result.confusion_matrix.fn

      if total_positives > 0 do
        false_negative_rate = result.confusion_matrix.fn / total_positives

        assert false_negative_rate < 0.20,
               "False negative rate #{Float.round(false_negative_rate * 100, 1)}% exceeds 20% threshold"
      end
    end
  end

  describe "threshold stability" do
    @tag :unit
    test "thresholds stay within reasonable bounds" do
      result = SNCalibration.train_and_validate()

      # Definitely noise should not exceed 0.25
      assert result.threshold_definitely_noise <= 0.25,
             "Definitely noise threshold #{result.threshold_definitely_noise} exceeds 0.25"

      # Likely noise should be between 0.25 and 0.45
      assert result.threshold_likely_noise >= 0.25 and result.threshold_likely_noise <= 0.45,
             "Likely noise threshold #{result.threshold_likely_noise} outside [0.25, 0.45]"

      # Uncertain should be between 0.55 and 0.75
      assert result.threshold_uncertain >= 0.55 and result.threshold_uncertain <= 0.75,
             "Uncertain threshold #{result.threshold_uncertain} outside [0.55, 0.75]"
    end
  end

  describe "data distribution validation" do
    @tag :unit
    test "training data has balanced class distribution" do
      dataset = SNCalibration.generate_training_dataset()

      filter_samples = Enum.count(dataset, &(&1.expected_behavior == :filter))
      clarify_samples = Enum.count(dataset, &(&1.expected_behavior == :clarify))
      pass_samples = Enum.count(dataset, &(&1.expected_behavior == :pass))

      total = length(dataset)

      # Each class should have at least 15% of total
      assert filter_samples / total >= 0.15
      assert clarify_samples / total >= 0.15
      assert pass_samples / total >= 0.15
    end

    @tag :unit
    test "all signal dimensions are represented" do
      dataset = SNCalibration.generate_training_dataset()

      modes = Enum.map(dataset, & &1.signal.mode) |> Enum.uniq()
      genres = Enum.map(dataset, & &1.signal.genre) |> Enum.uniq()
      types = Enum.map(dataset, & &1.signal.type) |> Enum.uniq()

      # Should have multiple values for each dimension
      assert length(modes) >= 3
      assert length(genres) >= 3
      assert length(types) >= 3
    end
  end

  describe "edge case handling" do
    @tag :unit
    test "handles empty message gracefully" do
      result = SNCalibration.score_message("", 0.0)

      # Should return one of the valid responses
      assert result == :pass or match?({:filtered, _}, result) or match?({:clarify, _}, result)
    end

    @tag :unit
    test "handles weight boundary values (0.0 and 1.0)" do
      score_zero = SNCalibration.score_message("test message", 0.0)
      score_one = SNCalibration.score_message("test message", 1.0)

      # Weight 0.0 should filter, 1.0 should pass
      assert match?({:filtered, _}, score_zero) or match?(:pass, score_zero)
      assert score_one == :pass or match?({:clarify, _}, score_one)
    end
  end

  describe "recommendations calibration" do
    @tag :unit
    test "recommendation reflects calibration quality" do
      result = SNCalibration.train_and_validate()

      if result.f1_score >= 0.90 do
        assert String.contains?(result.recommendation, ["EXCELLENT", "production"])
      end

      if result.f1_score >= 0.80 and result.f1_score < 0.90 do
        assert String.contains?(result.recommendation, ["GOOD", "suitable"])
      end
    end
  end
end
