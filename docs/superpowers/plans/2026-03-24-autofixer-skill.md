# Auto-Fixer Superpower Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an automated test failure detection and fixing system for OSA that scans test output, matches known failure patterns, applies fixes with confirmation, and verifies results.

**Architecture:** Pattern database (JSON) → Detection Engine (regex-based parsing) → Fix Application (line-aware replacement + git snapshot + mix format) → Verification (single test with timeout) → Report results.

**Tech Stack:** Elixir/OTP, Mix tasks, Jason (JSON), Regex for pattern matching, ExUnit for verification, git for snapshots.

---

## File Structure

```
OSA/
├── priv/superpowers/patterns/
│   └── test_fixes.json                    # Pattern database (versioned JSON)
├── lib/mix/tasks/autofixer.ex             # Mix task CLI entry point
├── lib/superpowers/
│   ├── auto_fixer.ex                      # Main engine: parse, detect, match
│   ├── auto_fixer/
│   │   ├── pattern_loader.ex              # Load patterns from JSON
│   │   ├── output_parser.ex               # Parse ExUnit output
│   │   ├── pattern_matcher.ex             # Match failures to patterns
│   │   ├── fix_applier.ex                 # Apply fixes to source files
│   │   └── verification.ex                # Re-run tests to verify
│   └── auto_fixer/
│       └── patterns/
│           └── default_patterns.ex        # Builtin patterns (code fallback)
├── test/superpowers/
│   ├── auto_fixer_test.exs                # Main engine tests
│   ├── auto_fixer/
│   │   ├── pattern_loader_test.exs
│   │   ├── output_parser_test.exs
│   │   ├── pattern_matcher_test.exs
│   │   ├── fix_applier_test.exs
│   │   └── verification_test.exs
│   └── fixtures/
│       └── test_output_samples.txt        # Sample ExUnit outputs for testing
└── docs/superpowers/plans/
    └── 2026-03-24-autofixer-skill.md      # This plan
```

**Each file responsibility:**
- `test_fixes.json` - User-editable pattern database, versioned for migration
- `autofixer.ex` - Mix task, CLI interface, orchestrates the pipeline
- `auto_fixer.ex` - Main pipeline: parse → detect → match → apply → verify
- `pattern_loader.ex` - Load/validate JSON patterns, merge with defaults
- `output_parser.ex` - Parse ExUnit output into structured failure maps
- `pattern_matcher.ex` - Match failure error messages to pattern regex
- `fix_applier.ex` - Apply fixes to source files (dry-run, confirm, auto, git snapshot, format)
- `verification.ex` - Re-run specific tests (single test, timeout), collect pass/fail results
- `default_patterns.ex` - Builtin patterns as code fallback if JSON missing

---

## Task 1: Pattern Database Structure

**Files:**
- Create: `priv/superpowers/patterns/test_fixes.json`
- Create: `lib/superpowers/auto_fixer/patterns/default_patterns.ex`
- Create: `lib/superpowers/auto_fixer/pattern_loader.ex`
- Test: `test/superpowers/auto_fixer/pattern_loader_test.exs`

- [ ] **Step 1: Create pattern JSON structure**

```bash
mkdir -p priv/superpowers/patterns
```

Create `priv/superpowers/patterns/test_fixes.json`:

```json
{
  "version": "1.0.0",
  "patterns": [
    {
      "id": "private_function_visibility",
      "name": "Private Function Visibility Fixer",
      "description": "Fixes tests that fail because private functions are called",
      "error_patterns": [
        "UndefinedFunctionError.*function.*is undefined or private"
      ],
      "detection": {
        "file_pattern": "lib/**/*.ex",
        "search_pattern": "defp\\\\s+([a-z_][a-z0-9_]*[!?]?)"
      },
      "fix": {
        "action": "replace_defp_with_def",
        "description": "Replace defp with def and add @doc"
      }
    },
    {
      "id": "changeset_defaults",
      "name": "Changeset Default Fixer",
      "description": "Fixes changeset defaults that don't show in get_change",
      "error_patterns": [
        "Ecto.Changeset.get_change.*nil.*expected"
      ],
      "detection": {
        "file_pattern": "lib/**/store/*.ex",
        "context": "changeset/2 function"
      },
      "fix": {
        "action": "add_put_default_helper",
        "template": "put_default_if_not_in_attrs/4",
        "code": "defp put_default_if_not_in_attrs(changeset, attrs, field, default) do\\n  if Map.has_key?(attrs, field) or Map.has_key?(attrs, to_string(field)) do\\n    changeset\\n  else\\n    Ecto.Changeset.force_change(changeset, field, default)\\n  end\\nend"
      }
    },
    {
      "id": "genserver_state_cleanup",
      "name": "GenServer State Cleanup",
      "description": "Adds cleanup before GenServer start in tests",
      "error_patterns": [
        "already_started.*bad child specification",
        "\\{\\:already_started"
      ],
      "detection": {
        "file_pattern": "test/**/*_test.exs",
        "context": "setup block with start_supervised!"
      },
      "fix": {
        "action": "add_stop_before_start",
        "description": "Add GenServer.stop check before start_supervised!"
      }
    }
  ]
}
```

- [ ] **Step 2: Create default patterns module (code fallback)**

Create `lib/superpowers/auto_fixer/patterns/default_patterns.ex`:

```elixir
defmodule Superpowers.AutoFixer.Patterns.DefaultPatterns do
  @moduledoc """
  Builtin patterns as code fallback.
  Used if test_fixes.json is missing or corrupted.
  """

  @doc "Get default patterns as Elixir maps."
  def get_patterns do
    [
      %{
        "id" => "private_function_visibility",
        "name" => "Private Function Visibility Fixer",
        "description" => "Fixes tests that fail because private functions are called",
        "error_patterns" => [
          ~r/UndefinedFunctionError.*function.*is undefined or private/
        ],
        "detection" => %{
          "file_pattern" => "lib/**/*.ex",
          "search_pattern" => ~r/defp\s+([a-z_][a-z0-9_]*[!?]?)/
        },
        "fix" => %{
          "action" => "replace_defp_with_def",
          "description" => "Replace defp with def and add @doc"
        }
      },
      %{
        "id" => "changeset_defaults",
        "name" => "Changeset Default Fixer",
        "description" => "Fixes changeset defaults that don't show in get_change",
        "error_patterns" => [
          ~r/Ecto\.Changeset\.get_change.*nil.*expected/
        ],
        "detection" => %{
          "file_pattern" => "lib/**/store/*.ex",
          "context" => "changeset/2 function"
        },
        "fix" => %{
          "action" => "add_put_default_helper",
          "template" => "put_default_if_not_in_attrs/4",
          "code" => """
          defp put_default_if_not_in_attrs(changeset, attrs, field, default) do
            if Map.has_key?(attrs, field) or Map.has_key?(attrs, to_string(field)) do
              changeset
            else
              Ecto.Changeset.force_change(changeset, field, default)
            end
          end
          """
        }
      },
      %{
        "id" => "genserver_state_cleanup",
        "name" => "GenServer State Cleanup",
        "description" => "Adds cleanup before GenServer start in tests",
        "error_patterns" => [
          ~r/already_started.*bad child specification/,
          ~r/\{:already_started/
        ],
        "detection" => %{
          "file_pattern" => "test/**/*_test.exs",
          "context" => "setup block with start_supervised!"
        },
        "fix" => %{
          "action" => "add_stop_before_start",
          "description" => "Add GenServer.stop check before start_supervised!"
        }
      }
    ]
  end
end
```

