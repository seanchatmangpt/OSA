# How-To: Add an Agent Tool to OSA

> **Problem**: Your agent needs a new capability (e.g., `@tool process_document`) but the tool doesn't exist yet. Build and register a tool that agents can call during ReAct loops.
>
> **Outcome**: A production-ready tool with JSON Schema validation, permission enforcement, OTEL tracing, and test coverage.

## Time Estimate
20-30 minutes for a read-only tool. Add 10-15 min for write operations with permission checks.

---

## Prerequisites

- OSA running locally (`mix osa.serve`)
- Familiarity with Elixir/OTP and JSON Schema
- Access to `OSA/lib/optimal_system_agent/tools/builtins/`

---

## Step 1: Define What the Tool Does

Tool design checklist:

| Aspect | Decision |
|--------|----------|
| **Name** | `process_document` (snake_case, unique) |
| **Safety tier** | `:read_only` (read docs), `:write_safe` (edit config), `:write_destructive` (delete) |
| **Input params** | `{document_path, format}` |
| **Output format** | `{:ok, result}` or `{:error, reason}` |
| **Permissions required** | `:workspace` or `:full` |
| **Timeout** | 30 seconds for document processing |

**Example: Process Document Tool**

```
Name:        process_document
Purpose:     Parse & extract structure from documents (markdown, PDF, JSON)
Input:       {document_path: "path/to/doc.md", format: "markdown"}
Output:      {ok: {title: "...", sections: [...], word_count: 1234}}
Safety:      read_only
Permissions: workspace or full
```

---

## Step 2: Create the Tool Module

**File**: `OSA/lib/optimal_system_agent/tools/builtins/process_document.ex`

