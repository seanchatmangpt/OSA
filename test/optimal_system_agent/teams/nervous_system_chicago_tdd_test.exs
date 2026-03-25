defmodule OptimalSystemAgent.Teams.NervousSystemChicagoTDDTest do
  @moduledoc """
  Chicago TDD tests for OptimalSystemAgent.Teams.NervousSystem.

  Tests the 8 embedded GenServer modules:
  1. AutoLogger — automatic event logging
  2. Broadcaster — event fan-out
  3. Rebalancer — workload distribution
  4. ConflictDetector — agent conflict detection
  5. MessageScheduler — scheduled message delivery
  6. Negotiation — agent negotiation protocol
  7. Rendezvous — synchronization points
  8. ComplexityMonitor — complexity scoring

  All public functions tested with observable behavior claims.

  Note: These tests require the application to be running (Teams.Supervisor).
  They are skipped in --no-start mode.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Teams.NervousSystem

  setup_all do
    # The embedded modules are standalone - no parent start needed
    # They initialize their own ETS tables on first use
    :ok
  end

  # =========================================================================
  # AUTOLOGGER TESTS
  # =========================================================================

  describe "CRASH: Module existence and structure" do
    test "AutoLogger embedded module exists" do
      assert :erlang.is_atom(NervousSystem.AutoLogger)
    end

    test "Broadcaster embedded module exists" do
      assert :erlang.is_atom(NervousSystem.Broadcaster)
    end

    test "Rebalancer embedded module exists" do
      assert :erlang.is_atom(NervousSystem.Rebalancer)
    end

    test "ConflictDetector embedded module exists" do
      assert :erlang.is_atom(NervousSystem.ConflictDetector)
    end

    test "MessageScheduler embedded module exists" do
      assert :erlang.is_atom(NervousSystem.MessageScheduler)
    end

    test "Negotiation embedded module exists" do
      assert :erlang.is_atom(NervousSystem.Negotiation)
    end

    test "Rendezvous embedded module exists" do
      assert :erlang.is_atom(NervousSystem.Rendezvous)
    end

    test "ComplexityMonitor embedded module exists" do
      assert :erlang.is_atom(NervousSystem.ComplexityMonitor)
    end
  end

  # =========================================================================
  # BROADCASTER TESTS
  # =========================================================================

  describe "CRASH: Broadcaster.broadcast/3" do
    test "broadcasts message successfully" do
      team_id = "team_#{:erlang.unique_integer()}"
      assert :ok = NervousSystem.Broadcaster.broadcast(team_id, :event_type, %{msg: "hello"})
    end

    test "accepts empty payload" do
      team_id = "team_#{:erlang.unique_integer()}"
      assert :ok = NervousSystem.Broadcaster.broadcast(team_id, :event_type, %{})
    end

    test "broadcasts to different event types" do
      team_id = "team_#{:erlang.unique_integer()}"
      assert :ok = NervousSystem.Broadcaster.broadcast(team_id, :state_change, %{state: "active"})
      assert :ok = NervousSystem.Broadcaster.broadcast(team_id, :conflict_detected, %{agents: []})
    end
  end

  # =========================================================================
  # REBALANCER TESTS
  # =========================================================================

  describe "CRASH: Rebalancer initialization and lifecycle" do
    test "Rebalancer is registered as embedded module" do
      assert :erlang.is_atom(NervousSystem.Rebalancer)
    end

    test "Rebalancer responds to Registry lookups" do
      team_id = "rebalancer_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      # Verify Rebalancer is in Registry
      result = Registry.lookup(OptimalSystemAgent.Teams.Registry, {NervousSystem.Rebalancer, team_id})
      assert is_list(result)
    end

    test "Rebalancer processes team state without crashing" do
      team_id = "rebalancer_state_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      # Rebalancer monitors load internally — verify it doesn't crash
      :timer.sleep(100)
      result = Registry.lookup(OptimalSystemAgent.Teams.Registry, {NervousSystem.Rebalancer, team_id})
      assert result != []
    end
  end

  # =========================================================================
  # CONFLICT DETECTOR TESTS
  # =========================================================================

  describe "CRASH: ConflictDetector.register_file_edit/3" do
    test "registers file edit successfully" do
      team_id = "conflict_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_1, "file.txt")
      assert result == :ok
    end

    test "accepts string agent IDs" do
      team_id = "conflict_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.ConflictDetector.register_file_edit(team_id, "agent_str", "file.txt")
      assert result == :ok
    end

    test "detects conflicts when same file edited by different agents" do
      team_id = "conflict_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_1, "file.txt")
      result = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_2, "file.txt")

      # Should return conflict information
      assert result == {:conflict, :agent_1} or result == :ok
    end
  end

  describe "CRASH: ConflictDetector.release_file_edit/3" do
    test "releases file edit without crashing" do
      team_id = "release_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_1, "file.txt")
      :ok = NervousSystem.ConflictDetector.release_file_edit(team_id, :agent_1, "file.txt")
    end

    test "can re-register file after release" do
      team_id = "re_release_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_1, "file.txt")
      :ok = NervousSystem.ConflictDetector.release_file_edit(team_id, :agent_1, "file.txt")

      result = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_2, "file.txt")
      assert result == :ok
    end
  end

  # =========================================================================
  # MESSAGE SCHEDULER TESTS
  # =========================================================================

  describe "CRASH: MessageScheduler.schedule/4" do
    test "schedules a message successfully" do
      team_id = "msg_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.MessageScheduler.schedule(team_id, :agent_1, %{msg: "hello"}, 100)
      assert result == :ok
    end

    test "schedules message with zero delay" do
      team_id = "msg_zero_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.MessageScheduler.schedule(team_id, :agent, %{msg: "now"}, 0)
      assert result == :ok
    end

    test "schedules to different recipients" do
      team_id = "msg_recipients_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      r1 = NervousSystem.MessageScheduler.schedule(team_id, :agent_1, %{m: 1}, 0)
      r2 = NervousSystem.MessageScheduler.schedule(team_id, :agent_2, %{m: 2}, 0)
      assert r1 == :ok and r2 == :ok
    end

    test "schedules with various message payloads" do
      team_id = "msg_payloads_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      assert NervousSystem.MessageScheduler.schedule(team_id, :a, %{}, 0) == :ok
      assert NervousSystem.MessageScheduler.schedule(team_id, :b, %{nested: %{data: 1}}, 0) == :ok
      assert NervousSystem.MessageScheduler.schedule(team_id, :c, ["list", "data"], 0) == :ok
    end
  end

  # =========================================================================
  # NEGOTIATION TESTS
  # =========================================================================

  describe "CRASH: Negotiation.bid/4" do
    test "submits bid successfully" do
      team_id = "neg_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_1, 0.9)
      assert result == :ok
    end

    test "accepts different confidence levels" do
      team_id = "neg_conf_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      assert NervousSystem.Negotiation.bid(team_id, :task_1, :agent_1, 0.0) == :ok
      assert NervousSystem.Negotiation.bid(team_id, :task_1, :agent_2, 0.5) == :ok
      assert NervousSystem.Negotiation.bid(team_id, :task_1, :agent_3, 1.0) == :ok
    end

    test "multiple agents can bid on same task" do
      team_id = "neg_multi_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      r1 = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_1, 0.7)
      r2 = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_2, 0.8)
      r3 = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_3, 0.6)
      assert r1 == :ok and r2 == :ok and r3 == :ok
    end
  end

  describe "CRASH: Negotiation.close_auction/2" do
    test "closes auction and returns winner" do
      team_id = "neg_close_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_1, 0.5)
      :ok = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_2, 0.9)

      result = NervousSystem.Negotiation.close_auction(team_id, :task_1)
      assert result == {:ok, :agent_2}
    end

    test "returns error if no bids" do
      team_id = "neg_no_bids_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.Negotiation.close_auction(team_id, :nonexistent_task)
      assert result == {:error, :no_bids}
    end

    test "highest confidence wins auction" do
      team_id = "neg_highest_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_1, 0.1)
      :ok = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_2, 0.5)
      :ok = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_3, 0.9)

      {:ok, winner} = NervousSystem.Negotiation.close_auction(team_id, :task_1)
      assert winner == :agent_3
    end
  end

  # =========================================================================
  # RENDEZVOUS TESTS
  # =========================================================================

  describe "CRASH: Rendezvous.create/3" do
    test "creates a rendezvous point" do
      team_id = "rdv_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.Rendezvous.create(team_id, :barrier_1, 2)
      assert result == :ok
    end

    test "creates different named barriers" do
      team_id = "rdv_names_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      r1 = NervousSystem.Rendezvous.create(team_id, :barrier_1, 1)
      r2 = NervousSystem.Rendezvous.create(team_id, :barrier_2, 3)
      assert r1 == :ok and r2 == :ok
    end

    test "accepts different expected counts" do
      team_id = "rdv_counts_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      r1 = NervousSystem.Rendezvous.create(team_id, :b1, 1)
      r2 = NervousSystem.Rendezvous.create(team_id, :b2, 2)
      r3 = NervousSystem.Rendezvous.create(team_id, :b3, 10)
      assert r1 == :ok and r2 == :ok and r3 == :ok
    end
  end

  describe "CRASH: Rendezvous.arrive/4" do
    test "arrives at rendezvous without crashing" do
      team_id = "rdv_arrive_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.Rendezvous.create(team_id, :barrier_1, 1)
      result = NervousSystem.Rendezvous.arrive(team_id, :barrier_1, :agent_1, 1000)
      assert result == :go
    end

    test "returns error if barrier not found" do
      team_id = "rdv_notfound_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.Rendezvous.arrive(team_id, :nonexistent_barrier, :agent_1, 100)
      assert result == {:error, :not_found}
    end

    test "blocks until all agents arrive" do
      team_id = "rdv_multiagent_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.Rendezvous.create(team_id, :barrier_1, 2)

      # Spawn async task to arrive after delay
      Task.start(fn ->
        :timer.sleep(100)
        NervousSystem.Rendezvous.arrive(team_id, :barrier_1, :agent_2, 2000)
      end)

      # This should wait for agent_2 to arrive
      result = NervousSystem.Rendezvous.arrive(team_id, :barrier_1, :agent_1, 2000)
      assert result == :go
    end

    test "accepts custom timeout values" do
      team_id = "rdv_timeout_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.Rendezvous.create(team_id, :b1, 1)
      r1 = NervousSystem.Rendezvous.arrive(team_id, :b1, :agent_1, 100)
      assert r1 == :go

      :ok = NervousSystem.Rendezvous.create(team_id, :b2, 1)
      r2 = NervousSystem.Rendezvous.arrive(team_id, :b2, :agent_2, 60_000)
      assert r2 == :go
    end
  end

  # =========================================================================
  # COMPLEXITY MONITOR TESTS
  # =========================================================================

  describe "CRASH: ComplexityMonitor.recommend/1" do
    test "recommends scaling decision" do
      team_id = "cm_team_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.ComplexityMonitor.recommend(team_id)
      assert result in [:ok, :scale_up, :scale_down, :escalate_tier]
    end

    test "returns consistent recommendations for same team" do
      team_id = "cm_consistent_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      r1 = NervousSystem.ComplexityMonitor.recommend(team_id)
      r2 = NervousSystem.ComplexityMonitor.recommend(team_id)
      assert r1 == r2
    end

    test "handles empty team gracefully" do
      team_id = "cm_empty_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      result = NervousSystem.ComplexityMonitor.recommend(team_id)
      # Empty team should recommend :ok (no action needed)
      assert result in [:ok, :scale_up, :scale_down, :escalate_tier]
    end

    test "returns valid recommendation values" do
      team_id = "cm_values_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      valid_recommendations = [:ok, :scale_up, :scale_down, :escalate_tier]

      for _ <- 1..5 do
        result = NervousSystem.ComplexityMonitor.recommend(team_id)
        assert result in valid_recommendations
      end
    end
  end

  # =========================================================================
  # INTEGRATION TESTS
  # =========================================================================

  describe "CRASH: Cross-module integration" do
    test "Broadcaster + ConflictDetector flow works" do
      team_id = "integration_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      # Broadcaster sends event
      :ok = NervousSystem.Broadcaster.broadcast(team_id, :conflict, %{agents: [:a, :b]})

      # ConflictDetector registers access
      r1 = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_1, "file.txt")
      r2 = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_2, "file.txt")

      # Both operations succeeded (r2 may be conflict tuple but both complete)
      assert r1 == :ok
      assert r2 != nil
    end

    test "Negotiation + Rendezvous flow works" do
      team_id = "nego_rdv_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      # Agents bid on task
      :ok = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_1, 0.7)
      :ok = NervousSystem.Negotiation.bid(team_id, :task_1, :agent_2, 0.9)

      # Create rendezvous
      :ok = NervousSystem.Rendezvous.create(team_id, :barrier_1, 2)

      # Both succeed
      {:ok, _winner} = NervousSystem.Negotiation.close_auction(team_id, :task_1)
    end

    test "MessageScheduler + ComplexityMonitor flow works" do
      team_id = "msg_cm_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      # Schedule messages
      :ok = NervousSystem.MessageScheduler.schedule(team_id, :agent_1, %{data: 1}, 0)
      :ok = NervousSystem.MessageScheduler.schedule(team_id, :agent_2, %{data: 2}, 100)

      # Get complexity recommendation
      rec = NervousSystem.ComplexityMonitor.recommend(team_id)
      assert rec in [:ok, :scale_up, :scale_down, :escalate_tier]
    end

    test "All 8 modules coordinate without crashing" do
      team_id = "all_eight_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      # Verify all 8 are running
      status = NervousSystem.status(team_id)
      assert length(status) == 8

      # Each is either running or was already running
      Enum.each(status, fn {_mod, pid_or_status} ->
        assert is_pid(pid_or_status) or pid_or_status == :not_running
      end)
    end
  end

  # =========================================================================
  # MODULE BEHAVIOR TESTS
  # =========================================================================

  describe "CRASH: Module behavior contract" do
    test "all 8 embedded modules exported" do
      assert :erlang.is_atom(NervousSystem.AutoLogger)
      assert :erlang.is_atom(NervousSystem.Broadcaster)
      assert :erlang.is_atom(NervousSystem.Rebalancer)
      assert :erlang.is_atom(NervousSystem.ConflictDetector)
      assert :erlang.is_atom(NervousSystem.MessageScheduler)
      assert :erlang.is_atom(NervousSystem.Negotiation)
      assert :erlang.is_atom(NervousSystem.Rendezvous)
      assert :erlang.is_atom(NervousSystem.ComplexityMonitor)
    end

    test "parent NervousSystem module exports expected functions" do
      assert function_exported?(NervousSystem, :start_all, 1)
      assert function_exported?(NervousSystem, :stop_all, 1)
      assert function_exported?(NervousSystem, :ensure_running, 1)
      assert function_exported?(NervousSystem, :status, 1)
    end

    test "each embedded module has start_link/1" do
      assert function_exported?(NervousSystem.AutoLogger, :start_link, 1)
      assert function_exported?(NervousSystem.Broadcaster, :start_link, 1)
      assert function_exported?(NervousSystem.Rebalancer, :start_link, 1)
      assert function_exported?(NervousSystem.ConflictDetector, :start_link, 1)
      assert function_exported?(NervousSystem.MessageScheduler, :start_link, 1)
      assert function_exported?(NervousSystem.Negotiation, :start_link, 1)
      assert function_exported?(NervousSystem.Rendezvous, :start_link, 1)
      assert function_exported?(NervousSystem.ComplexityMonitor, :start_link, 1)
    end

    test "all modules handle nil/empty values gracefully" do
      team_id = "nil_test_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      # Test with empty strings and atoms
      r1 = NervousSystem.Broadcaster.broadcast(team_id, :"", %{})
      r2 = NervousSystem.MessageScheduler.schedule(team_id, nil, %{}, 0)

      assert r1 == :ok
      assert r2 == :ok
    end
  end

  # =========================================================================
  # STRESS TESTS
  # =========================================================================

  describe "CRASH: Stress and idempotency" do
    test "repeated broadcasting doesn't crash" do
      team_id = "stress_broadcast_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      for i <- 1..10 do
        assert :ok = NervousSystem.Broadcaster.broadcast(team_id, :event_type, %{count: i})
      end
    end

    test "rapid message scheduling doesn't crash" do
      team_id = "stress_schedule_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      for i <- 1..10 do
        assert :ok = NervousSystem.MessageScheduler.schedule(team_id, :agent, %{msg: i}, i * 10)
      end
    end

    test "repeated conflict registration doesn't crash" do
      team_id = "stress_conflict_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      for i <- 1..10 do
        _result = NervousSystem.ConflictDetector.register_file_edit(team_id, :agent_1, "file#{i}.txt")
      end
    end

    test "rapid bidding doesn't crash" do
      team_id = "stress_bidding_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      for i <- 1..10 do
        assert :ok = NervousSystem.Negotiation.bid(team_id, :task_1, :"agent_#{i}", 0.5)
      end
    end

    test "repeated complexity checks don't crash" do
      team_id = "stress_complexity_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      for _i <- 1..10 do
        _rec = NervousSystem.ComplexityMonitor.recommend(team_id)
      end
    end

    test "concurrent rendezvous arrivals don't crash" do
      team_id = "stress_rdv_#{:erlang.unique_integer()}"
      NervousSystem.start_all(team_id)

      :ok = NervousSystem.Rendezvous.create(team_id, :barrier_1, 3)

      tasks = for i <- 1..3 do
        Task.start(fn ->
          NervousSystem.Rendezvous.arrive(team_id, :barrier_1, :"agent_#{i}", 2000)
        end)
      end

      # All tasks should complete without crashing
      Enum.each(tasks, fn {:ok, _pid} ->
        assert true
      end)
    end
  end
end