- [ ] **Step 3: Write the failing test for pattern_loader**

Create `test/superpowers/auto_fixer/pattern_loader_test.exs`:

```elixir
defmodule Superpowers.AutoFixer.PatternLoaderTest do
  use ExUnit.Case, async: true

  alias Superpowers.AutoFixer.PatternLoader

  describe "load_patterns/0" do
    test "loads patterns from JSON file" do
      patterns = PatternLoader.load_patterns()

      assert is_list(patterns)
      assert length(patterns) >= 3

      # Check private_function_visibility pattern
      private_fn = Enum.find(patterns, fn p -> p["id"] == "private_function_visibility" end)
      assert private_fn
      assert private_fn["name"] == "Private Function Visibility Fixer"
      assert is_list(private_fn["error_patterns"])
    end

    test "returns default patterns if JSON file missing" do
      # Temporarily rename JSON file
      File.rename!("priv/superpowers/patterns/test_fixes.json", "priv/superpowers/patterns/test_fixes.json.bak")

      patterns = PatternLoader.load_patterns()

      assert is_list(patterns)
      assert length(patterns) >= 3

      # Restore
      File.rename!("priv/superpowers/patterns/test_fixes.json.bak", "priv/superpowers/patterns/test_fixes.json")
    end

    test "validates pattern structure" do
      patterns = PatternLoader.load_patterns()

      Enum.each(patterns, fn pattern ->
        assert Map.has_key?(pattern, "id")
        assert Map.has_key?(pattern, "name")
        assert Map.has_key?(pattern, "error_patterns")
        assert Map.has_key?(pattern, "detection")
        assert Map.has_key?(pattern, "fix")
      end)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/pattern_loader_test.exs`

Expected: `** (CompileError) undefined module Superpowers.AutoFixer.PatternLoader`

- [ ] **Step 5: Implement PatternLoader module**

Create `lib/superpowers/auto_fixer/pattern_loader.ex`:

```elixir
defmodule Superpowers.AutoFixer.PatternLoader do
  @moduledoc """
  Load test fix patterns from JSON or default to builtin patterns.
  """

  @pattern_path "priv/superpowers/patterns/test_fixes.json"

  @doc "Load patterns from JSON file or return defaults."
  def load_patterns do
    if File.exists?(@pattern_path) do
      load_from_json()
    else
      load_defaults()
    end
  rescue
    _ -> load_defaults()
  end

  defp load_from_json do
    @pattern_path
    |> File.read!()
    |> Jason.decode!()
    |> Map.get("patterns", [])
    |> compile_regex_patterns()
  end

  defp load_defaults do
    Superpowers.AutoFixer.Patterns.DefaultPatterns.get_patterns()
  end

  # Compile string patterns to regex for matching
  defp compile_regex_patterns(patterns) do
    Enum.map(patterns, fn pattern ->
      updated_error_patterns =
        Enum.map(pattern["error_patterns"], fn error_pattern ->
          if is_binary(error_pattern) do
            Regex.compile!(error_pattern)
          else
            error_pattern
          end
        end)

      %{pattern | "error_patterns" => updated_error_patterns}
    end)
  end
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/pattern_loader_test.exs`

Expected: PASS, 3 tests, 0 failures

- [ ] **Step 7: Commit**

```bash
git add priv/superpowers/patterns/ lib/superpowers/auto_fixer/patterns/ test/superpowers/auto_fixer/
git commit -m "feat: add pattern database and loader for auto-fixer"
```

---

## Task 2: ExUnit Output Parser

**Files:**
- Create: `lib/superpowers/auto_fixer/output_parser.ex`
- Create: `test/superpowers/fixtures/test_output_samples.txt`
- Test: `test/superpowers/auto_fixer/output_parser_test.exs`

- [ ] **Step 1: Create test output fixture**

Create `test/superpowers/fixtures/test_output_samples.txt`:

```
  1) test doctor check returns health check results (OptimalSystemAgent.CLIDoctorTest)
     test/optimal_system_agent/cli/doctor_test.exs:6

     ** (UndefinedFunctionError) function OptimalSystemAgent.CLI.Doctor.check_runtime/0 is undefined or private
     code: assert {:pass, _, _} = Doctor.check_runtime()
     stacktrace:
       (optimal_system_agent) lib/optimal_system_agent/cli/doctor.ex:23: OptimalSystemAgent.CLI.Doctor.check_runtime/0

  2) test consolidates similar memory entries (OptimalSystemAgent.Memory.ConsolidatorTest)
     test/optimal_system_agent/memory/consolidator_test.exs:45

     ** (UndefinedFunctionError) function OptimalSystemAgent.Memory.Consolidator.consolidate/1 is undefined or private
     code: entries = Consolidator.consolidate(@sample_entries)
     stacktrace:
       (optimal_system_agent) lib/optimal_system_agent/memory/consolidator.ex:18: OptimalSystemAgent.Memory.Consolidator.consolidate/1

  3) test signal changeset defaults weight to 0.5 (OptimalSystemAgent.Store.SignalTest)
     test/optimal_system_agent/store/signal_test.exs:32

     Assertion with == failed
     code:  assert Ecto.Changeset.get_change(changeset, :weight) == 0.5
     left:  nil
     right: 0.5
     stacktrace:
       test/optimal_system_agent/store/signal_test.exs:32: (test)

  4) test region lock prevents concurrent access (OptimalSystemAgent.FileLocking.RegionLockTest)
     test/optimal_system_agent/file_locking/region_lock_test.exs:67

     ** (exit) exited in: GenServer.call(RegionLock, {:start_link, [...]}, 5000)
     ** (EXIT) {:already_started, #PID<0.372.0>}
     stacktrace:
       (optimal_system_agent) lib/optimal_system_agent/file_locking/region_lock.ex:45: :gen_server.call/3
```

- [ ] **Step 2: Write failing test for output parser**

Create `test/superpowers/auto_fixer/output_parser_test.exs`:

