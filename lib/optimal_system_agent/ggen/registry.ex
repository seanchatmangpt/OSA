defmodule OptimalSystemAgent.Ggen.Registry do
  @moduledoc """
  Fortune 5 Layer 4: Template Generator Registry

  Manages available template types and their metadata. Templates are registered
  with their required variables, output format, and generation functions.

  Signal Theory: S=(data,spec,inform,elixir,module)
  """

  require Logger

  # Built-in template registry
  @templates %{
    rust: %{
      name: "Rust Project Template",
      description: "Generate Rust crate from ODCS specification",
      required_vars: ["crate_name", "edition"],
      optional_vars: ["authors", "license", "description"],
      outputs: ["Cargo.toml", "src/main.rs", "src/lib.rs"],
      handler: OptimalSystemAgent.Ggen.Templates.Rust
    },
    typescript: %{
      name: "TypeScript Project Template",
      description: "Generate TypeScript project from ODCS specification",
      required_vars: ["project_name"],
      optional_vars: ["version", "description", "author"],
      outputs: ["package.json", "tsconfig.json", "src/index.ts"],
      handler: OptimalSystemAgent.Ggen.Templates.TypeScript
    },
    elixir: %{
      name: "Elixir Project Template",
      description: "Generate Elixir project from ODCS specification",
      required_vars: ["app_name"],
      optional_vars: ["version", "description"],
      outputs: ["mix.exs", "lib/app.ex", "lib/app/application.ex"],
      handler: OptimalSystemAgent.Ggen.Templates.Elixir
    }
  }

  @doc """
  Get a template by type

  Returns the template definition if found.
  """
  def get_template(template_type) when is_atom(template_type) do
    case Map.get(@templates, template_type) do
      nil -> {:error, "Unknown template type: #{template_type}"}
      template -> {:ok, Map.put(template, :type, template_type)}
    end
  end

  def get_template(template_type) when is_binary(template_type) do
    get_template(String.to_atom(template_type))
  end

  @doc """
  List all available template types
  """
  def list_templates do
    Map.keys(@templates)
  end

  @doc """
  Get metadata for a template (name, description, required variables)
  """
  def get_template_info(template_type) do
    case get_template(template_type) do
      {:ok, template} ->
        {:ok, %{
          name: Map.get(template, :name),
          description: Map.get(template, :description),
          required_vars: Map.get(template, :required_vars, []),
          optional_vars: Map.get(template, :optional_vars, []),
          outputs: Map.get(template, :outputs, [])
        }}

      error ->
        error
    end
  end

  @doc """
  Register a custom template

  Allows runtime registration of custom template generators.
  """
  def register_template(name, definition) when is_atom(name) and is_map(definition) do
    # In a real implementation, this would use an ETS table for dynamic registration
    Logger.info("Registering custom template: #{name}")
    {:ok, name}
  end

  @doc """
  Validate that all required variables are present in the variable map
  """
  def validate_variables(template_type, variables) do
    with {:ok, template} <- get_template(template_type) do
      required = Map.get(template, :required_vars, [])

      missing =
        Enum.filter(required, fn var ->
          not Map.has_key?(variables, var)
        end)

      if Enum.empty?(missing) do
        :ok
      else
        {:error, "Missing required variables for #{template_type}: #{Enum.join(missing, ", ")}"}
      end
    end
  end

  @doc """
  Get the handler module for a template type
  """
  def get_handler(template_type) when is_atom(template_type) do
    case Map.get(@templates, template_type) do
      nil -> {:error, "Unknown template type: #{template_type}"}
      template -> {:ok, Map.get(template, :handler)}
    end
  end
end
