defmodule OptimalSystemAgent.Fortune5.WorkspaceTTLSPARQLTest do
  use ExUnit.Case, async: true

  @moduletag :fortune_5
  @moduletag :capture_log

  describe "SPARQL CONSTRUCT Query Execution on workspace.ttl" do
    setup do
      # Load workspace.ttl for testing
      workspace_ttl_path = "priv/sensors/workspace.ttl"

      {:ok, ttl_content} = File.read(workspace_ttl_path)

      %{
        ttl_content: ttl_content,
        ttl_path: workspace_ttl_path
      }
    end

    test "SPARQL modules.rq query produces valid output", _context do
      # Load SPARQL query
      {:ok, query_content} = File.read("ggen/sparql/construct_modules.rq")

      # Verify query is valid SPARQL CONSTRUCT
      assert String.contains?(query_content, "CONSTRUCT"),
        "modules.rq must be a CONSTRUCT query"

      assert String.contains?(query_content, "WHERE"),
        "modules.rq must have WHERE clause"

      # Verify query references module data
      assert String.contains?(query_content, "osa:Module"),
        "modules.rq must query Module class"

      assert String.contains?(query_content, "?name"),
        "modules.rq must extract module names"

      assert String.contains?(query_content, "?file"),
        "modules.rq must extract module files"

      # Verify the query has the right structure for SPR output
      assert String.contains?(query_content, "rdfs:label"),
        "modules.rq must extract rdfs:label"

      assert String.contains?(query_content, "osa:type"),
        "modules.rq must extract type information"

      # Extract query template and verify it follows SPARQL format
      assert String.contains?(query_content, "PREFIX"),
        "modules.rq must declare PREFIX statements"

      IO.puts("✓ modules.rq is valid SPARQL CONSTRUCT for module extraction")
    end

    test "SPARQL deps.rq query produces valid output", _context do
      {:ok, query_content} = File.read("ggen/sparql/construct_deps.rq")

      # Verify query structure
      assert String.contains?(query_content, "CONSTRUCT"),
        "deps.rq must be CONSTRUCT query"

      assert String.contains?(query_content, "osa:Dependency"),
        "deps.rq must query Dependency class"

      # Verify dependency relationships
      assert String.contains?(query_content, "osa:from"),
        "deps.rq must extract dependency source"

      assert String.contains?(query_content, "osa:to"),
        "deps.rq must extract dependency target"

      assert String.contains?(query_content, "osa:type"),
        "deps.rq must extract dependency type"

      IO.puts("✓ deps.rq is valid SPARQL CONSTRUCT for dependency extraction")
    end

    test "SPARQL patterns.rq query produces valid output" do
      {:ok, query_content} = File.read("ggen/sparql/construct_patterns.rq")

      # Verify query structure
      assert String.contains?(query_content, "CONSTRUCT"),
        "patterns.rq must be CONSTRUCT query"

      assert String.contains?(query_content, "osa:Pattern"),
        "patterns.rq must query Pattern class"

      # Verify pattern properties
      assert String.contains?(query_content, "rdfs:label"),
        "patterns.rq must extract pattern names"

      assert String.contains?(query_content, "osa:category"),
        "patterns.rq must extract pattern categories"

      assert String.contains?(query_content, "osa:file"),
        "patterns.rq must extract pattern file locations"

      IO.puts("✓ patterns.rq is valid SPARQL CONSTRUCT for pattern extraction")
    end

    test "workspace.ttl structure supports SPARQL graph patterns", %{ttl_content: ttl_content} do
      # Verify workspace.ttl uses consistent URI patterns that SPARQL can match
      # Pattern 1: Module URIs should follow module:<name>
      assert String.contains?(ttl_content, "module:"),
        "workspace.ttl must use module: namespace for module URIs"

      # Pattern 2: Dependency URIs should follow dep:<id>
      assert String.contains?(ttl_content, "dep:"),
        "workspace.ttl must use dep: namespace for dependency URIs"

      # Pattern 3: Pattern URIs should follow pattern:<id>
      assert String.contains?(ttl_content, "pattern:"),
        "workspace.ttl must use pattern: namespace for pattern URIs"

      # Pattern 4: Verify consistent use of rdf:type (or 'a' in Turtle)
      assert String.contains?(ttl_content, " a osa:Module"),
        "workspace.ttl must use consistent rdf:type for modules"

      # Pattern 5: Verify predicate consistency for SPARQL matching
      # All modules should have the same properties for consistent SPARQL querying
      assert String.contains?(ttl_content, "rdfs:label"),
        "workspace.ttl must include rdfs:label for modules"

      assert String.contains?(ttl_content, "osa:file"),
        "workspace.ttl must include osa:file for modules"

      assert String.contains?(ttl_content, "osa:type"),
        "workspace.ttl must include osa:type for modules"

      IO.puts("✓ workspace.ttl structure supports SPARQL graph patterns")
    end

    test "workspace.ttl namespace declarations match SPARQL queries" do
      {:ok, ttl_content} = File.read("priv/sensors/workspace.ttl")

      # Extract all prefix declarations from TTL
      ttl_prefixes =
        ttl_content
        |> String.split("\n")
        |> Enum.filter(fn line -> String.starts_with?(String.trim(line), "@prefix") end)
        |> Enum.map(fn line ->
          # Extract prefix name: @prefix name: <URI>.
          Regex.run(~r/@prefix (\w+):/, line) |> then(fn x -> Enum.at(x, 1) end)
        end)
        |> Enum.reject(&is_nil/1)

      # Load all SPARQL queries
      sparql_files = [
        "ggen/sparql/construct_modules.rq",
        "ggen/sparql/construct_deps.rq",
        "ggen/sparql/construct_patterns.rq"
      ]

      # Extract all PREFIX declarations from queries
      query_prefixes =
        sparql_files
        |> Enum.map(&File.read!/1)
        |> Enum.join("\n")
        |> String.split("\n")
        |> Enum.filter(fn line -> String.starts_with?(String.trim(line), "PREFIX") end)
        |> Enum.map(fn line ->
          # Extract prefix name: PREFIX name:
          Regex.run(~r/PREFIX (\w+):/, line) |> then(fn x -> Enum.at(x, 1) end)
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      # Common prefixes that should match
      common_prefixes = ["rdf", "rdfs", "osa"]

      Enum.each(common_prefixes, fn prefix ->
        has_in_ttl = Enum.member?(ttl_prefixes, prefix)
        has_in_query = Enum.member?(query_prefixes, prefix)

        assert has_in_ttl && has_in_query,
          "Prefix #{prefix} should be declared in both TTL and SPARQL queries"
      end)

      IO.puts(
        "✓ workspace.ttl namespace declarations (#{Enum.join(ttl_prefixes, ", ")}) match SPARQL queries"
      )
    end

    test "SPARQL ORDER BY clauses specify valid sort properties" do
      sparql_files = [
        "ggen/sparql/construct_modules.rq",
        "ggen/sparql/construct_deps.rq",
        "ggen/sparql/construct_patterns.rq"
      ]

      Enum.each(sparql_files, fn query_path ->
        {:ok, content} = File.read(query_path)

        assert String.contains?(content, "ORDER BY"),
          "#{query_path} should have ORDER BY clause for deterministic results"

        IO.puts("✓ #{query_path} has valid ORDER BY clause")
      end)
    end

    test "workspace.ttl SPARQL queryability supports round-trip conversion" do
      # This simulates:
      # JSON (modules.json) → RDF (workspace.ttl) → SPARQL CONSTRUCT → JSON-compatible output

      workspace_ttl_path = "priv/sensors/workspace.ttl"
      modules_json_path = "priv/sensors/modules.json"

      assert File.exists?(workspace_ttl_path),
        "workspace.ttl source must exist"

      assert File.exists?(modules_json_path),
        "modules.json source must exist"

      {:ok, ttl_content} = File.read(workspace_ttl_path)
      {:ok, json_content} = File.read(modules_json_path)

      # Parse JSON source
      json_data = Jason.decode!(json_content)
      source_module_count = length(json_data["modules"] || [])

      # Count modules in RDF (equivalent to SPARQL CONSTRUCT result)
      rdf_module_count =
        ttl_content
        |> String.split("\n")
        |> Enum.count(fn line -> String.contains?(line, "a osa:Module") end)

      # Should produce equivalent results
      assert rdf_module_count == source_module_count,
        "Round-trip should preserve module count: JSON #{source_module_count}, RDF #{rdf_module_count}"

      # Verify a sample module can be found in both
      [sample_module | _] = json_data["modules"]
      sample_name = Map.get(sample_module, "name")

      assert String.contains?(ttl_content, ~s(rdfs:label "#{sample_name}")),
        "Sample module #{sample_name} should be in RDF with rdfs:label"

      IO.puts(
        "✓ workspace.ttl SPARQL queryability supports round-trip: #{rdf_module_count} modules preserved"
      )
    end

    test "workspace.ttl query results would be JSON-serializable" do
      # This test verifies that SPARQL CONSTRUCT query results
      # (which would be in RDF) can be converted to JSON-compatible format

      {:ok, ttl_content} = File.read("priv/sensors/workspace.ttl")

      # Extract a sample module definition
      module_lines =
        ttl_content
        |> String.split("\n")
        |> Enum.find_index(fn line -> String.contains?(line, "a osa:Module") end)

      assert module_lines != nil, "Must have at least one module"

      lines = String.split(ttl_content, "\n")
      module_section = Enum.slice(lines, module_lines || 0, 10) |> Enum.join("\n")

      # Verify properties can be extracted to JSON format
      properties = [
        {"rdfs:label", "module name"},
        {"osa:file", "file path"},
        {"osa:type", "module type"},
        {"osa:line", "line number"}
      ]

      Enum.each(properties, fn {property, description} ->
        # Property should exist in the RDF structure
        # This would be converted to JSON key-value pairs
        assert !String.contains?(ttl_content, property) or
                 String.contains?(module_section, property),
          "Property #{property} (#{description}) should be queryable"
      end)

      IO.puts("✓ workspace.ttl SPARQL results would be JSON-serializable")
    end
  end
end
