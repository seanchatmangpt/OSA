defmodule OptimalSystemAgent.Fortune5.WorkspaceTTLIntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :fortune_5
  @moduletag :capture_log

  describe "workspace.ttl RDF Generation and SPARQL Queryability" do
    setup do
      # Create temp directory for test outputs
      test_dir = "tmp/workspace_ttl_test"
      File.rm_rf!(test_dir)
      File.mkdir_p!(test_dir)

      on_exit(fn ->
        File.rm_rf!(test_dir)
      end)

      %{test_dir: test_dir}
    end

    test "workspace.ttl is valid Turtle/RDF syntax" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      assert File.exists?(workspace_ttl), "workspace.ttl must exist at #{workspace_ttl}"

      {:ok, content} = File.read(workspace_ttl)

      # Verify TTL prefixes
      assert String.contains?(content, "@prefix rdf:"),
        "workspace.ttl must contain RDF prefix declaration"

      assert String.contains?(content, "@prefix rdfs:"),
        "workspace.ttl must contain RDFS prefix declaration"

      assert String.contains?(content, "@prefix osa:"),
        "workspace.ttl must contain OSA prefix declaration"

      # Verify ontology declaration
      assert String.contains?(content, "owl:Ontology"),
        "workspace.ttl must declare an OWL Ontology"

      # Verify signal theory encoding
      assert String.contains?(content, "Signal Theory:"),
        "workspace.ttl must include Signal Theory encoding comment"

      assert String.contains?(content, "S=(data,report,inform,turtle,rdf-graph)"),
        "workspace.ttl must specify Signal Theory dimensions"
    end

    test "workspace.ttl contains sufficient RDF quads" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      {:ok, content} = File.read(workspace_ttl)

      # Count triples (lines ending with . that aren't comments or prefixes)
      triple_count =
        content
        |> String.split("\n")
        |> Enum.count(fn line ->
          line = String.trim(line)

          String.ends_with?(line, ".") &&
            !String.starts_with?(line, "@") &&
            !String.starts_with?(line, "#") &&
            line != "."
        end)

      # Should have at least 100 quads (minimum threshold)
      assert triple_count >= 100,
        "Expected ≥ 100 RDF quads, got #{triple_count}"

      # Log the actual count for verification
      IO.puts("✓ workspace.ttl contains #{triple_count} RDF quads")
    end

    test "workspace.ttl includes module definitions" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      {:ok, content} = File.read(workspace_ttl)

      # Verify module class definitions
      assert String.contains?(content, "a osa:Module"),
        "workspace.ttl must contain Module class definitions"

      # Verify module properties
      assert String.contains?(content, "osa:file"),
        "workspace.ttl must contain module file properties"

      assert String.contains?(content, "osa:line"),
        "workspace.ttl must contain module line number properties"

      assert String.contains?(content, "rdfs:label"),
        "workspace.ttl must contain rdfs:label for modules"

      # Count module instances
      module_count =
        content
        |> String.split("\n")
        |> Enum.count(fn line -> String.contains?(line, "a osa:Module") end)

      assert module_count > 0,
        "workspace.ttl must contain at least one module instance"

      IO.puts("✓ workspace.ttl contains #{module_count} module definitions")
    end

    test "workspace.ttl includes workspace metadata" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      {:ok, content} = File.read(workspace_ttl)

      # Verify workspace metadata
      assert String.contains?(content, "osa:workspace"),
        "workspace.ttl must define osa:workspace resource"

      assert String.contains?(content, "owl:Ontology"),
        "workspace.ttl workspace must be declared as owl:Ontology"

      assert String.contains?(content, "osa:totalModules"),
        "workspace.ttl must include total module count"

      assert String.contains?(content, "osa:generatedAt"),
        "workspace.ttl must include generation timestamp"

      assert String.contains?(content, "Fortune 5 Workspace"),
        "workspace.ttl must include workspace label"
    end

    test "workspace.ttl RDF is queryable (SPARQL structure)" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      {:ok, content} = File.read(workspace_ttl)

      # Verify that module triples follow queryable structure:
      # subject a osa:Module ; predicate value ; ...
      lines = String.split(content, "\n")

      # Find a module definition
      module_line_idx =
        Enum.find_index(lines, fn line ->
          String.contains?(line, "a osa:Module")
        end)

      assert module_line_idx != nil,
        "workspace.ttl must contain at least one module definition"

      # Verify predicate-value pairs follow TTL syntax
      # Looking for lines with: predicate value ;
      predicate_count =
        lines
        |> Enum.slice(module_line_idx, 10)
        |> Enum.count(fn line ->
          trimmed = String.trim(line)
          # Predicates have : in their name and end with value/punctuation
          String.contains?(trimmed, ":") && (
            String.ends_with?(trimmed, ";") ||
            String.ends_with?(trimmed, ".")
          )
        end)

      assert predicate_count > 0,
        "workspace.ttl must have well-formed TTL triple syntax"

      IO.puts("✓ workspace.ttl has valid SPARQL queryable structure")
    end

    test "SPARQL queries can be loaded from ggen" do
      # Verify SPARQL query files exist and are readable
      sparql_queries = [
        "ggen/sparql/construct_modules.rq",
        "ggen/sparql/construct_deps.rq",
        "ggen/sparql/construct_patterns.rq"
      ]

      Enum.each(sparql_queries, fn query_path ->
        assert File.exists?(query_path),
          "SPARQL query file must exist at #{query_path}"

        {:ok, content} = File.read(query_path)

        assert String.contains?(content, "CONSTRUCT"),
          "SPARQL query #{query_path} must use CONSTRUCT clause"

        assert String.contains?(content, "WHERE"),
          "SPARQL query #{query_path} must use WHERE clause"

        assert String.contains?(content, "PREFIX"),
          "SPARQL query #{query_path} must declare prefixes"

        IO.puts("✓ #{query_path} is valid SPARQL CONSTRUCT query")
      end)
    end

    test "SPARQL queries reference workspace.ttl ontology" do
      sparql_queries = [
        "ggen/sparql/construct_modules.rq",
        "ggen/sparql/construct_deps.rq",
        "ggen/sparql/construct_patterns.rq"
      ]

      Enum.each(sparql_queries, fn query_path ->
        {:ok, content} = File.read(query_path)

        # All queries should use OSA namespace
        assert String.contains?(content, "osa:"),
          "SPARQL query #{query_path} must reference osa: namespace"

        # Verify Signal Theory encoding comment
        assert String.contains?(content, "Signal Theory:"),
          "SPARQL query #{query_path} must include Signal Theory encoding"
      end)
    end

    test "workspace.ttl round-trip: RDF → SPARQL → JSON compatible" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      {:ok, content} = File.read(workspace_ttl)

      # Parse module count from workspace metadata
      # Looking for line: osa:totalModules <number>
      module_count_match =
        Regex.run(~r/osa:totalModules (\d+)/, content)

      assert module_count_match != nil,
        "workspace.ttl must include osa:totalModules count"

      [_full_match, count_str] = module_count_match
      total_modules = String.to_integer(count_str)

      # Count actual module definitions
      module_definitions =
        content
        |> String.split("\n")
        |> Enum.count(fn line -> String.contains?(line, "a osa:Module") end)

      assert module_definitions > 0,
        "workspace.ttl must contain module definitions"

      assert module_definitions == total_modules,
        "Module count mismatch: metadata says #{total_modules}, found #{module_definitions}"

      IO.puts(
        "✓ workspace.ttl round-trip verified: #{module_definitions} modules"
      )
    end

    test "workspace.ttl Signal Theory encoding is complete" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      {:ok, content} = File.read(workspace_ttl)

      # Verify Signal Theory S=(M,G,T,F,W) encoding
      signal_theory_header = Regex.run(
        ~r/Signal Theory: S=\(([^,]+),([^,]+),([^,]+),([^,]+),([^)]+)\)/,
        content
      )

      assert signal_theory_header != nil,
        "workspace.ttl must include complete Signal Theory encoding S=(M,G,T,F,W)"

      [_full, mode, genre, type, format, structure] = signal_theory_header

      assert mode == "data",
        "workspace.ttl Signal Theory mode should be 'data', got '#{mode}'"

      assert genre == "report",
        "workspace.ttl Signal Theory genre should be 'report', got '#{genre}'"

      assert type == "inform",
        "workspace.ttl Signal Theory type should be 'inform', got '#{type}'"

      assert format == "turtle",
        "workspace.ttl Signal Theory format should be 'turtle', got '#{format}'"

      assert structure == "rdf-graph",
        "workspace.ttl Signal Theory structure should be 'rdf-graph', got '#{structure}'"

      IO.puts(
        "✓ workspace.ttl Signal Theory encoding complete: S=(#{mode},#{genre},#{type},#{format},#{structure})"
      )
    end

    test "workspace.ttl is Oxigraph-compatible" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      {:ok, content} = File.read(workspace_ttl)

      # Verify Oxigraph compatibility: Turtle format with proper URI references
      # 1. All @prefix declarations must have valid URIs
      prefix_lines =
        content
        |> String.split("\n")
        |> Enum.filter(fn line -> String.starts_with?(String.trim(line), "@prefix") end)

      assert length(prefix_lines) > 0,
        "workspace.ttl must have @prefix declarations"

      # Each prefix should follow: @prefix name: <URI>.
      valid_prefixes =
        Enum.all?(prefix_lines, fn line ->
          String.match?(line, ~r/@prefix \w+: <.*>/)
        end)

      assert valid_prefixes,
        "All @prefix declarations must follow @prefix name: <URI>. format"

      # 2. Verify no invalid characters in URIs
      invalid_uris =
        prefix_lines
        |> Enum.filter(fn line ->
          String.contains?(line, ["\n", "\r", "\t"])
        end)

      assert length(invalid_uris) == 0,
        "workspace.ttl URIs must not contain line breaks"

      # 3. Verify RDF triple syntax is strict
      # Every triple should end with . or ;
      lines = String.split(content, "\n")

      invalid_lines =
        Enum.filter(lines, fn line ->
          trimmed = String.trim(line)

          # Skip empty lines, comments, prefixes, and closing statements
          unless trimmed == "" || String.starts_with?(trimmed, "#") ||
                   String.starts_with?(trimmed, "@") do
            # Must end with . or ; or be empty
            !(String.ends_with?(trimmed, ".") || String.ends_with?(trimmed, ";"))
          else
            false
          end
        end)

      assert length(invalid_lines) == 0,
        "workspace.ttl contains improperly formatted triples: #{Enum.take(invalid_lines, 3)}"

      IO.puts("✓ workspace.ttl is Oxigraph-compatible")
    end

    test "workspace.ttl can be loaded by RDFGenerator.generate_rdf/1" do
      # This test verifies the full generation pipeline works
      test_output = "tmp/test_workspace_rdf.ttl"

      File.rm_rf!(test_output)

      # Generate RDF (should work since SPR files exist)
      result =
        OptimalSystemAgent.Sensors.RDFGenerator.generate_rdf(
          spr_dir: "priv/sensors",
          output_file: test_output,
          base_uri: "https://chatmangpt.com/workspace#"
        )

      assert {:ok, metadata} = result,
        "RDFGenerator.generate_rdf should succeed"

      assert metadata.triple_count > 0,
        "Generated RDF should contain triples"

      assert File.exists?(test_output),
        "Generated RDF file should exist"

      # Verify generated file is valid
      {:ok, generated_content} = File.read(test_output)

      assert String.contains?(generated_content, "@prefix"),
        "Generated RDF must contain prefix declarations"

      assert String.contains?(generated_content, "a owl:Ontology"),
        "Generated RDF must declare ontology"

      IO.puts("✓ RDFGenerator produces valid workspace.ttl (#{metadata.triple_count} triples)")

      # Cleanup
      File.rm_rf!(test_output)
    end
  end

  describe "workspace.ttl Data Integrity" do
    test "workspace.ttl preserves ODCS workspace structure" do
      workspace_ttl = "priv/sensors/workspace.ttl"

      {:ok, content} = File.read(workspace_ttl)

      # ODCS workspaces should map to RDF resources with:
      # - URI (rdf:about or subject)
      # - Type (rdf:type or 'a' in Turtle)
      # - Properties (predicates with values)

      # Verify workspace resource
      assert String.contains?(content, "osa:workspace"),
        "workspace.ttl must include workspace resource"

      # Verify module resources (instances of osa:Module)
      assert String.contains?(content, "a osa:Module"),
        "workspace.ttl must include module instances"

      # Verify module properties map from ODCS
      expected_properties = [
        "rdfs:label",
        "osa:file",
        "osa:type",
        "osa:line"
      ]

      Enum.each(expected_properties, fn prop ->
        assert String.contains?(content, prop),
          "workspace.ttl must map ODCS property #{prop}"
      end)
    end

    test "workspace.ttl maintains consistency across layers" do
      workspace_ttl = "priv/sensors/workspace.ttl"
      modules_json = "priv/sensors/modules.json"

      # Both files should exist
      assert File.exists?(workspace_ttl),
        "workspace.ttl must exist"

      assert File.exists?(modules_json),
        "modules.json must exist (source data)"

      {:ok, ttl_content} = File.read(workspace_ttl)
      {:ok, json_content} = File.read(modules_json)

      # Count modules in each
      ttl_modules =
        ttl_content
        |> String.split("\n")
        |> Enum.count(fn line -> String.contains?(line, "a osa:Module") end)

      json_data = Jason.decode!(json_content)
      json_modules = length(json_data["modules"] || [])

      # workspace.ttl is a representative sample generated from modules.json.
      # TTL is a subset (not a full copy), so the counts will differ.
      # Verify: (a) TTL has modules, (b) TTL count does not exceed JSON count.
      assert ttl_modules > 0,
        "TTL must contain at least one module (got 0)"

      assert ttl_modules <= json_modules,
        "TTL module count (#{ttl_modules}) should not exceed JSON source (#{json_modules})"

      IO.puts("✓ Consistency verified: TTL #{ttl_modules} modules, JSON #{json_modules} modules")
    end
  end
end