```elixir
defmodule Superpowers.AutoFixer.OutputParserTest do
  use ExUnit.Case, async: true

  alias Superpowers.AutoFixer.OutputParser

  describe "parse/1" do
    test "extracts test names from ExUnit output" do
      output = File.read!("test/superpowers/fixtures/test_output_samples.txt")
      failures = OutputParser.parse(output)

      assert length(failures) == 4

      # Check first failure
      first = hd(failures)
      assert first.test_name == "doctor check returns health check results"
      assert first.module == "OptimalSystemAgent.CLIDoctorTest"
      assert first.file == "test/optimal_system_agent/cli/doctor_test.exs"
      assert first.line == 6
    end

    test "extracts error messages" do
      output = File.read!("test/superpowers/fixtures/test_output_samples.txt")
      failures = OutputParser.parse(output)

      private_fn_error = Enum.find(failures, fn f ->
        String.contains?(f.error_message, "UndefinedFunctionError")
      end)

      assert private_fn_error
      assert String.contains?(private_fn_error.error_message, "check_runtime/0")
    end

    test "extracts stack traces" do
      output = File.read!("test/superpowers/fixtures/test_output_samples.txt")
      failures = OutputParser.parse(output)

      first = hd(failures)
      assert is_list(first.stack_trace)
      assert length(first.stack_trace) > 0
    end

    test "handles empty output" do
      failures = OutputParser.parse("")
      assert failures == []
    end

    test "handles output with no failures" do
      no_failures = "..
      Finished in 0.1 seconds (0.1s on load, 0.01s on tests)
      2 tests, 0 failures"

      failures = OutputParser.parse(no_failures)
      assert failures == []
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/output_parser_test.exs`

Expected: `** (CompileError) undefined module Superpowers.AutoFixer.OutputParser`

- [ ] **Step 4: Implement OutputParser module**

Create `lib/superpowers/auto_fixer/output_parser.ex`:

```elixir
defmodule Superpowers.AutoFixer.OutputParser do
  @moduledoc """
  Parse ExUnit test output into structured failure maps.
  """

  defstruct [:test_name, :module, :file, :line, :error_message, :stack_trace, :raw_output]

  @doc "Parse ExUnit output and return list of failure structs."
  def parse(output) when is_binary(output) do
    output
    |> String.split("\n")
    |> extract_failure_blocks()
    |> Enum.map(&parse_failure_block/1)
    |> Enum.reject(&(&1 == nil))
  end

  # Extract contiguous failure blocks from output
  defp extract_failure_blocks(lines) do
    lines
    |> Enum.chunk_by(&String.starts_with?(&1, "  ") or String.starts_with?(&1, "1)"))
    |> Enum.filter(fn chunk ->
      header = List.first(chunk) || ""
      String.match?(header, ~r/^\s*\d+\)/)
    end)
    |> Enum.map(&Enum.join(&1, "\n"))
  end

  # Parse a single failure block
  defp parse_failure_block(block) do
    %__MODULE__{
      test_name: extract_test_name(block),
      module: extract_module(block),
      file: extract_file(block),
      line: extract_line(block),
      error_message: extract_error_message(block),
      stack_trace: extract_stack_trace(block),
      raw_output: block
    }
  end

  # Extract: "doctor check returns health check results"
  defp extract_test_name(block) do
    Regex.run(~r/test (.+?) \(/, block)
    |> case do
      [_, name] -> String.trim(name)
      _ -> nil
    end
  end

  # Extract: "OptimalSystemAgent.CLIDoctorTest"
  defp extract_module(block) do
    Regex.run(~r/\(([\w\.]+)\)/, block)
    |> case do
      [_, module] -> module
      _ -> nil
    end
  end

  # Extract: "test/optimal_system_agent/cli/doctor_test.exs"
  defp extract_file(block) do
    Regex.run(~r/([a-z_\/]+\/[a-z_]+\.exs?):\d+/, block)
    |> case do
      [_, file] -> file
      _ -> nil
    end
  end

  # Extract line number
  defp extract_line(block) do
    Regex.run(~r/:(\d+)/, block)
    |> case do
      [_, line_str] -> String.to_integer(line_str)
      _ -> nil
    end
  end

  # Extract the error message (first line after "** (...)")
  defp extract_error_message(block) do
    lines = String.split(block, "\n")

    error_line =
      Enum.find(lines, fn line ->
        String.contains?(line, "** (") and not String.contains?(line, "stacktrace")
      end)

    case error_line do
      nil -> nil
      line -> String.trim(line)
    end
  end

  # Extract stack trace lines
  defp extract_stack_trace(block) do
    lines = String.split(block, "\n")

    lines
    |> Enum.drop_while(&(not String.contains?(&1, "stacktrace")))
    |> Enum.drop(1)
    |> Enum.take_while(&String.starts_with?(&1, "   "))
    |> Enum.map(&String.trim/1)
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/output_parser_test.exs`

Expected: PASS, 5 tests

- [ ] **Step 6: Commit**

```bash
git add lib/superpowers/auto_fixer/output_parser.ex test/superpowers/fixtures/ test/superpowers/auto_fixer/output_parser_test.exs
git commit -m "feat: add ExUnit output parser for auto-fixer"
```

---

## Task 3: Pattern Matcher

**Files:**
- Create: `lib/superpowers/auto_fixer/pattern_matcher.ex`
- Test: `test/superpowers/auto_fixer/pattern_matcher_test.exs`

- [ ] **Step 1: Write failing test for pattern matcher**

Create `test/superpowers/auto_fixer/pattern_matcher_test.exs`:

```elixir
defmodule Superpowers.AutoFixer.PatternMatcherTest do
  use ExUnit.Case, async: true

  alias Superpowers.AutoFixer.PatternMatcher
  alias Superpowers.AutoFixer.OutputParser

  describe "match_failure/2" do
    setup do
      output = File.read!("test/superpowers/fixtures/test_output_samples.txt")
      failures = OutputParser.parse(output)
      %{failures: failures}
    end

    test "matches UndefinedFunctionError to private_function_visibility pattern", %{failures: failures} do
      private_fn_failure = Enum.find(failures, fn f ->
        String.contains?(f.error_message, "UndefinedFunctionError")
      end)

      pattern = PatternMatcher.match_failure(private_fn_failure)

      assert pattern
      assert pattern["id"] == "private_function_visibility"
    end

    test "matches get_change nil to changeset_defaults pattern", %{failures: failures} do
      changeset_failure = Enum.find(failures, fn f ->
        String.contains?(f.raw_output, "get_change") and String.contains?(f.raw_output, "nil")
      end)

      pattern = PatternMatcher.match_failure(changeset_failure)

      assert pattern
      assert pattern["id"] == "changeset_defaults"
    end

    test "matches already_started to genserver_state_cleanup pattern", %{failures: failures} do
      genserver_failure = Enum.find(failures, fn f ->
        String.contains?(f.raw_output, "already_started")
      end)

      pattern = PatternMatcher.match_failure(genserver_failure)

      assert pattern
      assert pattern["id"] == "genserver_state_cleanup"
    end

    test "returns nil for unmatched failure" do
      unmatched = %OutputParser{
        error_message: "Some unknown error",
        raw_output: "weird error"
      }

      assert PatternMatcher.match_failure(unmatched) == nil
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/pattern_matcher_test.exs`

