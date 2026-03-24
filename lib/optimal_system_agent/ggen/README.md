# GGEN: Fortune 5 Layer 4 - Template Generation Engine

**Status:** ✅ IMPLEMENTED (Phase 3b)

## Overview

GGEN is a template generation engine for Fortune 5 Layer 4 (Correlation). It provides:

1. **Deterministic Template Generation** - Converts ODCS workspace definitions into code templates
2. **Multi-Language Support** - Rust, TypeScript, Elixir templates with consistent structure
3. **Variable Substitution** - Parameterized template rendering with validation
4. **Generator Registry** - Pluggable template system for extensibility

## Architecture

```
lib/optimal_system_agent/ggen/
├── engine.ex              ← Main generation orchestrator
├── registry.ex            ← Template manager and metadata
├── template_renderer.ex   ← Variable substitution and rendering
├── templates/
│   ├── rust.ex           ← Rust project generator
│   ├── typescript.ex      ← TypeScript project generator
│   └── elixir.ex         ← Elixir project generator
└── README.md             ← This file

ggen/                      ← SPARQL correlation layer
├── sparql/
│   ├── construct_modules.rq    ← Extract modules.json
│   ├── construct_deps.rq       ← Extract deps.json
│   └── construct_patterns.rq   ← Extract patterns.json
└── README.md
```

## API

### Core Module: `OptimalSystemAgent.Ggen.Engine`

#### `generate(template_type, variables, options)`

Generate code from a template.

```elixir
{:ok, result} = Engine.generate(:rust, %{
  "crate_name" => "my_app",
  "edition" => "2021",
  "authors" => ["Alice <alice@example.com>"],
  "license" => "MIT",
  "description" => "My application"
}, output_dir: "src")

# Returns
{:ok, %{
  files: [
    {"Cargo.toml", "..."},
    {"src/lib.rs", "..."},
    {"src/main.rs", "..."}
  ],
  metadata: %{
    template_type: :rust,
    file_count: 5,
    generated_at: #DateTime<...>,
    variables_used: ["crate_name", "edition", ...]
  }
}}
```

**Parameters:**
- `template_type`: `:rust`, `:typescript`, `:elixir`
- `variables`: Map of variable names to values
- `options`: Keyword list:
  - `output_dir`: Where to write files (default: ".")
  - `dry_run`: If true, don't write files (default: false)
  - `workspace_rdf`: Path to workspace.ttl for SPARQL correlation

**Returns:**
- `{:ok, %{files: [...], metadata: %{...}}}`
- `{:error, reason}`

### Registry Module: `OptimalSystemAgent.Ggen.Registry`

#### Available Templates

```elixir
Registry.list_templates()
# => [:rust, :typescript, :elixir]

{:ok, info} = Registry.template_info(:rust)
# => %{
#      name: "Rust Project Template",
#      description: "Generate Rust crate from ODCS specification",
#      required_vars: ["crate_name", "edition"],
#      optional_vars: ["authors", "license", "description"],
#      outputs: ["Cargo.toml", "src/main.rs", "src/lib.rs"]
#    }
```

#### Variable Validation

```elixir
Registry.validate_variables(:rust, %{
  "crate_name" => "my_app",
  "edition" => "2021"
})
# => :ok

Registry.validate_variables(:rust, %{})
# => {:error, "Missing required variables: crate_name, edition"}
```

## Template Specifications

### Rust Template

**Required Variables:**
- `crate_name` - Name of the Rust crate (lowercase, alphanumeric with underscores)
- `edition` - Rust edition (2015, 2018, 2021)

**Optional Variables:**
- `authors` - List of author strings
- `license` - License type (default: MIT)
- `description` - Crate description
- `dependencies` - Map of dependency names to versions

**Generated Files:**
- `Cargo.toml` - Package manifest
- `src/lib.rs` - Library root with documentation and tests
- `src/main.rs` - Executable entry point
- `tests/integration_test.rs` - Integration test structure
- `.gitignore` - Rust-specific ignore rules
- `README.md` - Project documentation

### TypeScript Template

**Required Variables:**
- `project_name` - Name of the project

**Optional Variables:**
- `version` - Version number (default: 1.0.0)
- `description` - Project description
- `author` - Author name

**Generated Files:**
- `package.json` - npm configuration
- `tsconfig.json` - TypeScript compiler configuration
- `src/index.ts` - Entry point
- `src/utils.ts` - Utility functions
- `tests/index.test.ts` - Jest test suite
- `.gitignore` - Node.js specific ignore rules
- `.npmrc` - npm configuration
- `README.md` - Project documentation

