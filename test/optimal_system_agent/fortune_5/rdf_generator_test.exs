defmodule OptimalSystemAgent.Fortune5.RDFGeneratorTest do
  use ExUnit.Case

  @moduledoc """
  Tests for RDF Generator - Fortune 5 Layer 3: Data Recording

  Following real testing methodology:
    - Step 1: Write failing tests (RDF generation not implemented)
    - Step 2: Verify tests fail
    - Step 3: Implement RDF generation
    - Step 4: Verify all tests pass
  """

  alias OptimalSystemAgent.Sensors.RDFGenerator

  describe "RDF Generation - workspace.ttl" do
    setup do
      # Create test SPR directory
      spr_dir = "tmp/rdf_test"
      File.rm_rf(spr_dir)
      File.mkdir_p!(spr_dir)

      # Create test SPR files
      modules = %{
        "version" => "2.0",
        "scan_type" => "modules",
        "timestamp" => System.system_time(:millisecond),
        "total_modules" => 2,
        "modules" => [
          %{"name" => "Elixir.MyModule", "file" => "lib/my_module.ex", "type" => "module", "line" => 1},
          %{"name" => "Elixir.Agent", "file" => "lib/agent.ex", "type" => "agent", "line" => 10}
        ]
      }

      deps = %{
        "version" => "2.0",
        "scan_type" => "dependencies",
        "timestamp" => System.system_time(:millisecond),
        "total_deps" => 1,
        "dependencies" => [
          %{"from" => "Elixir.MyModule", "to" => "Elixir.Agent", "type" => "use"}
        ]
      }

      patterns = %{
        "version" => "2.0",
        "scan_type" => "patterns",
        "timestamp" => System.system_time(:millisecond),
        "total_patterns" => 1,
        "patterns" => [
          %{"name" => "Sequence", "category" => "control-flow", "file" => "lib/workflow.ex"}
        ]
      }

      File.write!(Path.join(spr_dir, "modules.json"), Jason.encode!(modules))
      File.write!(Path.join(spr_dir, "deps.json"), Jason.encode!(deps))
      File.write!(Path.join(spr_dir, "patterns.json"), Jason.encode!(patterns))

      on_exit(fn -> File.rm_rf(spr_dir) end)

      %{spr_dir: spr_dir}
    end

    test "workspace.ttl RDF file is generated", %{spr_dir: spr_dir} do
      output_file = "tmp/rdf_test/workspace.ttl"

      result = RDFGenerator.generate_rdf(
        spr_dir: spr_dir,
        output_file: output_file
      )

      assert match?({:ok, %{file: ^output_file, triple_count: _count}}, result)
      assert File.exists?(output_file)

      # Verify file has content
      content = File.read!(output_file)
      assert String.contains?(content, "@prefix")
      assert String.contains?(content, "osa:workspace")
    end

    test "workspace.ttl contains module triples", %{spr_dir: spr_dir} do
      output_file = "tmp/rdf_test/workspace.ttl"

      {:ok, _} = RDFGenerator.generate_rdf(
        spr_dir: spr_dir,
        output_file: output_file
      )

      content = File.read!(output_file)

      # Check for module triples
      # Note: Module names are escaped (Elixir. prefix removed, converted to lowercase)
      assert String.contains?(content, "module:mymodule")
      assert String.contains?(content, "rdfs:label \"Elixir.MyModule\"")
      assert String.contains?(content, "osa:file \"lib/my_module.ex\"")
    end

    test "workspace.ttl contains dependency triples", %{spr_dir: spr_dir} do
      output_file = "tmp/rdf_test/workspace.ttl"

      {:ok, _} = RDFGenerator.generate_rdf(
        spr_dir: spr_dir,
        output_file: output_file
      )

      content = File.read!(output_file)

      # Check for dependency triples
      assert String.contains?(content, "dep:dep0")
      assert String.contains?(content, "osa:from \"Elixir.MyModule\"")
      assert String.contains?(content, "osa:to \"Elixir.Agent\"")
    end

    test "workspace.ttl contains pattern triples", %{spr_dir: spr_dir} do
      output_file = "tmp/rdf_test/workspace.ttl"

      {:ok, _} = RDFGenerator.generate_rdf(
        spr_dir: spr_dir,
        output_file: output_file
      )

      content = File.read!(output_file)

      # Check for pattern triples
      assert String.contains?(content, "pattern:pattern0")
      assert String.contains?(content, "rdfs:label \"Sequence\"")
      assert String.contains?(content, "osa:category \"control-flow\"")
    end

    test "workspace.ttl has valid Turtle syntax", %{spr_dir: spr_dir} do
      output_file = "tmp/rdf_test/workspace.ttl"

      {:ok, _} = RDFGenerator.generate_rdf(
        spr_dir: spr_dir,
        output_file: output_file
      )

      content = File.read!(output_file)

      # Basic syntax checks
      assert String.contains?(content, "@prefix rdf:")
      assert String.contains?(content, "@prefix rdfs:")
      assert String.contains?(content, "@prefix osa:")

      # Check for proper triple structure
      assert String.match?(content, ~r/a [a-z]+:/)
    end

    test "RDF generation returns metadata", %{spr_dir: spr_dir} do
      output_file = "tmp/rdf_test/workspace.ttl"

      result = RDFGenerator.generate_rdf(
        spr_dir: spr_dir,
        output_file: output_file
      )

      assert match?({:ok, %{file: _, triple_count: _, size: _, base_uri: _}}, result)
    end
  end
end
