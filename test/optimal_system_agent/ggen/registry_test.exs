defmodule OptimalSystemAgent.Ggen.RegistryTest do
  use ExUnit.Case

  alias OptimalSystemAgent.Ggen.Registry

  describe "Registry.get_template/1" do
    test "returns Rust template" do
      {:ok, template} = Registry.get_template(:rust)

      assert Map.has_key?(template, :name)
      assert Map.has_key?(template, :description)
      assert Map.has_key?(template, :required_vars)
      assert template.type == :rust
    end

    test "returns TypeScript template" do
      {:ok, template} = Registry.get_template(:typescript)

      assert Map.has_key?(template, :name)
      assert template.type == :typescript
    end

    test "returns Elixir template" do
      {:ok, template} = Registry.get_template(:elixir)

      assert Map.has_key?(template, :name)
      assert template.type == :elixir
    end

    test "returns error for unknown template" do
      {:error, message} = Registry.get_template(:unknown)

      assert String.contains?(message, "Unknown template type")
    end

    test "accepts string template types" do
      {:ok, template} = Registry.get_template("rust")

      assert template.type == :rust
    end
  end

  describe "Registry.list_templates/0" do
    test "returns list of all available templates" do
      templates = Registry.list_templates()

      assert is_list(templates)
      assert :rust in templates
      assert :typescript in templates
      assert :elixir in templates
      assert length(templates) >= 3
    end
  end

  describe "Registry.get_template_info/1" do
    test "returns metadata for Rust template" do
      {:ok, info} = Registry.get_template_info(:rust)

      assert info.name == "Rust Project Template"
      assert is_list(info.required_vars)
      assert is_list(info.optional_vars)
      assert "crate_name" in info.required_vars
      assert "edition" in info.required_vars
    end

    test "returns metadata for TypeScript template" do
      {:ok, info} = Registry.get_template_info(:typescript)

      assert info.name == "TypeScript Project Template"
      assert "project_name" in info.required_vars
    end

    test "returns metadata for Elixir template" do
      {:ok, info} = Registry.get_template_info(:elixir)

      assert info.name == "Elixir Project Template"
      assert "app_name" in info.required_vars
    end

    test "returns error for unknown template" do
      {:error, _message} = Registry.get_template_info(:unknown)

      assert true
    end
  end

  describe "Registry.validate_variables/2" do
    test "validates Rust template variables" do
      variables = %{"crate_name" => "my_app", "edition" => "2021"}

      :ok = Registry.validate_variables(:rust, variables)
    end

    test "returns error for missing required Rust variables" do
      variables = %{}

      {:error, message} = Registry.validate_variables(:rust, variables)

      assert String.contains?(message, "Missing required variables")
    end

    test "returns error for partially missing Rust variables" do
      variables = %{"crate_name" => "my_app"}

      {:error, message} = Registry.validate_variables(:rust, variables)

      assert String.contains?(message, "Missing required variables")
    end

    test "validates TypeScript template variables" do
      variables = %{"project_name" => "my_app"}

      :ok = Registry.validate_variables(:typescript, variables)
    end

    test "validates Elixir template variables" do
      variables = %{"app_name" => "MyApp"}

      :ok = Registry.validate_variables(:elixir, variables)
    end

    test "allows extra variables" do
      variables = %{
        "crate_name" => "my_app",
        "edition" => "2021",
        "extra_field" => "ignored"
      }

      :ok = Registry.validate_variables(:rust, variables)
    end
  end

  describe "Registry.get_handler/1" do
    test "returns Rust handler module" do
      {:ok, handler} = Registry.get_handler(:rust)

      assert handler == OptimalSystemAgent.Ggen.Templates.Rust
    end

    test "returns TypeScript handler module" do
      {:ok, handler} = Registry.get_handler(:typescript)

      assert handler == OptimalSystemAgent.Ggen.Templates.TypeScript
    end

    test "returns Elixir handler module" do
      {:ok, handler} = Registry.get_handler(:elixir)

      assert handler == OptimalSystemAgent.Ggen.Templates.Elixir
    end

    test "returns error for unknown template" do
      {:error, _message} = Registry.get_handler(:unknown)

      assert true
    end
  end

  describe "Registry.register_template/2" do
    test "allows registering custom templates" do
      definition = %{
        name: "Custom Template",
        description: "A custom template",
        required_vars: ["var1"],
        optional_vars: ["var2"],
        outputs: ["output.txt"],
        handler: CustomHandler
      }

      {:ok, name} = Registry.register_template(:custom, definition)

      assert name == :custom
    end
  end

  describe "Template requirements" do
    test "Rust template has required variables" do
      {:ok, template} = Registry.get_template(:rust)

      required = template.required_vars
      assert is_list(required)
      assert length(required) > 0
      assert "crate_name" in required
    end

    test "Rust template specifies output files" do
      {:ok, template} = Registry.get_template(:rust)

      outputs = template.outputs
      assert is_list(outputs)
      assert length(outputs) > 0
    end

    test "TypeScript template has required variables" do
      {:ok, template} = Registry.get_template(:typescript)

      required = template.required_vars
      assert "project_name" in required
    end

    test "Elixir template has required variables" do
      {:ok, template} = Registry.get_template(:elixir)

      required = template.required_vars
      assert "app_name" in required
    end
  end

  describe "Template handler functions" do
    test "Rust handler is defined" do
      assert Keyword.has_key?(OptimalSystemAgent.Ggen.Templates.Rust.__info__(:functions), :render)
    end

    test "TypeScript handler is defined" do
      assert Keyword.has_key?(OptimalSystemAgent.Ggen.Templates.TypeScript.__info__(:functions), :render)
    end

    test "Elixir handler is defined" do
      assert Keyword.has_key?(OptimalSystemAgent.Ggen.Templates.Elixir.__info__(:functions), :render)
    end
  end
end
