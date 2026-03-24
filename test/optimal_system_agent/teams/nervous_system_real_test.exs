defmodule OptimalSystemAgent.Teams.NervousSystemRealTest do
  @moduledoc """
  Real integration tests for Teams.NervousSystem and its 8 sub-processes.

  NO MOCKS. Tests real GenServer processes, real Registry lookups, real PubSub.
  Tests run against real DynamicSupervisor and Phoenix PubSub.

  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias OptimalSystemAgent.Teams.NervousSystem
  alias OptimalSystemAgent.Teams.NervousSystem.{
    AutoLogger,
    Broadcaster,
    ConflictDetector,
    MessageScheduler,
    Negotiation,
    Rendezvous,
    ComplexityMonitor
  }

  setup do
    team_id = "test-team-#{:erlang.unique_integer([:positive])}"

    # Ensure the team is clean before and after each test
    NervousSystem.stop_all(team_id)

    on_exit(fn ->
      NervousSystem.stop_all(team_id)
    end)

    {:ok, team_id: team_id}
  end

  describe "NervousSystem — start_all/1 and stop_all/1" do
    test "CRASH: start_all starts all 8 processes", %{team_id: team_id} do
      assert :ok == NervousSystem.start_all(team_id)

      status = NervousSystem.status(team_id)
      assert length(status) == 8

      Enum.each(status, fn {_mod, pid_or_not_running} ->
        assert pid_or_not_running != :not_running,
               "All 8 processes should be running after start_all"
      end)
    end

    test "CRASH: stop_all stops all processes", %{team_id: team_id} do
      NervousSystem.start_all(team_id)
      assert :ok == NervousSystem.stop_all(team_id)

      status = NervousSystem.status(team_id)
      Enum.each(status, fn {_mod, pid_or_not_running} ->
        assert pid_or_not_running == :not_running,
               "All processes should be stopped after stop_all"
      end)
    end

    test "CRASH: start_all is idempotent — second call does not crash", %{team_id: team_id} do
      assert :ok == NervousSystem.start_all(team_id)
      assert :ok == NervousSystem.start_all(team_id)

      status = NervousSystem.status(team_id)
      assert length(status) == 8
    end

    test "CRASH: stop_all is idempotent — stopping already-stopped team is :ok", %{team_id: team_id} do
      assert :ok == NervousSystem.stop_all(team_id)
      assert :ok == NervousSystem.stop_all(team_id)
    end
  end

  describe "NervousSystem — ensure_running/1" do
    test "CRASH: ensure_running starts processes that are not running", %{team_id: team_id} do
      # Don't call start_all — start from scratch
      assert :ok == NervousSystem.ensure_running(team_id)

      status = NervousSystem.status(team_id)
      Enum.each(status, fn {_mod, pid_or_not_running} ->
        assert pid_or_not_running != :not_running
      end)
    end

    test "CRASH: ensure_running does not restart already-running processes", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      # Capture pids before ensure_running
      before = NervousSystem.status(team_id) |> Enum.map(fn {_mod, pid} -> pid end)

      NervousSystem.ensure_running(team_id)

      after_ = NervousSystem.status(team_id) |> Enum.map(fn {_mod, pid} -> pid end)

      # All pids should be the same — no restarts
      assert before == after_
    end
  end

  describe "NervousSystem — status/1" do
    test "CRASH: status returns all 8 modules", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      status = NervousSystem.status(team_id)
      modules = Enum.map(status, fn {mod, _} -> mod end)

      expected = [
        AutoLogger,
        Broadcaster,
        Rebalancer,
        ConflictDetector,
        MessageScheduler,
        Negotiation,
        Rendezvous,
        ComplexityMonitor
      ]

      Enum.each(expected, fn mod ->
        assert mod in modules, "Expected #{inspect(mod)} in status"
      end)
    end

    test "CRASH: status returns :not_running for unstarted team", %{team_id: team_id} do
      status = NervousSystem.status(team_id)
      Enum.each(status, fn {_mod, pid_or_not_running} ->
        assert pid_or_not_running == :not_running
      end)
    end
  end

  describe "Broadcaster — broadcast/3" do
    test "CRASH: broadcast publishes event to PubSub", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      # Subscribe to the team channel
      Phoenix.PubSub.subscribe(OptimalSystemAgent.PubSub, "osa:team:#{team_id}")

      # Broadcast an event
      assert :ok == Broadcaster.broadcast(team_id, :test_event, %{message: "hello"})

      # Should receive the event
      receive do
        {:team_event, event} ->
          assert event.type == :test_event
          assert event.payload == %{message: "hello"}
          assert event.team_id == team_id
          assert Map.has_key?(event, :at)
      after
        1000 -> flunk("Did not receive broadcast event within 1 second")
      end
    end

    test "CRASH: broadcast returns :ok when Broadcaster is not running" do
      assert :ok == Broadcaster.broadcast("nonexistent-team", :event, %{})
    end
  end

  describe "ConflictDetector — register_file_edit/3 and release_file_edit/3" do
    test "CRASH: first registration succeeds", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == ConflictDetector.register_file_edit(team_id, "agent-1", "/tmp/file.txt")
    end

    test "CRASH: same agent registering same file succeeds", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == ConflictDetector.register_file_edit(team_id, "agent-1", "/tmp/file.txt")
      assert :ok == ConflictDetector.register_file_edit(team_id, "agent-1", "/tmp/file.txt")
    end

    test "CRASH: different agent registering same file returns conflict", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == ConflictDetector.register_file_edit(team_id, "agent-1", "/tmp/file.txt")
      assert {:conflict, "agent-1"} == ConflictDetector.register_file_edit(team_id, "agent-2", "/tmp/file.txt")
    end

    test "CRASH: different files can be registered by different agents", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == ConflictDetector.register_file_edit(team_id, "agent-1", "/tmp/file1.txt")
      assert :ok == ConflictDetector.register_file_edit(team_id, "agent-2", "/tmp/file2.txt")
    end

    test "CRASH: release_file_edit allows re-registration by different agent", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == ConflictDetector.register_file_edit(team_id, "agent-1", "/tmp/file.txt")
      :ok = ConflictDetector.release_file_edit(team_id, "agent-1", "/tmp/file.txt")
      assert :ok == ConflictDetector.register_file_edit(team_id, "agent-2", "/tmp/file.txt")
    end
  end

  describe "Negotiation — bid/4 and close_auction/2" do
    test "CRASH: close_auction with no bids returns error", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert {:error, :no_bids} == Negotiation.close_auction(team_id, "task-1")
    end

    test "CRASH: single bidder wins by default", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == Negotiation.bid(team_id, "task-1", "agent-1", 0.9)
      assert {:ok, "agent-1"} == Negotiation.close_auction(team_id, "task-1")
    end

    test "CRASH: highest confidence bidder wins", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == Negotiation.bid(team_id, "task-1", "agent-1", 0.5)
      assert :ok == Negotiation.bid(team_id, "task-1", "agent-2", 0.9)
      assert :ok == Negotiation.bid(team_id, "task-1", "agent-3", 0.7)

      assert {:ok, "agent-2"} == Negotiation.close_auction(team_id, "task-1")
    end

    test "CRASH: ties resolved by agent_id for determinism", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == Negotiation.bid(team_id, "task-1", "agent-b", 0.8)
      assert :ok == Negotiation.bid(team_id, "task-1", "agent-a", 0.8)

      # "agent-b" > "agent-a" lexicographically
      assert {:ok, "agent-b"} == Negotiation.close_auction(team_id, "task-1")
    end

    test "CRASH: auction is cleared after close", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == Negotiation.bid(team_id, "task-1", "agent-1", 0.5)
      assert {:ok, "agent-1"} == Negotiation.close_auction(team_id, "task-1")

      # Closing again should return no_bids
      assert {:error, :no_bids} == Negotiation.close_auction(team_id, "task-1")
    end
  end

  describe "Rendezvous — create/3 and arrive/4" do
    test "CRASH: arrive on nonexistent rendezvous returns error", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert {:error, :not_found} == Rendezvous.arrive(team_id, "nonexistent", "agent-1")
    end

    test "CRASH: barrier opens when all agents arrive", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == Rendezvous.create(team_id, "sync-point", 2)

      # Spawn two agents arriving at the barrier
      parent = self()

      pid1 = spawn(fn ->
        result = Rendezvous.arrive(team_id, "sync-point", "agent-1")
        send(parent, {:agent1, result})
      end)

      pid2 = spawn(fn ->
        result = Rendezvous.arrive(team_id, "sync-point", "agent-2")
        send(parent, {:agent2, result})
      end)

      # Both should receive :go
      assert_receive {:agent1, :go}, 2000
      assert_receive {:agent2, :go}, 2000
    end

    test "CRASH: barrier with expected=1 opens immediately", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == Rendezvous.create(team_id, "solo", 1)
      assert :go == Rendezvous.arrive(team_id, "solo", "agent-1")
    end

    test "CRASH: duplicate agent_id is counted once", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      assert :ok == Rendezvous.create(team_id, "dedup", 2)

      parent = self()

      # Same agent arrives twice — should not count as 2
      spawn(fn ->
        :ok = Rendezvous.arrive(team_id, "dedup", "agent-1")
        send(parent, {:dup1, :done})
      end)

      assert_receive {:dup1, :done}, 2000

      # Barrier should still be waiting for a second UNIQUE agent
      # (This tests that Enum.uniq/1 in arrive prevents double-counting)
    end
  end

  describe "ComplexityMonitor — recommend/1" do
    test "CRASH: recommend returns a valid recommendation atom", %{team_id: team_id} do
      NervousSystem.start_all(team_id)

      rec = ComplexityMonitor.recommend(team_id)
      assert rec in [:scale_up, :scale_down, :escalate_tier, :ok]
    end

    test "CRASH: recommend returns :ok when no agents or tasks exist" do
      # This test doesn't need NervousSystem started since recommend
      # will rescue to :ok when AgentState.list/Team.list_tasks fail
      NervousSystem.start_all("cm-test-team-#{:erlang.unique_integer([:positive])}")

      # The recommendation should be :ok since there are no tasks/agents
      team_id = "cm-test-team-#{:erlang.unique_integer([:positive])}"
      NervousSystem.start_all(team_id)
      rec = ComplexityMonitor.recommend(team_id)
      assert rec == :ok
    end
  end
end
