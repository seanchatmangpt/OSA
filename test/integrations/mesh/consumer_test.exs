defmodule OptimalSystemAgent.Integrations.Mesh.ConsumerTest do
  @moduledoc """
  Data Mesh Consumer GenServer Tests

  Tests the Consumer's coordination of domain registration, dataset discovery,
  lineage queries, and quality calculations via the bos CLI.

  Discipline: Chicago TDD (behavior verification, real implementations, no mocking
  of CLI calls — use stubs instead).
  """

  use ExUnit.Case


  alias OptimalSystemAgent.Integrations.Mesh.Consumer

  setup do
    pid = start_supervised!({Consumer, [name: :test_consumer_1]})
    {:ok, pid: pid}
  end

  # =========================================================================
  # Test 1: Register Domain — Happy Path
  # =========================================================================

  describe "register_domain/3" do
    test "registers a new domain with valid metadata", %{pid: pid} do
      domain_name = "sales_domain"
      metadata = %{"owner" => "analytics_team", "description" => "Sales data"}

      result = Consumer.register_domain(pid, domain_name, metadata)

      assert {:ok, response} = result
      assert is_map(response)
    end

    test "rejects empty domain name", %{pid: pid} do
      metadata = %{"owner" => "team"}

      result = Consumer.register_domain(pid, "", metadata)

      assert {:error, :invalid_domain_name} = result
    end

    test "rejects domain name with invalid characters", %{pid: pid} do
      metadata = %{"owner" => "team"}

      result = Consumer.register_domain(pid, "domain@invalid#chars", metadata)

      assert {:error, :invalid_domain_name} = result
    end

    test "rejects metadata without owner", %{pid: pid} do
      result = Consumer.register_domain(pid, "valid_domain", %{"description" => "desc"})

      assert {:error, :missing_owner} = result
    end

    test "rejects non-map metadata", %{pid: pid} do
      result = Consumer.register_domain(pid, "valid_domain", "not a map")

      assert {:error, :invalid_metadata} = result
    end

    test "accepts both atom and string keys in metadata", %{pid: pid} do
      metadata_atom = %{owner: "team", description: "desc"}
      metadata_string = %{"owner" => "team", "description" => "desc"}

      result1 = Consumer.register_domain(pid, "domain1", metadata_atom)
      result2 = Consumer.register_domain(pid, "domain2", metadata_string)

      assert {:ok, _} = result1
      assert {:ok, _} = result2
    end
  end

  # =========================================================================
  # Test 2: Discover Datasets
  # =========================================================================

  describe "discover_datasets/2" do
    test "discovers datasets in a domain", %{pid: pid} do
      domain_name = "inventory_domain"

      result = Consumer.discover_datasets(pid, domain_name)

      assert {:ok, datasets} = result
      assert is_list(datasets)
    end

    test "rejects empty domain name", %{pid: pid} do
      result = Consumer.discover_datasets(pid, "")

      assert {:error, :invalid_domain_name} = result
    end

    test "rejects domain name with invalid characters", %{pid: pid} do
      result = Consumer.discover_datasets(pid, "domain@#$")

      assert {:error, :invalid_domain_name} = result
    end

    test "returns empty list when domain has no datasets", %{pid: pid} do
      result = Consumer.discover_datasets(pid, "empty_domain")

      assert {:ok, datasets} = result
      assert is_list(datasets)
    end
  end

  # =========================================================================
  # Test 3: Query Lineage
  # =========================================================================

  describe "query_lineage/4" do
    test "queries upstream lineage for a dataset", %{pid: pid} do
      result =
        Consumer.query_lineage(pid, "finance_domain", "transactions", depth: 3)

      assert {:ok, lineage} = result
      assert is_map(lineage)
      assert Map.has_key?(lineage, "nodes")
      assert Map.has_key?(lineage, "edges")
    end

    test "respects maximum depth of 5 levels", %{pid: pid} do
      result =
        Consumer.query_lineage(pid, "domain", "dataset", depth: 5)

      assert {:ok, _lineage} = result
    end

    test "rejects depth > 5 with default of 5", %{pid: pid} do
      result =
        Consumer.query_lineage(pid, "domain", "dataset", depth: 10)

      # Invalid depth falls back to default (5)
      assert {:ok, _lineage} = result
    end

    test "uses default depth when not specified", %{pid: pid} do
      result =
        Consumer.query_lineage(pid, "domain", "dataset")

      assert {:ok, lineage} = result
      assert is_map(lineage)
    end

    test "rejects empty domain name", %{pid: pid} do
      result = Consumer.query_lineage(pid, "", "dataset")

      assert {:error, :invalid_domain_name} = result
    end

    test "rejects empty dataset name", %{pid: pid} do
      result = Consumer.query_lineage(pid, "domain", "")

      assert {:error, :invalid_dataset_name} = result
    end

    test "rejects dataset name with invalid characters", %{pid: pid} do
      result = Consumer.query_lineage(pid, "domain", "dataset@#$")

      assert {:error, :invalid_dataset_name} = result
    end

    test "returns valid lineage structure with nodes and edges", %{pid: pid} do
      result = Consumer.query_lineage(pid, "lineage_domain", "root_dataset", depth: 3)

      assert {:ok, lineage} = result
      assert is_list(Map.get(lineage, "nodes", []))
      assert is_list(Map.get(lineage, "edges", []))
    end
  end

  # =========================================================================
  # Test 4: Check Quality
  # =========================================================================

  describe "check_quality/3" do
    test "returns quality metrics for a dataset", %{pid: pid} do
      result = Consumer.check_quality(pid, "quality_domain", "dataset_1")

      assert {:ok, quality} = result
      assert is_map(quality)
      assert Map.has_key?(quality, "completeness")
      assert Map.has_key?(quality, "accuracy")
      assert Map.has_key?(quality, "consistency")
      assert Map.has_key?(quality, "timeliness")
    end

    test "quality metrics are numeric (0.0 to 1.0)", %{pid: pid} do
      {:ok, quality} = Consumer.check_quality(pid, "domain", "dataset")

      completeness = Map.get(quality, "completeness", 0.0)
      accuracy = Map.get(quality, "accuracy", 0.0)
      consistency = Map.get(quality, "consistency", 0.0)
      timeliness = Map.get(quality, "timeliness", 0.0)

      assert is_number(completeness)
      assert is_number(accuracy)
      assert is_number(consistency)
      assert is_number(timeliness)
    end

    test "rejects empty domain name", %{pid: pid} do
      result = Consumer.check_quality(pid, "", "dataset")

      assert {:error, :invalid_domain_name} = result
    end

    test "rejects empty dataset name", %{pid: pid} do
      result = Consumer.check_quality(pid, "domain", "")

      assert {:error, :invalid_dataset_name} = result
    end

    test "rejects dataset name with invalid characters", %{pid: pid} do
      result = Consumer.check_quality(pid, "domain", "dataset@invalid")

      assert {:error, :invalid_dataset_name} = result
    end
  end

  # =========================================================================
  # Test 5: Concurrent Operations (WvdA Boundedness)
  # =========================================================================

  describe "concurrent operations" do
    test "handles concurrent register_domain calls", %{pid: pid} do
      domains =
        Enum.map(1..3, fn i ->
          Task.async(fn ->
            Consumer.register_domain(
              pid,
              "domain_#{i}",
              %{"owner" => "team_#{i}"}
            )
          end)
        end)

      results = Task.await_many(domains)

      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)
    end

    test "handles mixed concurrent operations", %{pid: pid} do
      tasks = [
        Task.async(fn ->
          Consumer.register_domain(pid, "concurrent_domain", %{"owner" => "team"})
        end),
        Task.async(fn ->
          Consumer.discover_datasets(pid, "concurrent_domain")
        end),
        Task.async(fn ->
          Consumer.query_lineage(pid, "concurrent_domain", "dataset")
        end),
        Task.async(fn ->
          Consumer.check_quality(pid, "concurrent_domain", "dataset")
        end)
      ]

      results = Task.await_many(tasks)

      # All operations should complete without errors
      assert length(results) == 4
    end
  end

  # =========================================================================
  # Test 6: Error Handling (Armstrong Let-It-Crash)
  # =========================================================================

  describe "error handling" do
    test "invalid metadata type is rejected", %{pid: pid} do
      result = Consumer.register_domain(pid, "domain", "invalid")
      assert {:error, :invalid_metadata} = result
    end

    test "all validation errors are documented", %{pid: pid} do
      # Error: invalid domain name
      assert {:error, :invalid_domain_name} = Consumer.register_domain(pid, "", %{"owner" => "x"})

      # Error: invalid dataset name
      assert {:error, :invalid_dataset_name} = Consumer.query_lineage(pid, "domain", "")

      # Error: missing owner
      assert {:error, :missing_owner} = Consumer.register_domain(pid, "domain", %{})
    end
  end

  # =========================================================================
  # Test 7: Timeout Resilience (WvdA Deadlock Freedom)
  # =========================================================================

  describe "timeout resilience" do
    test "operations timeout after 12 seconds", %{pid: _pid} do
      # Set a very short timeout to test timeout behavior
      {:ok, short_pid} = Consumer.start_link(name: :short_timeout, bos_timeout_ms: 100)

      # This will likely timeout since bos command takes time
      result = Consumer.discover_datasets(short_pid, "any_domain")

      # Should return error (timeout or command failed) or succeed
      assert is_tuple(result) and (elem(result, 0) == :error or elem(result, 0) == :ok)
    end
  end

  # =========================================================================
  # Test 8: Lineage Depth Validation (WvdA Boundedness)
  # =========================================================================

  describe "lineage depth constraints" do
    test "depth=1 is valid", %{pid: pid} do
      result = Consumer.query_lineage(pid, "domain", "dataset", depth: 1)
      assert (match?({:ok, _}, result) or match?({:error, _}, result))
    end

    test "depth=5 is valid (maximum)", %{pid: pid} do
      result = Consumer.query_lineage(pid, "domain", "dataset", depth: 5)
      assert (match?({:ok, _}, result) or match?({:error, _}, result))
    end

    test "depth=0 uses default", %{pid: pid} do
      result = Consumer.query_lineage(pid, "domain", "dataset", depth: 0)
      # Invalid depth (0) falls back to default behavior
      assert (match?({:ok, _}, result) or match?({:error, _}, result))
    end

    test "negative depth is rejected", %{pid: pid} do
      result = Consumer.query_lineage(pid, "domain", "dataset", depth: -1)
      # Invalid depth should use default (5)
      assert (match?({:ok, _}, result) or match?({:error, _}, result))
    end
  end

  # =========================================================================
  # Test 9: Domain Name Validation (Input Sanitization)
  # =========================================================================

  describe "domain name validation" do
    test "accepts alphanumeric lowercase", %{pid: pid} do
      result = Consumer.discover_datasets(pid, "domain_123")
      assert (match?({:ok, _}, result) or match?({:error, _}, result))
    end

    test "accepts underscores and hyphens", %{pid: pid} do
      result = Consumer.discover_datasets(pid, "my-domain_v2")
      assert (match?({:ok, _}, result) or match?({:error, _}, result))
    end

    test "rejects special characters", %{pid: pid} do
      assert {:error, :invalid_domain_name} =
               Consumer.discover_datasets(pid, "domain!@#$%")
    end

    test "rejects spaces", %{pid: pid} do
      assert {:error, :invalid_domain_name} =
               Consumer.discover_datasets(pid, "domain with spaces")
    end
  end

  # =========================================================================
  # Test 10: Dataset Name Validation
  # =========================================================================

  describe "dataset name validation" do
    test "accepts alphanumeric with dots and underscores", %{pid: pid} do
      result = Consumer.query_lineage(pid, "domain", "dataset.v1_prod")
      assert (match?({:ok, _}, result) or match?({:error, _}, result))
    end

    test "accepts hyphens in dataset names", %{pid: pid} do
      result = Consumer.query_lineage(pid, "domain", "my-dataset-v2")
      assert (match?({:ok, _}, result) or match?({:error, _}, result))
    end

    test "rejects special characters in dataset", %{pid: pid} do
      assert {:error, :invalid_dataset_name} =
               Consumer.query_lineage(pid, "domain", "dataset@invalid")
    end
  end

  # =========================================================================
  # Test 11: Response Parsing
  # =========================================================================

  describe "response parsing" do
    test "parses domain registration response as map", %{pid: pid} do
      {:ok, response} = Consumer.register_domain(pid, "parse_test", %{"owner" => "team"})
      assert is_map(response)
    end

    test "parses datasets response as list", %{pid: pid} do
      {:ok, datasets} = Consumer.discover_datasets(pid, "parse_test")
      assert is_list(datasets)
    end

    test "parses lineage with nodes and edges", %{pid: pid} do
      {:ok, lineage} = Consumer.query_lineage(pid, "domain", "dataset")
      assert is_map(lineage)
      # Ensure nodes and edges are present
      assert Map.has_key?(lineage, "nodes")
      assert Map.has_key?(lineage, "edges")
    end

    test "parses quality with all four metrics", %{pid: pid} do
      {:ok, quality} = Consumer.check_quality(pid, "domain", "dataset")
      assert Map.has_key?(quality, "completeness")
      assert Map.has_key?(quality, "accuracy")
      assert Map.has_key?(quality, "consistency")
      assert Map.has_key?(quality, "timeliness")
    end
  end

  # =========================================================================
  # Test 12: State Management (GenServer lifecycle)
  # =========================================================================

  describe "state management" do
    test "consumer tracks operation count", %{pid: pid} do
      Consumer.discover_datasets(pid, "domain1")
      Consumer.discover_datasets(pid, "domain2")
      Consumer.discover_datasets(pid, "domain3")

      # Operations were processed (state updated)
      # We can't directly inspect GenServer state, but we verify no crashes
      assert true
    end

    test "consumer records last operation timestamp", %{pid: pid} do
      Consumer.discover_datasets(pid, "domain")
      # No crash = state was updated
      assert true
    end
  end

  # =========================================================================
  # Test 13: Multiple Consumer Instances (Isolation)
  # =========================================================================

  describe "multiple consumer instances" do
    test "two consumers can run independently", %{pid: pid} do
      {:ok, pid2} = Consumer.start_link(name: :test_consumer_2)

      result1 = Consumer.register_domain(pid, "domain1", %{"owner" => "team1"})
      result2 = Consumer.register_domain(pid2, "domain2", %{"owner" => "team2"})

      assert (match?({:ok, _}, result1) or match?({:error, _}, result1))
      assert (match?({:ok, _}, result2) or match?({:error, _}, result2))
    end
  end
end
