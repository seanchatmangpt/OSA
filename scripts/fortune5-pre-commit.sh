#!/bin/bash
# Fortune 5 Pre-commit Hook
# Validates Signal Theory coherence (S/N >= 0.8) before allowing commits

set -e

# Find the OSA directory (handle both standalone and submodule cases)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSA_DIR="$(dirname "$SCRIPT_DIR")"

# Change to OSA directory
cd "$OSA_DIR"

# Run the Elixir pre-commit validation
if ! mix run -e "case OptimalSystemAgent.Agent.Hooks.PreCommit.validate_commit() do {:ok, true} -> System.halt(0); {:error, msg} -> IO.puts(\"✗ Commit rejected: #{msg}\"); System.halt(1) end" 2>&1; then
  echo "Pre-commit hook validation failed"
  exit 1
fi

exit 0
