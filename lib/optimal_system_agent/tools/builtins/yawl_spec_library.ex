defmodule OptimalSystemAgent.Tools.Builtins.YawlSpecLibrary do
  @moduledoc """
  OSA tool for browsing and retrieving YAWL workflow specifications.

  Provides access to example YAWL specs covering all 43 Workflow Control-Flow
  Patterns (WCPs) plus real-world process datasets (Repair, Traffic, Order) and
  process-mining benchmarks (BPI 2019, BPIC12, simple Petri net).

  Configuration via environment variables:
    YAWL_SPECS_DIR — Base directory (default: ~/yawlv6/exampleSpecs)

  All operations are pure filesystem reads — no HTTP calls.

  Pattern categories:
    basic, branching, cancellation, iteration, multiinstance,
    resource, state, structural, termination, trigger
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  @default_specs_dir "~/yawlv6/exampleSpecs"

  # ──────────────────────────────────────────────────────────────────────────
  # Behaviour Implementation
  # ──────────────────────────────────────────────────────────────────────────

  @impl true
  def safety, do: :read_only

  @impl true
  def name, do: "yawl_spec_library"

  @impl true
  def description do
    """
    Browse and retrieve YAWL workflow specifications from the local spec library.

    Operations:
    - list_patterns   — List all WCP pattern specs with WCP number, name, and category
    - get_pattern     — Return the XML content of a specific WCP pattern (e.g. "WCP01")
    - list_real_data  — List real-world process specs (real-data/ and processmining/)
    - get_spec_xml    — Return the full XML/YAWL content of a named file

    No network access required — reads directly from the local YAWL spec directory.
    Useful for loading reference workflows, testing pattern coverage, or feeding
    specs to process discovery and conformance tools.
    """
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "operation" => %{
          "type" => "string",
          "enum" => ["list_patterns", "get_pattern", "list_real_data", "get_spec_xml"],
          "description" => "Operation to perform"
        },
        "wcp_id" => %{
          "type" => "string",
          "description" =>
            "WCP identifier for get_pattern (e.g. \"WCP01\", \"WCP19\"). Case-insensitive."
        },
        "filename" => %{
          "type" => "string",
          "description" =>
            "Filename for get_spec_xml (e.g. \"RepairProcess.yawl.xml\", \"SimplePN.yawl\")"
        }
      },
      "required" => ["operation"]
    }
  end

  @impl true
  def execute(%{"operation" => "list_patterns"}) do
    specs_dir = resolve_specs_dir()
    patterns_dir = Path.join(specs_dir, "wcp-patterns")

    case File.exists?(patterns_dir) do
      false ->
        {:error, "WCP patterns directory not found: #{patterns_dir}"}

      true ->
        patterns =
          Path.wildcard(Path.join(patterns_dir, "**/*.xml"))
          |> Enum.sort()
          |> Enum.map(&parse_pattern_entry(&1, patterns_dir))
          |> Enum.reject(&is_nil/1)

        {:ok,
         %{
           "count" => length(patterns),
           "patterns" => patterns,
           "categories" => patterns |> Enum.map(& &1["category"]) |> Enum.uniq() |> Enum.sort()
         }}
    end
  end

  def execute(%{"operation" => "get_pattern", "wcp_id" => wcp_id})
      when is_binary(wcp_id) do
    specs_dir = resolve_specs_dir()
    patterns_dir = Path.join(specs_dir, "wcp-patterns")
    normalized = String.upcase(wcp_id)

    matches =
      Path.wildcard(Path.join(patterns_dir, "**/*.xml"))
      |> Enum.filter(fn path ->
        basename = Path.basename(path, ".xml")
        String.starts_with?(String.upcase(basename), normalized <> "_") or
          String.upcase(basename) == normalized
      end)

    case matches do
      [] ->
        {:error, :not_found,
         "No WCP pattern found for '#{wcp_id}'. Use list_patterns to see available patterns."}

      [path | _] ->
        read_spec_file(path)
    end
  end

  def execute(%{"operation" => "get_pattern"}) do
    {:error, "Missing required parameter: wcp_id (e.g. \"WCP01\")"}
  end

  def execute(%{"operation" => "list_real_data"}) do
    specs_dir = resolve_specs_dir()

    real_data_entries = list_dir_entries(Path.join(specs_dir, "real-data"), "real-data")
    processmining_entries = list_dir_entries(Path.join(specs_dir, "processmining"), "processmining")

    all_entries = real_data_entries ++ processmining_entries

    {:ok,
     %{
       "count" => length(all_entries),
       "files" => all_entries
     }}
  end

  def execute(%{"operation" => "get_spec_xml", "filename" => filename})
      when is_binary(filename) do
    specs_dir = resolve_specs_dir()

    # Search in real-data and processmining directories
    search_dirs = [
      Path.join(specs_dir, "real-data"),
      Path.join(specs_dir, "processmining")
    ]

    matches =
      search_dirs
      |> Enum.flat_map(fn dir ->
        candidate = Path.join(dir, filename)
        if File.regular?(candidate), do: [candidate], else: []
      end)

    case matches do
      [] ->
        {:error, :not_found,
         "File '#{filename}' not found. Use list_real_data to see available files."}

      [path | _] ->
        read_spec_file(path)
    end
  end

  def execute(%{"operation" => "get_spec_xml"}) do
    {:error, "Missing required parameter: filename (e.g. \"RepairProcess.yawl.xml\")"}
  end

  def execute(%{"operation" => op}) do
    {:error,
     "Unknown operation: #{op}. Valid operations: list_patterns, get_pattern, list_real_data, get_spec_xml"}
  end

  def execute(_) do
    {:error, "Missing required parameter: operation"}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Private Helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp resolve_specs_dir do
    raw = System.get_env("YAWL_SPECS_DIR") || @default_specs_dir
    Path.expand(raw)
  end

  # Parse a path like `.../wcp-patterns/basic/WCP01_Sequence.xml` into a map.
  defp parse_pattern_entry(path, patterns_dir) do
    # Category is the immediate subdirectory under wcp-patterns/
    relative = Path.relative_to(path, patterns_dir)
    parts = Path.split(relative)

    case parts do
      [category, filename] ->
        basename = Path.basename(filename, ".xml")
        parse_wcp_basename(basename, category, path)

      _ ->
        Logger.debug("[YawlSpecLibrary] Unexpected path structure: #{path}")
        nil
    end
  end

  # Filename like `WCP01_Sequence` → %{wcp: "WCP01", name: "Sequence", ...}
  # Handles multi-word names: `WCP13_MultiInstanceStructuredSynchronizingMerge`
  defp parse_wcp_basename(basename, category, full_path) do
    case String.split(basename, "_", parts: 2) do
      [wcp_id, name_raw] ->
        if Regex.match?(~r/^WCP\d+$/i, wcp_id) do
          %{
            "wcp" => String.upcase(wcp_id),
            "name" => camel_to_words(name_raw),
            "raw_name" => name_raw,
            "category" => category,
            "path" => full_path
          }
        else
          nil
        end

      _ ->
        nil
    end
  end

  # Convert CamelCase name to space-separated words for readability.
  # "MultiChoice" → "Multi Choice", "MIStatic" → "MI Static"
  defp camel_to_words(name) do
    name
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1 \\2")
    |> String.trim()
  end

  defp list_dir_entries(dir, source_label) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.reject(fn f -> f == "README.md" end)
      |> Enum.sort()
      |> Enum.map(fn filename ->
        full_path = Path.join(dir, filename)
        stat = File.stat!(full_path)

        %{
          "filename" => filename,
          "source" => source_label,
          "path" => full_path,
          "size_bytes" => stat.size
        }
      end)
    else
      Logger.debug("[YawlSpecLibrary] Directory not found: #{dir}")
      []
    end
  end

  defp read_spec_file(path) do
    case File.read(path) do
      {:ok, content} ->
        {:ok,
         %{
           "path" => path,
           "filename" => Path.basename(path),
           "size_bytes" => byte_size(content),
           "content" => content
         }}

      {:error, reason} ->
        Logger.warning("[YawlSpecLibrary] Failed to read #{path}: #{reason}")
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end
end
