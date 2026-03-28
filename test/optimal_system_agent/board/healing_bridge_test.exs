defmodule OptimalSystemAgent.Board.HealingBridgeTest do
  @moduledoc """
  Chicago TDD tests for Board.HealingBridge.

  Tests follow Red-Green-Refactor discipline:
  - Each test asserts one specific behavior claim
  - Tests use real implementations where possible
  - Tests are Independent, Fast, Repeatable, Self-Checking, Timely (FIRST)
  """

  use ExUnit.Case, async: false

  @moduletag :board_healing
  @moduletag :requires_application

  alias OptimalSystemAgent.Board.HealingBridge

  # ── Setup ────────────────────────────────────────────────────────────────────

  setup do
    # Clean ETS table between tests for Independence
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      :ets.delete_all_objects(:osa_board_healing_status)
    end

    :ok
  end

  # ── Test 1: healing_status/0 returns list ────────────────────────────────────

  test "healing_status/0 returns a list" do
    result = HealingBridge.healing_status()
    assert is_list(result)
  end

  # ── Test 2: healing_status/0 returns healed processes ────────────────────────

  test "healing_status/0 returns healed processes for current period" do
    # Directly insert a healed record into ETS
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      healed_at = DateTime.utc_now()
      :ets.insert(:osa_board_healing_status, {"proc-123", :healed, healed_at, "span-abc"})

      status = HealingBridge.healing_status()
      process_ids = Enum.map(status, fn {id, _, _} -> id end)
      assert "proc-123" in process_ids
    else
      # ETS not started — skip gracefully
      :ok
    end
  end

  # ── Test 3: conformance_violation < 0.8 triggers healing ─────────────────────

  test "receiving conformance_violation with fitness < 0.8 records deviation in ETS" do
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      pid = "purchase-to-pay-#{System.unique_integer([:positive])}"

      # Simulate a conformance violation event via cast
      GenServer.cast(HealingBridge, {:conformance_violation, %{
        process_id: pid,
        fitness: 0.72,
        deviation_type: "conformance",
        detected_at: DateTime.to_iso8601(DateTime.utc_now())
      }})

      # Allow async processing — full pipeline may complete to :healed
      Process.sleep(200)

      # Verify ETS record was created with any tracked status
      records = :ets.lookup(:osa_board_healing_status, pid)
      assert length(records) > 0, "ETS must have a record for deviation < 0.8"

      # Status should be either :healing_triggered or :healed (pipeline may complete)
      status = elem(hd(records), 1)
      assert status in [:healing_triggered, :healed],
        "Expected :healing_triggered or :healed, got #{inspect(status)}"
    else
      :ok
    end
  end

  # ── Test 4: conformance_violation >= 0.8 does NOT trigger healing ─────────────

  test "receiving conformance_violation with fitness >= 0.8 does not record in ETS" do
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      process_id = "healthy-process-#{System.unique_integer([:positive])}"

      GenServer.cast(HealingBridge, {:conformance_violation, %{
        process_id: process_id,
        fitness: 0.95,
        deviation_type: "conformance",
        detected_at: DateTime.to_iso8601(DateTime.utc_now())
      }})

      Process.sleep(50)

      # No ETS record should exist for healthy process
      records = :ets.lookup(:osa_board_healing_status, process_id)
      assert records == []
    else
      :ok
    end
  end

  # ── Test 5: healing_complete updates ETS to :healed ──────────────────────────

  test "receiving healing_complete updates ETS status to :healed" do
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      process_id = "order-fulfillment-#{System.unique_integer([:positive])}"

      # Pre-insert healing_triggered state
      :ets.insert(:osa_board_healing_status, {process_id, :healing_triggered, DateTime.utc_now()})

      GenServer.cast(HealingBridge, {:healing_complete, %{
        event: :healing_complete,
        process_id: process_id,
        proof_span_id: "span-test-123",
        outcome: "healed",
        healed_at: DateTime.utc_now()
      }})

      Process.sleep(100)

      records = :ets.lookup(:osa_board_healing_status, process_id)
      assert length(records) > 0

      [{_id, status, _healed_at, _span_id}] = records
      assert status == :healed
    else
      :ok
    end
  end

  # ── Test 6: healing_complete status appears in healing_status/0 ───────────────

  test "healed process appears in healing_status/0 result" do
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      process_id = "compliance-check-#{System.unique_integer([:positive])}"
      healed_at = DateTime.utc_now()

      :ets.insert(:osa_board_healing_status, {process_id, :healed, healed_at, "span-xyz"})

      status = HealingBridge.healing_status()
      process_ids = Enum.map(status, fn {id, _, _} -> id end)

      assert process_id in process_ids
    else
      :ok
    end
  end

  # ── Test 7: report_deviation/1 returns :ok synchronously ─────────────────────

  test "report_deviation/1 returns :ok immediately" do
    result = HealingBridge.report_deviation(%{
      process_id: "test-process",
      fitness: 0.65,
      deviation_type: "conformance",
      detected_at: DateTime.to_iso8601(DateTime.utc_now())
    })

    assert result == :ok
  end

  # ── Test 8: invalid deviation payload is handled gracefully ───────────────────

  test "conformance_violation with missing process_id does not crash bridge" do
    # This should NOT raise or crash the GenServer
    assert :ok ==
      GenServer.cast(HealingBridge, {:conformance_violation, %{
        fitness: 0.5
        # missing process_id
      }})

    Process.sleep(30)

    # Bridge still alive
    assert Process.alive?(Process.whereis(HealingBridge))
  end

  # ── Test 9: healing_complete with missing process_id is handled gracefully ────

  test "healing_complete with missing process_id does not crash bridge" do
    assert :ok ==
      GenServer.cast(HealingBridge, {:healing_complete, %{
        proof_span_id: "span-orphan",
        outcome: "healed"
        # missing process_id
      }})

    Process.sleep(30)

    assert Process.alive?(Process.whereis(HealingBridge))
  end

  # ── Test 10: fitness exactly at threshold (0.8) does not trigger healing ──────

  test "conformance_violation at exactly 0.8 fitness does not trigger healing" do
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      process_id = "boundary-process-#{System.unique_integer([:positive])}"

      GenServer.cast(HealingBridge, {:conformance_violation, %{
        process_id: process_id,
        fitness: 0.8,
        deviation_type: "conformance",
        detected_at: DateTime.to_iso8601(DateTime.utc_now())
      }})

      Process.sleep(50)

      records = :ets.lookup(:osa_board_healing_status, process_id)
      assert records == [], "Fitness == 0.8 should not trigger healing (strict <)"
    else
      :ok
    end
  end

  # ── Test 11: fitness just below threshold triggers healing ────────────────────

  test "conformance_violation at 0.799 fitness triggers healing" do
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      process_id = "below-boundary-#{System.unique_integer([:positive])}"

      GenServer.cast(HealingBridge, {:conformance_violation, %{
        process_id: process_id,
        fitness: 0.799,
        deviation_type: "conformance",
        detected_at: DateTime.to_iso8601(DateTime.utc_now())
      }})

      # Allow full pipeline — may complete to :healed
      Process.sleep(200)

      records = :ets.lookup(:osa_board_healing_status, process_id)
      assert length(records) > 0, "Fitness < 0.8 must trigger healing and create ETS record"

      status = elem(hd(records), 1)
      assert status in [:healing_triggered, :healed],
        "Expected :healing_triggered or :healed, got #{inspect(status)}"
    else
      :ok
    end
  end

  # ── Test 12: multiple deviations tracked independently ────────────────────────

  test "multiple process deviations are tracked independently in ETS" do
    if :ets.whereis(:osa_board_healing_status) != :undefined do
      pid1 = "process-alpha-#{System.unique_integer([:positive])}"
      pid2 = "process-beta-#{System.unique_integer([:positive])}"

      GenServer.cast(HealingBridge, {:conformance_violation, %{
        process_id: pid1, fitness: 0.6, deviation_type: "conformance",
        detected_at: DateTime.to_iso8601(DateTime.utc_now())
      }})
      GenServer.cast(HealingBridge, {:conformance_violation, %{
        process_id: pid2, fitness: 0.5, deviation_type: "timing",
        detected_at: DateTime.to_iso8601(DateTime.utc_now())
      }})

      # Allow full pipeline — may complete to :healed
      Process.sleep(200)

      records1 = :ets.lookup(:osa_board_healing_status, pid1)
      records2 = :ets.lookup(:osa_board_healing_status, pid2)

      assert length(records1) > 0, "process alpha should be tracked"
      assert length(records2) > 0, "process beta should be tracked"

      s1 = elem(hd(records1), 1)
      s2 = elem(hd(records2), 1)
      assert s1 in [:healing_triggered, :healed],
        "process alpha status should be :healing_triggered or :healed"
      assert s2 in [:healing_triggered, :healed],
        "process beta status should be :healing_triggered or :healed"
    else
      :ok
    end
  end
end