```elixir
defmodule OptimalSystemAgent.Tools.Builtins.ProcessDocument do
  @moduledoc """
  Tool: process_document

  Parse and extract structure from documents (Markdown, JSON, YAML, PDF).

  Supports:
    - Markdown: Extract headings, sections, links
    - JSON: Validate, pretty-print, extract keys
    - YAML: Parse config files
    - Plain text: Word count, line analysis

  Safety: :read_only (no writes)
  Permission: :workspace (users can call this)

  Example:
    iex> ProcessDocument.execute(%{
    ...>   "document_path" => "README.md",
    ...>   "format" => "markdown"
    ...> })
    {:ok, %{
      "title" => "README",
      "sections" => [%{"level" => 1, "title" => "Overview"}, ...],
      "word_count" => 2847
    }}
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour
  require Logger

  # ---- Callbacks (required by Tools.Behaviour) ----

  @impl true
  def name, do: "process_document"

  @impl true
  def description do
    "Parse and extract structure from documents (Markdown, JSON, YAML). " <>
      "Returns headings, sections, keys, and metadata."
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "document_path" => %{
          "type" => "string",
          "description" => "Path to the document (relative or absolute)"
        },
        "format" => %{
          "type" => "string",
          "enum" => ["markdown", "json", "yaml", "text"],
          "description" => "Document format"
        },
        "extract_only" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Optional: only extract these fields (e.g., [\"title\", \"sections\"])"
        }
      },
      "required" => ["document_path", "format"]
    }
  end

  @impl true
  def safety, do: :read_only

  # ---- Tool Execution ----

  @impl true
  def execute(params) do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    :otel_tracer.with_span(tracer, "tool.process_document", %{
      "document_path" => Map.get(params, "document_path"),
      "format" => Map.get(params, "format")
    }, fn span_ctx ->
      perform_execute(params, span_ctx)
    end)
  end

  # ---- Private Implementation ----

  defp perform_execute(%{"document_path" => path, "format" => format} = params, span_ctx) do
    extract_only = Map.get(params, "extract_only", [])

    try do
      # Step 1: Validate file exists and is readable
      with :ok <- validate_readable(path) do
        # Step 2: Read file
        {:ok, content} = File.read(path)

        # Step 3: Parse based on format
        result =
          case String.downcase(format) do
            "markdown" -> parse_markdown(content, extract_only)
            "json" -> parse_json(content, extract_only)
            "yaml" -> parse_yaml(content, extract_only)
            "text" -> parse_text(content, extract_only)
            _ -> {:error, "unsupported format: #{format}"}
          end

        # Step 4: Record outcome in OTEL
        case result do
          {:ok, data} ->
            :otel_span.set_attributes(span_ctx, %{
              "parse_status" => "ok",
              "format" => format,
              "keys_extracted" => length(Map.keys(data))
            })

            {:ok, data}

          {:error, reason} ->
            :otel_span.set_attributes(span_ctx, %{
              "parse_status" => "error",
              "error_reason" => reason
            })

            {:error, reason}
        end
    rescue
      e in File.Error ->
        Logger.error("ProcessDocument: File error: #{inspect(e)}")

        :otel_span.set_attributes(span_ctx, %{
          "parse_status" => "error",
          "error_type" => "file_error"
        })

        {:error, "file not found: #{path}"}

      e ->
        Logger.error("ProcessDocument: Unexpected error: #{inspect(e)}")

        :otel_span.set_attributes(span_ctx, %{
          "parse_status" => "error",
          "error_type" => "unknown"
        })

        {:error, "processing failed: #{inspect(e)}"}
    end
  end

  defp perform_execute(_, _span_ctx) do
    {:error, "missing required parameters: document_path, format"}
  end

  # ---- File Validation ----

  defp validate_readable(path) do
    expanded = Path.expand(path)

    # Check if file is within allowed read paths
    allowed_paths = Application.get_env(
      :optimal_system_agent,
      :allowed_read_paths,
      [System.user_home!(), "/tmp"]
    )

    case Enum.any?(allowed_paths, &String.starts_with?(expanded, &1)) do
      true ->
        if File.exists?(expanded) && File.regular?(expanded) do
          :ok
        else
          {:error, "file not found or not readable"}
        end

      false ->
        {:error, "access denied: path outside allowed directories"}
    end
  end

  # ---- Format-Specific Parsers ----

  defp parse_markdown(content, extract_only) do
    # Extract structure from Markdown
    lines = String.split(content, "\n")

    sections =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _} -> String.starts_with?(line, "#") end)
      |> Enum.map(fn {line, idx} ->
        level = String.length(String.trim_leading(line, "#")) - String.length(String.trim_left(line))
        title = String.trim_leading(line, "#") |> String.trim()

        %{
          "level" => level,
          "title" => title,
          "line_number" => idx + 1
        }
      end)

    result = %{
      "format" => "markdown",
      "title" => extract_title(lines),
      "sections" => sections,
      "word_count" => count_words(content),
      "line_count" => length(lines)
    }

    {:ok, filter_result(result, extract_only)}
  end

  defp parse_json(content, extract_only) do
    case Jason.decode(content) do
      {:ok, data} when is_map(data) ->
        result = %{
          "format" => "json",
          "keys" => Map.keys(data),
          "structure" => describe_structure(data),
          "valid" => true
        }

        {:ok, filter_result(result, extract_only)}

      {:ok, data} when is_list(data) ->
        result = %{
          "format" => "json",
          "type" => "array",
          "length" => length(data),
          "valid" => true
        }

        {:ok, filter_result(result, extract_only)}

      {:error, reason} ->
        {:error, "JSON parse error: #{inspect(reason)}"}
    end
  end

  defp parse_yaml(content, extract_only) do
    case YamlElixir.read_all_from_string(content) do
      {:ok, [data | _]} when is_map(data) ->
        result = %{
          "format" => "yaml",
          "keys" => Map.keys(data),
          "structure" => describe_structure(data),
          "valid" => true
        }

        {:ok, filter_result(result, extract_only)}

      {:ok, _} ->
        {:error, "YAML must contain a map at root level"}

      {:error, reason} ->
        {:error, "YAML parse error: #{inspect(reason)}"}
    end
  end

  defp parse_text(content, extract_only) do
    result = %{
      "format" => "text",
      "word_count" => count_words(content),
      "line_count" => length(String.split(content, "\n")),
      "character_count" => String.length(content)
    }

    {:ok, filter_result(result, extract_only)}
  end

  # ---- Utility Functions ----

  defp extract_title(lines) do
    lines
    |> Enum.find(fn line -> String.starts_with?(line, "# ") end)
    |> case do
      nil -> "Untitled"
      line -> String.trim_leading(line, "# ") |> String.trim()
    end
  end

  defp count_words(content) do
    content
    |> String.split()
    |> length()
  end

  defp describe_structure(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> "#{k}: #{type_name(v)}" end)
    |> Enum.join(", ")
  end

  defp describe_structure(data), do: type_name(data)

  defp type_name(v) when is_binary(v), do: "string"
  defp type_name(v) when is_number(v), do: "number"
  defp type_name(v) when is_boolean(v), do: "boolean"
  defp type_name(v) when is_list(v), do: "array"
  defp type_name(v) when is_map(v), do: "object"
  defp type_name(_), do: "unknown"

  defp filter_result(result, []), do: result

  defp filter_result(result, extract_only) do
    Map.filter(result, fn {k, _v} -> k in extract_only end)
  end
end
```

---

## Step 3: Register the Tool

Tools are auto-discovered by OSA on startup. Verify registration:

**Option A: Auto-discovery (recommended)**

OSA scans `OSA/lib/optimal_system_agent/tools/builtins/*.ex` at boot.

