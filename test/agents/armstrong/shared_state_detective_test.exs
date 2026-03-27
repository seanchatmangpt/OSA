defmodule OptimalSystemAgent.Agents.Armstrong.SharedStateDetectiveTest do
  @moduledoc """
  Chicago TDD: Shared State Detective Tests

  **RED Phase**: Test that detector finds common Armstrong violations.
  **GREEN Phase**: Implement pattern matching in detective.
  **REFACTOR Phase**: Extract violation patterns to helper modules.

  ## Armstrong Principle: No Shared Mutable State

  All inter-process communication must be via message passing.
  No shared memory, no global variables, no unprotected ETS writes.

  ## Test Structure

  Each test:
  1. Creates a temporary .ex file with a specific violation pattern
  2. Runs static analysis on that file
  3. Asserts the detector catches the expected violation
  4. Cleans up the temp file

  This ensures violations are caught at code review time, not in production.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agents.Armstrong.SharedStateDetective

  setup do
    {:ok, _pid} = SharedStateDetective.start_link(codebase_root: temp_dir())

    on_exit(fn ->
      # Clean up temp directory
      File.rm_rf(temp_dir())
    end)

    :ok
  end

  # ─────────────────────────────────────────────────────────────────
  # Tests: Global Mutable Variables
  # ─────────────────────────────────────────────────────────────────

  describe "global mutable variables" do
    test "detects @mutable_state at module level" do
      code = """
      defmodule BadModule do
        @mutable_state []

        def add(item) do
          {:ok, :added}
        end
      end
      """

      _file = create_temp_file("bad_state.ex", code)

      violations = SharedStateDetective.scan_codebase()

      # Should find the global variable violation
      global_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :global_variable end)

      assert length(global_violations) >= 1
      {_type, violation_file, line, description} = Enum.find(global_violations, &String.ends_with?(elem(&1, 1), "bad_state.ex"))
      assert line == 2
      assert String.contains?(description, "@mutable_state")
      assert String.contains?(description, "GenServer")
    end

    test "detects @state module attribute" do
      code = """
      defmodule BadModule do
        @state []

        def get_state, do: @state
      end
      """

      _file = create_temp_file("bad_module_state.ex", code)

      violations = SharedStateDetective.scan_codebase()

      global_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :global_variable end)

      assert length(global_violations) >= 1
      assert Enum.any?(global_violations, fn {_type, f, _l, _d} ->
        String.ends_with?(f, "bad_module_state.ex")
      end)
    end

    test "ignores @doc and comment annotations" do
      code = """
      defmodule GoodModule do
        # @mutable_state is bad — don't use it
        @doc "This is documentation"

        def handle_call({:get, key}, _from, state) do
          {:reply, state, state}
        end
      end
      """

      _file = create_temp_file("good_module_comments.ex", code)

      violations = SharedStateDetective.scan_codebase()

      global_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :global_variable end)

      # Comments should not trigger violations
      violations_in_file =
        Enum.filter(global_violations, fn {_type, f, _l, _d} ->
          String.ends_with?(f, "good_module_comments.ex")
        end)

      assert violations_in_file == []
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # Tests: Agent Usage
  # ─────────────────────────────────────────────────────────────────

  describe "Agent.update() violations" do
    test "detects Agent.update() calls" do
      code = """
      defmodule BadAgent do
        def share_state do
          Agent.start_link(fn -> [] end, name: :shared)
          Agent.update(:shared, fn state -> [1 | state] end)
        end
      end
      """

      _file = create_temp_file("bad_agent.ex", code)

      violations = SharedStateDetective.scan_codebase()

      agent_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :agent_update end)

      assert length(agent_violations) >= 1
      assert Enum.any?(agent_violations, fn {_type, f, _l, _d} ->
        String.ends_with?(f, "bad_agent.ex")
      end)
    end

    test "detects Agent.start() calls" do
      code = """
      defmodule BadAgentStart do
        def init do
          Agent.start(fn -> %{count: 0} end, name: :counter)
        end
      end
      """

      _file = create_temp_file("bad_agent_start.ex", code)

      violations = SharedStateDetective.scan_codebase()

      agent_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :agent_update end)

      assert length(agent_violations) >= 1
    end

    test "ignores Agent in comments" do
      code = """
      defmodule GoodModule do
        # Don't use Agent.update() — use GenServer instead

        def handle_call(:get, _from, state) do
          {:reply, state, state}
        end
      end
      """

      _file = create_temp_file("good_agent_comments.ex", code)

      violations = SharedStateDetective.scan_codebase()

      agent_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :agent_update end)

      violations_in_file =
        Enum.filter(agent_violations, fn {_type, f, _l, _d} ->
          String.ends_with?(f, "good_agent_comments.ex")
        end)

      assert violations_in_file == []
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # Tests: ETS Violations
  # ─────────────────────────────────────────────────────────────────

  describe "ETS violations" do
    test "detects ETS.insert outside GenServer context" do
      code = """
      defmodule BadETS do
        def initialize do
          :ets.insert(:my_table, {1, "value"})
        end
      end
      """

      _file = create_temp_file("bad_ets.ex", code)

      violations = SharedStateDetective.scan_codebase()

      ets_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :ets_write_no_genserver end)

      assert length(ets_violations) >= 1
      assert Enum.any?(ets_violations, fn {_type, f, _l, _d} ->
        String.ends_with?(f, "bad_ets.ex")
      end)
    end

    test "detects ETS.update_counter outside GenServer" do
      code = """
      defmodule BadETSCounter do
        def increment do
          :ets.update_counter(:counters, :my_counter, 1)
        end
      end
      """

      _file = create_temp_file("bad_ets_counter.ex", code)

      violations = SharedStateDetective.scan_codebase()

      ets_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :ets_write_no_genserver end)

      assert length(ets_violations) >= 1
    end

    test "ignores ETS.insert inside handle_call" do
      code = """
      defmodule GoodETSServer do
        use GenServer

        def handle_call({:store, key, value}, _from, state) do
          :ets.insert(:my_table, {key, value})
          {:reply, :ok, state}
        end
      end
      """

      _file = create_temp_file("good_ets_genserver.ex", code)

      violations = SharedStateDetective.scan_codebase()

      ets_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :ets_write_no_genserver end)

      # Should NOT flag ETS writes inside handle_call
      violations_in_file =
        Enum.filter(ets_violations, fn {_type, f, _l, _d} ->
          String.ends_with?(f, "good_ets_genserver.ex")
        end)

      assert violations_in_file == []
    end

    test "detects ETS.new without write_concurrency" do
      code = """
      defmodule BadETSTable do
        def init do
          :ets.new(:my_table, [:named_table])
        end
      end
      """

      _file = create_temp_file("bad_ets_table.ex", code)

      violations = SharedStateDetective.scan_codebase()

      write_conc_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :ets_no_write_concurrency end)

      assert length(write_conc_violations) >= 1
      assert Enum.any?(write_conc_violations, fn {_type, f, _l, _d} ->
        String.ends_with?(f, "bad_ets_table.ex")
      end)
    end

    test "ignores ETS.new with write_concurrency" do
      code = """
      defmodule GoodETSTable do
        def init do
          :ets.new(:my_table, [:named_table, {:write_concurrency, true}])
        end
      end
      """

      _file = create_temp_file("good_ets_write_conc.ex", code)

      violations = SharedStateDetective.scan_codebase()

      write_conc_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :ets_no_write_concurrency end)

      violations_in_file =
        Enum.filter(write_conc_violations, fn {_type, f, _l, _d} ->
          String.ends_with?(f, "good_ets_write_conc.ex")
        end)

      assert violations_in_file == []
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # Tests: Process Dictionary
  # ─────────────────────────────────────────────────────────────────

  describe "Process dictionary violations" do
    test "detects Process.put() calls" do
      code = """
      defmodule BadProcessDict do
        def store_value(key, value) do
          Process.put(key, value)
        end
      end
      """

      _file = create_temp_file("bad_process_dict.ex", code)

      violations = SharedStateDetective.scan_codebase()

      dict_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :process_dict_communication end)

      assert length(dict_violations) >= 1
      assert Enum.any?(dict_violations, fn {_type, f, _l, _d} ->
        String.ends_with?(f, "bad_process_dict.ex")
      end)
    end

    test "detects Process.get() calls" do
      code = """
      defmodule BadProcessGet do
        def retrieve_value(key) do
          Process.get(key)
        end
      end
      """

      _file = create_temp_file("bad_process_get.ex", code)

      violations = SharedStateDetective.scan_codebase()

      dict_violations =
        Enum.filter(violations, fn {type, _f, _l, _d} -> type == :process_dict_communication end)

      assert length(dict_violations) >= 1
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # Tests: Proper Message Passing (Should NOT Trigger Violations)
  # ─────────────────────────────────────────────────────────────────

  describe "proper message passing patterns" do
    test "ignores GenServer with proper state handling" do
      code = """
      defmodule GoodGenServer do
        use GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts) do
          {:ok, opts}
        end

        def handle_call({:get, key}, _from, state) do
          value = Map.get(state, key)
          {:reply, value, state}
        end

        def handle_call({:set, key, value}, _from, state) do
          new_state = Map.put(state, key, value)
          {:reply, :ok, new_state}
        end
      end
      """

      _file = create_temp_file("good_genserver.ex", code)

      violations = SharedStateDetective.scan_codebase()

      # Filter violations to only those in this file
      violations_in_file =
        Enum.filter(violations, fn {_type, f, _l, _d} ->
          String.ends_with?(f, "good_genserver.ex")
        end)

      # Should have NO violations
      assert violations_in_file == []
    end

    test "ignores proper message passing" do
      code = """
      defmodule GoodMessaging do
        def send_message(pid, data) do
          send(pid, {:message, data})
        end

        def receive_message do
          receive do
            {:message, data} -> data
          end
        end
      end
      """

      _file = create_temp_file("good_messaging.ex", code)

      violations = SharedStateDetective.scan_codebase()

      violations_in_file =
        Enum.filter(violations, fn {_type, f, _l, _d} ->
          String.ends_with?(f, "good_messaging.ex")
        end)

      assert violations_in_file == []
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # Tests: API Methods
  # ─────────────────────────────────────────────────────────────────

  describe "detector API" do
    test "get_violations returns empty list initially" do
      SharedStateDetective.clear_violations()
      violations = SharedStateDetective.get_violations()
      assert violations == []
    end

    test "get_violations returns all violations after scan" do
      code = """
      defmodule TestModule do
        @mutable_state []
        Agent.update(:agent, fn s -> s end)
      end
      """

      _file = create_temp_file("test_violations.ex", code)

      violations = SharedStateDetective.scan_codebase()

      assert length(violations) >= 2
    end

    test "clear_violations resets detector state" do
      code = """
      defmodule TestModule do
        @mutable_state []
      end
      """

      _file = create_temp_file("test_clear.ex", code)

      _violations = SharedStateDetective.scan_codebase()

      SharedStateDetective.clear_violations()
      remaining = SharedStateDetective.get_violations()

      assert remaining == []
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # Helpers
  # ─────────────────────────────────────────────────────────────────

  defp temp_dir do
    Path.join(System.tmp_dir!(), "shared_state_detective_test")
  end

  defp create_temp_file(name, content) do
    dir = temp_dir()
    File.mkdir_p!(dir)

    file_path = Path.join(dir, name)
    File.write!(file_path, content)

    file_path
  end
end
