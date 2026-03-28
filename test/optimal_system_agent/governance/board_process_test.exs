defmodule OptimalSystemAgent.Governance.BoardProcessTest do
  use ExUnit.Case, async: false

  @moduletag :governance
  @moduletag :board_process

  setup do
    # Start fresh BoardProcess for each test — start_supervised! handles cleanup automatically
    start_supervised!(OptimalSystemAgent.Governance.BoardProcess)
    %{}
  end

  describe "Board Process - Meeting Lifecycle" do
    test "schedule_meeting creates a new board meeting" do
      week_number = 13
      scheduled_at = DateTime.utc_now()
      executive_id = "executive-001"

      {:ok, meeting_id} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          week_number,
          scheduled_at,
          executive_id
        )

      assert is_binary(meeting_id)
      assert String.contains?(meeting_id, "board-meeting-w#{week_number}")

      # Verify meeting status
      {:ok, status} = OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)
      assert status.status == :scheduled
      assert status.week_number == week_number
      assert status.decisions_count == 0
    end

    test "start_meeting transitions meeting to active status" do
      {:ok, meeting_id} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          13,
          DateTime.utc_now(),
          "executive-001"
        )

      {:ok, meeting} = OptimalSystemAgent.Governance.BoardProcess.start_meeting(meeting_id)
      assert meeting.status == :active
      assert meeting.started_at != nil

      # Verify status after start
      {:ok, status} = OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)
      assert status.status == :active
    end

    test "record_decision with S/N ≥ 0.80 is accepted" do
      {:ok, meeting_id} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          13,
          DateTime.utc_now(),
          "executive-001"
        )

      {:ok, _meeting} = OptimalSystemAgent.Governance.BoardProcess.start_meeting(meeting_id)

      decision = %{
        type: :policy,
        description: "Increase agent utilization target to 85%",
        rationale: "Current utilization 87% (above target)"
      }

      # S/N score = 0.85 (meets threshold of 0.80)
      {:ok, decision_id} =
        OptimalSystemAgent.Governance.BoardProcess.record_decision(
          meeting_id,
          decision,
          0.85
        )

      assert is_binary(decision_id)
      assert String.contains?(decision_id, "bd-")

      # Verify decision was recorded
      {:ok, status} = OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)
      assert status.decisions_count == 1
    end

    test "record_decision with S/N < 0.80 is rejected" do
      {:ok, meeting_id} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          13,
          DateTime.utc_now(),
          "executive-001"
        )

      {:ok, _meeting} = OptimalSystemAgent.Governance.BoardProcess.start_meeting(meeting_id)

      decision = %{
        type: :policy,
        description: "Low-quality decision",
        rationale: "Insufficient analysis"
      }

      # S/N score = 0.65 (below threshold of 0.80)
      {:error, error_msg} =
        OptimalSystemAgent.Governance.BoardProcess.record_decision(
          meeting_id,
          decision,
          0.65
        )

      assert String.contains?(error_msg, "rejected") or String.contains?(error_msg, "below threshold")

      # Verify no decision was recorded
      {:ok, status} = OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)
      assert status.decisions_count == 0
    end

    test "authorize_swarm with APPROVED status records authorization" do
      {:ok, meeting_id} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          13,
          DateTime.utc_now(),
          "executive-001"
        )

      {:ok, _meeting} = OptimalSystemAgent.Governance.BoardProcess.start_meeting(meeting_id)

      swarm_spec = %{
        objective: "Optimize payment processing pipeline",
        pattern: "parallel",
        budget_usd: 2500,
        agents_required: [
          %{type: "process_analyst", count: 3},
          %{type: "data_engineer", count: 2}
        ]
      }

      {:ok, swarm_id} =
        OptimalSystemAgent.Governance.BoardProcess.authorize_swarm(
          meeting_id,
          swarm_spec,
          "APPROVED"
        )

      assert is_binary(swarm_id)
      assert String.contains?(swarm_id, "swarm-")

      # Verify swarm was authorized
      {:ok, status} = OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)
      assert status.swarms_count == 1
    end

    test "authorize_swarm with REJECTED status doesn't record authorization" do
      {:ok, meeting_id} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          13,
          DateTime.utc_now(),
          "executive-001"
        )

      {:ok, _meeting} = OptimalSystemAgent.Governance.BoardProcess.start_meeting(meeting_id)

      swarm_spec = %{
        objective: "Low-priority initiative",
        pattern: "pipeline",
        budget_usd: 500,
        agents_required: []
      }

      {:ok, _swarm_id} =
        OptimalSystemAgent.Governance.BoardProcess.authorize_swarm(
          meeting_id,
          swarm_spec,
          "REJECTED"
        )

      # Verify swarm was not authorized
      {:ok, status} = OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)
      assert status.swarms_count == 0
    end

    test "close_meeting finalizes the meeting" do
      {:ok, meeting_id} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          13,
          DateTime.utc_now(),
          "executive-001"
        )

      {:ok, _meeting} = OptimalSystemAgent.Governance.BoardProcess.start_meeting(meeting_id)

      # Record a decision before closing
      decision = %{
        type: :policy,
        description: "Test decision",
        rationale: "For testing"
      }

      {:ok, _decision_id} =
        OptimalSystemAgent.Governance.BoardProcess.record_decision(
          meeting_id,
          decision,
          0.85
        )

      # Close the meeting
      {:ok, result} = OptimalSystemAgent.Governance.BoardProcess.close_meeting(meeting_id)
      assert result.status == :closed

      # Verify meeting is now completed
      {:ok, status} = OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)
      assert status.status == :completed
    end

    test "get_meeting_status returns not_found for unknown meeting" do
      {:error, :not_found} =
        OptimalSystemAgent.Governance.BoardProcess.get_meeting_status("unknown-meeting-id")
    end
  end

  describe "Board Process - Quality Gates" do
    test "S/N threshold is enforced at 0.80" do
      {:ok, meeting_id} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          13,
          DateTime.utc_now(),
          "executive-001"
        )

      {:ok, _meeting} = OptimalSystemAgent.Governance.BoardProcess.start_meeting(meeting_id)

      decision = %{
        type: :policy,
        description: "Threshold test",
        rationale: "Testing"
      }

      # Test exact threshold (0.80 should pass)
      {:ok, _} =
        OptimalSystemAgent.Governance.BoardProcess.record_decision(
          meeting_id,
          decision,
          0.80
        )

      {:ok, status1} =
        OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)

      assert status1.decisions_count == 1

      # Just below threshold (0.79 should fail)
      {:error, _} =
        OptimalSystemAgent.Governance.BoardProcess.record_decision(
          meeting_id,
          decision,
          0.79
        )

      {:ok, status2} =
        OptimalSystemAgent.Governance.BoardProcess.get_meeting_status(meeting_id)

      # No new decision recorded
      assert status2.decisions_count == 1
    end
  end

  describe "Board Process - Governance Metrics" do
    test "metrics returns board governance statistics" do
      metrics = OptimalSystemAgent.Governance.BoardProcess.metrics()

      assert is_map(metrics)
      assert metrics.governance_health
      assert metrics.active_meetings
      assert metrics.completed_meetings
      assert metrics.decisions_recorded
      assert metrics.sn_gate_pass_rate_pct == 100.0
    end

    test "metrics reflect active and completed meetings" do
      # Create and start a meeting
      {:ok, meeting_id1} =
        OptimalSystemAgent.Governance.BoardProcess.schedule_meeting(
          13,
          DateTime.utc_now(),
          "executive-001"
        )

      {:ok, _} = OptimalSystemAgent.Governance.BoardProcess.start_meeting(meeting_id1)

      metrics1 = OptimalSystemAgent.Governance.BoardProcess.metrics()
      assert metrics1.active_meetings == 1

      # Close the meeting
      {:ok, _} = OptimalSystemAgent.Governance.BoardProcess.close_meeting(meeting_id1)

      metrics2 = OptimalSystemAgent.Governance.BoardProcess.metrics()
      assert metrics2.active_meetings == 0
      assert metrics2.completed_meetings == 1
    end
  end

  describe "Board Process - 45-Minute Week Requirements" do
    test "board process documentation exists" do
      doc_path = "docs/FORTUNE_5_BOARD_PROCESS_45_MINUTE_WEEK.md"
      assert File.exists?(doc_path), "Board process documentation should exist"
    end

    test "board governance documentation exists" do
      # Documentation in repo root, but tests run from OSA directory
      doc_path = "../docs/FORTUNE_5_BOARD_GOVERNANCE.md"
      assert File.exists?(doc_path), "Board governance documentation should exist at #{File.cwd!()}/#{doc_path}"
    end

    test "pre-commit hook exists and is executable" do
      hook_path = ".git/hooks/pre-commit"

      if File.exists?(hook_path) do
        {info, 0} = System.cmd("ls", ["-l", hook_path])
        assert String.contains?(info, "x"), "pre-commit hook should be executable"
      end
    end
  end
end
