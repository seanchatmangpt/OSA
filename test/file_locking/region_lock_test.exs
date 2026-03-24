defmodule OptimalSystemAgent.FileLocking.RegionLockTest do
  @moduledoc """
  Unit tests for RegionLock module.

  Tests region-level file locking with overlap detection and auto-expiry.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.FileLocking.RegionLock

  @moduletag :capture_log

  setup do
    # Ensure RegionLock is started for tests
    unless Process.whereis(RegionLock) do
      _pid = start_supervised!(RegionLock)
    end

    # Clean up ETS tables after each test (guard: tables are owned by
    # the GenServer process and are destroyed when it terminates between tests)
    on_exit(fn ->
      if :ets.whereis(:osa_region_locks) != :undefined do
        :ets.delete_all_objects(:osa_region_locks)
      end

      if :ets.whereis(:osa_region_lock_index) != :undefined do
        :ets.delete_all_objects(:osa_region_lock_index)
      end
    end)

    :ok
  end

  describe "claim_region/4" do
    test "grants claim for non-overlapping region" do
      agent_id = "agent_1"
      file_path = "/test/file.ex"

      assert {:ok, region_id} = RegionLock.claim_region(agent_id, file_path, 1, 10)

      # Verify claim was stored
      claims = RegionLock.list_claims(file_path)
      assert length(claims) == 1
      claim = hd(claims)
      assert claim.region_id == region_id
      assert claim.agent_id == agent_id
      assert claim.file_path == file_path
      assert claim.start_line == 1
      assert claim.end_line == 10
      assert claim.claimed_at != nil
      assert claim.last_active_at != nil
    end

    test "returns conflict when region overlaps existing claim" do
      file_path = "/test/file.ex"

      # First agent claims lines 1-10
      {:ok, _region_id} = RegionLock.claim_region("agent_1", file_path, 1, 10)

      # Second agent tries to claim overlapping lines 5-15
      result = RegionLock.claim_region("agent_2", file_path, 5, 15)

      assert {:conflict, conflicting_claim} = result
      assert conflicting_claim.agent_id == "agent_1"
      assert conflicting_claim.start_line == 1
      assert conflicting_claim.end_line == 10
    end

    test "returns conflict when region is completely within existing claim" do
      file_path = "/test/file.ex"

      # First agent claims lines 1-100
      {:ok, _region_id} = RegionLock.claim_region("agent_1", file_path, 1, 100)

      # Second agent tries to claim lines 10-20 (within first claim)
      result = RegionLock.claim_region("agent_2", file_path, 10, 20)

      assert {:conflict, _conflicting_claim} = result
      assert elem(result, 1).agent_id == "agent_1"
    end

    test "returns conflict when region completely encloses existing claim" do
      file_path = "/test/file.ex"

      # First agent claims lines 50-60
      {:ok, _region_id} = RegionLock.claim_region("agent_1", file_path, 50, 60)

      # Second agent tries to claim lines 1-100 (encloses first claim)
      result = RegionLock.claim_region("agent_2", file_path, 1, 100)

      assert {:conflict, _conflicting_claim} = result
      assert elem(result, 1).agent_id == "agent_1"
    end

    test "allows multiple non-overlapping claims on same file" do
      file_path = "/test/file.ex"

      # Three agents claim non-overlapping regions
      {:ok, _r1} = RegionLock.claim_region("agent_1", file_path, 1, 10)
      {:ok, _r2} = RegionLock.claim_region("agent_2", file_path, 11, 20)
      {:ok, _r3} = RegionLock.claim_region("agent_3", file_path, 21, 30)

      claims = RegionLock.list_claims(file_path)
      assert length(claims) == 3
    end

    test "allows same agent to claim multiple non-overlapping regions" do
      file_path = "/test/file.ex"

      {:ok, _r1} = RegionLock.claim_region("agent_1", file_path, 1, 10)
      {:ok, _r2} = RegionLock.claim_region("agent_1", file_path, 20, 30)

      claims = RegionLock.list_claims(file_path)
      assert length(claims) == 2
      assert Enum.all?(claims, fn c -> c.agent_id == "agent_1" end)
    end

    test "generates unique region_id for each claim" do
      file_path = "/test/file.ex"

      {:ok, r1} = RegionLock.claim_region("agent_1", file_path, 1, 10)
      {:ok, r2} = RegionLock.claim_region("agent_2", file_path, 20, 30)

      assert r1 != r2
      assert String.starts_with?(r1, "region_")
      assert String.starts_with?(r2, "region_")
    end
  end

  describe "release_region/3" do
    test "removes claimed region from ETS" do
      agent_id = "agent_1"
      file_path = "/test/file.ex"

      {:ok, region_id} = RegionLock.claim_region(agent_id, file_path, 1, 10)

      # Verify claim exists
      assert length(RegionLock.list_claims(file_path)) == 1

      # Release the claim
      assert :ok = RegionLock.release_region(agent_id, file_path, region_id)

      # Verify claim was removed
      assert RegionLock.list_claims(file_path) == []
    end

    test "returns :ok even for unknown region_id" do
      result = RegionLock.release_region("agent_1", "/test/file.ex", "unknown_region")
      assert result == :ok
    end

    test "returns :ok when releasing claim owned by different agent" do
      file_path = "/test/file.ex"

      {:ok, region_id} = RegionLock.claim_region("agent_1", file_path, 1, 10)

      # Agent 2 tries to release agent 1's claim
      assert :ok = RegionLock.release_region("agent_2", file_path, region_id)

      # Claim should still exist (only owner can release)
      assert length(RegionLock.list_claims(file_path)) == 1
    end

    test "allows claiming same region after release" do
      file_path = "/test/file.ex"

      # Agent 1 claims and releases
      {:ok, region_id} = RegionLock.claim_region("agent_1", file_path, 1, 10)
      RegionLock.release_region("agent_1", file_path, region_id)

      # Agent 2 can now claim the same region
      {:ok, _new_region_id} = RegionLock.claim_region("agent_2", file_path, 1, 10)

      claims = RegionLock.list_claims(file_path)
      assert length(claims) == 1
      assert hd(claims).agent_id == "agent_2"
    end
  end

  describe "list_claims/1" do
    test "returns empty list for file with no claims" do
      assert RegionLock.list_claims("/nonexistent/file.ex") == []
    end

    test "returns claims sorted by start_line" do
      file_path = "/test/file.ex"

      # Claim regions in non-sequential order
      RegionLock.claim_region("agent_1", file_path, 50, 60)
      RegionLock.claim_region("agent_2", file_path, 10, 20)
      RegionLock.claim_region("agent_3", file_path, 30, 40)

      claims = RegionLock.list_claims(file_path)

      assert length(claims) == 3
      assert Enum.at(claims, 0).start_line == 10
      assert Enum.at(claims, 1).start_line == 30
      assert Enum.at(claims, 2).start_line == 50
    end

    test "returns only claims for specified file" do
      file1 = "/test/file1.ex"
      file2 = "/test/file2.ex"

      RegionLock.claim_region("agent_1", file1, 1, 10)
      RegionLock.claim_region("agent_2", file2, 1, 10)

      claims1 = RegionLock.list_claims(file1)
      claims2 = RegionLock.list_claims(file2)

      assert length(claims1) == 1
      assert length(claims2) == 1
      assert hd(claims1).file_path == file1
      assert hd(claims2).file_path == file2
    end
  end

  describe "touch_region/2" do
    test "updates last_active_at timestamp for owned region" do
      agent_id = "agent_1"
      file_path = "/test/file.ex"

      {:ok, region_id} = RegionLock.claim_region(agent_id, file_path, 1, 10)

      # Get original timestamp
      [claim_before] = RegionLock.list_claims(file_path)
      original_time = claim_before.last_active_at

      # Wait a bit and touch
      Process.sleep(10)
      RegionLock.touch_region(agent_id, region_id)

      # Verify timestamp was updated
      [claim_after] = RegionLock.list_claims(file_path)
      assert DateTime.after?(claim_after.last_active_at, original_time)
    end

    test "returns :ok for unknown region_id" do
      result = RegionLock.touch_region("agent_1", "unknown_region")
      assert result == :ok
    end

    test "returns :ok when touching region owned by different agent" do
      file_path = "/test/file.ex"

      {:ok, region_id} = RegionLock.claim_region("agent_1", file_path, 1, 10)

      # Agent 2 tries to touch agent 1's region
      result = RegionLock.touch_region("agent_2", region_id)
      assert result == :ok

      # Timestamp should not be updated
      [claim] = RegionLock.list_claims(file_path)
      assert claim.agent_id == "agent_1"
    end
  end

  describe "integration - claim and release lifecycle" do
    test "full lifecycle: claim, touch, release" do
      agent_id = "agent_1"
      file_path = "/test/file.ex"

      # Claim region
      {:ok, region_id} = RegionLock.claim_region(agent_id, file_path, 1, 10)
      assert length(RegionLock.list_claims(file_path)) == 1

      # Touch to update activity
      Process.sleep(10)
      RegionLock.touch_region(agent_id, region_id)

      # Release region
      RegionLock.release_region(agent_id, file_path, region_id)
      assert RegionLock.list_claims(file_path) == []
    end

    test "conflict resolution: wait and retry after release" do
      file_path = "/test/file.ex"

      # Agent 1 claims region
      {:ok, region_id} = RegionLock.claim_region("agent_1", file_path, 1, 10)

      # Agent 2 gets conflict
      assert {:conflict, _claim} = RegionLock.claim_region("agent_2", file_path, 5, 15)

      # Agent 1 releases
      RegionLock.release_region("agent_1", file_path, region_id)

      # Agent 2 can now claim
      {:ok, _new_region_id} = RegionLock.claim_region("agent_2", file_path, 5, 15)

      claims = RegionLock.list_claims(file_path)
      assert length(claims) == 1
      assert hd(claims).agent_id == "agent_2"
    end
  end

  describe "edge cases" do
    test "handles single-line regions" do
      file_path = "/test/file.ex"

      {:ok, _region_id} = RegionLock.claim_region("agent_1", file_path, 5, 5)

      claims = RegionLock.list_claims(file_path)
      assert length(claims) == 1
      claim = hd(claims)
      assert claim.start_line == 5
      assert claim.end_line == 5
    end

    test "handles adjacent regions (no overlap)" do
      file_path = "/test/file.ex"

      {:ok, _r1} = RegionLock.claim_region("agent_1", file_path, 1, 10)
      {:ok, _r2} = RegionLock.claim_region("agent_2", file_path, 11, 20)

      claims = RegionLock.list_claims(file_path)
      assert length(claims) == 2
    end

    test "handles large line numbers" do
      file_path = "/test/file.ex"

      {:ok, _region_id} = RegionLock.claim_region("agent_1", file_path, 1000000, 2000000)

      claims = RegionLock.list_claims(file_path)
      assert length(claims) == 1
      claim = hd(claims)
      assert claim.start_line == 1_000_000
      assert claim.end_line == 2_000_000
    end
  end
end
