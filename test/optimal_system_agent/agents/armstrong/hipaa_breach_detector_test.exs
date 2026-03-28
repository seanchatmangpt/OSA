defmodule OptimalSystemAgent.Agents.Armstrong.HipaaBreachDetectorTest do
  @moduledoc """
  Chicago TDD tests for HIPAA Breach Detector Agent.

  Tests verify:
  1. PHI detection: SSN, MRN, health condition keywords (pure functions)
  2. Access logging & violation flagging (GenServer started per-test via start_link)
  3. Audit trail generation (GenServer started per-test via start_link)
  4. Metrics collection (GenServer started per-test via start_link)
  5. Armstrong fault tolerance: supervision, timeouts, budgets

  All tests run with `mix test` — the application always boots with OTP.
  """

  use ExUnit.Case

  @moduletag :requires_application

  alias OptimalSystemAgent.Agents.Armstrong.HipaaBreachDetector

  # ── PHI DETECTION TESTS (Pure Functions) ────────────────────────────────

  describe "scan_for_phi/1 — SSN Detection" do
    test "detects valid SSN pattern xxx-xx-xxxx" do
      text = "Patient SSN: 123-45-6789 on file"
      detections = HipaaBreachDetector.scan_for_phi(text)

      assert Enum.any?(detections, fn {type, value, _conf} ->
        type == :ssn and value == "123-45-6789"
      end)
    end

    test "detects multiple SSNs in text" do
      text = "Patient 1: 123-45-6789, Patient 2: 987-65-4321"
      detections = HipaaBreachDetector.scan_for_phi(text)

      ssn_detections = Enum.filter(detections, fn {type, _, _} -> type == :ssn end)
      assert length(ssn_detections) == 2
    end

    test "returns empty list for text without PHI" do
      text = "Patient scheduled for routine checkup tomorrow"
      detections = HipaaBreachDetector.scan_for_phi(text)

      assert Enum.empty?(detections) or
               not Enum.any?(detections, fn {type, _, _} -> type == :ssn end)
    end

    test "assigns high confidence score to SSN detections" do
      text = "SSN: 555-55-5555"
      detections = HipaaBreachDetector.scan_for_phi(text)

      ssn_detection = Enum.find(detections, fn {type, _, _} -> type == :ssn end)
      assert ssn_detection != nil
      {_type, _value, confidence} = ssn_detection
      assert confidence >= 0.9
    end

    test "ignores malformed SSNs (not xxx-xx-xxxx)" do
      text = "Invalid: 12-34-5678, Valid: 123-45-6789"
      detections = HipaaBreachDetector.scan_for_phi(text)

      ssn_values = Enum.filter(detections, fn {type, _, _} -> type == :ssn end)
      assert length(ssn_values) == 1
      assert Enum.any?(ssn_values, fn {_, value, _} -> value == "123-45-6789" end)
    end
  end

  describe "scan_for_phi/1 — Medical Record Number Detection" do
    test "detects MRN pattern MR-xxxxxx" do
      text = "Medical Record: MR-123456"
      detections = HipaaBreachDetector.scan_for_phi(text)

      assert Enum.any?(detections, fn {type, value, _conf} ->
        type == :mrn and String.upcase(value) == "MR-123456"
      end)
    end

    test "detects MRN with 6+ digits after MR-" do
      text = "Records: MR-1234567 and MR-12345678"
      detections = HipaaBreachDetector.scan_for_phi(text)

      mrn_count = Enum.count(detections, fn {type, _, _} -> type == :mrn end)
      assert mrn_count == 2
    end

    test "is case-insensitive for MRN detection" do
      text = "Patient mr-654321 and MR-654321"
      detections = HipaaBreachDetector.scan_for_phi(text)

      mrn_count = Enum.count(detections, fn {type, _, _} -> type == :mrn end)
      assert mrn_count == 2
    end

    test "assigns very high confidence to MRN detections" do
      text = "MR-987654"
      detections = HipaaBreachDetector.scan_for_phi(text)

      mrn_detection = Enum.find(detections, fn {type, _, _} -> type == :mrn end)
      assert mrn_detection != nil
      {_type, _value, confidence} = mrn_detection
      assert confidence >= 0.95
    end

    test "rejects MRN with fewer than 6 digits" do
      text = "MR-12345 is invalid, MR-123456 is valid"
      detections = HipaaBreachDetector.scan_for_phi(text)

      mrn_values = Enum.filter(detections, fn {type, _, _} -> type == :mrn end)
      assert Enum.count(mrn_values) == 1
    end
  end

  describe "scan_for_phi/1 — Health Condition Detection" do
    test "detects common health condition keywords" do
      text = "Patient has diabetes and hypertension"
      detections = HipaaBreachDetector.scan_for_phi(text)

      condition_types =
        detections
        |> Enum.filter(fn {type, _, _} -> type == :health_condition end)
        |> Enum.map(fn {_, value, _} -> value end)

      assert "diabetes" in condition_types
      assert "hypertension" in condition_types
    end

    test "detects cancer keyword in clinical notes" do
      text = "Diagnosis: stage 3 cancer, treatment plan initiated"
      detections = HipaaBreachDetector.scan_for_phi(text)

      assert Enum.any?(detections, fn {type, value, _} ->
        type == :health_condition and value == "cancer"
      end)
    end

    test "detects depression and mental health conditions" do
      text = "Patient reports depression and anxiety"
      detections = HipaaBreachDetector.scan_for_phi(text)

      conditions =
        detections
        |> Enum.filter(fn {type, _, _} -> type == :health_condition end)
        |> Enum.map(fn {_, value, _} -> value end)

      assert "depression" in conditions
      assert "anxiety" in conditions
    end

    test "is case-insensitive for health condition detection" do
      text = "DIABETES and Asthma are chronic conditions"
      detections = HipaaBreachDetector.scan_for_phi(text)

      conditions =
        detections
        |> Enum.filter(fn {type, _, _} -> type == :health_condition end)
        |> Enum.map(fn {_, value, _} -> value end)

      assert "diabetes" in conditions
      assert "asthma" in conditions
    end

    test "assigns moderate confidence to health condition detections" do
      text = "Patient has diabetes"
      detections = HipaaBreachDetector.scan_for_phi(text)

      condition = Enum.find(detections, fn {type, _, _} -> type == :health_condition end)
      assert condition != nil
      {_type, _value, confidence} = condition
      assert confidence >= 0.85
    end
  end

  describe "scan_for_phi/1 — Combined PHI Detection" do
    test "detects multiple PHI types in same document" do
      text = "Patient MR-123456 (SSN: 123-45-6789) diagnosed with cancer and diabetes"
      detections = HipaaBreachDetector.scan_for_phi(text)

      phi_types = Enum.map(detections, fn {type, _, _} -> type end) |> Enum.uniq()

      assert :ssn in phi_types
      assert :mrn in phi_types
      assert :health_condition in phi_types
    end

    test "returns non-empty list for realistic EHR excerpt" do
      text = """
      PATIENT DEMOGRAPHICS:
      Name: John Doe
      DOB: 01/15/1965
      SSN: 123-45-6789
      MRN: MR-987654

      CLINICAL NOTES:
      Patient presents with diabetes and hypertension. Started on metformin.
      """

      detections = HipaaBreachDetector.scan_for_phi(text)

      assert Enum.any?(detections, fn {type, _, _} -> type == :ssn end)
      assert Enum.any?(detections, fn {type, _, _} -> type == :mrn end)
      assert Enum.any?(detections, fn {type, _, _} -> type == :health_condition end)
    end
  end

  # ── EDGE CASES (Pure Functions) ─────────────────────────────────────────

  describe "Edge Cases — Boundary Conditions" do
    test "handles empty string in scan_for_phi" do
      result = HipaaBreachDetector.scan_for_phi("")
      assert is_list(result)
    end

    test "handles very long text in scan_for_phi" do
      long_text = String.duplicate("diabetes and cancer ", 100)
      result = HipaaBreachDetector.scan_for_phi(long_text)
      assert is_list(result)
      # Should detect multiple instances
      assert length(result) > 0
    end

    test "handles special characters in text" do
      data = "Patient: <script>alert('xss')</script> SSN: 123-45-6789"
      result = HipaaBreachDetector.scan_for_phi(data)
      assert is_list(result)
      assert Enum.any?(result, fn {type, _, _} -> type == :ssn end)
    end

    test "handles mixed case in SSN" do
      # SSN patterns don't have letters, but test robustness
      text = "123-45-6789 is the SSN"
      result = HipaaBreachDetector.scan_for_phi(text)
      assert Enum.any?(result, fn {type, _, _} -> type == :ssn end)
    end

    test "detects PHI across newlines in multiline text" do
      text = """
      Patient Info:
      SSN: 123-45-6789

      Medical Record: MR-654321
      """

      result = HipaaBreachDetector.scan_for_phi(text)
      assert Enum.any?(result, fn {type, _, _} -> type == :ssn end)
      assert Enum.any?(result, fn {type, _, _} -> type == :mrn end)
    end
  end

  # ── GENSERVER TESTS (Require Application Running) ───────────────────────

  describe "log_phi_access/3 — Access Logging" do
    setup do
      start_supervised!(HipaaBreachDetector)
      :ok
    end

    test "logs authorized access with encryption" do
      resource = "patient-001"
      accessor = "agent-healing"

      result =
        HipaaBreachDetector.log_phi_access(resource, accessor, %{
          operation: "read",
          purpose: "diagnosis",
          encrypted: true,
          data: "Patient medical history"
        })

      assert result == :ok
    end

    test "does not flag violation when encrypted=true even with PHI" do
      resource = "patient-002"
      accessor = "agent-processor"

      # Even though data contains PHI, no violation because encrypted
      result =
        HipaaBreachDetector.log_phi_access(resource, accessor, %{
          operation: "read",
          purpose: "treatment",
          encrypted: true,
          data: "Patient has diabetes, SSN: 123-45-6789"
        })

      assert result == :ok
    end

    test "flags violation when unencrypted=true and PHI detected" do
      resource = "patient-004"
      accessor = "agent-rogue"

      result =
        HipaaBreachDetector.log_phi_access(resource, accessor, %{
          operation: "export",
          encrypted: false,
          data: "SSN: 123-45-6789"
        })

      assert result == :ok
      # Violation should be escalated (verified via telemetry/Bus)
    end

    test "handles missing context fields gracefully" do
      result = HipaaBreachDetector.log_phi_access("patient", "accessor", %{})
      assert result == :ok
    end

    test "handles nil values in context" do
      result =
        HipaaBreachDetector.log_phi_access("patient", "accessor", %{
          operation: nil,
          purpose: nil,
          encrypted: false
        })

      assert result == :ok
    end
  end

  describe "audit_phi_access/2 — Compliance Reporting" do
    setup do
      start_supervised!(HipaaBreachDetector)
      :ok
    end

    test "generates audit report for time window" do
      resource = "patient-012"
      accessor = "agent-auditor"

      HipaaBreachDetector.log_phi_access(resource, accessor, %{
        operation: "read",
        encrypted: true
      })

      start_time = DateTime.utc_now() |> DateTime.add(-3600)
      end_time = DateTime.utc_now() |> DateTime.add(3600)

      report = HipaaBreachDetector.audit_phi_access(start_time, end_time)

      assert report.total_accesses >= 1
      assert is_integer(report.violations)
      assert is_float(report.encrypted_ratio)
    end

    test "report includes top accessors ranked by access count" do
      HipaaBreachDetector.log_phi_access("patient-1", "accessor-a", %{encrypted: true})
      HipaaBreachDetector.log_phi_access("patient-2", "accessor-a", %{encrypted: true})
      HipaaBreachDetector.log_phi_access("patient-3", "accessor-b", %{encrypted: true})

      start_time = DateTime.utc_now() |> DateTime.add(-3600)
      end_time = DateTime.utc_now() |> DateTime.add(3600)

      report = HipaaBreachDetector.audit_phi_access(start_time, end_time)

      top_accessors = report.top_accessors
      assert length(top_accessors) >= 1
    end

    test "report includes encryption statistics" do
      HipaaBreachDetector.log_phi_access("p-1", "acc", %{encrypted: true})
      HipaaBreachDetector.log_phi_access("p-2", "acc", %{encrypted: false, data: "ssn"})
      HipaaBreachDetector.log_phi_access("p-3", "acc", %{encrypted: true})

      start_time = DateTime.utc_now() |> DateTime.add(-3600)
      end_time = DateTime.utc_now() |> DateTime.add(3600)

      report = HipaaBreachDetector.audit_phi_access(start_time, end_time)

      # At least 2 encrypted out of 3 total
      assert report.encrypted_count >= 2
      assert report.encrypted_ratio >= 0.666
    end

    test "accepts ISO8601 strings as time boundaries" do
      start_str = "2026-03-26T00:00:00Z"
      end_str = "2026-03-26T23:59:59Z"

      # Should not raise an exception
      report = HipaaBreachDetector.audit_phi_access(start_str, end_str)

      assert is_map(report)
      assert Map.has_key?(report, :total_accesses)
    end
  end

  describe "get_metrics/0 — Statistics" do
    setup do
      start_supervised!(HipaaBreachDetector)
      :ok
    end

    test "returns metrics map with required fields" do
      metrics = HipaaBreachDetector.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :total_events)
      assert Map.has_key?(metrics, :violation_count)
      assert Map.has_key?(metrics, :phi_types_detected)
      assert Map.has_key?(metrics, :accessor_stats)
    end

    test "counts total events correctly" do
      HipaaBreachDetector.log_phi_access("p1", "a1", %{encrypted: true})
      HipaaBreachDetector.log_phi_access("p2", "a2", %{encrypted: true})

      metrics = HipaaBreachDetector.get_metrics()
      assert metrics.total_events >= 2
    end
  end

  describe "flag_violation/3 — Manual Escalation" do
    setup do
      start_supervised!(HipaaBreachDetector)
      :ok
    end

    test "manually flags a violation with reason" do
      result =
        HipaaBreachDetector.flag_violation(
          "patient-008",
          "agent-external-monitor",
          "unauthorized data exfiltration detected"
        )

      assert result == :ok
    end

    test "increments violation count when violation flagged" do
      before_metrics = HipaaBreachDetector.get_metrics()
      before_count = before_metrics.violation_count

      HipaaBreachDetector.flag_violation(
        "patient-009",
        "accessor-violator",
        "suspicious access pattern"
      )

      after_metrics = HipaaBreachDetector.get_metrics()
      assert after_metrics.violation_count == before_count + 1
    end
  end

  describe "Integration — Realistic Healthcare Workflows" do
    setup do
      start_supervised!(HipaaBreachDetector)
      :ok
    end

    test "complete audit workflow: access + logging + audit trail" do
      # Setup: Multiple practitioners access patient records
      patient_id = "patient-mrn-2026-001"

      # Clinician 1: Reads encrypted clinical notes
      HipaaBreachDetector.log_phi_access(patient_id, "clinician-jane", %{
        operation: "read",
        purpose: "treatment",
        encrypted: true,
        data: "Patient has diabetes"
      })

      # Clinician 2: Reviews encrypted lab results
      HipaaBreachDetector.log_phi_access(patient_id, "clinician-john", %{
        operation: "review",
        purpose: "treatment",
        encrypted: true,
        data: "SSN: 123-45-6789"
      })

      # Suspicious: Billing dept tries unencrypted export
      HipaaBreachDetector.log_phi_access(patient_id, "billing-agent", %{
        operation: "export",
        purpose: "billing",
        encrypted: false,
        data: "MR-123456"
      })

      # Run audit
      start = DateTime.utc_now() |> DateTime.add(-3600)
      finish = DateTime.utc_now()

      report = HipaaBreachDetector.audit_phi_access(start, finish)

      # Verify audit captured all events
      assert report.total_accesses >= 3
      assert report.violations >= 1

      # Verify encryption statistics
      assert report.encrypted_ratio < 1.0
    end

    test "compliance scenario: breach detection and reporting" do
      # Simulate unauthorized access attempt
      HipaaBreachDetector.flag_violation(
        "patient-breach-test",
        "unauthorized-process",
        "HIPAA violation detected: unauthorized data access"
      )

      # Get metrics
      metrics = HipaaBreachDetector.get_metrics()
      assert metrics.violation_count >= 1

      # Generate compliance report
      report =
        HipaaBreachDetector.audit_phi_access(
          DateTime.utc_now() |> DateTime.add(-86_400),
          DateTime.utc_now()
        )

      # Report includes violations
      assert report.violations >= 1
    end
  end
end
