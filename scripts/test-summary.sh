#!/bin/bash
# Test result summary script for OSA
# Usage: mix test 2>&1 | tee test.log && bash scripts/test-summary.sh test.log

set -e

LOG_FILE="${1:--}"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                       OSA TEST SUMMARY REPORT                              ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"

# Extract statistics
TOTAL_TESTS=$(grep -c "test " "$LOG_FILE" || echo "0")
PASSED=$(grep -c "✓\|PASS" "$LOG_FILE" || echo "0")
FAILED=$(grep -c "✗\|FAIL" "$LOG_FILE" || echo "0")
SKIPPED=$(grep -c "SKIP\|@skip" "$LOG_FILE" || echo "0")

echo ""
echo "📊 OVERALL RESULTS"
echo "─────────────────────────────────────────────────────────────────────────────"
echo "Total Tests:      $TOTAL_TESTS"
echo "Passed:           $PASSED ✅"
echo "Failed:           $FAILED ❌"
echo "Skipped:          $SKIPPED ⏭️"

# Calculate pass rate
if [ "$TOTAL_TESTS" -gt 0 ]; then
    PASS_RATE=$((PASSED * 100 / TOTAL_TESTS))
    echo "Pass Rate:        ${PASS_RATE}%"
fi

echo ""
echo "📈 PERFORMANCE"
echo "─────────────────────────────────────────────────────────────────────────────"

# Extract timing info if available
if grep -q "Finished" "$LOG_FILE"; then
    DURATION=$(grep "Finished" "$LOG_FILE" | tail -1)
    echo "Duration:         $DURATION"
fi

# Identify slowest tests (if timing available)
if grep -q "ms\|s\)" "$LOG_FILE"; then
    echo ""
    echo "⚠️  TOP 5 SLOWEST TESTS"
    echo "─────────────────────────────────────────────────────────────────────────────"
    grep -E "[0-9]+\.?[0-9]*(ms|s\))" "$LOG_FILE" | sort -t: -k2 -rn | head -5 || echo "  (No timing data)"
fi

echo ""
echo "🔴 FAILURES"
echo "─────────────────────────────────────────────────────────────────────────────"
if [ "$FAILED" -gt 0 ]; then
    grep -E "✗|FAIL|Error" "$LOG_FILE" | head -10 || echo "  (None found)"
else
    echo "  ✅ No failures!"
fi

echo ""
echo "ℹ️  QUICK REFERENCE"
echo "─────────────────────────────────────────────────────────────────────────────"
echo "Run only unit tests (fast):        mix test.fast"
echo "Run only integration tests:        mix test.integration"
echo "Run only slow tests:               mix test.slow"
echo "Run only pure logic (no startup):  mix test.unit"
echo ""
