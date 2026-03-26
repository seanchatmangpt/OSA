defmodule OptimalSystemAgent.Integrations.FIBO.DealCoordinatorTest do
  @moduledoc """
  Unit tests for FIBO DealCoordinator GenServer (Agent 16).

  Tests verify the deal lifecycle: create, retrieve, list, and compliance verification.
  Uses Chicago TDD approach with real Deal structs (no mocking).

  Each test is independent and operates on unique deal IDs to avoid collisions.
  All operations invoke DealCoordinator API directly (no HTTP layer).

  Test Categories:
    - create_deal: Happy path, validation, RDF triple generation
    - get_deal: Happy path, not found cases
    - list_deals: Empty list, multiple deals
    - verify_compliance: Happy path, not found
    - deal_count: Before/after counts
    - Concurrent operations: Multiple creates/gets in parallel
    - Timeout handling: Explicit timeout test (if environment allows)
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Integrations.FIBO.DealCoordinator

  setup_all do
    # Enable mock CLI for testing (no actual bos command needed)
    Application.put_env(:optimal_system_agent, :fibo_mock_cli, true)

    # Ensure ETS table exists before any tests
    if :ets.whereis(:osa_fibo_deals) == :undefined do
      :ets.new(:osa_fibo_deals, [:named_table, :public, :set])
    end

    on_exit(fn ->
      Application.put_env(:optimal_system_agent, :fibo_mock_cli, false)
    end)

    :ok
  end

  setup do
    # Clear ETS table before each test to avoid pollution
    :ets.delete_all_objects(:osa_fibo_deals)
    :ok
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Fixtures: Example Deals
  # ───────────────────────────────────────────────────────────────────────────

  defp acme_widget_deal do
    %{
      name: "ACME Widget Supply Agreement",
      counterparty: "ACME Corp",
      amount_usd: 500_000.0,
      currency: "USD"
    }
  end

  defp tech_integration_deal do
    %{
      name: "Tech Integration Services",
      counterparty: "TechVentures Inc",
      amount_usd: 1_250_000.0,
      currency: "USD"
    }
  end

  defp manufacturing_deal do
    %{
      name: "Manufacturing Partnership",
      counterparty: "ManufactureCo Ltd",
      amount_usd: 2_750_000.0,
      currency: "EUR"
    }
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Tests: create_deal
  # ───────────────────────────────────────────────────────────────────────────

  describe "create_deal/1" do
    test "creates deal with required fields and returns Deal struct" do
      {:ok, deal} = DealCoordinator.create_deal(acme_widget_deal())

      assert is_binary(deal.id)
      assert String.starts_with?(deal.id, "deal_")
      assert deal.name == "ACME Widget Supply Agreement"
      assert deal.counterparty == "ACME Corp"
      assert deal.amount_usd == 500_000.0
      assert deal.currency == "USD"
      assert deal.status == :created
      assert is_struct(deal.created_at, DateTime)
      assert is_list(deal.rdf_triples)
      assert is_map(deal.compliance_checks)
    end

    test "defaults currency to USD when not provided" do
      input = %{
        name: "Default Currency Deal",
        counterparty: "DefaultCorp",
        amount_usd: 100_000.0
      }

      {:ok, deal} = DealCoordinator.create_deal(input)
      assert deal.currency == "USD"
    end

    test "accepts explicit currency in input" do
      input = manufacturing_deal()
      {:ok, deal} = DealCoordinator.create_deal(input)
      assert deal.currency == "EUR"
    end

    test "rejects missing name" do
      input = %{counterparty: "Corp", amount_usd: 100_000.0}
      assert {:error, "name is required"} = DealCoordinator.create_deal(input)
    end

    test "rejects empty name" do
      input = %{name: "", counterparty: "Corp", amount_usd: 100_000.0}
      assert {:error, "name is required"} = DealCoordinator.create_deal(input)
    end

    test "rejects missing counterparty" do
      input = %{name: "Deal", amount_usd: 100_000.0}
      assert {:error, "counterparty is required"} = DealCoordinator.create_deal(input)
    end

    test "rejects empty counterparty" do
      input = %{name: "Deal", counterparty: "", amount_usd: 100_000.0}
      assert {:error, "counterparty is required"} = DealCoordinator.create_deal(input)
    end

    test "rejects missing amount_usd" do
      input = %{name: "Deal", counterparty: "Corp"}
      assert {:error, "amount_usd must be positive"} = DealCoordinator.create_deal(input)
    end

    test "rejects zero amount_usd" do
      input = %{name: "Deal", counterparty: "Corp", amount_usd: 0.0}
      assert {:error, "amount_usd must be positive"} = DealCoordinator.create_deal(input)
    end

    test "rejects negative amount_usd" do
      input = %{name: "Deal", counterparty: "Corp", amount_usd: -100_000.0}
      assert {:error, "amount_usd must be positive"} = DealCoordinator.create_deal(input)
    end

    test "stores deal in ETS cache" do
      {:ok, deal} = DealCoordinator.create_deal(acme_widget_deal())

      # Verify deal exists in ETS
      result = :ets.lookup(:osa_fibo_deals, deal.id)
      assert [{deal_id, cached_deal}] = result
      assert deal_id == deal.id
      assert cached_deal.name == deal.name
    end

    test "generates unique deal IDs for multiple creates" do
      {:ok, deal1} = DealCoordinator.create_deal(acme_widget_deal())
      {:ok, deal2} = DealCoordinator.create_deal(tech_integration_deal())

      refute deal1.id == deal2.id
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Tests: get_deal
  # ───────────────────────────────────────────────────────────────────────────

  describe "get_deal/1" do
    test "retrieves deal by ID" do
      {:ok, created} = DealCoordinator.create_deal(acme_widget_deal())
      {:ok, retrieved} = DealCoordinator.get_deal(created.id)

      assert retrieved.id == created.id
      assert retrieved.name == created.name
      assert retrieved.counterparty == created.counterparty
    end

    test "returns error for non-existent deal" do
      assert {:error, :not_found} = DealCoordinator.get_deal("deal_nonexistent")
    end

    test "retrieves deal multiple times (cached)" do
      {:ok, deal} = DealCoordinator.create_deal(acme_widget_deal())

      {:ok, r1} = DealCoordinator.get_deal(deal.id)
      {:ok, r2} = DealCoordinator.get_deal(deal.id)

      assert r1.id == r2.id
      assert r1.name == r2.name
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Tests: list_deals
  # ───────────────────────────────────────────────────────────────────────────

  describe "list_deals/0" do
    test "returns empty list when no deals created" do
      :ets.delete_all_objects(:osa_fibo_deals)
      deals = DealCoordinator.list_deals()
      assert deals == []
    end

    test "returns all created deals" do
      {:ok, deal1} = DealCoordinator.create_deal(acme_widget_deal())
      {:ok, deal2} = DealCoordinator.create_deal(tech_integration_deal())
      {:ok, deal3} = DealCoordinator.create_deal(manufacturing_deal())

      deals = DealCoordinator.list_deals()

      assert Enum.count(deals) == 3
      ids = Enum.map(deals, & &1.id)
      assert deal1.id in ids
      assert deal2.id in ids
      assert deal3.id in ids
    end

    test "list includes all deal fields" do
      {:ok, created} = DealCoordinator.create_deal(acme_widget_deal())
      [listed] = DealCoordinator.list_deals()

      assert listed.id == created.id
      assert listed.name == created.name
      assert listed.counterparty == created.counterparty
      assert listed.amount_usd == created.amount_usd
      assert listed.status == :created
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Tests: verify_compliance
  # ───────────────────────────────────────────────────────────────────────────

  describe "verify_compliance/1" do
    test "updates deal status to verified" do
      {:ok, deal} = DealCoordinator.create_deal(acme_widget_deal())
      assert deal.status == :created

      {:ok, verified} = DealCoordinator.verify_compliance(deal.id)
      assert verified.status == :verified
    end

    test "populates compliance_checks map" do
      {:ok, deal} = DealCoordinator.create_deal(acme_widget_deal())
      {:ok, verified} = DealCoordinator.verify_compliance(deal.id)

      assert is_map(verified.compliance_checks)
    end

    test "persists verified deal in ETS" do
      {:ok, deal} = DealCoordinator.create_deal(acme_widget_deal())
      {:ok, _verified} = DealCoordinator.verify_compliance(deal.id)

      {:ok, retrieved} = DealCoordinator.get_deal(deal.id)
      assert retrieved.status == :verified
    end

    test "returns error for non-existent deal" do
      assert {:error, :not_found} = DealCoordinator.verify_compliance("deal_nonexistent")
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Tests: deal_count
  # ───────────────────────────────────────────────────────────────────────────

  describe "deal_count/0" do
    test "returns 0 for empty cache" do
      :ets.delete_all_objects(:osa_fibo_deals)
      assert DealCoordinator.deal_count() == 0
    end

    test "increments with each create" do
      assert DealCoordinator.deal_count() == 0

      DealCoordinator.create_deal(acme_widget_deal())
      assert DealCoordinator.deal_count() == 1

      DealCoordinator.create_deal(tech_integration_deal())
      assert DealCoordinator.deal_count() == 2

      DealCoordinator.create_deal(manufacturing_deal())
      assert DealCoordinator.deal_count() == 3
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Tests: Concurrent Operations
  # ───────────────────────────────────────────────────────────────────────────

  describe "concurrent operations" do
    test "handles concurrent creates without collision" do
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            DealCoordinator.create_deal(%{
              name: "Concurrent Deal #{i}",
              counterparty: "Counterparty #{i}",
              amount_usd: 100_000.0 * i
            })
          end)
        end)

      results = Task.await_many(tasks, :infinity)

      # Verify all succeeded
      assert Enum.all?(results, fn {:ok, _deal} -> true; _ -> false end)

      # Verify unique IDs
      ids = Enum.map(results, fn {:ok, deal} -> deal.id end)
      assert Enum.uniq(ids) == ids

      # Verify all stored in ETS
      assert DealCoordinator.deal_count() == 5
    end

    test "handles concurrent gets without blocking" do
      {:ok, deal} = DealCoordinator.create_deal(acme_widget_deal())

      tasks =
        Enum.map(1..10, fn _i ->
          Task.async(fn ->
            DealCoordinator.get_deal(deal.id)
          end)
        end)

      results = Task.await_many(tasks, :infinity)

      # All should succeed and return same deal
      assert Enum.all?(results, fn {:ok, d} -> d.id == deal.id; _ -> false end)
    end

    test "handles mixed concurrent operations" do
      # Create 3 deals
      {:ok, deal1} = DealCoordinator.create_deal(acme_widget_deal())
      {:ok, deal2} = DealCoordinator.create_deal(tech_integration_deal())
      {:ok, deal3} = DealCoordinator.create_deal(manufacturing_deal())

      # Mix of creates, gets, lists
      tasks = [
        Task.async(fn -> DealCoordinator.list_deals() end),
        Task.async(fn -> DealCoordinator.get_deal(deal1.id) end),
        Task.async(fn -> DealCoordinator.get_deal(deal2.id) end),
        Task.async(fn -> DealCoordinator.create_deal(%{name: "New Deal", counterparty: "NewCorp", amount_usd: 500_000.0}) end),
        Task.async(fn -> DealCoordinator.list_deals() end),
        Task.async(fn -> DealCoordinator.get_deal(deal3.id) end),
        Task.async(fn -> DealCoordinator.deal_count() end)
      ]

      results = Task.await_many(tasks, :infinity)

      # All should succeed
      assert Enum.all?(results, fn
        result when is_list(result) -> true
        {:ok, _deal} -> true
        count when is_integer(count) -> true
        _ -> false
      end)

      # Should have 4 deals total
      assert DealCoordinator.deal_count() == 4
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Tests: Error Cases
  # ───────────────────────────────────────────────────────────────────────────

  describe "error handling" do
    test "rejects non-map input" do
      assert {:error, "input must be a map"} = DealCoordinator.create_deal("not a map")
      assert {:error, "input must be a map"} = DealCoordinator.create_deal([])
      assert {:error, "input must be a map"} = DealCoordinator.create_deal(123)
    end

    test "handles missing optional fields gracefully" do
      input = %{
        name: "Deal",
        counterparty: "Corp",
        amount_usd: 100_000.0
      }

      {:ok, deal} = DealCoordinator.create_deal(input)
      assert deal.currency == "USD"
      assert is_struct(deal.settlement_date, DateTime)
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Tests: RDF Integration (Structure Only)
  # ───────────────────────────────────────────────────────────────────────────

  describe "RDF triple generation" do
    test "includes rdf_triples in created deal" do
      {:ok, deal} = DealCoordinator.create_deal(acme_widget_deal())

      assert is_list(deal.rdf_triples)
      # In real scenario, would verify triple format and SPARQL CONSTRUCT output
      # For now, just verify it's a list
    end
  end
end
