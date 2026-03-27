defmodule OptimalSystemAgent.Yawl.SpecLibrary do
  @moduledoc """
  Discovers and loads YAWL XML specs from ~/yawlv6/exampleSpecs/.
  Provides access to WCP pattern specs (43 patterns) and real-world process specs.

  The specs path is configurable via:
    config :optimal_system_agent, :yawl_specs_path, "~/yawlv6/exampleSpecs"

  Or at runtime via the YAWLV6_SPECS_PATH environment variable.
  """

  # Known wcp-patterns category subdirectories in discovery order.
  @wcp_categories [
    "basic",
    "branching",
    "iteration",
    "cancellation",
    "multiinstance",
    "state",
    "structural",
    "resource",
    "termination",
    "trigger"
  ]

  @doc """
  Returns sorted list of all available WCP pattern specs found on disk.

  Each entry is a map with keys:
    - `:id`       — "WCP-1", "WCP-2", ... (integer-sorted)
    - `:name`     — human-readable name, e.g. "Sequence"
    - `:category` — subdirectory name, e.g. "basic"
    - `:path`     — absolute path to the XML file
  """
  @spec list_patterns() :: [%{id: String.t(), name: String.t(), category: String.t(), path: String.t()}]
  def list_patterns do
    specs_path = spec_path()
    patterns_dir = Path.join(specs_path, "wcp-patterns")

    if File.dir?(patterns_dir) do
      @wcp_categories
      |> Enum.flat_map(fn category ->
        category_dir = Path.join(patterns_dir, category)

        if File.dir?(category_dir) do
          category_dir
          |> File.ls!()
          |> Enum.filter(&String.ends_with?(&1, ".xml"))
          |> Enum.map(fn filename ->
            {id, name} = parse_pattern_filename(filename)

            %{
              id: id,
              name: name,
              category: category,
              path: Path.join(category_dir, filename)
            }
          end)
        else
          []
        end
      end)
      |> Enum.sort_by(fn %{id: id} -> wcp_sort_key(id) end)
    else
      []
    end
  end

  @doc """
  Loads a YAWL spec XML by WCP pattern ID.

  Accepted ID formats:
    - "WCP-1", "WCP-01"  — dash-separated
    - "WCP1", "WCP01"    — no separator
    - "1", "01"          — numeric only

  Returns `{:ok, xml_string}` on success, `{:error, :not_found}` otherwise.
  """
  @spec load_spec(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def load_spec(pattern_id) do
    normalized = normalize_pattern_id(pattern_id)

    list_patterns()
    |> Enum.find(fn %{path: path} ->
      basename = Path.basename(path, ".xml")
      String.upcase(basename) |> String.starts_with?(normalized)
    end)
    |> case do
      nil ->
        {:error, :not_found}

      %{path: path} ->
        case File.read(path) do
          {:ok, xml} -> {:ok, xml}
          {:error, _} -> {:error, :not_found}
        end
    end
  end

  # Mapping from canonical dataset name to filename stem (case-insensitive prefix).
  # Supports both subdirectory layout (legacy) and flat file layout (current).
  @real_data_names %{
    "order-management" => "OrderManagement",
    "repair-process" => "RepairProcess",
    "traffic-fine-management" => "TrafficFineManagement"
  }

  @doc """
  Returns a list of available real-data dataset names.

  Each entry is a map:
    - `:name`  — canonical dataset name (e.g. "order-management")
    - `:path`  — absolute path to the XML file or directory

  Supports both layouts:
    - Flat: real-data/OrderManagement.yawl.xml (current exampleSpecs layout)
    - Subdirectory: real-data/order-management/ (legacy layout)
  """
  @spec list_real_data() :: [%{name: String.t(), path: String.t()}]
  def list_real_data do
    real_data_dir = Path.join(spec_path(), "real-data")

    if File.dir?(real_data_dir) do
      entries = File.ls!(real_data_dir)

      # First try subdirectory layout (legacy)
      dirs =
        entries
        |> Enum.filter(fn entry -> File.dir?(Path.join(real_data_dir, entry)) end)
        |> Enum.map(fn name -> %{name: name, path: Path.join(real_data_dir, name)} end)
        |> Enum.sort_by(& &1.name)

      if dirs != [] do
        dirs
      else
        # Flat file layout: map canonical names to files present on disk
        @real_data_names
        |> Enum.flat_map(fn {canonical, stem} ->
          match =
            entries
            |> Enum.find(fn f ->
              String.starts_with?(String.downcase(f), String.downcase(stem)) and
                String.ends_with?(f, ".xml")
            end)

          case match do
            nil -> []
            filename -> [%{name: canonical, path: Path.join(real_data_dir, filename)}]
          end
        end)
        |> Enum.sort_by(& &1.name)
      end
    else
      []
    end
  end

  @doc """
  Loads a real-world process spec XML by dataset name.

  Known datasets:
    - "order-management"
    - "repair-process"
    - "traffic-fine-management"

  Returns `{:ok, xml_string}` on success, `{:error, :not_found}` otherwise.

  Supports both layouts:
    - Flat: real-data/OrderManagement.yawl.xml (current exampleSpecs layout)
    - Subdirectory: real-data/order-management/ (legacy layout)
  """
  @spec load_real_data(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def load_real_data(name) do
    real_data_dir = Path.join(spec_path(), "real-data")

    # Try subdirectory layout first (legacy)
    target_dir = Path.join(real_data_dir, name)

    if File.dir?(target_dir) do
      target_dir
      |> File.ls!()
      |> Enum.sort()
      |> Enum.find(&String.ends_with?(&1, ".xml"))
      |> case do
        nil -> {:error, :not_found}
        filename -> File.read(Path.join(target_dir, filename))
      end
    else
      # Try flat file layout: look up stem from canonical name map
      case Map.get(@real_data_names, name) do
        nil ->
          {:error, :not_found}

        stem ->
          if File.dir?(real_data_dir) do
            match =
              real_data_dir
              |> File.ls!()
              |> Enum.find(fn f ->
                String.starts_with?(String.downcase(f), String.downcase(stem)) and
                  String.ends_with?(f, ".xml")
              end)

            case match do
              nil -> {:error, :not_found}
              filename -> File.read(Path.join(real_data_dir, filename))
            end
          else
            {:error, :not_found}
          end
      end
    end
  end

  @doc """
  Returns the resolved absolute path to the yawlv6 exampleSpecs directory.

  Resolution order:
    1. YAWLV6_SPECS_PATH environment variable (if set)
    2. `:yawl_specs_path` application config key
    3. Default: `~/yawlv6/exampleSpecs`
  """
  @spec spec_path() :: String.t()
  def spec_path do
    case System.get_env("YAWLV6_SPECS_PATH") do
      nil_or_empty when nil_or_empty in [nil, ""] ->
        Application.get_env(
          :optimal_system_agent,
          :yawl_specs_path,
          Path.expand("~/yawlv6/exampleSpecs")
        )

      env_path ->
        Path.expand(env_path)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Parse "WCP01_Sequence.xml" → {"WCP-1", "Sequence"}
  # Parse "WCP13_MultiInstanceStructuredSynchronizingMerge.xml" → {"WCP-13", "Multi Instance Structured Synchronizing Merge"}
  defp parse_pattern_filename(filename) do
    base = Path.basename(filename, ".xml")

    case Regex.run(~r/^WCP(\d+)_(.+)$/i, base) do
      [_, num_str, name_raw] ->
        num = String.to_integer(num_str)
        # Convert CamelCase and underscores to space-separated words
        name =
          name_raw
          |> String.replace("_", " ")
          |> split_camel_case()

        {"WCP-#{num}", name}

      _ ->
        {base, base}
    end
  end

  # "MultiChoice" → "Multi Choice", "ArbitraryCycles" → "Arbitrary Cycles"
  defp split_camel_case(str) do
    # Insert space before uppercase letters that follow lowercase letters
    Regex.replace(~r/([a-z])([A-Z])/, str, "\\1 \\2")
  end

  # Normalize any supported pattern ID format to "WCP" <zero-padded-2-digit>
  # "WCP-1" → "WCP01", "WCP1" → "WCP01", "1" → "WCP01", "WCP01" → "WCP01"
  defp normalize_pattern_id(id) do
    s = String.upcase(id) |> String.replace(~r/[^A-Z0-9]/, "")

    case Regex.run(~r/^WCP(\d+)$/, s) do
      [_, num] ->
        padded = String.pad_leading(num, 2, "0")
        "WCP#{padded}"

      _ ->
        # Maybe it's just a number like "1" or "01"
        case Regex.run(~r/^(\d+)$/, s) do
          [_, num] ->
            padded = String.pad_leading(num, 2, "0")
            "WCP#{padded}"

          _ ->
            s
        end
    end
  end

  # Sort WCP-1, WCP-2, ... WCP-43 by numeric value
  defp wcp_sort_key("WCP-" <> rest) do
    case Integer.parse(rest) do
      {n, _} -> n
      :error -> 9999
    end
  end

  defp wcp_sort_key(_), do: 9999
end
