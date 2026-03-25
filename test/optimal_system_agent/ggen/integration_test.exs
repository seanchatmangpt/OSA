defmodule OptimalSystemAgent.Ggen.IntegrationTest do
  use ExUnit.Case

  alias OptimalSystemAgent.Ggen.Engine
  require Logger

  @moduletag :ggen_integration

  setup do
    output_dir = "tmp/ggen_integration"
    File.rm_rf!(output_dir)
    File.mkdir_p!(output_dir)
    %{output_dir: output_dir}
  end

  describe "Ggen Integration - Template Generation from SPARQL" do
    test "SPARQL queries are available in ggen directory" do
      ggen_dir = Path.join(File.cwd!(), "ggen")
      sparql_dir = Path.join(ggen_dir, "sparql")

      assert File.dir?(ggen_dir),
        "ggen directory should exist at project root"

      assert File.dir?(sparql_dir),
        "ggen/sparql directory should exist"

      # Count SPARQL files
      sparql_files = Path.wildcard(Path.join(sparql_dir, "*.rq"))
      assert length(sparql_files) >= 3,
        "ggen/sparql should contain at least 3 SPARQL query files"

      # Check for CONSTRUCT queries
      construct_files = Enum.filter(sparql_files, fn file ->
        content = File.read!(file)
        String.contains?(content, "CONSTRUCT")
      end)

      assert length(construct_files) >= 1,
        "ggen/sparql should contain at least one CONSTRUCT query"
    end

    test "ggen/sparql/construct_modules.rq exists and is valid", %{output_dir: output_dir} do
      query_path = Path.join(File.cwd!(), "ggen/sparql/construct_modules.rq")
      assert File.exists?(query_path)

      content = File.read!(query_path)
      assert String.contains?(content, "CONSTRUCT")
      assert String.contains?(content, "Module")
      assert String.contains?(content, "WHERE")
    end

    test "ggen/sparql/construct_deps.rq exists and is valid", %{output_dir: output_dir} do
      query_path = Path.join(File.cwd!(), "ggen/sparql/construct_deps.rq")
      assert File.exists?(query_path)

      content = File.read!(query_path)
      assert String.contains?(content, "CONSTRUCT")
      assert String.contains?(content, "Dependency")
      assert String.contains?(content, "WHERE")
    end

    test "ggen/sparql/construct_patterns.rq exists and is valid", %{output_dir: output_dir} do
      query_path = Path.join(File.cwd!(), "ggen/sparql/construct_patterns.rq")
      assert File.exists?(query_path)

      content = File.read!(query_path)
      assert String.contains?(content, "CONSTRUCT")
      assert String.contains?(content, "Pattern")
      assert String.contains?(content, "WHERE")
    end

    test "README.md in ggen directory exists and documents the feature" do
      readme_path = Path.join(File.cwd!(), "ggen/README.md")
      assert File.exists?(readme_path)

      content = File.read!(readme_path)
      assert String.contains?(content, "SPARQL") or String.contains?(content, "CONSTRUCT")
      assert String.contains?(content, "Fortune 5") or String.contains?(content, "template")
    end
  end

  describe "Template Type Support - Rust Templates" do
    test "Generates valid Rust Cargo.toml structure", %{output_dir: output_dir} do
      variables = %{
        "crate_name" => "integration_test",
        "edition" => "2021",
        "authors" => ["Test Author <test@example.com>"],
        "license" => "MIT",
        "description" => "Integration test crate"
      }

      {:ok, _result} = Engine.generate(:rust, variables, output_dir: output_dir)

      cargo_path = Path.join(output_dir, "Cargo.toml")
      assert File.exists?(cargo_path)

      content = File.read!(cargo_path)
      assert String.contains?(content, "[package]")
      assert String.contains?(content, "integration_test")
      assert String.contains?(content, "2021")
    end

    test "Generates complete Rust project structure", %{output_dir: output_dir} do
      variables = %{"crate_name" => "mylib", "edition" => "2021"}

      {:ok, result} = Engine.generate(:rust, variables, output_dir: output_dir)

      # Verify all expected files
      paths = Enum.map(result.files, fn {path, _} -> path end)

      assert Enum.any?(paths, &String.contains?(&1, "Cargo.toml"))
      assert Enum.any?(paths, &String.contains?(&1, "src/lib.rs"))
      assert Enum.any?(paths, &String.contains?(&1, "src/main.rs"))
    end

    test "Rust crate name validation works" do
      # Invalid: uppercase
      variables = %{"crate_name" => "MyApp", "edition" => "2021"}

      result = Engine.generate(:rust, variables, output_dir: "tmp/test")
      assert {:error, _} = result
    end
  end

  describe "Template Type Support - TypeScript Templates" do
    test "Generates valid package.json", %{output_dir: output_dir} do
      variables = %{"project_name" => "my_typescript_app"}

      {:ok, _result} = Engine.generate(:typescript, variables, output_dir: output_dir)

      package_path = Path.join(output_dir, "package.json")
      assert File.exists?(package_path)

      content = File.read!(package_path)
      {:ok, json} = Jason.decode(content)

      assert json["name"] == "my_typescript_app"
      assert Map.has_key?(json, "scripts")
      assert Map.has_key?(json, "devDependencies")
    end

    test "Generates complete TypeScript project structure", %{output_dir: output_dir} do
      variables = %{"project_name" => "ts_app"}

      {:ok, result} = Engine.generate(:typescript, variables, output_dir: output_dir)

      paths = Enum.map(result.files, fn {path, _} -> path end)

      assert Enum.any?(paths, &String.contains?(&1, "package.json"))
      assert Enum.any?(paths, &String.contains?(&1, "tsconfig.json"))
      assert Enum.any?(paths, &String.contains?(&1, "src/"))
    end
  end

  describe "Template Type Support - Elixir Templates" do
    test "Generates valid mix.exs", %{output_dir: output_dir} do
      variables = %{"app_name" => "MyElixirApp"}

      {:ok, _result} = Engine.generate(:elixir, variables, output_dir: output_dir)

      mix_path = Path.join(output_dir, "mix.exs")
      assert File.exists?(mix_path)

      content = File.read!(mix_path)
      assert String.contains?(content, "defmodule MyElixirApp.MixProject")
      assert String.contains?(content, "def project do")
    end

    test "Generates complete Elixir project structure", %{output_dir: output_dir} do
      variables = %{"app_name" => "ElixirApp"}

      {:ok, result} = Engine.generate(:elixir, variables, output_dir: output_dir)

      paths = Enum.map(result.files, fn {path, _} -> path end)

      assert Enum.any?(paths, &String.contains?(&1, "mix.exs"))
      assert Enum.any?(paths, &String.contains?(&1, "lib/elixir_app.ex"))
      assert Enum.any?(paths, &String.contains?(&1, "application.ex"))
    end
  end

  describe "Cross-Template Features" do
    test "All template types support optional variables", %{output_dir: output_dir} do
      # Rust with optional variables
      rust_vars = %{
        "crate_name" => "mylib",
        "edition" => "2021",
        "authors" => ["John <john@example.com>"],
        "license" => "Apache-2.0",
        "description" => "A test library"
      }

      {:ok, result} = Engine.generate(:rust, rust_vars, output_dir: output_dir)
      assert Map.has_key?(result, :files)
      assert Map.has_key?(result, :metadata)
    end

    test "Metadata includes template type and variable info", %{output_dir: output_dir} do
      variables = %{"crate_name" => "test_crate", "edition" => "2021"}

      {:ok, result} = Engine.generate(:rust, variables, output_dir: output_dir)

      assert result.metadata.template_type == :rust
      assert is_list(result.metadata.variables_used)
      assert "crate_name" in result.metadata.variables_used
      assert result.metadata.file_count > 0
    end
  end

  describe "Error Handling and Edge Cases" do
    test "Proper error on missing required variables" do
      {:error, msg} = Engine.generate(:rust, %{})

      assert String.contains?(msg, "Missing required variables") or
             String.contains?(msg, "crate_name")
    end

    test "Proper error on invalid template type" do
      {:error, msg} = Engine.generate(:nonexistent, %{})

      assert String.contains?(msg, "Unknown template type")
    end

    test "Template info lookup works for all types" do
      for template_type <- [:rust, :typescript, :elixir] do
        {:ok, info} = Engine.template_info(template_type)

        assert Map.has_key?(info, :name)
        assert Map.has_key?(info, :required_vars)
        assert is_list(info.required_vars)
        assert length(info.required_vars) > 0
      end
    end
  end
end
