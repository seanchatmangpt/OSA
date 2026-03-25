# Auto-Fixer Superpower Skill Design Spec

**Date:** 2026-03-24
**Status:** Design Phase
**Superpower Type:** Creation (writing-skills)

## Overview

Automated test failure detection and fixing for OSA. Scans test output, matches known failure patterns, applies fixes with confirmation, verifies results.

## Problem Statement

OSA has 6000+ tests. Common failures recur:
- Private function visibility (`defp` should be `def`)
- Missing changeset defaults (schema defaults don't show in `get_change`)
- GenServer state cleanup (`{:already_started}` errors)
- ETS table pollution between tests

Manual fixing is repetitive. Pattern-based automation reduces 500+ failures to 0.

## Architecture

### Components

#### 1. Pattern Database
**Location:** `priv/superpowers/patterns/test_fixes.json`

```json
{
  "version": "1.0.0",
  "patterns": [
    {
      "id": "private_function_visibility",
      "name": "Private Function Visibility Fixer",
      "error_patterns": [
        "UndefinedFunctionError.*function.*is undefined or private"
      ],
      "detection": {
        "file_pattern": "lib/**/*.ex",
        "search_pattern": "defp\\s+(\\w+)",
        "requires": ["module_exports_list"]
      },
      "fix": {
        "action": "replace_defp_with_def",
        "function": "make_public_if_exported"
      }
    },
    {
      "id": "changeset_defaults",
      "name": "Changeset Default Fixer",
      "error_patterns": [
        "Ecto.Changeset.get_change.*nil.*expected"
      ],
      "detection": {
        "file_pattern": "lib/**/store/*.ex",
        "context": "changeset/2 function"
      },
      "fix": {
        "action": "add_put_default_helper",
        "template": "put_default_if_not_in_attrs/3",
        "code": "defp put_default_if_not_in_attrs(changeset, attrs, field, default) do\n  if Map.has_key?(attrs, field) or Map.has_key?(attrs, to_string(field)) do\n    changeset\n  else\n    Ecto.Changeset.force_change(changeset, field, default)\n  end\nend"
      }
    },
    {
      "id": "genserver_state_cleanup",
      "name": "GenServer State Cleanup",
      "error_patterns": [
        "already_started.*bad child specification"
      ],
      "detection": {
        "file_pattern": "test/**/*_test.exs",
        "context": "setup block, start_supervised!"
      },
      "fix": {
        "action": "add_stop_before_start",
        "code": "setup do\n  if pid = Process.whereis(ModuleName) do\n    GenServer.stop(pid)\n    await_stop(ModuleName)\n  end\n  start_supervised!(ModuleName)\nend"
      }
    }
  ]
}
```

#### 2. Auto-Fixer Engine

```elixir
defmodule Superpowers.AutoFixer do
  @moduledoc """
  Automatically detect and fix common test failures.
  """

  @doc """
  Run auto-fixer on test output.
  """
  def run(test_output_path, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, true)
    auto_approve = Keyword.get(opts, :auto_approve, false)

    test_output_path
    |> File.read!()
    |> parse_test_output()
    |> detect_failures()
    |> match_patterns()
    |> apply_fixes(dry_run, auto_approve)
    |> verify_fixes()
  end

  defp parse_test_output(output) do
    # Parse ExUnit output into structured failures
    # Extract: test name, error message, stack trace
    Regex.scan(~r/(?<=test ).*?(?=\s+\[)/, output)
    |> Enum.map(&String.trim/1)
  end

  defp detect_failures(test_names) do
    # Return list of failure maps
    # %{test: "...", error: "...", stack: "..."}
  end

  defp match_patterns(failures) do
    patterns = load_patterns()

    Enum.map(failures, fn failure ->
      case find_matching_pattern(failure, patterns) do
        nil -> {:no_match, failure}
        pattern -> {:match, failure, pattern}
      end
    end)
  end

  defp apply_fixes(matches, dry_run, auto_approve) do
    Enum.map(matches, fn
      {:no_match, failure} -> {:skipped, failure}
      {:match, failure, pattern} -> apply_single_fix(failure, pattern, dry_run, auto_approve)
    end)
  end

  defp apply_single_fix(failure, pattern, dry_run, auto_approve) do
    if dry_run do
      {:dry_run, failure, pattern}
    else
      if auto_approve do
        # Apply fix automatically
        {:applied, failure, pattern}
      else
        # Ask user for confirmation
        request_confirmation(failure, pattern)
      end
    end
  end
end
```

#### 3. Verification Engine

```elixir
defmodule Superpowers.AutoFixer.Verification do
  @doc """
  Verify that fixes actually work.
  """
  def verify_fixes(applied_fixes) do
    Enum.map(applied_fixes, fn {fix, failure, pattern} ->
      # Re-run specific test
      # Check if it passes now
      case run_single_test(failure.test) do
        :pass -> {:verified, fix}
        :fail -> {:verification_failed, fix}
      end
    end)
  end
end
```

## Safety Features

1. **Dry-run mode** - Show what would change without modifying
2. **Git integration** - Commit before fixing, easy rollback
3. **Confirmation required** - Ask before each fix (unless auto_approve)
4. **Verification** - Re-run tests to confirm fix worked
5. **Pattern versioning** - Patterns have versions, can be updated
6. **Fallback** - If auto-fixer fails, stops and reports

## Implementation Plan

### Phase 1: Pattern Database
1. Create pattern JSON structure
2. Add 3-5 initial patterns from recent fixes:
   - Private function visibility
   - Changeset defaults
   - GenServer cleanup

### Phase 2: Detection Engine
1. Parse ExUnit output
2. Match error patterns with regex
3. Extract context (file, line, module)

### Phase 3: Fix Application
1. Load fix template
2. Apply with AST or string manipulation
3. Preserve formatting (mix format)

### Phase 4: Verification
1. Re-run affected tests
2. Confirm fix worked
3. Report results

## Usage

```bash
# Dry run (default)
mix autofixer test/results.txt

# Auto-approve all fixes
mix autofixer test/results.txt --auto-approve

# Interactive mode
mix autofixer test/results.txt --confirm
```

## Success Metrics

- **Pattern coverage:** % of known failures with patterns
- **Fix success rate:** % of applied fixes that work
- **Time saved:** Compare to manual fixing time
- **Test improvement:** % reduction in test failures over time

## Next Steps

1. **Write this spec** → `docs/superpowers/specs/2026-03-24-autofixer-skill-design.md`
2. **Spec review** → Get approval
3. **Writing-plans** → Create implementation plan
4. **Implement** → Build the skill
5. **Test** → Verify on real test failures

## Related Superpowers

- **writing-skills** - This IS a skill, created with writing-skills
- **systematic-debugging** - Root cause analysis informs patterns
- **test-driven-development** - Tests validate fixes
- **dispatching-parallel-agents** - Accelerates pattern discovery

## Ralph Loop Continuation

This spec completes the auto-fixer design. Next Ralph Loop iterations will:
- Discover MORE superpowers to apply
- Find patterns FOR this superpower
- Combine superpowers (auto-fixer + parallel agents)
- NEVER STOP, always discover more