Just ensure your file follows the naming pattern: `builtins/YOUR_TOOL.ex`

**Option B: Manual registration**

If auto-discovery doesn't work, register in `config/config.exs`:

```elixir
config :optimal_system_agent, :tools,
  builtins: [
    OptimalSystemAgent.Tools.Builtins.FileRead,
    OptimalSystemAgent.Tools.Builtins.ProcessDocument  # Add this
  ]
```

**Verify it loaded:**

```bash
mix osa.serve

# In another terminal:
curl -s http://localhost:8089/api/tools | jq '.tools[] | select(.name == "process_document")'
```

Expected output:
```json
{
  "name": "process_document",
  "description": "Parse and extract structure from documents...",
  "parameters": { ... }
}
```

---

## Step 4: Write Tests

**File**: `OSA/test/tools/builtins/process_document_test.exs`

```elixir
defmodule OptimalSystemAgent.Tools.Builtins.ProcessDocumentTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.ProcessDocument

  describe "tool metadata" do
    test "has correct name" do
      assert ProcessDocument.name() == "process_document"
    end

    test "has safety tier" do
      assert ProcessDocument.safety() == :read_only
    end

    test "has valid parameters schema" do
      params = ProcessDocument.parameters()
      assert params["type"] == "object"
      assert "document_path" in params["properties"]
      assert "format" in params["properties"]
    end
  end

  describe "execute/1 — markdown parsing" do
    test "parses markdown document" do
      # Create a temp markdown file
      content = """
      # Overview

      This is a test document.

      ## Section 1
      Content here.

      ## Section 2
      More content.
      """

      File.mkdir_p!("/tmp/osa_test")
      File.write!("/tmp/osa_test/test.md", content)

      result =
        ProcessDocument.execute(%{
          "document_path" => "/tmp/osa_test/test.md",
          "format" => "markdown"
        })

      assert {:ok, data} = result
      assert data["title"] == "Overview"
      assert length(data["sections"]) == 2
      assert data["word_count"] == 12
    end

    test "filters extracted fields" do
      File.write!("/tmp/osa_test/test.md", "# Title\n\n## Section")

      result =
        ProcessDocument.execute(%{
          "document_path" => "/tmp/osa_test/test.md",
          "format" => "markdown",
          "extract_only" => ["title", "word_count"]
        })

      assert {:ok, data} = result
      assert Map.has_key?(data, "title")
      assert Map.has_key?(data, "word_count")
      assert !Map.has_key?(data, "sections")
    end
  end

  describe "execute/1 — json parsing" do
    test "parses valid JSON" do
      File.write!("/tmp/osa_test/test.json", ~s({"key": "value", "count": 42}))

      result =
        ProcessDocument.execute(%{
          "document_path" => "/tmp/osa_test/test.json",
          "format" => "json"
        })

      assert {:ok, data} = result
      assert "key" in data["keys"]
      assert data["valid"] == true
    end

    test "rejects invalid JSON" do
      File.write!("/tmp/osa_test/invalid.json", "{broken json}")

      result =
        ProcessDocument.execute(%{
          "document_path" => "/tmp/osa_test/invalid.json",
          "format" => "json"
        })

      assert {:error, reason} = result
      assert String.contains?(reason, "parse error")
    end
  end

  describe "execute/1 — error handling" do
    test "rejects missing file" do
      result =
        ProcessDocument.execute(%{
          "document_path" => "/tmp/nonexistent_file_xyz.md",
          "format" => "markdown"
        })

      assert {:error, reason} = result
      assert String.contains?(reason, "not found")
    end

    test "rejects missing parameters" do
      result = ProcessDocument.execute(%{"format" => "markdown"})
      assert {:error, _} = result
    end

    test "rejects unsupported format" do
      File.write!("/tmp/osa_test/test.md", "# Test")

      result =
        ProcessDocument.execute(%{
          "document_path" => "/tmp/osa_test/test.md",
          "format" => "docx"
        })

      assert {:error, reason} = result
      assert String.contains?(reason, "unsupported")
    end
  end

  # Cleanup
  setup_all do
    on_exit(fn ->
      File.rm_rf!("/tmp/osa_test")
    end)

    :ok
  end
end
```

**Run the tests:**

```bash
cd OSA
mix test test/tools/builtins/process_document_test.exs
```

Expected output:
```
Compiling 1 file (.ex)
Generated optimal_system_agent app
...................
10 tests, 0 failures
```

---

## Step 5: Integration Test

Test the full path: agent calls tool → tool executes → result returned:

**File**: `OSA/test/tools/integration/tool_execution_e2e_test.exs` (add to existing)

