#!/bin/bash

# MCP/A2A Integration Smoke Test
# Tests MCP server management, A2A agent communication, and cross-project messaging
# Requires OSA running on http://localhost:9089 (or set OSA_URL)

OSA_URL="${OSA_URL:-http://localhost:9089}"
BUSINESSOS_URL="${BUSINESSOS_URL:-http://localhost:8001}"

echo "═══════════════════════════════════════════════════════════════"
echo "MCP/A2A Integration Smoke Tests"
echo "═══════════════════════════════════════════════════════════════"
echo "OSA URL: $OSA_URL"
echo "BusinessOS URL: $BUSINESSOS_URL"
echo ""

PASS=0
FAIL=0

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

test_case() {
    local num=$1
    local description=$2
    local cmd=$3

    echo -n "Test $num: $description... "

    if OUTPUT=$(eval "$cmd" 2>&1); then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAIL++))
    fi
}

# Test 1: OSA agent card (service alive)
test_case 1 "OSA service alive" \
    "curl -s $OSA_URL/api/v1/a2a/agent-card | jq -e '.name == \"osa-agent\"'"

# Test 2: OSA agent card has version
test_case 2 "OSA agent card metadata" \
    "curl -s $OSA_URL/api/v1/a2a/agent-card | jq -e '.version' > /dev/null"

# Test 3: List available tools
test_case 3 "List available tools" \
    "curl -s $OSA_URL/api/v1/a2a/tools | jq -e '.tools | length > 0'"

# Test 4: List MCP servers (returns array)
test_case 4 "List MCP servers" \
    "curl -s $OSA_URL/api/v1/a2a/servers | jq -e '.servers | type == \"array\"'"

# Test 5: List agents
test_case 5 "List all A2A agents" \
    "curl -s $OSA_URL/api/v1/a2a/agents | jq -e '.agents | type == \"array\"'"

# Test 6: Create A2A task (returns status directly, not task_id format)
test_case 6 "Create A2A task" \
    "curl -s -X POST $OSA_URL/api/v1/a2a -H 'Content-Type: application/json' -d '{\"message\": \"Hello\"}' | jq -e '.status' > /dev/null"

# Test 7: JSON-RPC agent/card method
test_case 7 "JSON-RPC agent/card method" \
    "curl -s -X POST $OSA_URL/api/v1/a2a -H 'Content-Type: application/json' -d '{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"agent/card\", \"params\": {}}' | jq -e '.result.name == \"osa-agent\"'"

# Test 8: JSON-RPC tools/list method
test_case 8 "JSON-RPC tools/list method" \
    "curl -s -X POST $OSA_URL/api/v1/a2a -H 'Content-Type: application/json' -d '{\"jsonrpc\": \"2.0\", \"id\": 2, \"method\": \"tools/list\", \"params\": {}}' | jq -e '.result.tools | type == \"array\"'"

# Test 9: Agent card has capabilities
test_case 9 "Agent card has capabilities" \
    "curl -s $OSA_URL/api/v1/a2a/agent-card | jq -e '.capabilities | length > 0'"

# Test 10: File read tool available (called file_read)
test_case 10 "File read tool available" \
    "curl -s $OSA_URL/api/v1/a2a/tools | jq -e '.tools[] | select(.name == \"file_read\") | .name' > /dev/null"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All smoke tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
