# Fortune 5 Usage Examples

**Signal Theory:** S=(linguistic,tutorial,instruct,markdown,tutorial)

---

## Quick Examples

### Example 1: Scan a codebase for SPR data

```elixir
# Basic scan with default paths
{:ok, result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
  codebase_path: "lib",
  output_dir: "priv/sensors"
)

# Result contains:
# - scan_id: Unique identifier
# - timestamp: Scan time in milliseconds
# - duration_ms: How long the scan took
IO.inspect(result, label: "SPR Scan Result")
```

### Example 2: Generate RDF from SPR data

```elixir
# Generate workspace.ttl from existing SPR files
{:ok, metadata} = OptimalSystemAgent.Sensors.RDFGenerator.generate_rdf(
  spr_dir: "priv/sensors",
  output_file: "priv/sensors/workspace.ttl",
  base_uri: "https://chatmangpt.com/workspace#"
)

# Metadata contains:
# - file: Output file path
# - triple_count: Number of RDF triples
# - size: File size in bytes
IO.inspect(metadata, label: "RDF Generation")
```

### Example 3: Run SPARQL CONSTRUCT query

```bash
# Using Apache Jena ARQ
arq --data=priv/sensors/workspace.ttl \
    --query=ggen/sparql/construct_modules.rq \
    --results=TTL

# Or using Python rdflib
python3 << 'PYTHON'
from rdflib import Graph
g = Graph()
g.parse('priv/sensors/workspace.ttl', format='turtle')

# Run CONSTRUCT query
with open('ggen/sparql/construct_modules.rq') as f:
    results = g.query(f.read())

print(results.serialize(format='turtle'))
PYTHON
```

### Example 4: Validate Signal Theory S/N score

```python
import json

def score_spr_file(filepath):
    """Calculate S/N score for an SPR file"""
    with open(filepath, 'r') as f:
        data = json.load(f)

    dimensions = ["mode", "genre", "type", "format", "structure"]
    scores = [1.0 if data.get(dim) else 0.0 for dim in dimensions]
    return sum(scores) / len(scores)

# Score each SPR file
modules_score = score_spr_file("priv/sensors/modules.json")
deps_score = score_spr_file("priv/sensors/deps.json")
patterns_score = score_spr_file("priv/sensors/patterns.json")

# Combined score (weighted)
combined = (modules_score * 0.5 + deps_score * 0.25 + patterns_score * 0.25)
print(f"Combined S/N Score: {combined:.4f}")

# Quality gate
if combined >= 0.8:
    print("✅ QUALITY GATE PASSED")
else:
    print(f"❌ QUALITY GATE FAILED: {combined:.4f} < 0.8")
```

### Example 5: Run Fortune 5 test suite

```bash
# Run all Fortune 5 tests
mix test test/optimal_system_agent/fortune_5/

# Run specific test file
mix test test/optimal_system_agent/fortune_5/fortune_5_gaps_test.exs

# Run with verbose output
mix test test/optimal_system_agent/fortune_5/ --trace

# Run specific test by line number
mix test test/optimal_system_agent/fortune_5/fortune_5_gaps_test.exs:142
```

---

## Advanced Usage

### Custom SPR Output Directory

```elixir
{:ok, result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
  codebase_path: "lib",
  output_dir: "/tmp/fortune5_scan_#{System.system_time(:second)}"
)
```

### Custom Base URI for RDF

```elixir
{:ok, metadata} = OptimalSystemAgent.Sensors.RDFGenerator.generate_rdf(
  base_uri: "https://example.com/workspace#"
)
```

### Programmatically Check Quality Gate

```elixir
defmodule QualityGate do
  def check_score(threshold \\ 0.8) do
    scores = ["modules", "deps", "patterns"]
      |> Enum.map(fn name ->
        File.read!("priv/sensors/#{name}.json")
        |> Jason.decode!()
        |> score_dimensions()
      end)

    combined = Enum.zip(scores, [0.5, 0.25, 0.25])
      |> Enum.map(fn {score, weight} -> score * weight end)
      |> Enum.sum()

    if combined >= threshold, do: {:ok, combined}, else: {:error, combined}
  end

  defp score_dimensions(data) do
    ["mode", "genre", "type", "format", "structure"]
      |> Enum.count(fn dim -> Map.get(data, dim) != nil end)
      |> Kernel./(5)
  end
end
```

---

## Integration Examples

### Fortune 5 in Mix Task

```elixir
defmodule Mix.Tasks.Fortune5.Scan do
  use Mix.Task

  def run(args) do
    codebase = Keyword.get(args, :codebase, "lib")
    output = Keyword.get(args, :output, "priv/sensors")

    IO.puts("🔍 Scanning #{codebase}...")

    case OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
      codebase_path: codebase,
      output_dir: output
    ) do
      {:ok, result} ->
        IO.puts("✅ Scan complete: #{result.total_modules} modules found")

      {:error, reason} ->
        IO.puts("❌ Scan failed: #{inspect(reason)}")
    end
  end
end
```

### Fortune 5 in GenServer

```elixir
defmodule Fortune5.PeriodicScanner do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    interval = Keyword.get(opts, :interval, :timer.hours(1))
    schedule_scan(interval)
    {:ok, %{interval: interval}}
  end

  def handle_info(:scan, state) do
    IO.puts("🔄 Running periodic Fortune 5 scan...")

    OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
      codebase_path: "lib",
      output_dir: "priv/sensors"
    )

    schedule_scan(state.interval)
    {:noreply, state}
  end

  defp schedule_scan(interval) do
    Process.send_after(self(), :scan, interval)
  end
end
```

---

## Troubleshooting Examples

### Debug: Check SPR file contents

```elixir
# Read and inspect SPR file
content = File.read!("priv/sensors/modules.json")
data = Jason.decode!(content)

# Verify Signal Theory dimensions
required = ["mode", "genre", "type", "format", "structure"]
missing = Enum.reject(required, &Map.has_key?(data, &1))

if Enum.empty?(missing) do
  IO.puts("✅ All Signal Theory dimensions present")
else
  IO.puts("❌ Missing dimensions: #{inspect(missing)}")
end
```

### Debug: Verify RDF generation

```bash
# Count triples in workspace.ttl
grep -c "\\.$" priv/sensors/workspace.ttl

# Verify prefixes
grep "@prefix" priv/sensors/workspace.ttl

# Check for modules
grep "osa:Module" priv/sensors/workspace.ttl | wc -l
```

---

**Last Updated:** 2026-03-23
**Fortune 5 Layer:** All 7 Layers
