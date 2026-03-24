# YAWL Verification Service

**Formal Correctness as a Service** — YAWL v6 workflow verification via HTTP API

---

## Purpose

Expose YAWL's formal verification engine as an HTTP API — any workflow can be verified for correctness before deployment.

**The Problem**: Nobody verifies workflows before deployment. Deadlocks, livelocks, and unsound workflows cause production incidents.

**The Solution**: Upload any workflow → Get a formal correctness certificate with proof hash.

---

## Quick Start

### Start the Service

```bash
cd /Users/sac/chatmangpt/OSA/yawl-service
mix run --no-halt
```

### Verify a Workflow

```bash
curl -X POST http://localhost:9090/api/v1/verify/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "workflow": {
      "type": "yawl",
      "content": "<?xml version=\"1.0\"?>..."
    }
  }'
```

### Response

```json
{
  "verification_id": "ver-abc123",
  "status": "complete",
  "result": {
    "soundness": {
      "deadlock_freedom": true,
      "livelock_freedom": true,
      "proper_completion": true,
      "fairness": true,
      "overall_score": 5.0,
      "overall_verdict": "SOUND"
    },
    "certificate": {
      "certificate_hash": "sha256:abc123...",
      "proof_artifacts": ["trace.tla", "output.txt"],
      "issued_at": "2026-03-24T12:00:00Z"
    }
  }
}
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  YAWL VERIFICATION SERVICE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  HTTP Layer (Cowboy)                                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  | POST /api/v1/verify/workflow    — Verify single workflow |   │
│  | POST /api/v1/verify/batch       — Parallel verification  |   │
│  | GET  /api/v1/verify/certificate/:id — Retrieve cert     |   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  Verification Engine                                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  | Parser (YAWL/BPMN/Markdown)                              |   │
│  |   ↓                                                       |   │
│  | Structural Analyzer (deadlock, livelock, soundness)      |   │
│  |   ↓                                                       |   │
│  | Certificate Generator (hash, proof artifacts)            |   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  YAWL v6 Engine (Java 25 interop)                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  | YAWLVerifier.java — Formal verification engine           |   │
│  | TLA+ Model Checker — Exhaustive state exploration        |   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
OSA/yawl-service/
├── README.md              (this file)
├── mix.exs                (Elixir project config)
├── config/
│   └── config.exs         (Service configuration)
├── lib/
│   ├── application.ex     (Supervision tree)
│   ├── web/
│   │   ├── router.ex      (HTTP routes)
│   │   └── handlers/
│   │       ├── verify.ex  (Verification endpoint)
│   │       └── cert.ex    (Certificate retrieval)
│   └── verification/
│       ├── parser.ex      (YAWL/BPMN parser)
│       ├── analyzer.ex    (Structural analysis)
│       └── certificate.ex (Certificate generation)
└── priv/
    └── java/
        └── YAWLVerifier.jar  (Java verification engine)
```

---

## API Endpoints

### POST /api/v1/verify/workflow

Verify a single workflow for formal correctness.

**Request:**
```json
{
  "workflow": {
    "type": "yawl|bpmn|markdown",
    "content": "string or base64-encoded",
    "source_url": "optional URL"
  }
}
```

**Response:**
```json
{
  "verification_id": "uuid",
  "status": "complete|pending|failed",
  "result": {
    "soundness": {
      "deadlock_freedom": true,
      "livelock_freedom": true,
      "proper_completion": true,
      "fairness": true,
      "overall_score": 5.0,
      "overall_verdict": "SOUND"
    },
    "analysis": {
      "places": 12,
      "transitions": 18,
      "yawl_patterns_used": [1, 2, 6, 10, 14, 21],
      "potential_issues": []
    },
    "certificate": {
      "certificate_hash": "SHA256(...)",
      "proof_artifacts": ["trace.tla", "output.txt"],
      "issued_at": "ISO8601"
    }
  }
}
```

### POST /api/v1/verify/batch

Verify multiple workflows in parallel.

**Request:**
```json
{
  "workflows": [
    {"type": "yawl", "content": "..."},
    {"type": "bpmn", "content": "..."}
  ]
}
```

**Response:**
```json
{
  "batch_id": "uuid",
  "status": "processing",
  "verification_ids": ["ver-1", "ver-2"],
  "completed": 0,
  "total": 2
}
```

### GET /api/v1/verify/certificate/:id

Retrieve a verification certificate.

