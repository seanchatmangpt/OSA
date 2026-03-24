defmodule OptimalSystemAgent.Verification.CheckpointChicagoTDDTest do
  @moduledoc """
  Chicago TDD integration tests for Verification.Checkpoint.

  NO MOCKS. Tests real file I/O — real directories, real JSON files.
  Uses a temp directory via config override to avoid polluting ~/.osa/.

  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  setup do
    # Use a unique temp directory per test to avoid cross-test pollution
    tmp_dir = System.tmp_dir!() |> Path.join("osa_checkpoint_test_#{:erlang.unique_integer([:positive])}")
    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    original_dir = Application.get_env(:optimal_system_agent, :verification_checkpoint_dir)
    Application.put_env(:optimal_system_agent, :verification_checkpoint_dir, tmp_dir)

    on_exit(fn ->
      if original_dir do
        Application.put_env(:optimal_system_agent, :verification_checkpoint_dir, original_dir)
      else
        Application.delete_env(:optimal_system_agent, :verification_checkpoint_dir)
      end

      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "Checkpoint — save/2" do
    test "CRASH: save creates directory and writes JSON file", %{tmp_dir: tmp_dir} do
      assert :ok == OptimalSystemAgent.Verification.Checkpoint.save("test-loop-1", %{status: :running, iteration: 3})

      path = Path.join(tmp_dir, "test-loop-1.json")
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      {:ok, decoded} = Jason.decode(content)
      assert decoded["loop_id"] == "test-loop-1"
      assert decoded["status"] == "running"
      assert decoded["iteration"] == 3
    end

    test "CRASH: save adds checkpointed_at timestamp", %{tmp_dir: tmp_dir} do
      OptimalSystemAgent.Verification.Checkpoint.save("ts-test", %{foo: :bar})

      path = Path.join(tmp_dir, "ts-test.json")
      {:ok, content} = File.read(path)
      {:ok, decoded} = Jason.decode(content)

      assert Map.has_key?(decoded, "checkpointed_at")
      {:ok, _datetime} = DateTime.from_iso8601(decoded["checkpointed_at"])
    end

    test "CRASH: save converts atom keys to strings", %{tmp_dir: tmp_dir} do
      OptimalSystemAgent.Verification.Checkpoint.save("atom-test", %{
        status: :passed,
        data: %{nested_atom: :value, count: 42}
      })

      path = Path.join(tmp_dir, "atom-test.json")
      {:ok, content} = File.read(path)
      {:ok, decoded} = Jason.decode(content)

      # Top-level atom keys → string keys
      assert decoded["status"] == "passed"
      # Nested atom keys → string keys
      assert decoded["data"]["nested_atom"] == "value"
      assert decoded["data"]["count"] == 42
    end

    test "CRASH: save overwrites existing checkpoint", %{tmp_dir: tmp_dir} do
      OptimalSystemAgent.Verification.Checkpoint.save("overwrite-test", %{iteration: 1})
      OptimalSystemAgent.Verification.Checkpoint.save("overwrite-test", %{iteration: 2})

      path = Path.join(tmp_dir, "overwrite-test.json")
      {:ok, content} = File.read(path)
      {:ok, decoded} = Jason.decode(content)
      assert decoded["iteration"] == 2
    end

    test "CRASH: save handles nested maps with atom values" do
      # Atoms that are not true/false/nil should become strings
      OptimalSystemAgent.Verification.Checkpoint.save("nested-atom", %{
        level1: %{level2: %{status: :active}}
      })

      path = Path.join(Application.get_env(:optimal_system_agent, :verification_checkpoint_dir), "nested-atom.json")
      {:ok, content} = File.read(path)
      {:ok, decoded} = Jason.decode(content)
      assert decoded["level1"]["level2"]["status"] == "active"
    end

    test "CRASH: save handles list values" do
      OptimalSystemAgent.Verification.Checkpoint.save("list-test", %{
        items: [1, "two", :three, %{nested: :value}]
      })

      path = Path.join(Application.get_env(:optimal_system_agent, :verification_checkpoint_dir), "list-test.json")
      {:ok, content} = File.read(path)
      {:ok, decoded} = Jason.decode(content)
      assert decoded["items"] == [1, "two", "three", %{"nested" => "value"}]
    end
  end

  describe "Checkpoint — restore/1" do
    test "CRASH: restore returns {:ok, nil} when no checkpoint exists" do
      assert {:ok, nil} == OptimalSystemAgent.Verification.Checkpoint.restore("nonexistent")
    end

    test "CRASH: restore returns saved state", %{tmp_dir: tmp_dir} do
      OptimalSystemAgent.Verification.Checkpoint.save("restore-test", %{
        status: :failed,
        iteration: 5,
        message: "tests broke"
      })

      assert {:ok, state} = OptimalSystemAgent.Verification.Checkpoint.restore("restore-test")
      assert state["status"] == "failed"
      assert state["iteration"] == 5
      assert state["message"] == "tests broke"
      assert state["loop_id"] == "restore-test"
    end

    test "CRASH: restore returns metadata fields" do
      OptimalSystemAgent.Verification.Checkpoint.save("meta-test", %{iteration: 1})

      {:ok, state} = OptimalSystemAgent.Verification.Checkpoint.restore("meta-test")
      assert Map.has_key?(state, "loop_id")
      assert Map.has_key?(state, "checkpointed_at")
    end
  end

  describe "Checkpoint — delete/1" do
    test "CRASH: delete removes existing checkpoint file", %{tmp_dir: tmp_dir} do
      OptimalSystemAgent.Verification.Checkpoint.save("delete-test", %{iteration: 1})
      path = Path.join(tmp_dir, "delete-test.json")
      assert File.exists?(path)

      assert :ok == OptimalSystemAgent.Verification.Checkpoint.delete("delete-test")
      refute File.exists?(path)
    end

    test "CRASH: delete returns :ok for nonexistent file" do
      assert :ok == OptimalSystemAgent.Verification.Checkpoint.delete("does-not-exist")
    end
  end

  describe "Checkpoint — checkpoint_path/1" do
    test "CRASH: checkpoint_path returns correct file path" do
      path = OptimalSystemAgent.Verification.Checkpoint.checkpoint_path("my-loop")
      assert String.ends_with?(path, "my-loop.json")
      assert String.contains?(path, "verification_checkpoints")
    end
  end

  describe "Checkpoint — round-trip save/restore" do
    test "CRASH: complex state survives save → restore round-trip" do
      original_state = %{
        loop_id: "round-trip",
        status: :running,
        iteration: 42,
        confidence_score: 65.5,
        results_history: [
          %{iteration: 40, passed: true, exit_code: 0},
          %{iteration: 41, passed: false, exit_code: 1}
        ],
        nested: %{deep: %{value: [1, 2, 3]}}
      }

      OptimalSystemAgent.Verification.Checkpoint.save("round-trip", original_state)
      {:ok, restored} = OptimalSystemAgent.Verification.Checkpoint.restore("round-trip")

      # Verify all keys survived the round-trip
      assert restored["loop_id"] == "round-trip"
      assert restored["status"] == "running"
      assert restored["iteration"] == 42
      assert restored["confidence_score"] == 65.5
      assert length(restored["results_history"]) == 2
      assert restored["nested"]["deep"]["value"] == [1, 2, 3]
    end
  end

  describe "Checkpoint — checkpoint_dir/0" do
    test "CRASH: checkpoint_dir returns expanded path" do
      dir = OptimalSystemAgent.Verification.Checkpoint.checkpoint_dir()
      assert is_binary(dir)
      assert Path.type(dir) == :absolute
    end
  end
end
