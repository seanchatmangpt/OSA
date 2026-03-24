#!/bin/bash
# Install Fortune 5 Pre-commit Hook
# Sets up the git pre-commit hook for Signal Theory coherence validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSA_DIR="$(dirname "$SCRIPT_DIR")"
HOOK_SOURCE="$SCRIPT_DIR/fortune5-pre-commit.sh"

# Determine git hooks directory
# Handle both standalone git repo and git submodule cases
if [ -d "$OSA_DIR/.git" ]; then
  # Standalone git repository
  HOOKS_DIR="$OSA_DIR/.git/hooks"
elif [ -f "$OSA_DIR/.git" ]; then
  # Submodule (git file points to parent repo's modules directory)
  GIT_DIR=$(grep "gitdir:" "$OSA_DIR/.git" | cut -d: -f2 | xargs)
  HOOKS_DIR="$GIT_DIR/hooks"
else
  # Not in a git repo
  echo "Error: OSA directory is not a git repository or submodule"
  exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Copy hook script
HOOK_FILE="$HOOKS_DIR/pre-commit"
cp "$HOOK_SOURCE" "$HOOK_FILE"
chmod +x "$HOOK_FILE"

echo "✓ Pre-commit hook installed at $HOOK_FILE"
echo "✓ Signal Theory coherence validation enabled (threshold: S/N >= 0.8)"
