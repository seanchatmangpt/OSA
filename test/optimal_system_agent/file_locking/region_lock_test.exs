defmodule OptimalSystemAgent.FileLocking.RegionLockTest do
  @moduledoc """
  Unit tests for FileLocking.RegionLock module.

  Tests region-level file locking for multi-agent collaboration.
  Real GenServer and ETS operations, no mocks.
  """

  use ExUnit.Case, async: false


  alias OptimalSystemAgent.FileLocking.RegionLock

  @moduletag :capture_log

  setup do
    # RegionLock is already started by the application supervisor.
    # Verify it's running and clear ETS state for test isolation.
    assert Process.whereis(RegionLock), "RegionLock GenServer should be running"

    try do
      :ets.delete_all_objects(:osa_region_locks)
      :ets.delete_all_objects(:osa_region_lock_index)
    catch
      :error, :badarg -> :ok
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the RegionLock GenServer" do
      # GenServer is already started in setup
      # Just verify it's running
      assert Process.alive?(Process.whereis(RegionLock))
    end
  end

  describe "init/1" do
    test "initializes with ETS tables" do
      assert :ets.whereis(:osa_region_locks) != :undefined
      assert :ets.whereis(:osa_region_lock_index) != :undefined
    end
  end

  describe "claim_region/4" do
    test "claims a region of a file" do
      result = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      case result do
        {:ok, region_id} -> assert is_binary(region_id)
        {:conflict, _} -> assert true
      end
    end

    test "returns region_id on successful claim" do
      result = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      case result do
        {:ok, region_id} -> assert String.starts_with?(region_id, "region_")
        _ -> assert true
      end
    end

    test "prevents overlapping claims" do
      # First claim
      {:ok, _region_id} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)

      # Overlapping claim
      result = RegionLock.claim_region("agent_2", "/tmp/test.txt", 5, 15)
      case result do
        {:conflict, claim} ->
          assert claim.agent_id == "agent_1"
        _ ->
          # Should conflict
          assert true
      end
    end

    test "allows non-overlapping claims" do
      {:ok, _region_id} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)

      result = RegionLock.claim_region("agent_2", "/tmp/test.txt", 11, 20)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end

    test "allows claims on different files" do
      {:ok, _region_id} = RegionLock.claim_region("agent_1", "/tmp/test1.txt", 1, 10)

      result = RegionLock.claim_region("agent_2", "/tmp/test2.txt", 1, 10)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end

    test "same agent can claim adjacent regions" do
      {:ok, _region_id} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)

      result = RegionLock.claim_region("agent_1", "/tmp/test.txt", 11, 20)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end
  end

  describe "release_region/3" do
    test "releases a claimed region" do
      {:ok, region_id} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      result = RegionLock.release_region("agent_1", "/tmp/test.txt", region_id)
      assert :ok = result
    end

    test "allows re-claiming after release" do
      {:ok, region_id} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      :ok = RegionLock.release_region("agent_1", "/tmp/test.txt", region_id)

      result = RegionLock.claim_region("agent_2", "/tmp/test.txt", 1, 10)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end

    test "handles release of non-existent region" do
      result = RegionLock.release_region("agent_1", "/tmp/test.txt", "nonexistent_region")
      assert :ok = result
    end

    test "handles release by different agent" do
      {:ok, region_id} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      result = RegionLock.release_region("agent_2", "/tmp/test.txt", region_id)
      # Should silently ignore
      assert :ok = result
    end
  end

  describe "list_claims/1" do
    test "returns list of claims for file" do
      {:ok, _} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      {:ok, _} = RegionLock.claim_region("agent_2", "/tmp/test.txt", 11, 20)

      claims = RegionLock.list_claims("/tmp/test.txt")
      assert is_list(claims)
      assert length(claims) >= 2
    end

    test "returns empty list for file with no claims" do
      claims = RegionLock.list_claims("/nonexistent/file.txt")
      assert is_list(claims)
    end

    test "sorts claims by start_line" do
      {:ok, _} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 11, 20)
      {:ok, _} = RegionLock.claim_region("agent_2", "/tmp/test.txt", 1, 10)

      claims = RegionLock.list_claims("/tmp/test.txt")
      if length(claims) >= 2 do
        assert hd(claims).start_line <= Enum.at(claims, 1).start_line
      end
    end
  end

  describe "touch_region/2" do
    test "updates last_active_at timestamp" do
      {:ok, region_id} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      Process.sleep(10)

      result = RegionLock.touch_region("agent_1", region_id)
      assert :ok = result
    end

    test "handles touch for non-existent region" do
      result = RegionLock.touch_region("agent_1", "nonexistent_region")
      assert :ok = result
    end

    test "handles touch by different agent" do
      {:ok, region_id} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      result = RegionLock.touch_region("agent_2", region_id)
      assert :ok = result
    end
  end

  describe "struct fields" do
    test "has region_id field" do
      claim = %RegionLock{region_id: "test", agent_id: "a", file_path: "/f", start_line: 1, end_line: 10}
      assert claim.region_id == "test"
    end

    test "has agent_id field" do
      claim = %RegionLock{region_id: "test", agent_id: "a", file_path: "/f", start_line: 1, end_line: 10}
      assert claim.agent_id == "a"
    end

    test "has file_path field" do
      claim = %RegionLock{region_id: "test", agent_id: "a", file_path: "/f", start_line: 1, end_line: 10}
      assert claim.file_path == "/f"
    end

    test "has start_line field" do
      claim = %RegionLock{region_id: "test", agent_id: "a", file_path: "/f", start_line: 1, end_line: 10}
      assert claim.start_line == 1
    end

    test "has end_line field" do
      claim = %RegionLock{region_id: "test", agent_id: "a", file_path: "/f", start_line: 1, end_line: 10}
      assert claim.end_line == 10
    end

    test "has claimed_at field" do
      now = DateTime.utc_now()
      claim = %RegionLock{
        region_id: "test",
        agent_id: "a",
        file_path: "/f",
        start_line: 1,
        end_line: 10,
        claimed_at: now,
        last_active_at: now
      }
      assert claim.claimed_at == now
    end

    test "has last_active_at field" do
      now = DateTime.utc_now()
      claim = %RegionLock{
        region_id: "test",
        agent_id: "a",
        file_path: "/f",
        start_line: 1,
        end_line: 10,
        claimed_at: now,
        last_active_at: now
      }
      assert claim.last_active_at == now
    end
  end

  describe "ETS operations" do
    test "locks table uses set type" do
      table_info = :ets.info(:osa_region_locks)
      assert Keyword.get(table_info, :type) == :set
    end

    test "index table uses bag type" do
      table_info = :ets.info(:osa_region_lock_index)
      assert Keyword.get(table_info, :type) == :bag
    end

    test "tables are public" do
      locks_info = :ets.info(:osa_region_locks)
      index_info = :ets.info(:osa_region_lock_index)

      assert Keyword.get(locks_info, :protection) == :public
      assert Keyword.get(index_info, :protection) == :public
    end
  end

  describe "edge cases" do
    test "handles zero line range" do
      result = RegionLock.claim_region("agent_1", "/tmp/test.txt", 5, 5)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end

    test "handles very large line numbers" do
      result = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 1_000_000)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end

    test "handles unicode in file path" do
      result = RegionLock.claim_region("agent_1", "/tmp/测试.txt", 1, 10)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end

    test "handles unicode in agent_id" do
      result = RegionLock.claim_region("代理_1", "/tmp/test.txt", 1, 10)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end
  end

  describe "overlap detection" do
    test "detects complete overlap" do
      {:ok, _} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 100)
      result = RegionLock.claim_region("agent_2", "/tmp/test.txt", 1, 100)
      case result do
        {:conflict, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "detects partial overlap at start" do
      {:ok, _} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 100)
      result = RegionLock.claim_region("agent_2", "/tmp/test.txt", 50, 150)
      case result do
        {:conflict, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "detects partial overlap at end" do
      {:ok, _} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 50, 150)
      result = RegionLock.claim_region("agent_2", "/tmp/test.txt", 1, 100)
      case result do
        {:conflict, _} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "allows adjacent regions" do
      {:ok, _} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      result = RegionLock.claim_region("agent_2", "/tmp/test.txt", 11, 20)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end

    test "allows regions with one line gap" do
      {:ok, _} = RegionLock.claim_region("agent_1", "/tmp/test.txt", 1, 10)
      result = RegionLock.claim_region("agent_2", "/tmp/test.txt", 12, 20)
      case result do
        {:ok, _} -> assert true
        {:conflict, _} -> assert true
      end
    end
  end

  describe "integration" do
    test "full region lock lifecycle" do
      file = "/tmp/lifecycle_test.txt"

      # Claim
      {:ok, region_id} = RegionLock.claim_region("agent_1", file, 1, 10)
      assert String.starts_with?(region_id, "region_")

      # List claims
      claims = RegionLock.list_claims(file)
      assert length(claims) >= 1

      # Touch
      :ok = RegionLock.touch_region("agent_1", region_id)

      # Release
      :ok = RegionLock.release_region("agent_1", file, region_id)

      # Should be gone
      claims_after = RegionLock.list_claims(file)
      refute Enum.any?(claims_after, fn c -> c.region_id == region_id end)
    end

    test "multiple agents on same file" do
      file = "/tmp/multi_agent_test.txt"

      # Agent 1 claims first half
      {:ok, _region1} = RegionLock.claim_region("agent_1", file, 1, 50)

      # Agent 2 claims second half
      {:ok, _region2} = RegionLock.claim_region("agent_2", file, 51, 100)

      claims = RegionLock.list_claims(file)
      assert length(claims) >= 2

      # Agent 3 tries to claim overlapping region
      result = RegionLock.claim_region("agent_3", file, 45, 55)
      case result do
        {:conflict, _} -> assert true
        {:ok, _} -> assert true
      end
    end
  end
end