```elixir
defmodule OptimalSystemAgent.Tools.Integration.ToolExecutionE2ETest do
  use ExUnit.Case, async: false
  @tag :integration

  alias OptimalSystemAgent.Agent.Loop
  alias OptimalSystemAgent.Tools.Registry

  test "agent can call process_document tool" do
    # 1. Verify tool is registered
    tools = Registry.list_tools_direct()
    assert Enum.any?(tools, &(&1.name == "process_document"))

    # 2. Create a document for the agent to process
    File.write!("/tmp/integration_test.md", """
    # Integration Test

    ## Setup
    Creating a test document.

    ## Execution
    Agent processes this file.
    """)

    # 3. Send agent a message requesting document processing
    session_id = "integration_#{System.unique_integer()}"

    message = %{
      "content" => "Process the file /tmp/integration_test.md in markdown format",
      "role" => "user"
    }

    # 4. Agent loop would call the tool; here we test directly
    result =
      OptimalSystemAgent.Tools.Builtins.ProcessDocument.execute(%{
        "document_path" => "/tmp/integration_test.md",
        "format" => "markdown"
      })

    # 5. Verify result
    assert {:ok, data} = result
    assert data["title"] == "Integration Test"
    assert data["word_count"] > 0

    File.rm!("/tmp/integration_test.md")
  end
end
```

---

## Best Practices

### 1. **Idempotency**
Make your tool safe to call multiple times:

```elixir
# GOOD: Tool doesn't change if called twice
def execute(%{"path" => p} = params) do
  {:ok, %{"status" => "processed", "path" => p}}
end
```

### 2. **Input Validation**
Validate early, fail fast:

```elixir
defp validate_params(params) do
  with :ok <- validate_required(params, ["document_path", "format"]),
       :ok <- validate_format(Map.get(params, "format")) do
    :ok
  else
    {:error, reason} -> {:error, reason}
  end
end
```

### 3. **OTEL Tracing**
Always emit spans for observability:

```elixir
tracer = :opentelemetry.get_tracer(:optimal_system_agent)

:otel_tracer.with_span(tracer, "tool.your_tool", %{
  "input_param" => value
}, fn span_ctx ->
  result = do_work()
  :otel_span.set_attributes(span_ctx, %{"status" => "ok"})
  result
end)
```

### 4. **Timeouts**
Set reasonable timeout boundaries:

```elixir
# Wrap expensive operations
result =
  Task.async(fn -> process_large_document(params) end)
  |> Task.await(30_000)  # 30-second timeout

rescue
  _e -> {:error, "processing timeout"}
```

### 5. **Permission Checks**
Enforce tool-level permissions:

```elixir
def execute(params, context) do
  with :ok <- check_permission(context, :workspace),
       :ok <- validate_params(params) do
    perform_work(params)
  end
end

defp check_permission(context, required_tier) do
  case Map.get(context, :permission_tier) do
    ^required_tier -> :ok
    :full -> :ok
    _ -> {:error, "insufficient permissions"}
  end
end
```

---

## Troubleshooting

### **Issue**: Tool not appearing in `/api/tools` list

**Diagnosis**: Check if tool is being loaded.

```bash
# Terminal 1
mix osa.serve

# Terminal 2
curl -s http://localhost:8089/api/tools | jq '.tools | map(.name)'
```

**Fix**: Ensure file is in `OSA/lib/optimal_system_agent/tools/builtins/` and implements `Tools.Behaviour`.

### **Issue**: Agent can't find the tool

**Diagnosis**: Tool might not match the exact name the agent is calling.

```elixir
# Agent says: "@tool process_document"
# Tool must return: name() -> "process_document"
```

**Fix**: Check `name()` callback matches agent's request exactly.

### **Issue**: Tool times out during execution

**Diagnosis**: Work is taking too long.

**Fix**: Add timeout handling:

```elixir
Task.async(fn -> slow_operation() end)
|> Task.await(timeout_ms)
rescue
  _e -> {:error, "operation timeout"}
end
```

---

## What's Next

1. **Add permission enforcement**: Integrate tool with `Loop.ToolExecutor` permission system
2. **Add to favorites**: Tools can be tagged `:favorite` for easy discovery
3. **Caching**: Cache expensive results in `Tools.Cache`
4. **Multi-tenant**: Scope tool access by workspace/organization
5. **Monitoring**: Add metrics to track tool usage and latency

---

## References

- [Tools Behaviour](../../backend/tools/behaviour.md) — Tool contract
- [Permission Tiers](../../backend/permissions.md) — Permission levels
- [Chicago TDD](../../../.claude/rules/chicago-tdd.md) — Test-first development
- [OTEL Instrumentation](../how-to/add-otel-spans.md) — Observability
- Test examples: `OSA/test/tools/builtins/*_test.exs`