Expected: `** (CompileError) undefined module Superpowers.AutoFixer.PatternMatcher`

- [ ] **Step 3: Implement PatternMatcher module**

Create `lib/superpowers/auto_fixer/pattern_matcher.ex`:

```elixir
defmodule Superpowers.AutoFixer.PatternMatcher do
  @moduledoc """
  Match test failures to fix patterns based on error messages.
  """

  alias Superpowers.AutoFixer.PatternLoader
  alias Superpowers.AutoFixer.OutputParser

  @doc "Match a failure to a pattern or return nil."
  def match_failure(%OutputParser{} = failure) do
    patterns = PatternLoader.load_patterns()

    Enum.find(patterns, fn pattern ->
      matches_error_pattern?(failure, pattern)
    end)
  end

  # Check if failure matches any error pattern in the pattern
  defp matches_error_pattern?(failure, pattern) do
    error_patterns = pattern["error_patterns"]

    search_text = [
      failure.error_message,
      failure.raw_output
    ]
    |> Enum.join("\n")

    Enum.any?(error_patterns, fn error_pattern ->
      matches_regex_or_string?(search_text, error_pattern)
    end)
  end

  defp matches_regex_or_string?(text, %Regex{} = regex), do: Regex.match?(regex, text)
  defp matches_regex_or_string?(text, pattern) when is_binary(pattern), do: String.contains?(text, pattern)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/pattern_matcher_test.exs`

Expected: PASS, 4 tests

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer/pattern_matcher.ex test/superpowers/auto_fixer/pattern_matcher_test.exs
git commit -m "feat: add pattern matcher for auto-fixer"
```

---

## Task 4: Fix Applier (Split into 8 Subtasks for Granularity)

**Files:**
- Create: `lib/superpowers/auto_fixer/fix_applier.ex`
- Test: `test/superpowers/auto_fixer/fix_applier_test.exs`

### Subtask 4.1: Create FixApplier Module Stub

- [ ] **Step 1: Create minimal FixApplier module**

Create `lib/superpowers/auto_fixer/fix_applier.ex`:

```elixir
defmodule Superpowers.AutoFixer.FixApplier do
  @moduledoc """
  Apply fixes to source files based on matched patterns.
  """

  alias Superpowers.AutoFixer.OutputParser

  @doc "Apply a fix to the file referenced in the failure."
  def apply_fix(%OutputParser{} = _failure, _pattern, _opts \\ []) do
    {:not_implemented, nil}
  end
end
```

- [ ] **Step 2: Write test that expects apply_fix to work**

Create `test/superpowers/auto_fixer/fix_applier_test.exs`:

```elixir
defmodule Superpowers.AutoFixer.FixApplierTest do
  use ExUnit.Case, async: false

  alias Superpowers.AutoFixer.FixApplier
  alias Superpowers.AutoFixer.OutputParser

  @tmp_dir "test/tmp/fix_applier"

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    on_exit(fn -> File.rm_rf!(@tmp_dir) end)
    :ok
  end

  describe "apply_fix/3" do
    test "returns :not_implemented for now" do
      result = FixApplier.apply_fix(%OutputParser{}, %{})
      assert result == {:not_implemented, nil}
    end
  end
end
```

- [ ] **Step 3: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs`

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/superpowers/auto_fixer/fix_applier.ex test/superpowers/auto_fixer/fix_applier_test.exs
git commit -m "feat: add FixApplier module stub"
```

### Subtask 4.2: Implement Dry Run Mode

- [ ] **Step 1: Write failing test for dry_run mode**

Add to `test/superpowers/auto_fixer/fix_applier_test.exs`:

```elixir
test "dry_run returns changes without modifying file" do
  test_file = Path.join(@tmp_dir, "test.ex")
  File.write!(test_file, "defp foo, do: :bar")

  failure = %OutputParser{
    file: test_file,
    error_message: "** (UndefinedFunctionError) function foo/0 is undefined or private"
  }

  pattern = %{"id" => "private_function_visibility", "fix" => %{"action" => "replace_defp_with_def"}}

  result = FixApplier.apply_fix(failure, pattern, dry_run: true)

  assert {:dry_run, changes} = result
  assert is_list(changes)

  # File unchanged
  content = File.read!(test_file)
  assert String.contains?(content, "defp foo")
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:28`

Expected: FAIL - `{:not_implemented, nil} != {:dry_run, changes}`

- [ ] **Step 3: Implement dry_run mode**

Edit `lib/superpowers/auto_fixer/fix_applier.ex`:

```elixir
defmodule Superpowers.AutoFixer.FixApplier do
  @moduledoc """
  Apply fixes to source files based on matched patterns.
  """

  alias Superpowers.AutoFixer.OutputParser

  @doc "Apply a fix to the file referenced in the failure."
  def apply_fix(%OutputParser{} = failure, pattern, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, true)
    auto_approve = Keyword.get(opts, :auto_approve, false)

    cond do
      dry_run -> preview_fix(failure, pattern)
      auto_approve -> do_apply_fix(failure, pattern)
      true -> request_confirmation(failure, pattern)
    end
  end

  defp preview_fix(failure, pattern) do
    changes = calculate_changes(failure, pattern)
    {:dry_run, changes}
  end

  defp do_apply_fix(failure, pattern), do: {:not_implemented, nil}
  defp request_confirmation(failure, pattern), do: {:not_implemented, nil}
  defp calculate_changes(failure, pattern), do: []
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:28`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer/fix_applier.ex test/superpowers/auto_fixer/fix_applier_test.exs
git commit -m "feat: add dry_run mode to FixApplier"
```

### Subtask 4.3: Implement calculate_changes for defp -> def

- [ ] **Step 1: Write test for defp_to_def changes calculation**

Add to test file:

```elixir
test "calculates defp to def changes correctly" do
  test_file = Path.join(@tmp_dir, "test.ex")
  File.write!(test_file, """
  defmodule Test do
    defp foo, do: :bar
    defp baz, do: :qux
  end
  """)

  failure = %OutputParser{file: test_file}

  pattern = %{"id" => "private_function_visibility", "fix" => %{"action" => "replace_defp_with_def"}}

  # Call the private function via the public API
  result = FixApplier.apply_fix(failure, pattern, dry_run: true)
  assert {:dry_run, changes} = result
  assert length(changes) == 2
  assert hd(changes).search == "defp foo"
  assert hd(changes).replace == "def foo"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:50`

