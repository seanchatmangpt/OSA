# Fortune 5 Troubleshooting Guide

**Signal Theory:** S=(linguistic,guide,instruct,markdown,faq)

---

## Common Issues

### Issue: SPR scan returns empty modules list

**Symptom:** `modules.json` has `"total_modules": 0` or empty `"modules"` array

**Possible Causes:**
1. Invalid `codebase_path` - path doesn't exist
2. No `.ex` files in the codebase
3. File permissions preventing read access

**Solutions:**
```elixir
# Verify path exists
File.dir?("lib")  # Should return true

# Check for .ex files
Path.wildcard("lib/**/*.ex") |> length()  # Should be > 0

# Re-run scan with explicit path
OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
  codebase_path: "/absolute/path/to/lib",
  output_dir: "priv/sensors"
)
```

---

### Issue: workspace.ttl generation fails

**Symptom:** `RDFGenerator.generate_rdf/1` returns `{:error, reason}`

**Possible Causes:**
1. SPR files don't exist in `priv/sensors/`
2. Invalid JSON in SPR files
3. Missing write permissions for output directory

**Solutions:**
```elixir
# Check SPR files exist
File.exists?("priv/sensors/modules.json")    # Should be true
File.exists?("priv/sensors/deps.json")       # Should be true
File.exists?("priv/sensors/patterns.json")   # Should be true

# Validate JSON
Jason.decode(File.read!("priv/sensors/modules.json"))

# Generate with explicit paths
OptimalSystemAgent.Sensors.RDFGenerator.generate_rdf(
  spr_dir: "priv/sensors",
  output_file: "priv/sensors/workspace.ttl"
)
```

---

### Issue: Pre-commit hook not firing

**Symptom:** Low-quality commits pass without quality gate check

**Possible Causes:**
1. Hook not executable
2. Hook in wrong location (submodule vs. main repo)
3. Git config `core.hooksPath` overriding default hooks

**Solutions:**
```bash
# Find correct git directory
git rev-parse --git-dir
# For submodules: .git/modules/OSA/hooks/

# Make hook executable
chmod +x .git/modules/OSA/hooks/pre-commit

# Verify hook location
ls -la .git/modules/OSA/hooks/pre-commit

# Test hook manually
.git/modules/OSA/hooks/pre-commit
```

---

### Issue: Quality gate fails with "Python not found"

**Symptom:** Pre-commit hook exits with error about Python

**Solution:**
```bash
# Verify Python 3 is available
python3 --version

# Update hook shebang if needed
# Change #!/usr/bin/env python3 to #!/usr/local/bin/python3
```

---

### Issue: S/N score is 0.0 despite having data

**Symptom:** Quality gate reports `Combined S/N Score: 0.0000`

**Possible Causes:**
1. Signal Theory dimensions missing from SPR files
2. JSON keys are atoms instead of strings
3. Scoring algorithm expects different structure

**Solutions:**
```elixir
# Check SPR file has required dimensions
modules = Jason.decode!(File.read!("priv/sensors/modules.json"))
Map.has_key?(modules, "mode")      # Should be true
Map.has_key?(modules, "genre")     # Should be true
Map.has_key?(modules, "type")      # Should be true
Map.has_key?(modules, "format")    # Should be true
Map.has_key?(modules, "structure") # Should be true

# All 5 dimensions must be present
# Each dimension should have a non-empty value
```

---

### Issue: ggen SPARQL queries return no results

**Symptom:** CONSTRUCT queries produce empty output

**Possible Causes:**
1. workspace.ttl doesn't match query prefixes
2. No data in workspace.ttl
3. SPARQL engine not installed

**Solutions:**
```bash
# Verify workspace.ttl has data
wc -l priv/sensors/workspace.ttl  # Should be > 20 lines

# Check prefixes match
grep "@prefix" priv/sensors/workspace.ttl
grep "@prefix" ggen/sparql/construct_modules.rq

# Use Apache Jena ARQ
arq --data=priv/sensors/workspace.ttl --query=ggen/sparql/construct_modules.rq

# Or use rdflib in Python
python3 -c "
from rdflib import Graph
g = Graph()
g.parse('priv/sensors/workspace.ttl', format='turtle')
print(len(g))  # Should be > 0
"
```

---

### Issue: Board process documentation not found

**Symptom:** Test fails looking for `docs/FORTUNE_5_BOARD_PROCESS_45_MINUTE_WEEK.md`

**Solution:**
```bash
# Verify file exists
ls -la docs/FORTUNE_5_BOARD_PROCESS_45_MINUTE_WEEK.md

# If missing, copy from parent repo
cp ../docs/FORTUNE_5_BOARD_PROCESS_45_MINUTE_WEEK.md docs/
```

---

## Debug Mode

Enable debug logging to troubleshoot issues:

```elixir
# In config/dev.exs
config :logger, level: :debug

# Or inline
Logger.configure(level: :debug)
```

---

## Getting Help

If issues persist:
1. Check test output for specific error messages
2. Review Signal Theory S=(M,G,T,F,W) encoding in outputs
3. Verify all 7 Fortune 5 layers are implemented
4. Run comprehensive test suite: `mix test test/optimal_system_agent/fortune_5/`

---

**Last Updated:** 2026-03-23
**Fortune 5 Layer:** 7 - Event Horizon (Governance)
