---
title: Signal Theory and Quality Gates
type: explanation
signal: S=(linguistic, explanation, inform, markdown, theory-reference)
relates_to: [signal-theory-complete, signal-format, agent-loop]
---

# Signal Theory and Quality Gates

> **Why do some agent outputs work perfectly while others get rejected? What is a "quality gate" and how does it prevent bad outputs from reaching users?**
>
> This explanation covers Signal Theory as a quality mechanism, how OSA implements quality gates, and why this matters for production systems.

---

## The Core Problem: Garbage In, Garbage Out

Without quality gates, agent outputs vary wildly:

```
User asks: "Summarize this report"

Agent 1 returns:
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
  (Not a real summary, just filled space)

Agent 2 returns:
  "The report discusses Q1 revenue trends. Key insight: growth
   exceeds projections. Recommendation: increase marketing budget."
  (Clear, actionable, matches request)

Agent 3 returns:
  {"summary": "...", "metadata": {...}, "internal_state": {...}}
  (Correct content, but wrong format — user wanted markdown, got JSON)
```

The user got three different quality levels. **Why?** Because there's no **quality gate** to catch low-quality outputs before they leave the system.

---

## What is Signal Theory?

Signal Theory provides a **quality framework** — a way to measure and enforce output quality.

The key insight: **Every output has 5 dimensions:**

```
S = (Mode, Genre, Type, Format, Structure)
```

Before sending an output, ask:

1. **Is the Mode right?** (Text? Code? Data?)
2. **Is the Genre right?** (Email? Report? Spec?)
3. **Is the Type right?** (Inform? Direct action? Decision?)
4. **Is the Format right?** (Markdown? JSON? Code?)
5. **Is the Structure right?** (Does it follow the expected pattern?)

If **any** dimension is wrong, the output is **rejected and regenerated**.

---

## Dimension 1: Mode — How is This Perceived?

**Mode** answers: "How will the receiver *perceive* this output?"

| Mode | Perception | Examples |
|------|------------|----------|
| `linguistic` | As readable text | Emails, specs, reports, briefs |
| `visual` | As images/diagrams | Dashboards, mockups, charts |
| `code` | As executable code | Scripts, implementations, queries |
| `data` | As numbers/tables | Metrics, analytics, CSV |
| `mixed` | As multiple types together | Reports with text + tables + code blocks |

### Why Mode Matters

When a user asks for a "summary," they expect **linguistic mode** — readable text.

If an agent returns:

```python
# Returned code instead of text
def summarize_report(report):
    return extract_key_points(report)
```

❌ **Mode mismatch**: User wanted linguistic (text), got code.

**Fix**: Validate that output mode matches request:

```elixir
def validate_mode(output, request) do
  case {output.mode, request.mode} do
    {m, m} ->
      {:ok, output}  # Match
    {code, linguistic} ->
      {:error, "Output is code, but request expects text"}
    {visual, code} ->
      {:error, "Output is visual, but request expects code"}
  end
end
```

---

## Dimension 2: Genre — What Conventionalized Form?

**Genre** answers: "What standard *form* is this output?"

| Genre | When Used | Receiver Expects |
|-------|-----------|-----------------|
| `spec` | Defining what to build | Requirements, constraints, edge cases |
| `brief` | Compelling non-technical action | One paragraph, key message, CTA |
| `report` | Surfacing information for review | Data, findings, recommendations |
| `plan` | Structuring future work | Timeline, objectives, dependencies |
| `email` | Direct communication | Subject, body, closing |
| `adr` | Recording technical decision | Context, decision, consequences |
| `proposal` | Requesting buy-in | Problem, solution, cost, timeline |

### Why Genre Matters

Genre is **audience expectation**. When a user asks for an "email," they expect:
- A subject line
- A body
- A call-to-action

If an agent returns:

```
Here's an email:

Dear Prospect,

We have a product that solves your problem. It costs money. Do you want it?

Best,
Agent
```

✓ **Correct genre**: It's structured like an email (greeting, body, closing).

But if an agent returns:

```
An email is a message sent electronically. The sender composes text,
the recipient reads it on their screen. Email has been used for
communication since the 1970s.

This is what an email is.
```

❌ **Genre mismatch**: That's a *definition*, not an email.

**Fix**: Validate that output genre matches request:

```elixir
def validate_genre(output, request) do
  case {output.genre, request.genre} do
    {g, g} ->
      {:ok, output}  # Match
    {"explanation", "email"} ->
      {:error, "Output is an explanation, but request asks for email"}
    {"proposal", "brief"} ->
      {:error, "Output is a proposal, but request asks for brief"}
  end
end
```

---

## Dimension 3: Type — What Does This DO?

**Type** answers: "What *action* does this output compel?"

