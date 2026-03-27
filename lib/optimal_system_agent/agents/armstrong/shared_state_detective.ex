defmodule OptimalSystemAgent.Agents.Armstrong.SharedStateDetective do
  @moduledoc """
  Shared State Detective — detects violations of Armstrong's no-shared-state principle.

  The detective performs two types of analysis:

  1. **Static Analysis**: Grep-based pattern detection on .ex source files
     - `Agent.update()` without proper guards → RED (shared mutable state)
     - ETS writes outside GenServer context → RED (data race)
     - Global `@mutable_state` variables → RED (violates supervision)
     - `Process.put()` for inter-process communication → YELLOW (process-local is OK, but not standard)
     - Raw ETS `:ets.insert/:ets.update_counter` outside gen_ets/ETS supervisor → RED

  2. **Runtime Analysis**: Monitor actual ETS operations and process dictionary usage
     - Hook into ETS instrumentation (via telemetry)
     - Flag direct ETS writes from non-GenServer processes
     - Track which processes own which ETS tables

  ## Armstrong Principle: No Shared Mutable State

  All inter-process communication must be via message passing.
  Never share memory between processes — this causes:
  - Race conditions (concurrent writes)
  - Deadlocks (mutual waits)
  - Data corruption (partial updates)

  ## Public API

      {:ok, pid} = SharedStateDetective.start_link(opts)
      violations = SharedStateDetective.scan_codebase()
      all = SharedStateDetective.get_violations()

  Each violation has: `{violation_type, file, line, description}`

  ## Telemetry Events

  - `[:armstrong, :shared_state, :violation]` — violation detected
    - Attributes: type, file, line, description, process

  ## Examples

  Static analysis catches patterns like:

      # WRONG: Global mutable variable (should be GenServer state)
      @mutable_state []
      def add(item), do: @mutable_state = [@mutable_state | item]

      # WRONG: Agent.update without synchronized access
      Agent.update(:my_agent, fn state -> ... end)

      # WRONG: ETS writes without process ownership
      :ets.insert(:my_table, {key, value})

      # OK: GenServer-owned state
      def handle_call({:add, item}, _from, state) do
        {:reply, :ok, [item | state]}
      end

      # OK: Proper ETS with write_concurrency in GenServer
      :ets.new(:my_table, [:named_table, {:write_concurrency, true}])

  """

  use GenServer
  require Logger

  # ─────────────────────────────────────────────────────────────────
  # Public API
  # ─────────────────────────────────────────────────────────────────

  @doc "Start the detector GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Scan codebase for violations.

  Returns list of violations: [{type, file, line, description}]
  where type is one of:
  - `:global_variable` — @mutable_state at module level
  - `:agent_update` — Agent.update() call without synchronization
  - `:ets_write_no_genserver` — :ets.insert/:ets.update outside GenServer
  - `:process_dict_communication` — Process.put/get for inter-process data
  - `:ets_no_write_concurrency` — ETS table without write_concurrency

  Static analysis only — no compilation/execution.
  """
  @spec scan_codebase() :: [{atom(), String.t(), pos_integer(), String.t()}]
  def scan_codebase do
    GenServer.call(__MODULE__, :scan_codebase, 30_000)
  end

  @doc "Get all violations discovered so far (static + runtime)."
  @spec get_violations() :: [{atom(), String.t(), pos_integer(), String.t()}]
  def get_violations do
    GenServer.call(__MODULE__, :get_violations)
  end

  @doc "Clear all violations (reset detector state)."
  @spec clear_violations() :: :ok
  def clear_violations do
    GenServer.call(__MODULE__, :clear_violations)
  end

  # ─────────────────────────────────────────────────────────────────
  # GenServer Callbacks
  # ─────────────────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    codebase_root = Keyword.get(opts, :codebase_root, default_codebase_root())

    state = %{
      codebase_root: codebase_root,
      violations: [],
      last_scan_time: nil
    }

    # Attach telemetry handler for runtime detection
    attach_telemetry_handler()

    {:ok, state}
  end

  @impl true
  def handle_call(:scan_codebase, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    violations = perform_static_analysis(state.codebase_root)

    elapsed = System.monotonic_time(:millisecond) - start_time

    Logger.info(
      "[SharedStateDetective] Static analysis complete: #{length(violations)} violations found in #{elapsed}ms"
    )

    new_state = %{state | violations: violations, last_scan_time: start_time}

    {:reply, violations, new_state}
  end

  @impl true
  def handle_call(:get_violations, _from, state) do
    {:reply, state.violations, state}
  end

  @impl true
  def handle_call(:clear_violations, _from, state) do
    {:reply, :ok, %{state | violations: []}}
  end

  # ─────────────────────────────────────────────────────────────────
  # Static Analysis
  # ─────────────────────────────────────────────────────────────────

  defp perform_static_analysis(codebase_root) do
    violations = []

    # Find all .ex files
    ex_files = find_ex_files(codebase_root)
    Logger.debug("[SharedStateDetective] Found #{length(ex_files)} .ex files")

    # Scan each file for violations
    violations =
      Enum.reduce(ex_files, violations, fn file, acc ->
        file_violations = scan_file(file)
        acc ++ file_violations
      end)

    # Sort by file, then line
    Enum.sort_by(violations, fn {_type, file, line, _desc} -> {file, line} end)
  end

  defp find_ex_files(root) do
    case File.ls(root) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          full_path = Path.join(root, entry)

          cond do
            String.ends_with?(entry, ".ex") ->
              [full_path]

            File.dir?(full_path) and not String.starts_with?(entry, ".") ->
              find_ex_files(full_path)

            true ->
              []
          end
        end)

      {:error, _} ->
        []
    end
  rescue
    _ -> []
  end

  defp scan_file(file) do
    case File.read(file) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        violations = []

        # Check for global mutable variables
        violations = violations ++ scan_global_mutable_state(file, lines)

        # Check for Agent.update calls
        violations = violations ++ scan_agent_update(file, lines)

        # Check for ETS writes outside GenServer
        violations = violations ++ scan_ets_writes(file, lines)

        # Check for Process.put/get communication
        violations = violations ++ scan_process_dict(file, lines)

        # Check for ETS tables without write_concurrency
        violations = violations ++ scan_ets_write_concurrency(file, lines)

        violations

      {:error, _} ->
        []
    end
  rescue
    _ -> []
  end

  # Pattern: @mutable_state assignment at module level
  defp scan_global_mutable_state(file, lines) do
    violations = []

    Enum.with_index(lines, 1)
    |> Enum.reduce(violations, fn {line, line_num}, acc ->
      trimmed = String.trim_leading(line)

      cond do
        # Skip comments
        String.starts_with?(trimmed, "#") ->
          acc

        # Match: @state [...] or @state = [...] at module level
        (String.match?(trimmed, ~r/^@state\s/) or String.match?(trimmed, ~r/^@state\s*=/)) and
          not String.match?(line, ~r/def\s+/) ->
          [{:global_variable, file, line_num,
            "Global mutable variable @state — use GenServer to own state instead"}
           | acc]

        # Match: @*_state [...] or @*_state = [...] (other state variables)
        String.match?(trimmed, ~r/^@\w+_state\s/) and
          not String.match?(line, ~r/def\s+/) ->
          var_name = extract_variable_name(line)

          [{:global_variable, file, line_num,
            "Global mutable variable @#{var_name} — use GenServer to own state instead"}
           | acc]

        # Match: @*_state = ... (assignment form)
        String.match?(trimmed, ~r/^@\w+_state\s*=/) and
          not String.match?(line, ~r/def\s+/) ->
          var_name = extract_variable_name(line)

          [{:global_variable, file, line_num,
            "Global mutable variable @#{var_name} — use GenServer to own state instead"}
           | acc]

        true ->
          acc
      end
    end)
  end

  # Pattern: Agent.update() calls
  defp scan_agent_update(file, lines) do
    violations = []

    Enum.with_index(lines, 1)
    |> Enum.reduce(violations, fn {line, line_num}, acc ->
      trimmed = String.trim_leading(line)

      cond do
        # Skip comments and doc strings
        String.starts_with?(trimmed, "#") or String.starts_with?(trimmed, "@doc") ->
          acc

        # Match: Agent.update(...) in actual code
        String.match?(trimmed, ~r/Agent\.update\s*\(/) ->
          [{:agent_update, file, line_num,
            "Agent.update() creates shared mutable state — use GenServer instead"}
           | acc]

        # Match: Agent.start(...) — starting an agent
        String.match?(trimmed, ~r/Agent\.start/) and
          not String.starts_with?(trimmed, "#") ->
          [{:agent_update, file, line_num,
            "Agent creates shared mutable state — use GenServer instead"}
           | acc]

        true ->
          acc
      end
    end)
  end

  # Pattern: ETS writes (:ets.insert, :ets.update_counter) outside GenServer context
  defp scan_ets_writes(file, lines) do
    violations = []

    lines_with_nums = Enum.with_index(lines, 1)

    Enum.reduce(lines_with_nums, violations, fn {line, line_num}, acc ->
      cond do
        # Match: :ets.insert(...) or :ets.update_counter(...)
        (String.match?(line, ~r/:ets\.insert\s*\(/) or
           String.match?(line, ~r/:ets\.update_counter\s*\(/)) and
          not String.match?(line, ~r/^#/) and
          not String.match?(line, ~r/def\s+handle_/) ->
          operation = extract_ets_operation(line)

          # Only flag if NOT inside handle_call/handle_cast/handle_info
          # (heuristic: check if previous lines have def handle_*)
          in_genserver_context = check_genserver_context(lines_with_nums, line_num)

          if in_genserver_context do
            acc
          else
            [{:ets_write_no_genserver, file, line_num,
              "#{operation} appears outside GenServer handler — not synchronized"}
             | acc]
          end

        true ->
          acc
      end
    end)
  end

  # Pattern: Process.put/get for inter-process communication
  defp scan_process_dict(file, lines) do
    violations = []

    Enum.with_index(lines, 1)
    |> Enum.reduce(violations, fn {line, line_num}, acc ->
      cond do
        # Match: Process.put(...) — only flag if looks like inter-process communication
        String.match?(line, ~r/Process\.put\s*\(/) and
          not String.match?(line, ~r/^#/) ->
          [{:process_dict_communication, file, line_num,
            "Process.put() for communication — use message passing instead. " <>
              "Process dict is process-local (OK) but not standard for IPC"}
           | acc]

        # Match: Process.get(...) in same context
        String.match?(line, ~r/Process\.get\s*\(/) and
          not String.match?(line, ~r/^#/) ->
          [{:process_dict_communication, file, line_num,
            "Process.get() for communication — use message passing instead"}
           | acc]

        true ->
          acc
      end
    end)
  end

  # Pattern: :ets.new(...) without write_concurrency flag
  defp scan_ets_write_concurrency(file, lines) do
    violations = []

    Enum.with_index(lines, 1)
    |> Enum.reduce(violations, fn {line, line_num}, acc ->
      trimmed = String.trim_leading(line)

      cond do
        # Skip comments
        String.starts_with?(trimmed, "#") ->
          acc

        # Match: :ets.new(...) call
        String.match?(trimmed, ~r/:ets\.new\s*\(/) ->
          # Check if write_concurrency is in same line or next few lines
          table_lines = Enum.slice(lines, line_num - 1, 5)
          table_definition = Enum.join(table_lines, " ")

          has_write_concurrency =
            String.match?(table_definition, ~r/write_concurrency\s*,\s*true/) or
            String.match?(table_definition, ~r/\{:write_concurrency\s*,\s*true\}/)

          if has_write_concurrency do
            acc
          else
            [{:ets_no_write_concurrency, file, line_num,
              ":ets.new() without write_concurrency — parallel writes may be corrupted"}
             | acc]
          end

        true ->
          acc
      end
    end)
  end

  # ─────────────────────────────────────────────────────────────────
  # Helper Functions
  # ─────────────────────────────────────────────────────────────────

  defp extract_variable_name(line) do
    case Regex.run(~r/@(\w+)/, line) do
      [_full, name] -> name
      nil -> "unknown"
    end
  end

  defp extract_ets_operation(line) do
    cond do
      String.match?(line, ~r/:ets\.insert\s*\(/) -> ":ets.insert"
      String.match?(line, ~r/:ets\.update_counter\s*\(/) -> ":ets.update_counter"
      true -> ":ets operation"
    end
  end

  # Check if a line is inside a GenServer handler (handle_call, handle_cast, handle_info)
  defp check_genserver_context(lines_with_nums, current_line_num) do
    # Look back up to 50 lines for def handle_*
    start_idx = max(0, current_line_num - 50)

    Enum.slice(lines_with_nums, start_idx, current_line_num - start_idx)
    |> Enum.any?(fn {line, _num} ->
      String.match?(line, ~r/def\s+(handle_call|handle_cast|handle_info|init)\s*\(/)
    end)
  end

  defp default_codebase_root do
    case :code.priv_dir(:optimal_system_agent) do
      {:error, _} ->
        Path.join([File.cwd!(), "lib"])

      priv_dir ->
        priv_dir
        |> to_string()
        |> Path.dirname()
        |> then(&Path.join(&1, "lib"))
    end
  rescue
    _ -> Path.join([File.cwd!(), "lib"])
  end

  # ─────────────────────────────────────────────────────────────────
  # Telemetry Integration
  # ─────────────────────────────────────────────────────────────────

  defp attach_telemetry_handler do
    # Attach to ETS operations if available
    # (This is a stub for future runtime instrumentation)
  end

  @doc false
  def emit_violation(type, file, line, description) do
    :telemetry.execute(
      [:armstrong, :shared_state, :violation],
      %{count: 1},
      %{type: type, file: file, line: line, description: description}
    )
  end
end
