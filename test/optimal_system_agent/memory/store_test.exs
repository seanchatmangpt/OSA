defmodule OptimalSystemAgent.Memory.StoreTest do
  @moduledoc """
  Unit tests for Memory.Store module.

  Tests ETS + SQLite persistence layer for memory entries.
  Real ETS operations, no mocks.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Memory.Store

  @moduletag :capture_log

  setup do
    # Ensure a clean table for each test
    table_name = :memory_store_test
    Store.init_table(table_name, "./test_memory.db")
    :ets.delete_all_objects(table_name)
    :ok
  end

  describe "init_table/2" do
    test "creates ETS table with given name" do
      table_name = :test_table
      assert {:ok, ^table_name} = Store.init_table(table_name, "./test.db")
      assert :ets.whereis(table_name) != :undefined
      :ets.delete(table_name)
    end

    test "returns existing table if already created" do
      table_name = :test_table_existing
      assert {:ok, ^table_name} = Store.init_table(table_name, "./test.db")
      assert {:ok, ^table_name} = Store.init_table(table_name, "./test.db")
      :ets.delete(table_name)
    end

    test "table is :set type" do
      table_name = :test_table_type
      {:ok, ^table_name} = Store.init_table(table_name, "./test.db")
      info = :ets.table_info(table_name, :type)
      assert info == :set
      :ets.delete(table_name)
    end

    test "table is :public" do
      table_name = :test_table_protection
      {:ok, ^table_name} = Store.init_table(table_name, "./test.db")
      info = :ets.table_info(table_name, :protection)
      assert info == :public
      :ets.delete(table_name)
    end
  end

  describe "insert/3" do
    test "inserts entry into ETS table" do
      table_name = :memory_store_test
      entry = %{
        id: "test_1",
        content: "Test content",
        keywords: "test",
        category: "decision"
      }
      assert {:ok, "test_1"} = Store.insert(table_name, "test_1", entry)
      assert [{^table_name, {"test_1", _}}] = :ets.lookup(table_name, "test_1")
    end

    test "returns error for duplicate ID" do
      table_name = :memory_store_test
      entry = %{id: "test_dup", content: "test", keywords: "test", category: "decision"}
      assert {:ok, "test_dup"} = Store.insert(table_name, "test_dup", entry)
      assert {:error, :exists} = Store.insert(table_name, "test_dup", entry)
    end

    test "adds timestamp to entry" do
      table_name = :memory_store_test
      entry = %{content: "test", keywords: "test", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)
      [{_, {^id, retrieved}}] = :ets.lookup(table_name, id)
      assert Map.has_key?(retrieved, :created_at) or Map.has_key?(retrieved, "created_at")
    end
  end

  describe "get/2" do
    test "retrieves entry by ID" do
      table_name = :memory_store_test
      entry = %{content: "test content", keywords: "test", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)
      assert {:ok, retrieved} = Store.get(table_name, id)
      assert retrieved.content == "test content"
    end

    test "returns error for non-existent entry" do
      table_name = :memory_store_test
      assert {:error, :not_found} = Store.get(table_name, "nonexistent")
    end

    test "returns error for nil ID" do
      table_name = :memory_store_test
      assert {:error, :not_found} = Store.get(table_name, nil)
    end
  end

  describe "update/3" do
    test "updates existing entry" do
      table_name = :memory_store_test
      entry = %{content: "original", keywords: "test", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)
      assert {:ok, _} = Store.update(table_name, id, %{content: "updated"})
      assert {:ok, retrieved} = Store.get(table_name, id)
      assert retrieved.content == "updated"
    end

    test "returns error for non-existent entry" do
      table_name = :memory_store_test
      assert {:error, :not_found} = Store.update(table_name, "nonexistent", %{content: "test"})
    end

    test "merges update with existing data" do
      table_name = :memory_store_test
      entry = %{content: "test", keywords: "original", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)
      assert {:ok, _} = Store.update(table_name, id, %{keywords: "updated"})
      assert {:ok, retrieved} = Store.get(table_name, id)
      assert retrieved.content == "test"  # Original preserved
      assert retrieved.keywords == "updated"  # Updated
    end
  end

  describe "delete/2" do
    test "removes entry from ETS" do
      table_name = :memory_store_test
      entry = %{content: "test", keywords: "test", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)
      assert :ok = Store.delete(table_name, id)
      assert {:error, :not_found} = Store.get(table_name, id)
    end

    test "returns :ok for non-existent entry" do
      table_name = :memory_store_test
      assert :ok = Store.delete(table_name, "nonexistent")
    end
  end

  describe "list/1" do
    test "returns all entries in table" do
      table_name = :list_test_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_list.db")

      entry1 = %{content: "test1", keywords: "test", category: "decision"}
      entry2 = %{content: "test2", keywords: "test", category: "preference"}
      assert {:ok, _} = Store.insert(table_name, nil, entry1)
      assert {:ok, _} = Store.insert(table_name, nil, entry2)

      entries = Store.list(table_name)
      assert length(entries) == 2
      :ets.delete(table_name)
    end

    test "returns empty list for empty table" do
      table_name = :empty_list_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_empty.db")
      assert Store.list(table_name) == []
      :ets.delete(table_name)
    end
  end

  describe "search/3" do
    test "finds entries by keyword" do
      table_name = :search_test_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_search.db")

      entry1 = %{content: "test1", keywords: "elixir,testing", category: "decision"}
      entry2 = %{content: "test2", keywords: "rust,performance", category: "decision"}
      assert {:ok, _} = Store.insert(table_name, nil, entry1)
      assert {:ok, _} = Store.insert(table_name, nil, entry2)

      results = Store.search(table_name, "elixir", 0.5)
      assert length(results) >= 1
      :ets.delete(table_name)
    end

    test "returns empty list when no matches" do
      table_name = :search_empty_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_search_empty.db")

      entry = %{content: "test", keywords: "elixir", category: "decision"}
      assert {:ok, _} = Store.insert(table_name, nil, entry)

      results = Store.search(table_name, "nonexistent", 0.9)
      assert results == []
      :ets.delete(table_name)
    end

    test "respects similarity threshold" do
      table_name = :threshold_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_threshold.db")

      entry = %{content: "test", keywords: "elixir", category: "decision"}
      assert {:ok, _} = Store.insert(table_name, nil, entry)

      high_results = Store.search(table_name, "elixir,testing", 0.9)
      low_results = Store.search(table_name, "elixir,testing", 0.1)

      assert length(low_results) >= length(high_results)
      :ets.delete(table_name)
    end
  end

  describe "count/1" do
    test "returns number of entries in table" do
      table_name = :count_test_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_count.db")

      assert Store.count(table_name) == 0

      for i <- 1..5 do
        Store.insert(table_name, nil, %{content: "test#{i}", keywords: "test", category: "decision"})
      end

      assert Store.count(table_name) == 5
      :ets.delete(table_name)
    end
  end

  describe "clear/1" do
    test "removes all entries from table" do
      table_name = :clear_test_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_clear.db")

      for i <- 1..3 do
        Store.insert(table_name, nil, %{content: "test#{i}", keywords: "test", category: "decision"})
      end

      assert Store.count(table_name) == 3
      assert :ok = Store.clear(table_name)
      assert Store.count(table_name) == 0
      :ets.delete(table_name)
    end
  end

  describe "edge cases" do
    test "handles entry with unicode content" do
      table_name = :unicode_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_unicode.db")

      entry = %{content: "测试内容", keywords: "测试,中文", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)
      assert {:ok, retrieved} = Store.get(table_name, id)
      assert retrieved.content == "测试内容"
      :ets.delete(table_name)
    end

    test "handles entry with empty keywords" do
      table_name = :empty_keywords_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_empty_kw.db")

      entry = %{content: "test", keywords: "", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)
      assert {:ok, retrieved} = Store.get(table_name, id)
      assert retrieved.keywords == ""
      :ets.delete(table_name)
    end

    test "handles very long content" do
      table_name = :long_content_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_long.db")

      long_content = String.duplicate("test ", 1000)
      entry = %{content: long_content, keywords: "test", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)
      assert {:ok, retrieved} = Store.get(table_name, id)
      assert retrieved.content == long_content
      :ets.delete(table_name)
    end
  end

  describe "integration" do
    test "full CRUD lifecycle" do
      table_name = :crud_table
      {:ok, ^table_name} = Store.init_table(table_name, "./test_crud.db")

      # Create
      entry = %{content: "CRUD test", keywords: "test,crud", category: "decision"}
      assert {:ok, id} = Store.insert(table_name, nil, entry)

      # Read
      assert {:ok, retrieved} = Store.get(table_name, id)
      assert retrieved.content == "CRUD test"

      # Update
      assert {:ok, _} = Store.update(table_name, id, %{content: "Updated"})
      assert {:ok, updated} = Store.get(table_name, id)
      assert updated.content == "Updated"

      # Search
      results = Store.search(table_name, "crud", 0.5)
      assert length(results) >= 1

      # Delete
      assert :ok = Store.delete(table_name, id)
      assert {:error, :not_found} = Store.get(table_name, id)
      :ets.delete(table_name)
    end
  end
end