### Elixir Template

**Required Variables:**
- `app_name` - Name of the Elixir application (CamelCase)

**Optional Variables:**
- `version` - Version number (default: 0.1.0)
- `description` - Application description
- `elixir_version` - Required Elixir version (default: ~> 1.14)

**Generated Files:**
- `mix.exs` - Mix project configuration
- `lib/app_name.ex` - Main module with business logic
- `lib/app_name/application.ex` - Application callback
- `test/app_name_test.exs` - Test suite
- `.gitignore` - Elixir specific ignore rules
- `.formatter.exs` - Code formatter configuration
- `README.md` - Project documentation

## SPARQL Correlation (Layer 4)

The `ggen/sparql/` directory contains SPARQL CONSTRUCT queries that:

1. **construct_modules.rq** - Extracts module information from workspace.ttl
2. **construct_deps.rq** - Extracts dependency relationships
3. **construct_patterns.rq** - Extracts YAWL workflow patterns

These queries generate SPR output (modules.json, deps.json, patterns.json) which can be used as input variables for template generation.

## Examples

### Generate Rust Project

```elixir
alias OptimalSystemAgent.Ggen.Engine

Engine.generate(:rust, %{
  "crate_name" => "mylib",
  "edition" => "2021",
  "authors" => ["John Doe <john@example.com>"],
  "license" => "Apache-2.0",
  "description" => "A useful library"
}, output_dir: "projects/mylib")
```

### Generate TypeScript Project

```elixir
Engine.generate(:typescript, %{
  "project_name" => "my_app",
  "version" => "2.0.0",
  "description" => "Frontend application",
  "author" => "Jane Smith"
}, output_dir: "frontend")
```

### Generate Elixir Project

```elixir
Engine.generate(:elixir, %{
  "app_name" => "MyService",
  "version" => "0.2.0",
  "description" => "Microservice for order processing",
  "elixir_version" => "~> 1.15"
}, output_dir: "services/my_service")
```

### Dry Run (No File Writing)

```elixir
{:ok, result} = Engine.generate(:rust, variables, dry_run: true)

# result.files contains the file contents without writing to disk
Enum.each(result.files, fn {path, content} ->
  IO.puts("Would create: #{path}")
end)
```

## Testing

**Unit Tests:** 54 tests in `/test/optimal_system_agent/ggen/`
- Engine tests (45 tests)
- Registry tests (9 tests)

**Integration Tests:** 17 tests in `/test/optimal_system_agent/ggen/integration_test.exs`
- SPARQL query validation
- Full template generation pipelines
- Error handling and edge cases

**Run Tests:**

```bash
# All ggen tests
mix test test/optimal_system_agent/ggen/ --no-start

# Specific test file
mix test test/optimal_system_agent/ggen/engine_test.exs --no-start

# Integration tests only
mix test test/optimal_system_agent/ggen/integration_test.exs --include ggen_integration
```

## Design Principles

### 1. Deterministic Generation
- Same input variables → identical output
- No random generation or non-deterministic operations
- Reproducible across time and platforms

### 2. Variable-Driven
- All customization through variables
- No template language Turing-completeness
- Validation at generation time

### 3. Extensible Registry
- New templates registered at runtime
- Handler modules implement `render/2`
- Pluggable without modifying core

### 4. Signal Theory Integration
- All outputs encode Signal Theory S=(M,G,T,F,W)
- Template metadata includes generation timestamp
- Traceable artifact lineage

## Signal Theory Encoding

All template generation follows Signal Theory:

```
S = (Mode, Genre, Type, Format, Structure)

Mode:      code (generated source code)
Genre:     spec (specification templates)
Type:      inform (informational output)
Format:    text (Cargo.toml, JSON, TypeScript, etc.)
Structure: template-output (generated artifact)
```

## Future Enhancements

- [ ] Conditional template blocks (if/else/for)
- [ ] Filter functions (upcase, downcase, etc.)
- [ ] Template composition (include other templates)
- [ ] Custom template registration at runtime
- [ ] SPARQL-driven variable extraction
- [ ] Template versioning and evolution tracking

## References

- Fortune 5 definition: `docs/FORTUNE_5_COMPREHENSIVE_GAPS_VERIFIED.md`
- Signal Theory: `docs/diataxis/explanation/signal-theory-complete.md`
- ggen reference implementation: `/Users/sac/ggen/`
- Parent Ggen Thesis: `https://github.com/seanchatmangpt/ggen`