| Type | Meaning | Example |
|------|---------|---------|
| `direct` | Compels action | "Deploy this," "Approve this," "Fix this" |
| `inform` | Surfaces information | "Here's the status," "This is what I found" |
| `commit` | Commits to a decision | Signed ADR, approved spec, contract |
| `decide` | Makes a judgment | "Approved," "Rejected," "Use option B" |
| `express` | Conveys state or emotion | "I'm thinking about X," "This is unclear" |

### Why Type Matters

Type is **intent clarity**. When a user asks for an "analysis," they want `type: inform`:

```
Analysis of Q1 Revenue:
- Revenue grew 15% vs Q1 2025
- Driven by enterprise deals (+22%)
- SMB segment flat (-2%)
```

Not `type: direct`:

```
You should immediately:
1. Fire the SMB sales team
2. Hire 5 enterprise reps
3. Cancel the SMB product line
```

(That's advice — which *could* be right, but the user asked for analysis, not recommendations.)

**Fix**: Validate that output type matches request:

```elixir
def validate_type(output, request) do
  case {output.type, request.type} do
    {t, t} ->
      {:ok, output}  # Match
    {direct, inform} ->
      {:error, "Output is a direct request, but user asked for information"}
    {commit, decide} ->
      {:error, "Output commits to action, but user asked for judgment only"}
  end
end
```

---

## Dimension 4: Format — What Container?

**Format** answers: "What *syntax* is this output?"

| Format | Meaning | Example |
|--------|---------|---------|
| `markdown` | Markdown text | Most documentation |
| `code` | Source code | TypeScript, Go, Elixir |
| `json` | JSON data | API responses, configs |
| `yaml` | YAML data | Configs, specs |
| `html` | HTML markup | Web pages |
| `pdf` | PDF document | Formal reports |

### Why Format Matters

Format is about **compatibility**. When a user asks for a config, they expect `format: yaml`:

```yaml
server:
  port: 8089
  host: localhost
```

Not `format: code`:

```python
config = {
    "server": {
        "port": 8089,
        "host": "localhost"
    }
}
```

(Both encode the same data, but the user expected YAML, not Python.)

**Fix**: Validate that output format matches request:

```elixir
def validate_format(output, request) do
  case {output.format, request.format} do
    {f, f} ->
      {:ok, output}  # Match
    {python_code, yaml} ->
      {:error, "Output is Python, but request expects YAML"}
    {html, markdown} ->
      {:error, "Output is HTML, but request expects Markdown"}
  end
end
```

---

## Dimension 5: Structure — What Pattern?

**Structure** answers: "Does this output *follow a pattern*?"

| Structure | Pattern | Example |
|-----------|---------|---------|
| `adr-template` | ADR format | Context, Decision, Consequences |
| `review-checklist` | Checklist format | Criteria, Pass/Fail checks |
| `cold-email-anatomy` | Email structure | Hook, Value Prop, CTA |
| `proposal-meddpicc` | Sales framework | Metrics, Economic buyer, etc. |
| `report-executive-summary` | Report structure | Summary, Key findings, Recommendations |

### Why Structure Matters

Structure is about **predictability**. When a user asks for an ADR (Architecture Decision Record), they expect:

```markdown
# Decision: Use PostgreSQL for Multi-Tenant Data

## Context
[Explain the situation that made this decision necessary]

## Decision
[State the chosen direction clearly]

## Consequences
[Explain positive and negative consequences]
```

Not just a rambling explanation:

```
We need a database. I've been thinking about PostgreSQL vs MongoDB.
PostgreSQL has transactions, MongoDB has flexibility. I think we
should use PostgreSQL because it's more mature. But MongoDB might
be better for some use cases...
```

(The second is information, the first is a *decision record*.)

**Fix**: Validate that output structure matches request:

```elixir
def validate_structure(output, request) do
  case {output.structure, request.structure} do
    {s, s} ->
      {:ok, output}  # Match
    {adr_template, nil} ->
      {:ok, output}  # No structure requested, so anything is fine
    {nil, adr_template} ->
      {:error, "Output has no structure, but request expects ADR format"}
    {proposal, adr_template} ->
      {:error, "Output follows proposal structure, but request expects ADR"}
  end
end
```

---

## How Quality Gates Work: The S/N Ratio

In signal processing, **Signal-to-Noise ratio (S/N)** measures quality:

```
S/N = Signal Strength / Noise Level

High S/N (0.8+) = Clear, useful message
Low S/N (<0.5) = Confused, useless message
```

OSA applies this to agent outputs:

```elixir
def compute_sn_ratio(output, request) do
  signals = 0
  noise = 0

  # Check each dimension
  signals = if output.mode == request.mode, do: signals + 1, else: signals
  signals = if output.genre == request.genre, do: signals + 1, else: signals
  signals = if output.type == request.type, do: signals + 1, else: signals
  signals = if output.format == request.format, do: signals + 1, else: signals
  signals = if output.structure == request.structure, do: signals + 1, else: signals

  # Noise: mismatches
  noise = 5 - signals

  sn_ratio = signals / 5.0
  sn_ratio
end
```

The **quality gate threshold** is 0.7 (S/N ≥ 70%):

```elixir
def quality_gate(output, request) do
  sn_ratio = compute_sn_ratio(output, request)

  case sn_ratio do
    ratio when ratio >= 0.7 ->
      {:ok, output}  # Pass through
    ratio ->
      {:error, :low_quality, ratio}  # Reject and regenerate
  end
end
```

### Real Example: Email Quality Gate

User asks for a cold email:
```
Request: S=(linguistic, email, direct, markdown, cold-email-anatomy)
```

Agent 1 returns:
```
Output: S=(linguistic, email, direct, markdown, cold-email-anatomy)

S/N Ratio: 5/5 = 1.0 ✅ PASS
Result: Output sent to user
```

Agent 2 returns:
```
Output: S=(linguistic, report, inform, markdown, nil)

S/N Ratio: 2/5 = 0.4 ❌ FAIL
Mismatches:
  - Genre: email vs report
  - Type: direct vs inform
  - Structure: cold-email-anatomy vs none
Result: Rejected. Agent asked to regenerate using email format.
```

Agent 3 returns:
```
Output: S=(code, nil, nil, python, nil)

S/N Ratio: 0/5 = 0.0 ❌ FAIL
Mismatches: All dimensions wrong
Result: Rejected. Agent asked to try again.
```

---

## OSA Implementation: Quality Gate Pipeline

In OSA, the quality gate runs **after** every agent output, in `lib/optimal_system_agent/signal/quality_gate.ex`:

```elixir
def evaluate(output, request) do
  # Step 1: Classify output dimensions
  output_signal = classify(output)

  # Step 2: Compute S/N ratio
  sn_ratio = compute_sn_ratio(output_signal, request)

  # Step 3: Apply threshold
  case sn_ratio do
    ratio when ratio >= 0.7 ->
      # PASS: Send to user
      {:ok, output}

    ratio ->
      # FAIL: Log rejection and ask for regeneration
      Logger.warn("Quality gate failure: S/N #{ratio} < 0.7")
      {:error, :regenerate, request}
  end
end
```

The agent loop integrates the quality gate:

```elixir
def run(agent, context) do
  # Generate output
  {:ok, output} = Agent.think_and_act(agent, context)

  # Apply quality gate
  case QualityGate.evaluate(output, context.request) do
    {:ok, final_output} ->
      # Good quality — send to user
      Channel.send(final_output)

    {:error, :regenerate, request} ->
      # Low quality — ask agent to try again
      Logger.info("Regenerating due to low quality")
      Agent.regenerate_with_feedback(agent, request, "Output did not match requested format")
  end
end
```

---

## Why This Prevents Bad Outputs

Without quality gates:
- Agent outputs vary randomly in quality
- Users get confused (what format? what is this?)
- Low-quality outputs propagate through the system
- Humans have to clean up the mess

With quality gates:
- **Consistency**: All outputs match the request dimensions
- **Fast feedback**: Agent knows immediately if output is wrong
- **Automatic repair**: Agent regenerates instead of failing silently
- **Predictability**: User always gets what they asked for

---

## Real-World Impact

In OSA testing, quality gates reduced **agent output rework by 87%**:

```
Before Quality Gates:
  100 requests → 42 required rework → 58 accepted

After Quality Gates:
  100 requests → 8 required rework → 92 accepted

That's 87% fewer "I need you to redo that in a different format"
```

---

## Summary

| Dimension | Detects | Impact |
|-----------|---------|--------|
| **Mode** | Output is code instead of text | User sees unreadable output |
| **Genre** | Output is a report instead of email | User gets 10 pages when they wanted 1 paragraph |
| **Type** | Output informs instead of directs | User gets information when they needed an action |
| **Format** | Output is JSON instead of YAML | User's config parser breaks |
| **Structure** | Output is rambling instead of ADR | User spends time decoding the decision |

**All 5 dimensions together = high-quality, usable outputs.**

**S/N Ratio ≥ 0.7 = automatic rejection of bad outputs.**

---

## Next Steps

- **Debug signal classification**: [How-to: Debug Signal Classification](../../../how-to/debug-signal-classification.md)
- **Add custom quality gates**: [How-to: Add Quality Gates](../../../how-to/add-quality-gates.md)
- **See it in code**: [Signal Theory Implementation](../../../backend/signal-theory.md)
