defmodule OptimalSystemAgent.Sensors.RDFGenerator do
  @moduledoc """
  RDF Generator — Fortune 5 Layer 3: Data Recording

  Generates workspace.ttl RDF file from SPR sensor outputs.

  Signal Theory S=(M,G,T,F,W) encoding:
    - mode: data
    - genre: report
    - type: inform
    - format: turtle
    - structure: rdf-graph
  """

  require Logger

  # SensorRegistry not used directly in this module

  @doc """
  Generate workspace.ttl RDF file from SPR sensor outputs.

  ## Options
    * `:spr_dir` - Directory containing SPR JSON files (default: priv/sensors)
    * `:output_file` - Output path for workspace.ttl (default: priv/sensors/workspace.ttl)
    * `:base_uri` - Base URI for RDF resources (default: https://chatmangpt.com/workspace#)

  ## Returns
    * `{:ok, metadata}` - Map with file path, triple count, size
    * `{:error, reason}` - Generation failed
  """
  def generate_rdf(opts \\ []) do
    spr_dir = Keyword.get(opts, :spr_dir, "priv/sensors")
    output_file = Keyword.get(opts, :output_file, "priv/sensors/workspace.ttl")
    base_uri = Keyword.get(opts, :base_uri, "https://chatmangpt.com/workspace#")

    with true <- File.dir?(spr_dir) || {:error, :spr_directory_not_found},
         {:ok, modules_json} <- File.read(Path.join(spr_dir, "modules.json")),
         {:ok, deps_json} <- File.read(Path.join(spr_dir, "deps.json")),
         {:ok, patterns_json} <- File.read(Path.join(spr_dir, "patterns.json")),
         modules = Jason.decode!(modules_json),
         deps = Jason.decode!(deps_json),
         patterns = Jason.decode!(patterns_json),
         # Apply migration to support old SPR formats
         {:ok, migrated_modules} <- OptimalSystemAgent.Sensors.SPRMigration.migrate(modules),
         {:ok, migrated_deps} <- OptimalSystemAgent.Sensors.SPRMigration.migrate(deps),
         {:ok, migrated_patterns} <- OptimalSystemAgent.Sensors.SPRMigration.migrate(patterns),
         ttl_content = generate_ttl(migrated_modules, migrated_deps, migrated_patterns, base_uri),
         :ok <- File.write(output_file, ttl_content) do

      triple_count = count_triples(ttl_content)

      file_size = case File.stat(output_file) do
        {:ok, stat} -> stat.size
        {:error, _} -> 0
      end

      metadata = %{
        file: output_file,
        triple_count: triple_count,
        size: file_size,
        base_uri: base_uri,
        generated_at: System.system_time(:millisecond)
      }

      {:ok, metadata}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  end

  @doc """
  Count triples in Turtle content.
  """
  def count_triples(ttl_content) do
    # Simple heuristic: count lines ending with .
    ttl_content
    |> String.split("\n")
    |> Enum.count(fn line ->
      line = String.trim(line)
      # Count triples (lines ending with . that aren't prefixes/comments)
      String.ends_with?(line, ".") &&
        !String.starts_with?(line, "@prefix") &&
        !String.starts_with?(line, "#") &&
        line != "."
    end)
  end

  # Private Functions

  defp generate_ttl(modules, deps, patterns, base_uri) do
    # Signal Theory S=(M,G,T,F,W) encoding for the RDF output
    ~s"""
    # Fortune 5 Workspace RDF
    # Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    # Signal Theory: S=(data,report,inform,turtle,rdf-graph)

    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>.
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
    @prefix owl: <http://www.w3.org/2002/07/owl#>.
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#>.
    @prefix osa: <#{base_uri}>.
    @prefix module: <#{base_uri}module/>.
    @prefix dep: <#{base_uri}dep/>.
    @prefix pattern: <#{base_uri}pattern/>.

    # Workspace metadata
    osa:workspace a owl:Ontology ;
        rdfs:label "Fortune 5 Workspace" ;
        rdfs:comment "SPR sensor outputs converted to RDF" ;
        osa:generatedAt "#{DateTime.utc_now() |> DateTime.to_iso8601()}"^^xsd:dateTime ;
        osa:totalModules #{modules["total_modules"]} ;
        osa:totalDeps #{deps["total_deps"]} ;
        osa:totalPatterns #{patterns["total_patterns"]} .

    #{generate_modules_ttl(modules["modules"], base_uri)}
    #{generate_deps_ttl(deps["dependencies"], base_uri)}
    #{generate_patterns_ttl(patterns["patterns"], base_uri)}
    """
  end

  defp generate_modules_ttl(modules, _base_uri) when is_list(modules) do
    modules
    |> Enum.map(fn module ->
      name = Map.get(module, "name", "Unknown")
      file = Map.get(module, "file", "")
      type = Map.get(module, "type", "module")
      line = Map.get(module, "line", 0)

      ~s"""
      module:#{escape_name(name)} a osa:Module ;
          rdfs:label "#{name}" ;
          osa:type "#{type}" ;
          osa:file "#{file}" ;
          osa:line #{line} .
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_modules_ttl(_, _), do: ""

  defp generate_deps_ttl(deps, _base_uri) when is_list(deps) do
    deps
    |> Enum.with_index()
    |> Enum.map(fn {dep, index} ->
      from = Map.get(dep, "from", "")
      to = Map.get(dep, "to", "")
      type = Map.get(dep, "type", "use")

      ~s"""
      dep:dep#{index} a osa:Dependency ;
          osa:from "#{from}" ;
          osa:to "#{to}" ;
          osa:type "#{type}" .
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_deps_ttl(_, _), do: ""

  defp generate_patterns_ttl(patterns, _base_uri) when is_list(patterns) do
    patterns
    |> Enum.with_index()
    |> Enum.map(fn {pattern, index} ->
      name = Map.get(pattern, "name", "Unknown")
      category = Map.get(pattern, "category", "")
      file = Map.get(pattern, "file", "")

      ~s"""
      pattern:pattern#{index} a osa:Pattern ;
          rdfs:label "#{name}" ;
          osa:category "#{category}" ;
          osa:file "#{file}" .
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_patterns_ttl(_, _), do: ""

  # Escape module names for use in URIs
  defp escape_name(name) do
    name
    |> String.replace("Elixir.", "")
    |> String.replace(".", "_")
    |> String.downcase()
  end
end
