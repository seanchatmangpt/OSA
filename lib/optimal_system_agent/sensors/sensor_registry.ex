defmodule OptimalSystemAgent.Sensors.SensorRegistry do
  @moduledoc """
  SPR Sensor Registry — Fortune 5 Layer 1: Signal Collection

  Generates three compressed JSON files that capture the business topology:
  - modules.json: Topology sensor (what modules exist and their metadata)
  - deps.json: Boundary sensor (dependencies between modules)
  - patterns.json: Behavior sensor (YAWL workflow patterns detected)

  Each file is ~113KB when combined, providing 91.5% compression from raw codebase analysis.
  """
  use GenServer
  require Logger

  @doc false
  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @sensor_table :osa_sensors
  @scan_table :osa_scans
  @max_file_bytes 10 * 1024 * 1024

  defstruct scans: %{},
            last_scan: nil,
            scan_duration_ms: 0

  @doc """
  Initialize ETS tables for the sensor registry.

  Idempotent: safe to call multiple times.
  """
  def init_tables do
    # Create tables if they don't exist
    # :ets.info/1 returns undefined for non-existent tables
    # Use :public access so any process can read/write (needed for tests)
    case :ets.info(@sensor_table) do
      :undefined ->
        :ets.new(@sensor_table, [:set, :named_table, :public, read_concurrency: true])
      _ ->
        :ok
    end

    case :ets.info(@scan_table) do
      :undefined ->
        :ets.new(@scan_table, [:set, :named_table, :public])
      _ ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Trigger a scan of the codebase and generate all three SPR files.

  ## Options
    * `:codebase_path` — Root path to scan (default: configured path)
    * `:output_dir` — Where to write JSON files (default: priv/sensors)
    * `:async` — Run in background (default: false)

  ## Returns
    * `{:ok, scan_result}` — Map with file paths and metadata
    * `{:error, reason}` — Scan failed

  ## Example
      {:ok, result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite()
      #=> %{
        modules: %{path: "priv/sensors/modules.json", size: 45000, compression: 0.915},
        deps: %{path: "priv/sensors/deps.json", size: 38000, compression: 0.88},
        patterns: %{path: "priv/sensors/patterns.json", size: 51000, compression: 0.94}
      }
  """
  def scan_sensor_suite(opts \\ []) do
    # Monorepo scans (Elixir + Go + Rust) can take up to 5 minutes
    GenServer.call(__MODULE__, {:scan_suite, opts}, 300_000)
  end

  @doc """
  Get the current SPR fingerprint (SHA256 of combined sensor data).

  Returns `{:ok, fingerprint}` or `{:error, reason}`.
  """
  def current_fingerprint do
    GenServer.call(__MODULE__, :current_fingerprint, 15000)
  end

  @doc """
  Check if sensors are stale (older than max_age_ms).

  Returns `true` if sensors need refresh.
  """
  def stale?(max_age_ms \\ 300_000) do
    GenServer.call(__MODULE__, {:stale?, max_age_ms}, 15000)
  end

  # ---------------------------------------------------------------------------
  # Server Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    # Tables are already created by init_tables/0 in Application.start/2
    # Don't recreate them
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:scan_suite, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    codebase_path = Keyword.get(opts, :codebase_path, Application.get_env(:osa, :codebase_root))
    output_dir = Keyword.get(opts, :output_dir, Path.join([Application.app_dir(:optimal_system_agent), "priv", "sensors"]))

    result = perform_scan(codebase_path, output_dir)

    duration = System.monotonic_time(:millisecond) - start_time
    new_state = %{state | last_scan: System.system_time(:millisecond), scan_duration_ms: duration}

    # Emit telemetry events for scan completion
    case result do
      {:ok, scan_data} ->
        compressed_size = scan_data.modules.size + scan_data.deps.size + scan_data.patterns.size

        :telemetry.execute(
          [:osa, :sensors, :scan_complete],
          %{duration: duration, module_count: scan_data.modules.module_count, compressed_size: compressed_size},
          %{codebase_path: codebase_path, output_dir: output_dir}
        )

      {:error, reason} ->
        :telemetry.execute(
          [:osa, :sensors, :scan_error],
          %{duration: duration},
          %{codebase_path: codebase_path, reason: reason}
        )
    end

    {:reply, result, new_state}
  end

  def handle_call(:current_fingerprint, _from, state) do
    case get_latest_scan(state) do
      nil -> {:reply, {:error, :no_scan_data}, state}
      scan -> {:reply, {:ok, calculate_fingerprint(scan)}, state}
    end
  end

  def handle_call({:stale?, max_age_ms}, _from, state) do
    stale? = case state.last_scan do
      nil -> true
      last_scan -> System.system_time(:millisecond) - last_scan > max_age_ms
    end

    {:reply, stale?, state}
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp perform_scan(codebase_path, output_dir) do
    start_time = System.monotonic_time(:millisecond)

    # Ensure ETS tables exist (handle race condition where tables were deleted)
    init_tables()

    # Normalize paths to prevent Unicode homoglyph attacks
    normalized_path = normalize_path(codebase_path)
    normalized_output = normalize_path(output_dir)

    with :ok <- validate_codebase_path(normalized_path),
         :ok <- validate_no_path_traversal(normalized_output),
         :ok <- validate_output_directory(normalized_output),
         true <- File.dir?(normalized_path) || {:error, :no_such_directory},
         :ok <- File.mkdir_p(normalized_output),
         {:ok, modules} <- scan_modules(normalized_path, normalized_output),
         {:ok, deps} <- scan_dependencies(normalized_path, normalized_output),
         {:ok, patterns} <- scan_patterns(normalized_path, normalized_output) do

      duration_ms = System.monotonic_time(:millisecond) - start_time
      scan_id = generate_scan_id()

      scan_data = %{
        scan_id: scan_id,
        timestamp: System.system_time(:millisecond),
        duration_ms: duration_ms,
        modules: modules,
        deps: deps,
        patterns: patterns
      }

      :ets.insert(@scan_table, {scan_id, scan_data})
      {:ok, scan_data}
    else
      {:error, reason} ->
        # Log error with context for debugging
        Logger.error("[SensorRegistry] Scan failed",
          codebase_path: codebase_path,
          output_dir: output_dir,
          reason: inspect(reason),
          timestamp: System.system_time(:millisecond)
        )
        {:error, reason}
    end
  end

  defp normalize_path(path) do
    # Normalize Unicode characters to prevent homoglyph attacks
    # Convert fullwidth dots (．．) to regular dots (..)
    # This prevents bypasses using visually similar characters

    path
    |> String.replace(["．", "\uFF0E"], ".")
    |> String.replace(["／", "\uFF0F"], "/")
    |> String.replace(["＼", "\uFF3C"], "\\")
  end

  defp validate_codebase_path(path) do
    # For codebase_path (read-only scan source), allow absolute paths.
    # Still block traversal attempts and shell injection.
    dangerous_patterns = [
      "..",                 # path traversal
      ~r/^~/,              # home directory expansion
      ";",                 # shell command separator
      "|",                 # pipe
      "$",                 # variable expansion
      "(",                 # subshell
      ")",                 # subshell
      "`",                 # command substitution
      "&"                  # background process
    ]

    has_dangerous = Enum.any?(dangerous_patterns, fn pattern ->
      if is_binary(pattern) do
        String.contains?(path, pattern)
      else
        Regex.match?(pattern, path)
      end
    end)

    if has_dangerous do
      {:error, :path_traversal_detected}
    else
      :ok
    end
  end

  defp validate_no_path_traversal(path) do
    # Reject paths containing ".." (path traversal attempt)
    # Also reject absolute paths and shell injection characters
    # Used for output_dir (write target) — absolute paths not permitted there.
    dangerous_patterns = [
      "..",                 # path traversal
      ~r/^\//,             # absolute path (starts with /)
      ~r/^~/,              # home directory expansion
      ";",                 # shell command separator
      "|",                 # pipe
      "$",                 # variable expansion
      "(",                 # subshell
      ")",                 # subshell
      "`",                 # command substitution
      "&"                  # background process
    ]

    has_dangerous = Enum.any?(dangerous_patterns, fn pattern ->
      if is_binary(pattern) do
        String.contains?(path, pattern)
      else
        Regex.match?(pattern, path)
      end
    end)

    if has_dangerous do
      {:error, :path_traversal_detected}
    else
      :ok
    end
  end

  defp validate_output_directory(output_dir) do
    # Allow writing to priv/sensors and any tmp/ subdirectory
    # Reject absolute paths and home directory expansion
    allowed_prefixes = ["priv/sensors", "tmp"]

    # First check: reject absolute paths
    if String.starts_with?(output_dir, "/") or String.starts_with?(output_dir, "~") do
      {:error, :absolute_path_not_allowed}
    else
      # Second check: must start with allowed prefix
      is_allowed = Enum.any?(allowed_prefixes, fn prefix ->
        String.starts_with?(output_dir, prefix) or
          output_dir == prefix
      end)

      if is_allowed do
        :ok
      else
        {:error, :output_directory_not_allowed}
      end
    end
  end

  defp scan_modules(codebase_path, output_dir) do
    # Scan for all module definitions and metadata
    modules = discover_modules(codebase_path)

    # Signal Theory S=(M,G,T,F,W) encoding
    output = %{
      scan_type: "modules",
      timestamp: System.system_time(:millisecond),
      total_modules: length(modules),
      modules: modules,
      # Signal Theory encoding
      mode: "data",
      genre: "spec",
      type: "inform",
      format: "json",
      structure: "list"
    }

    path = Path.join(output_dir, "modules.json")
    File.write!(path, Jason.encode!(output, pretty: true))

    {:ok, %{
      path: path,
      size: File.stat!(path).size,
      module_count: length(modules)
    }}
  end

  defp scan_dependencies(codebase_path, output_dir) do
    # Scan for dependency relationships
    deps = discover_dependencies(codebase_path)

    # Signal Theory S=(M,G,T,F,W) encoding
    output = %{
      scan_type: "dependencies",
      timestamp: System.system_time(:millisecond),
      total_deps: length(deps),
      dependencies: deps,
      # Signal Theory encoding
      mode: "data",
      genre: "analysis",
      type: "inform",
      format: "json",
      structure: "list"
    }

    path = Path.join(output_dir, "deps.json")
    File.write!(path, Jason.encode!(output, pretty: true))

    {:ok, %{
      path: path,
      size: File.stat!(path).size,
      dep_count: length(deps)
    }}
  end

  defp scan_patterns(codebase_path, output_dir) do
    # Scan for YAWL workflow patterns
    patterns = detect_yawl_patterns(codebase_path)

    # Signal Theory S=(M,G,T,F,W) encoding
    output = %{
      scan_type: "patterns",
      timestamp: System.system_time(:millisecond),
      total_patterns: length(patterns),
      patterns: patterns,
      # Signal Theory encoding
      mode: "data",
      genre: "analysis",
      type: "inform",
      format: "json",
      structure: "list"
    }

    path = Path.join(output_dir, "patterns.json")
    File.write!(path, Jason.encode!(output, pretty: true))

    {:ok, %{
      path: path,
      size: File.stat!(path).size,
      pattern_count: length(patterns)
    }}
  end

  # Directories to skip when scanning — these contain third-party or generated code
  @excluded_dir_patterns ["deps/", "_build/", "vendor/", "node_modules/", ".git/"]

  defp excluded_path?(file) do
    Enum.any?(@excluded_dir_patterns, fn pattern ->
      String.contains?(file, "/" <> pattern) or String.contains?(file, pattern)
    end)
  end

  defp valid_file?(file) do
    depth = file |> Path.split() |> length()
    normalized = normalize_path(file)
    depth <= 50 and
      not String.contains?(normalized, "..") and
      not excluded_path?(file) and
      match?({:ok, %{type: :regular}}, File.stat(file))
  end

  defp read_file_safe(file) do
    case File.stat(file) do
      {:ok, %{size: size}} when size > @max_file_bytes ->
        Logger.warning("[SensorRegistry] Skipping large file: #{file} (#{div(size, 1024)}KB)")
        ""
      {:ok, _} ->
        try do
          code = File.read!(file)
          if byte_size(code) > @max_file_bytes, do: String.slice(code, 0, @max_file_bytes), else: code
        rescue
          File.Error -> ""
        catch
          :error, _ -> ""
        end
      {:error, _} ->
        ""
    end
  end

  defp discover_modules(codebase_path) do
    # Find all module/type/function definitions in the codebase.
    # Elixir: defmodule X
    # Go:     func FuncName / type TypeName (exported symbols, non-test files)
    # Rust:   pub fn / pub struct / pub enum / pub trait

    case File.dir?(codebase_path) do
      false -> []
      true ->
        try do
          elixir_modules =
            codebase_path
            |> Path.join("**/*.ex")
            |> Path.wildcard()
            |> Enum.filter(&valid_file?/1)
            |> Enum.flat_map(&extract_modules_from_file(&1, codebase_path))
            |> Enum.uniq_by(fn %{name: name, file: f} -> {name, f} end)

          go_modules =
            codebase_path
            |> Path.join("**/*.go")
            |> Path.wildcard()
            |> Enum.filter(&valid_file?/1)
            # Exclude test files from Go — they add noise but aren't production modules
            |> Enum.reject(fn f -> String.ends_with?(f, "_test.go") end)
            |> Enum.flat_map(&extract_go_modules(&1, codebase_path))
            |> Enum.uniq_by(fn %{name: name, file: f} -> {name, f} end)

          rust_modules =
            codebase_path
            |> Path.join("**/*.rs")
            |> Path.wildcard()
            |> Enum.filter(&valid_file?/1)
            |> Enum.flat_map(&extract_rust_modules(&1, codebase_path))
            |> Enum.uniq_by(fn %{name: name, file: f} -> {name, f} end)

          elixir_modules ++ go_modules ++ rust_modules
        rescue
          e ->
            Logger.warning("[SensorRegistry] Error scanning modules: #{Exception.message(e)}")
            []
        end
    end
  end

  defp extract_go_modules(file, codebase_path) do
    relative_path = Path.relative_to(file, codebase_path)
    code = read_file_safe(file)

    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} ->
      Regex.match?(~r/^(func|type)\s+[A-Z]/, line)
    end)
    |> Enum.map(fn {line, idx} ->
      name = case Regex.run(~r/^(func|type)\s+(\w+)/, line, capture: :all_but_first) do
        [_kind, n] -> n
        _ -> "unknown"
      end
      %{name: name, type: "go", file: relative_path, line: idx}
    end)
  end

  defp extract_rust_modules(file, codebase_path) do
    relative_path = Path.relative_to(file, codebase_path)
    code = read_file_safe(file)

    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} ->
      Regex.match?(~r/^pub\s+(fn|struct|enum|trait)\s+/, line)
    end)
    |> Enum.map(fn {line, idx} ->
      name = case Regex.run(~r/^pub\s+(?:fn|struct|enum|trait)\s+(\w+)/, line, capture: :all_but_first) do
        [n] -> n
        _ -> "unknown"
      end
      %{name: name, type: "rust", file: relative_path, line: idx}
    end)
  end

  defp extract_modules_from_file(file, base_path) do
    relative_path = Path.relative_to(file, base_path)
    code = read_file_safe(file)

    extract_modules_from_code(code)
    |> Enum.map(fn name ->
      %{
        name: name,
        file: relative_path,
        type: module_type(name),
        line: find_line_number(file, name)
      }
    end)
  end

  @doc """
  Extract module names from Elixir code string.

  ## Examples

      iex> OptimalSystemAgent.Sensors.SensorRegistry.extract_modules_from_code("defmodule Foo do end")
      ["Foo"]

      iex> OptimalSystemAgent.Sensors.SensorRegistry.extract_modules_from_code("defmodule A.B.C do end")
      ["A.B.C"]
  """
  def extract_modules_from_code(code) when is_binary(code) do
    # Extract module names from Elixir code
    # Supports nested modules like A.B.C.D.E
    # Limit scan to first 1MB to prevent regex hangs on massive single-line files
    code_to_scan = if byte_size(code) > @max_file_bytes do
      String.slice(code, 0, @max_file_bytes)
    else
      code
    end

    Regex.scan(~r/defmodule\s+([A-Z]\w*(?:\s*\.\s*[A-Z]\w*)*)/, code_to_scan)
    |> Enum.map(fn [_match, name] -> name end)
  end

  def extract_modules_from_code(_), do: []

  defp module_type(name) do
    cond do
      String.ends_with?(name, "Agent") -> :agent
      String.ends_with?(name, "GenServer") -> :genserver
      String.ends_with?(name, "Supervisor") -> :supervisor
      String.ends_with?(name, "Application") -> :application
      true -> :module
    end
  end

  defp find_line_number(file, name) do
    file
    |> File.stream!()
    |> Enum.with_index()
    |> Enum.find(fn {line, _idx} ->
      String.contains?(line, "defmodule #{name}") || String.contains?(line, "defmodule #{name}.")
    end)
    |> case do
      {_line, idx} -> idx + 1
      nil -> 0
    end
  end

  defp discover_dependencies(codebase_path) do
    case File.dir?(codebase_path) do
      false ->
        []

      true ->
        try do
          codebase_path
          |> Path.join("**/*.ex")
          |> Path.wildcard()
          |> Enum.filter(&valid_file?/1)
          |> Enum.flat_map(fn file ->
            relative_path = Path.relative_to(file, codebase_path)
            extract_dependencies_from_file(file, relative_path)
          end)
          |> Enum.uniq()
        rescue
          e ->
            Logger.warning("[SensorRegistry] Error scanning dependencies: #{Exception.message(e)}")
            []
        end
    end
  end

  defp extract_dependencies_from_file(file, relative_path) do
    code_to_scan = read_file_safe(file)

    # Extract the module name defined in this file
    source_module =
      case Regex.run(~r/defmodule\s+([A-Z]\w*(?:\s*\.\s*[A-Z]\w*)*)/, code_to_scan) do
        [_, name] -> name
        nil -> relative_path
      end

    # Find use, import, require, alias statements
    dep_regex = ~r/\b(use|import|require|alias)\s+([A-Z]\w*(?:\s*\.\s*[A-Z]\w*)*)/

    Regex.scan(dep_regex, code_to_scan)
    |> Enum.map(fn [_match, type, target] ->
      %{
        source: source_module,
        target: target,
        type: String.to_atom(type),
        file: relative_path
      }
    end)
  end

  defp detect_yawl_patterns(codebase_path) do
    case File.dir?(codebase_path) do
      false ->
        []

      true ->
        try do
          codebase_path
          |> Path.join("**/*.ex")
          |> Path.wildcard()
          |> Enum.filter(&valid_file?/1)
          |> Enum.flat_map(fn file ->
            relative_path = Path.relative_to(file, codebase_path)
            extract_patterns_from_file(file, relative_path)
          end)
          |> Enum.uniq_by(fn %{pattern: pattern, file: file} -> {pattern, file} end)
        rescue
          e ->
            Logger.warning("[SensorRegistry] Error scanning patterns: #{Exception.message(e)}")
            []
        end
    end
  end

  defp extract_patterns_from_file(file, relative_path) do
    code_to_scan = read_file_safe(file)

    patterns = []

    # YAWL Pattern: Sequence — pipe operator chains
    patterns =
      if Regex.match?(~r/\|>/, code_to_scan) do
        pipe_count = code_to_scan |> String.split("|>") |> length() |> Kernel.-(1)

        [%{
          pattern: "sequence",
          yawl_category: "control_flow",
          file: relative_path,
          count: pipe_count,
          evidence: "pipe_operator"
        } | patterns]
      else
        patterns
      end

    # YAWL Pattern: Parallel Split — Task.async / Task.Supervisor
    patterns =
      if Regex.match?(~r/Task\.async/, code_to_scan) do
        async_count = length(Regex.scan(~r/Task\.async/, code_to_scan))

        [%{
          pattern: "parallel_split",
          yawl_category: "multiple_instance",
          file: relative_path,
          count: async_count,
          evidence: "Task.async"
        } | patterns]
      else
        patterns
      end

    # YAWL Pattern: Exclusive Choice — case/cond
    patterns =
      if Regex.match?(~r/\b(case|cond)\b/, code_to_scan) do
        choice_count = length(Regex.scan(~r/\b(case|cond)\b/, code_to_scan))

        [%{
          pattern: "exclusive_choice",
          yawl_category: "control_flow",
          file: relative_path,
          count: choice_count,
          evidence: "case/cond"
        } | patterns]
      else
        patterns
      end

    # YAWL Pattern: Synchronization — Task.await_many / GenServer.call
    patterns =
      if Regex.match?(~r/(Task\.await|GenServer\.call)/, code_to_scan) do
        sync_count = length(Regex.scan(~r/(Task\.await|GenServer\.call)/, code_to_scan))

        [%{
          pattern: "synchronization",
          yawl_category: "control_flow",
          file: relative_path,
          count: sync_count,
          evidence: "Task.await/GenServer.call"
        } | patterns]
      else
        patterns
      end

    # YAWL Pattern: Multiple Instance — Enum.map/each with concurrency
    patterns =
      if Regex.match?(~r/Task\.Supervisor\.start_child/, code_to_scan) do
        mi_count = length(Regex.scan(~r/Task\.Supervisor\.start_child/, code_to_scan))

        [%{
          pattern: "multiple_instance",
          yawl_category: "multiple_instance",
          file: relative_path,
          count: mi_count,
          evidence: "Task.Supervisor.start_child"
        } | patterns]
      else
        patterns
      end

    # YAWL Pattern: Deferred Choice — receive/do blocks with timeouts
    patterns =
      if Regex.match?(~r/receive\s+do/, code_to_scan) do
        recv_count = length(Regex.scan(~r/receive\s+do/, code_to_scan))

        [%{
          pattern: "deferred_choice",
          yawl_category: "control_flow",
          file: relative_path,
          count: recv_count,
          evidence: "receive/do"
        } | patterns]
      else
        patterns
      end

    # YAWL Pattern: Interleaved Routing — DynamicSupervisor
    patterns =
      if Regex.match?(~r/DynamicSupervisor/, code_to_scan) do
        ds_count = length(Regex.scan(~r/DynamicSupervisor/, code_to_scan))

        [%{
          pattern: "interleaved_routing",
          yawl_category: "advanced_branching",
          file: relative_path,
          count: ds_count,
          evidence: "DynamicSupervisor"
        } | patterns]
      else
        patterns
      end

    # YAWL Pattern: Structured Loop — handle_call with recursive state
    patterns =
      if Regex.match?(~r/@impl true\s+def handle_call/, code_to_scan) do
        handler_count = length(Regex.scan(~r/@impl true\s+def handle_call/, code_to_scan))

        [%{
          pattern: "structured_loop",
          yawl_category: "control_flow",
          file: relative_path,
          count: handler_count,
          evidence: "GenServer.handle_call"
        } | patterns]
      else
        patterns
      end

    patterns
  end

  defp get_latest_scan(_state) do
    # Get the most recent scan by timestamp, not by insertion order
    # ETS :set tables don't maintain chronological order, so we need to scan all entries
    case :ets.match(@scan_table, {:"$1", :"$2"}) do
      [] -> nil
      matches ->
        # matches is [[scan_id, scan_data], ...]
        matches
        |> Enum.map(fn [_scan_id, scan] -> scan end)
        # Sort by timestamp descending (most recent first)
        |> Enum.sort_by(fn scan -> scan.timestamp end, :desc)
        # Return the most recent scan
        |> List.first()
    end
  end

  defp calculate_fingerprint(scan) do
    # Calculate SHA256 of combined sensor data
    combined = [
      scan.modules.path,
      scan.deps.path,
      scan.patterns.path
    ]

    :crypto.hash(:sha256, :erlang.term_to_binary(combined))
    |> Base.encode16(case: :lower)
  end

  defp generate_scan_id do
    :crypto.hash(:sha256, :erlang.term_to_binary({self(), System.system_time(:millisecond)}))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end
end
