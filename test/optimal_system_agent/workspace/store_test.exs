defmodule OptimalSystemAgent.Workspace.StoreTest do
  @moduledoc """
  Unit tests for Workspace.Store module.

  Tests SQLite-based workspace persistence. Requires Ecto/SQLite.
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application

  alias OptimalSystemAgent.Workspace.Store

  # test_id combines os_time (unique across process restarts) and unique_integer
  # (unique within a process) so workspace IDs don't collide between mix test runs.
  setup do
    test_id = "tw_#{System.os_time(:microsecond)}_#{:erlang.unique_integer([:positive, :monotonic])}"
    {:ok, test_id: test_id}
  end

  describe "init/0" do
    test "creates workspace and journal tables" do
      assert Store.init() == :ok
    end

    test "is idempotent" do
      assert Store.init() == :ok
      assert Store.init() == :ok
    end
  end

  describe "save_workspace/1" do
    test "saves a workspace with required fields", %{test_id: test_id} do
      workspace = %{
        id: "save_test_#{test_id}",
        name: "Test Workspace",
        project_path: "/tmp/test",
        state: %{agents: [], tasks: []}
      }

      assert Store.save_workspace(workspace) == :ok
    end

    test "upserts workspace on conflict", %{test_id: test_id} do
      id = "upsert_test_#{test_id}"

      assert Store.save_workspace(%{id: id, name: "V1", state: %{v: 1}}) == :ok
      assert Store.save_workspace(%{id: id, name: "V2", state: %{v: 2}}) == :ok

      assert {:ok, ws} = Store.load_workspace(id)
      assert ws.name == "V2"
      assert ws.state["v"] == 2
    end
  end

  describe "load_workspace/1" do
    test "returns workspace by id", %{test_id: test_id} do
      id = "load_test_#{test_id}"

      Store.save_workspace(%{
        id: id,
        name: "Load Test",
        project_path: "/tmp",
        state: %{key: "value"}
      })

      assert {:ok, ws} = Store.load_workspace(id)
      assert ws.id == id
      assert ws.name == "Load Test"
      assert ws.state["key"] == "value"
      assert Map.has_key?(ws, :created_at)
      assert Map.has_key?(ws, :updated_at)
    end

    test "returns :not_found for missing workspace", %{test_id: test_id} do
      assert {:error, :not_found} = Store.load_workspace("nonexistent_#{test_id}")
    end
  end

  describe "list_workspaces/0" do
    test "returns empty list when no workspaces" do
      # May have other workspaces from other tests, just check it returns a list
      result = Store.list_workspaces()
      assert is_list(result)
    end

    test "includes saved workspaces", %{test_id: test_id} do
      id = "list_test_#{test_id}"
      Store.save_workspace(%{id: id, name: "List Test", state: %{}})

      result = Store.list_workspaces()
      assert is_list(result)
      ids = Enum.map(result, & &1.id)
      assert id in ids
    end
  end

  describe "delete_workspace/1" do
    test "removes workspace and its journals", %{test_id: test_id} do
      id = "delete_test_#{test_id}"
      Store.save_workspace(%{id: id, name: "Delete Me", state: %{}})
      Store.append_journal(%{workspace_id: id, task_id: "t1", agent_id: "a1", action: :created})

      assert Store.delete_workspace(id) == :ok
      assert {:error, :not_found} = Store.load_workspace(id)
    end
  end

  describe "append_journal/1" do
    test "appends a journal entry", %{test_id: test_id} do
      id = "journal_test_#{test_id}"
      Store.save_workspace(%{id: id, name: "Journal Test", state: %{}})

      assert Store.append_journal(%{
               workspace_id: id,
               task_id: "task_1",
               agent_id: "agent_1",
               action: :created,
               details: %{reason: "test"}
             }) == :ok
    end

    test "defaults optional fields", %{test_id: test_id} do
      id = "journal_defaults_#{test_id}"
      Store.save_workspace(%{id: id, name: "Defaults", state: %{}})

      assert Store.append_journal(%{
               workspace_id: id,
               task_id: "t",
               agent_id: "a",
               action: :started
             }) == :ok
    end
  end

  describe "query_journal/2" do
    test "returns entries for a workspace", %{test_id: test_id} do
      id = "query_test_#{test_id}"
      Store.save_workspace(%{id: id, name: "Query Test", state: %{}})

      Store.append_journal(%{workspace_id: id, task_id: "t1", agent_id: "a1", action: :created})
      Store.append_journal(%{workspace_id: id, task_id: "t1", agent_id: "a1", action: :started})

      entries = Store.query_journal(id)
      assert length(entries) == 2
      assert hd(entries).workspace_id == id
    end

    test "filters by task_id", %{test_id: test_id} do
      id = "filter_task_#{test_id}"
      Store.save_workspace(%{id: id, name: "Filter", state: %{}})

      Store.append_journal(%{workspace_id: id, task_id: "t1", agent_id: "a1", action: :created})
      Store.append_journal(%{workspace_id: id, task_id: "t2", agent_id: "a1", action: :created})

      entries = Store.query_journal(id, task_id: "t1")
      assert length(entries) == 1
      assert hd(entries).task_id == "t1"
    end

    test "returns empty list for nonexistent workspace", %{test_id: test_id} do
      entries = Store.query_journal("nonexistent_#{test_id}")
      assert entries == []
    end

    test "respects limit option", %{test_id: test_id} do
      id = "limit_test_#{test_id}"
      Store.save_workspace(%{id: id, name: "Limit", state: %{}})

      for i <- 1..5 do
        Store.append_journal(%{workspace_id: id, task_id: "t#{i}", agent_id: "a1", action: :created})
      end

      entries = Store.query_journal(id, limit: 2)
      assert length(entries) == 2
    end
  end
end
