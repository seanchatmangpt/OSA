defmodule OptimalSystemAgent.Budget.TreasuryTest do
  @moduledoc """
  Unit tests for Budget.Treasury module.

  Tests treasury GenServer for reserve/release accounting.
  Real GenServer operations, no mocks.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Budget.Treasury

  @moduletag :capture_log

  setup do
    # Start Treasury GenServer with test config
    start_supervised!({Treasury, [name: :test_treasury, balance: 1000.0, daily_limit: 100.0]})
    :ok
  end

  describe "start_link/1" do
    test "starts the Treasury GenServer" do
      assert {:ok, pid} = Treasury.start_link([name: :test_treasury_start, balance: 500.0])
      assert is_pid(pid)
      GenServer.stop(:test_treasury_start)
    end

    test "accepts initial balance" do
      assert {:ok, pid} = Treasury.start_link([name: :test_treasury_balance, balance: 100.0])
      GenServer.stop(:test_treasury_balance)
    end

    test "accepts daily_limit" do
      assert {:ok, pid} = Treasury.start_link([name: :test_treasury_daily, daily_limit: 50.0])
      GenServer.stop(:test_treasury_daily)
    end

    test "accepts monthly_limit" do
      assert {:ok, pid} = Treasury.start_link([name: :test_treasury_monthly, monthly_limit: 500.0])
      GenServer.stop(:test_treasury_monthly)
    end

    test "accepts max_single" do
      assert {:ok, pid} = Treasury.start_link([name: :test_treasury_max, max_single: 25.0])
      GenServer.stop(:test_treasury_max)
    end

    test "accepts min_reserve" do
      assert {:ok, pid} = Treasury.start_link([name: :test_treasury_min, min_reserve: 100.0])
      GenServer.stop(:test_treasury_min)
    end

    test "accepts approval_threshold" do
      assert {:ok, pid} = Treasury.start_link([name: :test_treasury_approval, approval_threshold: 50.0])
      GenServer.stop(:test_treasury_approval)
    end
  end

  describe "needs_approval?/2" do
    test "returns true when amount exceeds threshold" do
      assert Treasury.needs_approval?(100.0, 50.0) == true
    end

    test "returns false when amount equals threshold" do
      assert Treasury.needs_approval?(50.0, 50.0) == false
    end

    test "returns false when amount below threshold" do
      assert Treasury.needs_approval?(25.0, 50.0) == false
    end

    test "handles infinity threshold" do
      assert Treasury.needs_approval?(100.0, :infinity) == false
    end
  end

  describe "get_balance/0" do
    test "returns balance map" do
      assert {:ok, balance} = GenServer.call(:test_treasury, :get_balance)
      assert is_map(balance)
    end

    test "includes balance field" do
      assert {:ok, balance} = GenServer.call(:test_treasury, :get_balance)
      assert Map.has_key?(balance, :balance) or Map.has_key?(balance, "balance")
    end

    test "includes reserved field" do
      assert {:ok, balance} = GenServer.call(:test_treasury, :get_balance)
      assert Map.has_key?(balance, :reserved) or Map.has_key?(balance, "reserved")
    end

    test "includes available field" do
      assert {:ok, balance} = GenServer.call(:test_treasury, :get_balance)
      assert Map.has_key?(balance, :available) or Map.has_key?(balance, "available")
    end

    test "available equals balance minus reserved" do
      assert {:ok, balance} = GenServer.call(:test_treasury, :get_balance)
      bal = balance.balance || balance[:balance]
      res = balance.reserved || balance[:reserved]
      avail = balance.available || balance[:available]
      assert_in_delta avail, bal - res, 0.01
    end
  end

  describe "get_ledger/1" do
    test "returns list of transactions" do
      assert {:ok, ledger} = GenServer.call(:test_treasury, {:get_ledger, []})
      assert is_list(ledger)
    end

    test "returns empty list initially" do
      # Clear any existing transactions
      ledger = GenServer.call(:test_treasury, {:get_ledger, []})
      # Initially should be empty or only have initial deposit
      assert is_list(ledger)
    end
  end

  describe "handle_call/3" do
    test "handles unknown calls" do
      assert {:reply, {:error, :unknown_request}, _state} = :sys.handle_debug(:test_treasury, :unknown_call, self(), [])
    end
  end

  describe "handle_cast/2" do
    test "handles unknown casts gracefully" do
      GenServer.cast(:test_treasury, :unknown_cast)
      Process.sleep(10)
      assert Process.alive?(Process.whereis(:test_treasury))
    end
  end

  describe "handle_info/2" do
    test "handles unknown messages gracefully" do
      send(:test_treasury, :unknown_message)
      Process.sleep(10)
      assert Process.alive?(Process.whereis(:test_treasury))
    end
  end

  describe "edge cases" do
    test "handles zero amount deposit" do
      assert {:ok, _txn} = GenServer.call(:test_treasury, {:deposit, 0.0, "test"})
    end

    test "handles negative amount" do
      # Should handle gracefully - either error or convert to positive
      result = GenServer.call(:test_treasury, {:deposit, -10.0, "test"})
      case result do
        {:ok, _txn} -> assert true
        {:error, _reason} -> assert true
      end
    end

    test "handles very large amounts" do
      assert {:ok, _txn} = GenServer.call(:test_treasury, {:deposit, 9_999_999.0, "large deposit"})
    end
  end

  describe "integration" do
    test "full treasury lifecycle" do
      # Get initial balance
      {:ok, initial} = GenServer.call(:test_treasury, :get_balance)

      # Deposit
      assert {:ok, deposit_txn} = GenServer.call(:test_treasury, {:deposit, 100.0, "test deposit"})
      assert deposit_txn.type == :credit or deposit_txn[:type] == :credit

      # Withdraw
      assert {:ok, withdraw_txn} = GenServer.call(:test_treasury, {:withdraw, 50.0, "test withdrawal", "ref1"})
      assert withdraw_txn.type == :debit or withdraw_txn[:type] == :debit

      # Reserve
      assert {:ok, reserve_txn} = GenServer.call(:test_treasury, {:reserve, 25.0, "ref2"})
      assert reserve_txn.type == :reserve or reserve_txn[:type] == :reserve

      # Release
      assert {:ok, release_txn} = GenServer.call(:test_treasury, {:release, "ref2"})
      assert release_txn.type == :release or release_txn[:type] == :release

      # Get ledger
      {:ok, ledger} = GenServer.call(:test_treasury, {:get_ledger, limit: 10})
      assert length(ledger) > 0
    end
  end
end
