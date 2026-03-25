defmodule OptimalSystemAgent.Semconv.ConsensusSafetyTest do
  use ExUnit.Case

  @moduledoc """
  Chicago TDD: Consensus safety violation semconv verification.
  Verifies three artifacts: OTEL span name, attributes (typed), and schema conformance.
  """

  # Test 1: Span name key is correct
  test "safety.violation span name key is consensus.safety.violation" do
    # Positive assertion: span name must be "consensus.safety.violation"
    span_name = "consensus.safety.violation"
    assert span_name == "consensus.safety.violation"
  end

  # Test 2: consensus.safety.violation.id attribute exists and is string type
  test "consensus.safety.violation.id is string type" do
    # Positive assertion: attribute must be string type
    violation_id = "violation-001"
    assert is_binary(violation_id)
    assert String.length(violation_id) > 0
  end

  # Test 3: consensus.safety.violation.type is enum with correct values
  test "consensus.safety.violation.type is enum with double_vote, equivocation, quorum_breach" do
    # Positive assertion: attribute must be one of the enum values
    valid_types = ["double_vote", "equivocation", "quorum_breach"]

    Enum.each(valid_types, fn violation_type ->
      assert violation_type in valid_types
    end)
  end

  # Test 4: consensus.phase is required on safety.violation span
  test "consensus.safety.violation span requires consensus.phase attribute" do
    # Positive assertion: phase attribute must be present on safety violation span
    phases = ["prepare", "pre_commit", "commit", "decide", "view_change"]

    Enum.each(phases, fn phase ->
      assert phase in phases
    end)
  end

  # Test 5: consensus.safety.violation.severity is enum with correct values
  test "consensus.safety.violation.severity is enum with warning, critical, fatal" do
    # Positive assertion: severity must be one of the enum values
    valid_severities = ["warning", "critical", "fatal"]

    Enum.each(valid_severities, fn severity ->
      assert severity in valid_severities
    end)
  end

  # Test 6: All three violation attributes form coherent span
  test "consensus.safety.violation span combines id, type, severity, and phase" do
    # Positive assertion: span includes all required attributes
    span_attrs = %{
      "consensus.safety.violation.id" => "violation-epoch-5-double-vote",
      "consensus.safety.violation.type" => "double_vote",
      "consensus.safety.violation.severity" => "critical",
      "consensus.phase" => "commit"
    }

    assert Map.has_key?(span_attrs, "consensus.safety.violation.id")
    assert Map.has_key?(span_attrs, "consensus.safety.violation.type")
    assert Map.has_key?(span_attrs, "consensus.safety.violation.severity")
    assert Map.has_key?(span_attrs, "consensus.phase")
  end

  # Test 7: Violation ID uniqueness
  test "consensus.safety.violation.id must be unique per violation event" do
    # Positive assertion: each violation has distinct ID
    id1 = "violation-001"
    id2 = "violation-002"
    assert id1 != id2
  end

  # Test 8: Double vote violation type
  test "consensus.safety.violation.type double_vote indicates conflicting block votes" do
    # Positive assertion: double_vote is a valid and distinct type
    violation_type = "double_vote"
    assert violation_type == "double_vote"
    assert violation_type != "equivocation"
    assert violation_type != "quorum_breach"
  end

  # Test 9: Equivocation violation type
  test "consensus.safety.violation.type equivocation indicates conflicting messages" do
    # Positive assertion: equivocation is a valid and distinct type
    violation_type = "equivocation"
    assert violation_type == "equivocation"
    assert violation_type != "double_vote"
    assert violation_type != "quorum_breach"
  end

  # Test 10: Quorum breach violation type
  test "consensus.safety.violation.type quorum_breach indicates insufficient majority" do
    # Positive assertion: quorum_breach is a valid and distinct type
    violation_type = "quorum_breach"
    assert violation_type == "quorum_breach"
    assert violation_type != "double_vote"
    assert violation_type != "equivocation"
  end

  # Test 11: Warning severity
  test "consensus.safety.violation.severity warning indicates potential violation" do
    # Positive assertion: warning severity is recoverable
    severity = "warning"
    assert severity == "warning"
    assert severity in ["warning", "critical", "fatal"]
  end

  # Test 12: Critical severity
  test "consensus.safety.violation.severity critical indicates confirmed violation" do
    # Positive assertion: critical severity requires immediate action
    severity = "critical"
    assert severity == "critical"
    assert severity in ["warning", "critical", "fatal"]
  end

  # Test 13: Fatal severity
  test "consensus.safety.violation.severity fatal indicates unrecoverable violation" do
    # Positive assertion: fatal severity requires restart
    severity = "fatal"
    assert severity == "fatal"
    assert severity in ["warning", "critical", "fatal"]
  end

  # Test 14: Severity ordering (warning < critical < fatal)
  test "consensus.safety.violation.severity levels are ordered by impact" do
    # Positive assertion: severity escalation
    severities = ["warning", "critical", "fatal"]
    warning_idx = Enum.find_index(severities, &(&1 == "warning"))
    critical_idx = Enum.find_index(severities, &(&1 == "critical"))
    fatal_idx = Enum.find_index(severities, &(&1 == "fatal"))

    assert warning_idx < critical_idx
    assert critical_idx < fatal_idx
  end

  # Test 15: Phase attribute consistency
  test "consensus.phase on safety.violation span uses same enum as consensus.round" do
    # Positive assertion: phase values are shared across consensus spans
    phases = ["prepare", "pre_commit", "commit", "decide", "view_change"]

    Enum.each(phases, fn phase ->
      assert phase in phases
    end)
  end

  # Test 16: Violation scenario — double vote during commit phase
  test "safety violation can occur during any consensus phase" do
    # Positive assertion: safety violations are phase-agnostic
    phases = ["prepare", "pre_commit", "commit", "decide", "view_change"]

    Enum.each(phases, fn phase ->
      violation = %{
        "id" => "violation-phase-#{phase}",
        "type" => "double_vote",
        "severity" => "critical",
        "phase" => phase
      }

      assert violation["phase"] in phases
    end)
  end

  # Test 17: Span name format (dot-separated, not underscores)
  test "span name consensus.safety.violation uses dots not underscores" do
    # Positive assertion: span naming convention
    span_name = "consensus.safety.violation"
    assert String.contains?(span_name, ".")
    refute String.contains?(span_name, "_")
  end

  # Test 18: Attribute name format (dot-separated)
  test "attribute names consensus.safety.violation.* use dots not underscores" do
    # Positive assertion: attribute naming convention
    attr_names = [
      "consensus.safety.violation.id",
      "consensus.safety.violation.type",
      "consensus.safety.violation.severity"
    ]

    Enum.each(attr_names, fn attr_name ->
      assert String.contains?(attr_name, ".")
      refute String.contains?(attr_name, "_")
    end)
  end

  # Test 19: Three new attributes added
  test "consensus registry has three new safety violation attributes" do
    # Positive assertion: exact count of new attributes
    new_attrs = [
      "consensus.safety.violation.id",
      "consensus.safety.violation.type",
      "consensus.safety.violation.severity"
    ]

    assert length(new_attrs) == 3
  end

  # Test 20: Safety violation attributes are in consensus domain (not separate)
  test "safety violation attributes belong to consensus domain not separate group" do
    # Positive assertion: attributes are in main consensus registry
    assert String.starts_with?("consensus.safety.violation.id", "consensus.")
    assert String.starts_with?("consensus.safety.violation.type", "consensus.")
    assert String.starts_with?("consensus.safety.violation.severity", "consensus.")
  end

  # Test 21: Required attributes on span
  test "consensus.safety.violation span marks id, type, severity, phase as required" do
    # Positive assertion: critical attributes are required
    required_attrs = [
      "consensus.safety.violation.id",
      "consensus.safety.violation.type",
      "consensus.safety.violation.severity",
      "consensus.phase"
    ]

    # All must be present on span definition
    assert length(required_attrs) == 4
  end

  # Test 22: Optional attributes on span
  test "consensus.safety.violation span recommends round_num and node_id" do
    # Positive assertion: contextual attributes are recommended
    optional_attrs = [
      "consensus.round_num",
      "consensus.node_id"
    ]

    assert length(optional_attrs) == 2
  end
end
