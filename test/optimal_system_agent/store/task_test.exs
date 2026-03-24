defmodule OptimalSystemAgent.Store.TaskTest do
  @moduledoc """
  Chicago TDD unit tests for Store.Task module.

  Tests Ecto schema for task_queue records.
  Real Ecto changesets, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Store.Task

  @moduletag :capture_log

  @valid_statuses ~w(pending leased completed failed)

  describe "changeset/2" do
    test "validates required fields" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1"
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?
    end

    test "requires task_id field" do
      attrs = %{
        agent_id: "agent_1"
      }
      changeset = Task.changeset(%Task{}, attrs)
      refute changeset.valid?
    end

    test "requires agent_id field" do
      attrs = %{
        task_id: "task_1"
      }
      changeset = Task.changeset(%Task{}, attrs)
      refute changeset.valid?
    end

    test "validates status is in allowed list" do
      for status <- @valid_statuses do
        attrs = %{
          task_id: "task_#{status}",
          agent_id: "agent_1",
          status: status
        }
        changeset = Task.changeset(%Task{}, attrs)
        assert changeset.valid?, "Status #{status} should be valid"
      end
    end

    test "rejects invalid status" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        status: "invalid_status"
      }
      changeset = Task.changeset(%Task{}, attrs)
      refute changeset.valid?
    end

    test "defaults status to pending" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1"
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :status) == "pending"
    end

    test "defaults payload to empty map" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1"
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :payload) == %{}
    end

    test "defaults attempts to 0" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1"
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :attempts) == 0
    end

    test "defaults max_attempts to 3" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1"
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :max_attempts) == 3
    end

    test "validates attempts is non-negative" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        attempts: 2
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?
    end

    test "rejects negative attempts" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        attempts: -1
      }
      changeset = Task.changeset(%Task{}, attrs)
      refute changeset.valid?
    end

    test "validates max_attempts is positive" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        max_attempts: 5
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?
    end

    test "rejects max_attempts of 0" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        max_attempts: 0
      }
      changeset = Task.changeset(%Task{}, attrs)
      refute changeset.valid?
    end

    test "rejects negative max_attempts" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        max_attempts: -1
      }
      changeset = Task.changeset(%Task{}, attrs)
      refute changeset.valid?
    end
  end

  describe "to_map/1" do
    test "converts Task struct to map with atom status" do
      task = %Task{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: %{"input" => "test"},
        status: "pending",
        attempts: 0,
        max_attempts: 3,
        inserted_at: DateTime.utc_now()
      }
      map = Task.to_map(task)
      assert is_map(map)
      assert map.status == :pending
      assert map.task_id == "task_1"
      assert map.agent_id == "agent_1"
    end

    test "converts completed status string to atom" do
      now = DateTime.utc_now()
      task = %Task{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: %{},
        status: "completed",
        result: %{"output" => "success"},
        completed_at: now,
        inserted_at: now
      }
      map = Task.to_map(task)
      assert map.status == :completed
      assert map.result == %{"output" => "success"}
    end

    test "converts failed status string to atom" do
      now = DateTime.utc_now()
      task = %Task{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: %{},
        status: "failed",
        error: "Task failed",
        inserted_at: now
      }
      map = Task.to_map(task)
      assert map.status == :failed
      assert map.error == "Task failed"
    end

    test "converts leased status string to atom" do
      now = DateTime.utc_now()
      leased_until = DateTime.utc_now() |> DateTime.add(300)
      task = %Task{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: %{},
        status: "leased",
        leased_until: leased_until,
        leased_by: "agent_2",
        inserted_at: now
      }
      map = Task.to_map(task)
      assert map.status == :leased
      assert map.leased_until == leased_until
      assert map.leased_by == "agent_2"
    end

    test "handles nil payload" do
      now = DateTime.utc_now()
      task = %Task{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: nil,
        status: "pending",
        inserted_at: now
      }
      map = Task.to_map(task)
      assert map.payload == %{}
    end

    test "converts NaiveDateTime to DateTime" do
      ndt = NaiveDateTime.utc_now()
      task = %Task{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: %{},
        status: "pending",
        inserted_at: ndt
      }
      map = Task.to_map(task)
      assert %DateTime{} = map.created_at
    end
  end

  describe "from_map/1" do
    test "converts map with atom status to Task attrs" do
      map = %{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: %{"input" => "test"},
        status: :pending,
        attempts: 0
      }
      attrs = Task.from_map(map)
      assert attrs.task_id == "task_1"
      assert attrs.agent_id == "agent_1"
      assert attrs.status == "pending"
      assert attrs.payload == %{"input" => "test"}
      assert attrs.attempts == 0
    end

    test "converts atom status to string" do
      map = %{
        task_id: "task_1",
        agent_id: "agent_1",
        status: :completed
      }
      attrs = Task.from_map(map)
      assert attrs.status == "completed"
    end

    test "converts failed atom status to string" do
      map = %{
        task_id: "task_1",
        agent_id: "agent_1",
        status: :failed
      }
      attrs = Task.from_map(map)
      assert attrs.status == "failed"
    end

    test "handles string keys in map" do
      map = %{
        "task_id" => "task_1",
        "agent_id" => "agent_1",
        "status" => :pending
      }
      attrs = Task.from_map(map)
      assert attrs.task_id == "task_1"
      assert attrs.agent_id == "agent_1"
      assert attrs.status == "pending"
    end

    test "handles mixed atom and string keys" do
      map = %{
        "agent_id" => "agent_1",
        task_id: "task_1",
        status: :pending
      }
      attrs = Task.from_map(map)
      assert attrs.task_id == "task_1"
      assert attrs.agent_id == "agent_1"
      assert attrs.status == "pending"
    end

    test "defaults missing fields" do
      map = %{
        task_id: "task_1",
        agent_id: "agent_1"
      }
      attrs = Task.from_map(map)
      assert attrs.status == "pending"
      assert attrs.payload == %{}
      assert attrs.attempts == 0
      assert attrs.max_attempts == 3
    end
  end

  describe "struct fields" do
    test "has task_id field" do
      task = %Task{task_id: "test", agent_id: "agent"}
      assert task.task_id == "test"
    end

    test "has agent_id field" do
      task = %Task{task_id: "test", agent_id: "agent"}
      assert task.agent_id == "agent"
    end

    test "has payload field" do
      task = %Task{task_id: "test", agent_id: "agent", payload: %{"key" => "value"}}
      assert task.payload == %{"key" => "value"}
    end

    test "has status field" do
      task = %Task{task_id: "test", agent_id: "agent", status: "pending"}
      assert task.status == "pending"
    end

    test "has leased_until field" do
      dt = DateTime.utc_now()
      task = %Task{task_id: "test", agent_id: "agent", leased_until: dt}
      assert task.leased_until == dt
    end

    test "has leased_by field" do
      task = %Task{task_id: "test", agent_id: "agent", leased_by: "agent_2"}
      assert task.leased_by == "agent_2"
    end

    test "has result field" do
      task = %Task{task_id: "test", agent_id: "agent", result: %{"output" => "test"}}
      assert task.result == %{"output" => "test"}
    end

    test "has error field" do
      task = %Task{task_id: "test", agent_id: "agent", error: "error message"}
      assert task.error == "error message"
    end

    test "has attempts field" do
      task = %Task{task_id: "test", agent_id: "agent", attempts: 2}
      assert task.attempts == 2
    end

    test "has max_attempts field" do
      task = %Task{task_id: "test", agent_id: "agent", max_attempts: 5}
      assert task.max_attempts == 5
    end

    test "has completed_at field" do
      dt = DateTime.utc_now()
      task = %Task{task_id: "test", agent_id: "agent", completed_at: dt}
      assert task.completed_at == dt
    end
  end

  describe "status_to_atom/1" do
    test "converts pending string to atom" do
      assert Task.status_to_atom("pending") == :pending
    end

    test "converts leased string to atom" do
      assert Task.status_to_atom("leased") == :leased
    end

    test "converts completed string to atom" do
      assert Task.status_to_atom("completed") == :completed
    end

    test "converts failed string to atom" do
      assert Task.status_to_atom("failed") == :failed
    end

    test "passes through atoms unchanged" do
      assert Task.status_to_atom(:pending) == :pending
      assert Task.status_to_atom(:completed) == :completed
    end
  end

  describe "status_to_string/1" do
    test "converts pending atom to string" do
      assert Task.status_to_string(:pending) == "pending"
    end

    test "converts leased atom to string" do
      assert Task.status_to_string(:leased) == "leased"
    end

    test "converts completed atom to string" do
      assert Task.status_to_string(:completed) == "completed"
    end

    test "converts failed atom to string" do
      assert Task.status_to_string(:failed) == "failed"
    end

    test "passes through strings unchanged" do
      assert Task.status_to_string("pending") == "pending"
      assert Task.status_to_string("completed") == "completed"
    end
  end

  describe "edge cases" do
    test "handles empty payload map" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: %{}
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?
    end

    test "handles unicode in agent_id" do
      attrs = %{
        task_id: "task_1",
        agent_id: "代理_1"
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?
    end

    test "handles unicode in error" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        error: "错误信息"
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?
    end

    test "handles complex payload structure" do
      complex_payload = %{
        "nested" => %{"key" => "value"},
        "list" => [1, 2, 3],
        "string" => "test"
      }
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: complex_payload
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?
    end

    test "handles nil optional fields" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        leased_until: nil,
        leased_by: nil,
        result: nil,
        error: nil,
        completed_at: nil
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?
    end
  end

  describe "integration" do
    test "full task lifecycle with conversions" do
      # Create from map
      map = %{
        task_id: "task_1",
        agent_id: "agent_1",
        payload: %{"input" => "test"},
        status: :pending,
        attempts: 0,
        max_attempts: 3
      }
      attrs = Task.from_map(map)

      # Create changeset
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?

      # Apply and convert back
      task = Ecto.Changeset.apply_changes(changeset)
      result_map = Task.to_map(task)

      assert result_map.task_id == "task_1"
      assert result_map.agent_id == "agent_1"
      assert result_map.status == :pending
      assert result_map.attempts == 0
      assert result_map.max_attempts == 3
    end

    test "completed task with result" do
      now = DateTime.utc_now()
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        status: "completed",
        result: %{"output" => "success"},
        completed_at: now
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?

      task = Ecto.Changeset.apply_changes(changeset)
      map = Task.to_map(task)

      assert map.status == :completed
      assert map.result == %{"output" => "success"}
      assert map.completed_at == now
    end

    test "failed task with error" do
      attrs = %{
        task_id: "task_1",
        agent_id: "agent_1",
        status: "failed",
        error: "Execution failed",
        attempts: 3
      }
      changeset = Task.changeset(%Task{}, attrs)
      assert changeset.valid?

      task = Ecto.Changeset.apply_changes(changeset)
      map = Task.to_map(task)

      assert map.status == :failed
      assert map.error == "Execution failed"
      assert map.attempts == 3
    end
  end
end