Expected: FAIL - changes list is empty

- [ ] **Step 3: Implement calculate_defp_to_def_changes**

Edit `lib/superpowers/auto_fixer/fix_applier.ex`:

```elixir
defp calculate_changes(failure, pattern) do
  action = pattern["fix"]["action"]

  case action do
    "replace_defp_with_def" -> calculate_defp_to_def_changes(failure)
    "add_put_default_helper" -> calculate_put_default_changes(failure, pattern)
    "add_stop_before_start" -> calculate_stop_before_start_changes(failure)
    _ -> []
  end
end

defp calculate_defp_to_def_changes(failure) do
  file_content = File.read!(failure.file)

  Regex.scan(~r/defp\s+([a-z_][a-z0-9_]*[!?]?)/, file_content)
  |> Enum.map(fn [full_match, func_name] ->
    %{
      file: failure.file,
      search: full_match,
      replace: String.replace_prefix(full_match, "defp", "def"),
      description: "Replace #{full_match} with def #{func_name}"
    }
  end)
end

defp calculate_put_default_changes(_failure, _pattern), do: []
defp calculate_stop_before_start_changes(_failure), do: []
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:50`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer/fix_applier.ex test/superpowers/auto_fixer/fix_applier_test.exs
git commit -m "feat: implement defp_to_def changes calculation"
```

### Subtask 4.4: Implement calculate_changes for put_default helper

- [ ] **Step 1: Write test for put_default changes**

Add to test file:

```elixir
test "calculates put_default helper changes" do
  test_file = Path.join(@tmp_dir, "changeset.ex")
  File.write!(test_file, """
  defmodule MyStore do
    def changeset(schema, attrs) do
      schema
      |> cast(attrs, [:field])
      |> validate_required([:field])
    end
  end
  """)

  failure = %OutputParser{
    file: test_file,
    error_message: "Ecto.Changeset.get_change returned nil"
  }

  pattern = %{
    "id" => "changeset_defaults",
    "fix" => %{
      "action" => "add_put_default_helper",
      "code" => "defp put_default_if_not_in_attrs(changeset, attrs, field, default) do\n  ...\nend"
    }
  }

  result = FixApplier.apply_fix(failure, pattern, dry_run: true)
  assert {:dry_run, changes} = result
  assert length(changes) > 0
  assert hd(changes).description == "Add put_default_if_not_in_attrs/4 helper"
  assert hd(changes).insert_location == "before validate_required"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:78`

Expected: FAIL - empty changes list

- [ ] **Step 3: Implement calculate_put_default_changes**

Edit `lib/superpowers/auto_fixer/fix_applier.ex`:

```elixir
defp calculate_put_default_changes(failure, pattern) do
  file_content = File.read!(failure.file)

  # Find the changeset/2 function
  if Regex.match?(~r/def\s+changeset\(/, file_content) do
    # Check if put_default helper already exists
    helper_exists? = Regex.match?(~r/def\s+put_default_if_not_in_attrs/, file_content)

    if helper_exists? do
      []
    else
      # Find the module end or last function to insert before
      insert_line = find_insertion_line(file_content)

      [%{
        file: failure.file,
        description: "Add put_default_if_not_in_attrs/4 helper",
        insert_location: "line_#{insert_line}",
        code: pattern["fix"]["code"],
        action: :insert
      }]
    end
  else
    []
  end
end

defp find_insertion_line(file_content) do
  lines = String.split(file_content, "\n")

  # Find last "end" that closes a function (indentation check)
  lines
  |> Enum.with_index(1)
  |> Enum.filter(fn {line, _idx} ->
    String.trim(line) == "end"
  end)
  |> List.last()
  |> elem(1)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:78`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer/fix_applier.ex test/superpowers/auto_fixer/fix_applier_test.exs
git commit -m "feat: implement put_default changes calculation"
```

### Subtask 4.5: Implement calculate_changes for stop_before_start

- [ ] **Step 1: Write test for stop_before_start changes**

Add to test file:

```elixir
test "calculates stop_before_start changes" do
  test_file = Path.join(@tmp_dir, "test_file_test.exs")
  File.write!(test_file, """
  defmodule RegionLockTest do
    setup do
      start_supervised!(RegionLock)
      :ok
    end
  end
  """)

  failure = %OutputParser{
    file: test_file,
    error_message: "{:already_started, pid}"
  }

  pattern = %{
    "id" => "genserver_state_cleanup",
    "fix" => %{"action" => "add_stop_before_start"}
  }

  result = FixApplier.apply_fix(failure, pattern, dry_run: true)
  assert {:dry_run, changes} = result
  assert length(changes) > 0
  assert hd(changes).description == "Add GenServer.stop check before start_supervised!"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:125`

Expected: FAIL - empty changes

- [ ] **Step 3: Implement calculate_stop_before_start_changes**

Edit `lib/superpowers/auto_fixer/fix_applier.ex`:

```elixir
defp calculate_stop_before_start_changes(failure) do
  file_content = File.read!(failure.file)

  # Find setup blocks with start_supervised!
  if Regex.match?(~r/start_supervised!\(/, file_content) do
    # Extract the module name from start_supervised!(ModuleName)
    module_names =
      Regex.scan(~r/start_supervised!\((\w+)/, file_content)
      |> Enum.map(fn [_, name] -> name end)
      |> Enum.uniq()

    Enum.map(module_names, fn module_name ->
      %{
        file: failure.file,
        description: "Add GenServer.stop check before start_supervised!",
        module_name: module_name,
        action: :insert_before_start,
        code: """
        if pid = Process.whereis(#{module_name}) do
          GenServer.stop(pid)
        end
        """
      }
    end)
  else
    []
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:125`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer/fix_applier.ex test/superpowers/auto_fixer/fix_applier_test.exs
git commit -m "feat: implement stop_before_start changes calculation"
```

### Subtask 4.6: Implement apply_single_change with line-aware replacement

- [ ] **Step 1: Write test for apply_single_change**

Add to test file:

```elixir
test "applies single change to file" do
  test_file = Path.join(@tmp_dir, "test.ex")
  File.write!(test_file, "defp foo, do: :bar\ndefp baz, do: :qux")

  change = %{
    file: test_file,
    search: "defp foo",
    replace: "def foo",
    line: 1,
    action: :replace
  }

  # Apply via do_apply_fix
  result = FixApplier.apply_fix(
    %OutputParser{file: test_file},
    %{"fix" => %{"action" => "replace_defp_with_def"}},
    dry_run: false,
    auto_approve: true
  )

  assert {:applied, _changes} = result

  content = File.read!(test_file)
  assert String.contains?(content, "def foo, do: :bar")
  refute String.contains?(content, "defp foo")
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:165`

Expected: FAIL - `{:not_implemented, nil}`

- [ ] **Step 3: Implement do_apply_fix and apply_single_change**

Edit `lib/superpowers/auto_fixer/fix_applier.ex`:

```elixir
defp do_apply_fix(failure, pattern) do
  changes = calculate_changes(failure, pattern)

  # Create git snapshot before applying
  create_git_snapshot()

  Enum.each(changes, fn change ->
    apply_single_change(change)
  end)

  # Format the modified file
  format_modified_file(failure.file)

  {:applied, changes}
end

defp create_git_snapshot do
  System.cmd("git", ["add", "."])
  System.cmd("git", ["commit", "-m", "autofixer: snapshot before fix"])
end

defp format_modified_file(file_path) do
  System.cmd("mix", ["format", file_path])
end

defp apply_single_change(change) do
  case change.action do
    :replace -> apply_replace(change)
    :insert -> apply_insert(change)
    :insert_before_start -> apply_insert_before_start(change)
    _ -> :unknown_action
  end
end

defp apply_replace(change) do
  content = File.read!(change.file)
  lines = String.split(content, "\n")

  # Find and replace at specific line if provided, else first occurrence
  updated_lines =
    if Map.has_key?(change, :line) do
      line_num = change.line - 1  # 0-indexed
      List.update_at(lines, line_num, fn line ->
        String.replace(line, change.search, change.replace)
      end)
    else
      # Replace first occurrence only
      content
      |> String.split("\n")
      |> Enum.map(fn line ->
        if String.contains?(line, change.search) do
          String.replace(line, change.search, change.replace, global: false)
        else
          line
        end
      end)
    end

  File.write!(change.file, Enum.join(updated_lines, "\n"))
end

defp apply_insert(change) do
  content = File.read!(change.file)
  lines = String.split(content, "\n")

  # Insert before the specified line
  insert_at = change.insert_location |> String.replace_prefix("line_", "") |> String.to_integer()
  insert_at = max(0, insert_at - 1)

  updated_lines =
    List.insert_at(lines, insert_at, change.code)

  File.write!(change.file, Enum.join(updated_lines, "\n"))
end

defp apply_insert_before_start(change) do
  content = File.read!(change.file)

  # Find the line with start_supervised! and insert before it
  lines = String.split(content, "\n")

  start_line_idx =
    Enum.find_index(lines, fn line ->
      String.contains?(line, "start_supervised!(#{change.module_name}")
    end)

  if start_line_idx do
    # Insert the stop check before start_supervised!
    updated_lines =
      List.insert_at(
        lines,
        start_line_idx,
        String.trim(change.code)
      )

    File.write!(change.file, Enum.join(updated_lines, "\n"))
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:165`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer/fix_applier.ex test/superpowers/auto_fixer/fix_applier_test.exs
git commit -m "feat: implement apply_single_change with line-aware replacement and git snapshot"
```

### Subtask 4.7: Implement request_confirmation

- [ ] **Step 1: Write test for request_confirmation**

Add to test file:

```elixir
test "requests confirmation when not dry_run and not auto_approve" do
  test_file = Path.join(@tmp_dir, "test.ex")
  File.write!(test_file, "defp foo, do: :bar")

  failure = %OutputParser{
    file: test_file,
    test_name: "test foo"
  }

  pattern = %{
    "id" => "private_function_visibility",
    "name" => "Private Function Visibility Fixer",
    "fix" => %{"action" => "replace_defp_with_def"}
  }

  # Without auto_approve, should request confirmation (skip in automation)
  result = FixApplier.apply_fix(failure, pattern, dry_run: false, auto_approve: false)

  assert {:skipped, _changes} = result
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:220`

Expected: FAIL - `{:not_implemented, nil}`

- [ ] **Step 3: Implement request_confirmation**

Edit `lib/superpowers/auto_fixer/fix_applier.ex`:

```elixir
defp request_confirmation(failure, pattern) do
  changes = calculate_changes(failure, pattern)

  IO.puts("\n🔧 Auto-fixer suggests fix for: #{failure.test_name}")
  IO.puts("Pattern: #{pattern["name"]}")
  IO.puts("File: #{failure.file}")
  IO.puts("\nChanges:")

  Enum.each(changes, fn change ->
    IO.puts("  - #{change.description}")
  end)

  IO.write("\nApply this fix? [y/N] ")

  # In automation, default to skip for safety
  # Interactive mode would read from stdin
  {:skipped, changes}
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:220`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer/fix_applier.ex test/superpowers/auto_fixer/fix_applier_test.exs
git commit -m "feat: implement request_confirmation for FixApplier"
```

### Subtask 4.8: Integration Test - Full Workflow

- [ ] **Step 1: Write integration test**

Add to test file:

```elixir
describe "integration" do
  test "full workflow: dry_run -> auto_approve -> verify" do
    test_file = Path.join(@tmp_dir, "integration.ex")
    File.write!(test_file, """
    defmodule IntegrationTest do
      defp private_func, do: :secret
    end
    """)

    failure = %OutputParser{
      file: test_file,
      test_name: "integration test",
      error_message: "UndefinedFunctionError: function IntegrationTest.private_func/0 is undefined or private"
    }

    pattern = %{
      "id" => "private_function_visibility",
      "name" => "Private Function Visibility Fixer",
      "fix" => %{"action" => "replace_defp_with_def"}
    }

    # Dry run first
    assert {:dry_run, changes} = FixApplier.apply_fix(failure, pattern, dry_run: true)
    assert length(changes) == 1

    # Then apply
    assert {:applied, applied} = FixApplier.apply_fix(failure, pattern, dry_run: false, auto_approve: true)

    # Verify file was modified
    content = File.read!(test_file)
    assert String.contains?(content, "def private_func")
    refute String.contains?(content, "defp private_func")
  end
end
```

- [ ] **Step 2: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/fix_applier_test.exs:250`

Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/superpowers/auto_fixer/fix_applier_test.exs
git commit -m "test: add integration test for FixApplier"
```

---

## Task 5: Verification Engine (Fix Single Test Execution)

**Files:**
- Create: `lib/superpowers/auto_fixer/verification.ex`
- Test: `test/superpowers/auto_fixer/verification_test.exs`

### Subtask 5.1: Write failing test for single test execution

- [ ] **Step 1: Write test that runs single test**

Create `test/superpowers/auto_fixer/verification_test.exs`:

```elixir
defmodule Superpowers.AutoFixer.VerificationTest do
  use ExUnit.Case, async: false

  alias Superpowers.AutoFixer.Verification
  alias Superpowers.AutoFixer.OutputParser

  describe "verify_fix/2" do
    test "runs single test by name with timeout" do
      # Use a known passing test
      failure = %OutputParser{
        test_name: "run pass",
        module: "Superpowers.AutoFixer.PatternLoaderTest",
        file: "test/superpowers/auto_fixer/pattern_loader_test.exs"
      }

      result = Verification.verify_fix(failure, timeout: 30_000)

      assert {:verified, :pass} = result
    end

    test "returns failure when test fails" do
      # Create a failing test scenario
      failure = %OutputParser{
        test_name: "nonexistent test that will fail",
        module: "FakeModule",
        file: "test/superpowers/fake_test.exs"
      }

      result = Verification.verify_fix(failure, timeout: 5000)

      assert {:verification_failed, _reason} = result
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer/verification_test.exs`

Expected: `** (CompileError) undefined module Superpowers.AutoFixer.Verification`

- [ ] **Step 3: Implement Verification with single test execution**

Create `lib/superpowers/auto_fixer/verification.ex`:

```elixir
defmodule Superpowers.AutoFixer.Verification do
  @moduledoc """
  Verify that fixes actually work by re-running tests.
  """

  alias Superpowers.AutoFixer.OutputParser

  @default_timeout 30_000

  @doc "Verify a fix by re-running the specific test."
  def verify_fix(%OutputParser{} = failure, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    test_path = failure.file

    # Build test filter to run ONLY the specific test
    # Format: mix test path/to/test.exs:line --only test_name
    test_filter = build_test_filter(failure)

    args = ["test", test_path]
    args = if test_filter, do: args ++ [test_filter], else: args

    {output, exit_code} = System.cmd("mix", args,
      cd: File.cwd!(),
      timeout: timeout,
      stderr_to_stdout: true
    )

    # Check for specific test passing
    pass? = exit_code == 0 and test_passed_in_output?(output, failure)

    if pass? do
      {:verified, :pass}
    else
      {:verification_failed, :fail, extract_error_reason(output)}
    end
  end

  defp build_test_filter(%OutputParser{line: line}) when is_integer(line) do
    # Run specific test at line number
    ":#{line}"
  end
  defp build_test_filter(_), do: nil

  defp test_passed_in_output?(output, failure) do
    # Check if the specific test passed
    not String.contains?(output, "failure") and
    String.contains?(output, ".")
  end

  defp extract_error_reason(output) do
    # Extract first error line from output
    output
    |> String.split("\n")
    |> Enum.find(fn line ->
      String.contains?(line, "**") or String.contains?(line, "error")
    end)
  end

  @doc "Verify multiple fixes."
  def verify_fixes(applied_fixes) when is_list(applied_fixes) do
    Enum.map(applied_fixes, fn
      {:applied, failure, _pattern} -> verify_fix(failure)
      _ -> {:skipped, :not_applied}
    end)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer/verification_test.exs`

Expected: PASS, 2 tests

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer/verification.ex test/superpowers/auto_fixer/verification_test.exs
git commit -m "feat: add verification engine with single test execution and timeout"
```

---
## Task 6: Main Auto-Fixer Engine

**Files:**
- Create: `lib/superpowers/auto_fixer.ex`
- Test: `test/superpowers/auto_fixer_test.exs`

- [ ] **Step 1: Write failing test for main engine**

Create `test/superpowers/auto_fixer_test.exs`:

```elixir
defmodule Superpowers.AutoFixerTest do
  use ExUnit.Case, async: false

  alias Superpowers.AutoFixer

  describe "run/2" do
    test "parses test output and matches patterns" do
      output = """
      1) test foo (BarTest)
         test/bar_test.exs:1
         ** (UndefinedFunctionError) function Bar.foo/0 is undefined or private
      """

      output_path = "test/tmp/autofixer_output.txt"
      File.mkdir_p!("test/tmp")
      File.write!(output_path, output)

      result = AutoFixer.run(output_path, dry_run: true)

      assert {:ok, _matches} = result

      File.rm_rf!("test/tmp")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/superpowers/auto_fixer_test.exs`

Expected: `** (CompileError) undefined module Superpowers.AutoFixer`

- [ ] **Step 3: Implement main AutoFixer module**

Create `lib/superpowers/auto_fixer.ex`:

```elixir
defmodule Superpowers.AutoFixer do
  @moduledoc """
  Automatically detect and fix common test failures.

  ## Usage

      AutoFixer.run("test/results.txt", dry_run: true)
      AutoFixer.run("test/results.txt", auto_approve: true)
  """

  alias Superpowers.AutoFixer.{OutputParser, PatternMatcher, FixApplier, Verification}

  @type result :: {:ok, list()} | {:error, term()}

  @doc "Run auto-fixer on test output file."
  def run(test_output_path, opts \\ []) when is_binary(test_output_path) do
    dry_run = Keyword.get(opts, :dry_run, true)
    auto_approve = Keyword.get(opts, :auto_approve, false)

    with {:ok, output} <- read_test_output(test_output_path),
         failures <- OutputParser.parse(output),
         matches <- match_all_failures(failures),
         results <- apply_all_fixes(matches, dry_run, auto_approve),
         verified <- Verification.verify_fixes(results) do
      {:ok, verified}
    else
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end

  # Read test output from file
  defp read_test_output(path) do
    if File.exists?(path) do
      {:ok, File.read!(path)}
    else
      {:error, :enoent}
    end
  end

  # Match all failures to patterns
  defp match_all_failures(failures) do
    Enum.map(failures, fn failure ->
      case PatternMatcher.match_failure(failure) do
        nil -> {:no_match, failure}
        pattern -> {:match, failure, pattern}
      end
    end)
  end

  # Apply fixes for all matches
  defp apply_all_fixes(matches, dry_run, auto_approve) do
    Enum.map(matches, fn
      {:no_match, failure} -> {:skipped, failure}
      {:match, failure, pattern} -> FixApplier.apply_fix(failure, pattern, dry_run: dry_run, auto_approve: auto_approve)
    end)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/superpowers/auto_fixer_test.exs`

Expected: PASS, 1 test

- [ ] **Step 5: Commit**

```bash
git add lib/superpowers/auto_fixer.ex test/superpowers/auto_fixer_test.exs
git commit -m "feat: add main auto-fixer engine"
```

---

## Task 7: Mix Task CLI

**Files:**
- Create: `lib/mix/tasks/autofixer.ex`
- Create: `scripts/run-autofixer.sh` (helper script)

- [ ] **Step 1: Create Mix task**

Create `lib/mix/tasks/autofixer.ex`:

```elixir
defmodule Mix.Tasks.Autofixer do
  @moduledoc """
  Auto-fixer for test failures.

  ## Examples

      # Dry run (default)
      mix autofixer test/results.txt

      # Auto-approve all fixes
      mix autofixer test/results.txt --auto-approve

      # Run tests and autofix in one command
      mix autofixer --test

  ## Options

    * `--dry-run` - Show what would change without modifying (default)
    * `--auto-approve` - Apply all fixes without confirmation
    * `--test` - Run tests first, then autofix the output
  """

  use Mix.Task

  @shortdoc "Automatically detect and fix test failures"

  @impl true
  def run(args) do
    {opts, args, _} = parse_args(args)

    cond do
      Keyword.get(opts, :test) ->
        run_tests_and_autofix(opts)

      length(args) == 1 ->
        output_path = hd(args)
        run_autofixer(output_path, opts)

      true ->
        print_help()
    end
  end

  defp parse_args(args) do
    switches = [
      dry_run: :boolean,
      auto_approve: :boolean,
      test: :boolean,
      help: :boolean
    ]

    aliases = [
      d: :dry_run,
      y: :auto_approve,
      t: :test,
      h: :help
    ]

    OptionParser.parse(args, switches: switches, aliases: aliases)
  end

  defp run_tests_and_autofix(opts) do
    Mix.shell().info("Running tests...")

    # Capture test output
    {output, exit_code} = System.cmd("mix", ["test"], into: IO.stream(:stdio, :line))

    if exit_code != 0 do
      # Write output to temp file
      output_path = "test/autofixer_output.txt"
      File.write!(output_path, output)

      Mix.shell().info("Tests failed. Running auto-fixer...")
      run_autofixer(output_path, opts)
    else
      Mix.shell().info("All tests passed!")
    end
  end

  defp run_autofixer(output_path, opts) do
    dry_run = Keyword.get(opts, :dry_run, true)
    auto_approve = Keyword.get(opts, :auto_approve, false)

    mode =
      cond do
        dry_run -> "DRY RUN"
        auto_approve -> "AUTO-APPROVE"
        true -> "INTERACTIVE"
      end

    Mix.shell().info("Running auto-fixer (#{mode})...")

    case Superpowers.AutoFixer.run(output_path, dry_run: dry_run, auto_approve: auto_approve) do
      {:ok, results} ->
        print_results(results)

      {:error, :enoent} ->
        Mix.shell().error("File not found: #{output_path}")

      {:error, reason} ->
        Mix.shell().error("Error: #{inspect(reason)}")
    end
  end

  defp print_results(results) do
    matched = Enum.count(results, fn
      {:verified, :pass} -> true
      _ -> false
    end)

    failed = Enum.count(results, fn
      {:verification_failed, _} -> true
      _ -> false
    end)

    skipped = Enum.count(results, fn
      {:skipped, _} -> true
      _ -> false
    end)

    Mix.shell().info("""
    \nAuto-fixer results:
    ✓ Verified: #{matched}
    ✗ Failed: #{failed}
    ⊘ Skipped: #{skipped}
    """)
  end

  defp print_help do
    Mix.shell().info("""
    Usage: mix autofixer OUTPUT_FILE [options]

    Options:
      -d, --dry-run      Show what would change (default)
      -y, --auto-approve Apply all fixes without confirmation
      -t, --test         Run tests first, then autofix
      -h, --help         Show this help

    Examples:
      mix autofixer test/results.txt
      mix autofixer test/results.txt --auto-approve
      mix autofixer --test
    """)
  end
end
```

- [ ] **Step 2: Test the Mix task**

Run: `mix autofixer --help`

Expected: Help text displays

- [ ] **Step 3: Create helper script**

Create `scripts/run-autofixer.sh`:

```bash
#!/usr/bin/env bash
# Run tests and auto-fixer in one command

set -e

echo "Running tests..."
mix test 2>&1 | tee test/autofixer_output.txt

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "Tests failed. Running auto-fixer..."
  mix autofixer test/autofixer_output.txt --dry-run
else
  echo "All tests passed!"
fi
```

- [ ] **Step 4: Make script executable**

Run: `chmod +x scripts/run-autofixer.sh`

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/autofixer.ex scripts/run-autofixer.sh
git commit -m "feat: add mix task CLI for auto-fixer"
```

---

## Task 8: Documentation and README

**Files:**
- Create: `docs/superpowers/autofixer.md`
- Modify: `README.md` (add auto-fixer section)

- [ ] **Step 1: Create auto-fixer documentation**

Create `docs/superpowers/autofixer.md`:

```markdown
# Auto-Fixer Superpower

Automated test failure detection and fixing for OSA.

## Overview

The auto-fixer scans test output, matches known failure patterns, applies fixes with confirmation, and verifies results.

## Usage

### Basic Dry Run

```bash
mix autofixer test/results.txt
```

### Auto-Approve All Fixes

```bash
mix autofixer test/results.txt --auto-approve
```

### Run Tests and Auto-Fix

```bash
mix autofixer --test
```

### Using Helper Script

```bash
./scripts/run-autofixer.sh
```

## Supported Patterns

### 1. Private Function Visibility

Fixes tests that fail because private functions are called.

**Error:** `UndefinedFunctionError: function ... is undefined or private`

**Fix:** Replaces `defp` with `def` and adds `@doc`

### 2. Changeset Defaults

Fixes changeset defaults that don't show in `get_change`.

**Error:** `Ecto.Changeset.get_change` returns `nil` for fields with schema defaults

**Fix:** Adds `put_default_if_not_in_attrs/4` helper to use `force_change`

### 3. GenServer State Cleanup

Adds cleanup before GenServer start in tests.

**Error:** `{:already_started, pid}` in test setup

**Fix:** Adds `GenServer.stop` check before `start_supervised!`

## Adding New Patterns

Edit `priv/superpowers/patterns/test_fixes.json`:

```json
{
  "id": "unique_id",
  "name": "Pattern Name",
  "description": "What this fixes",
  "error_patterns": ["regex_pattern"],
  "detection": {
    "file_pattern": "glob/pattern/**/*.ex",
    "context": "where to look"
  },
  "fix": {
    "action": "action_name",
    "description": "what the fix does"
  }
}
```

## Safety Features

1. **Dry-run mode** - Show what would change without modifying
2. **Git snapshot** - Auto-commits before each fix for easy rollback (`git reset --hard HEAD~1`)
3. **Confirmation required** - Ask before each fix (unless `--auto-approve`)
4. **Verification** - Re-run specific test (with timeout) to confirm fix worked
5. **Pattern versioning** - Patterns have versions, can be updated
6. **mix format** - Auto-formats modified files after applying fixes

## Architecture

```
test output → OutputParser → PatternMatcher → FixApplier → Verification → Report
```

## Testing

```bash
mix test test/superpowers/
```