**Response:**
```json
{
  "certificate": {
    "certificate_hash": "sha256:...",
    "verification_id": "ver-abc123",
    "soundness_score": 5.0,
    "properties_verified": {
      "deadlock_freedom": true,
      "livelock_freedom": true,
      "proper_completion": true,
      "fairness": true
    },
    "yawl_patterns_used": [1, 2, 6, 10, 14, 21],
    "proof_artifacts": ["trace.tla", "model_check_output.txt"],
    "issued_at": "2026-03-24T12:00:00Z",
    "expires_at": "2026-06-24T12:00:00Z"
  }
}
```

---

## YAWL Soundness Scoring

| Property | Score | Criteria |
|----------|-------|----------|
| **Deadlock Freedom** | 5/5 | No circular wait in YAWL net |
| **Livelock Freedom** | 5/5 | No infinite loops without progress |
| **Soundness** | 5/5 | Workflow net is sound |
| **Fairness** | 5/5 | No starvation under fairness assumption |
| **Overall** | 4.4–5.0 | Weighted average across properties |

---

## Verification Process

### Step 1: Parse & Convert

```elixir
case workflow.type do
  "bpmn" -> yawlNet = YAWL.Converter.bpmn_to_yawl(workflow.content)
  "markdown" -> yawlNet = YAWL.Extractor.extract_from_markdown(workflow.content)
  "yawl" -> yawlNet = YAWL.Parser.parse(workflow.content)
end
```

### Step 2: Extract Structure

```elixir
%YawlNet{
  places: [...],
  transitions: [...],
  arcs: [...]
}
```

### Step 3: Verify Properties

```elixir
def verify_deadlock_freedom(net) do
  has_deadlock = Reachability.analyze(net)
  !has_deadlock
end

def verify_livelock_freedom(net) do
  has_livelock = Termination.analyze(net)
  !has_livelock
end

def verify_soundness(net) do
  WorkflowNet.sound?(net)
end
```

### Step 4: Generate Certificate

```elixir
%Certificate{
  certificate_hash: :crypto.hash(:sha256, result ++ verification_id),
  verification_id: verification_id,
  soundness_score: 5.0,
  properties_verified: %{...},
  yawl_patterns_used: [1, 2, 6, 10, 14, 21],
  proof_artifacts: ["trace.tla", "model_check_output.txt"],
  issued_at: DateTime.utc_now()
}
```

---

## Git Hook Integration

Pre-commit hook for automatic verification:

```bash
#!/bin/bash
# .git/hooks/pre-commit

WORKFLOWS=$(git diff --cached --name-only | grep -E '\.(yawl|bpmn|md)$')

if [ -n "$WORKFLOWS" ]; then
  for workflow in $WORKFLOWS; do
    RESULT=$(curl -s -X POST http://localhost:9090/api/v1/verify/workflow \
      -d "{\"workflow\": {\"type\": \"file\", \"content\": \"$(base64 < "$workflow")\"}}")

    VERDICT=$(echo "$RESULT" | jq -r '.result.soundness.overall_verdict')

    if [ "$VERDICT" != "SOUND" ]; then
      echo "❌ Workflow $workflow is NOT SOUND: $VERDICT"
      exit 1
    fi
  done
fi
```

---

## S/N Quality Gate

Score ≥ 0.7 (GOOD) required:
- All 4 soundness properties verified
- Certificate hash is computable
- Proof artifacts generated
- Response time < 30 seconds

---

## Integration with OSA

The verification service integrates with OSA's existing verification module:

```elixir
# In OSA
def verify_workflow(workflow_content) do
  # Call YAWL service
  response = HTTPoison.post(
    "http://localhost:9090/api/v1/verify/workflow",
    Jason.encode!(%{workflow: %{type: "yawl", content: workflow_content}})
  )

  # Extract certificate
  %{"result" => %{"certificate" => certificate}} = Jason.decode!(response.body)

  # Store certificate
  Verification.save_certificate(certificate)
end
```

---

## References

- `/docs/superpowers/specs/2026-03-23-formal-correctness-api-design.md` — Full design spec
- `/docs/diataxis/reference/yawl-43-patterns.md` — YAWL pattern catalog
- YAWL v6 (Java 25) — Reference implementation

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Verification requests/month | 10,000 | Total API calls |
| Soundness pass rate | >95% | Workflows that are sound |
| Verification latency | <30s | p95 response time |
| Git hook adoptions | 1,000 repos | Pre-commit hooks installed |

---

*YAWL Verification Service — Production formal correctness API*
*Created: 2026-03-24*
*Ralph Loop: Iteration 13*
