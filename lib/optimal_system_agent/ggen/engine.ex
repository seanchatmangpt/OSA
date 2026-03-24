defmodule OptimalSystemAgent.Ggen.Engine do
  @moduledoc """
  Fortune 5 Layer 4: Correlation - Template Generation Engine

  Generates code templates from ODCS workspace definitions using SPARQL CONSTRUCT queries.
  Implements deterministic, variable-substitution-based template rendering.

  Signal Theory: S=(code,spec,inform,elixir,module)
  """

  alias OptimalSystemAgent.Ggen.Registry
  alias OptimalSystemAgent.Ggen.TemplateRenderer
  require Logger

  @doc """
  Generate a template from workspace definition

  ## Parameters
    - template_type: :rust, :typescript, :elixir, etc.
    - variables: map of variable name -> value for substitution
    - options: keyword list with:
      - :output_dir - where to write generated files
      - :dry_run - if true, return content without writing
      - :workspace_rdf - path to workspace.ttl for SPARQL correlation

  ## Returns
    {:ok, %{files: [...], metadata: %{}}}
    {:error, reason}

  ## Examples
      iex> Engine.generate(:rust, %{"crate" => "myapp"}, output_dir: "src")
      {:ok, %{files: ["src/main.rs", "src/lib.rs"], metadata: %{...}}}
  """
  def generate(template_type, variables, options \\ []) do
    with {:ok, template} <- Registry.get_template(template_type),
         :ok <- validate_variables(template, variables),
         {:ok, rendered} <- TemplateRenderer.render(template, variables, options) do
      case write_files(rendered, options) do
        :ok ->
          {:ok, %{
            files: Map.get(rendered, :files, []),
            metadata: Map.get(rendered, :metadata, %{})
          }}

        error ->
          error
      end
    end
  end

  @doc """
  Generate templates from SPARQL CONSTRUCT query results

  Correlates workspace.ttl data using ggen/sparql/*.rq queries to produce
  SPR output (modules.json, deps.json, patterns.json) and then generates
  code artifacts from those specifications.

  ## Parameters
    - workspace_rdf_path: path to workspace.ttl
    - query_path: path to SPARQL query file
    - template_type: :rust, :typescript, etc.
    - options: keyword list

  ## Returns
    {:ok, %{files: [...], spr_output: %{...}, metadata: %{...}}}
    {:error, reason}
  """
  def generate_from_sparql(workspace_rdf_path, query_path, template_type, options \\ []) do
    with true <- File.exists?(workspace_rdf_path),
         true <- File.exists?(query_path),
         {:ok, spr_output} <- execute_sparql_construct(workspace_rdf_path, query_path),
         {:ok, variables} <- extract_variables_from_spr(spr_output),
         {:ok, result} <- generate(template_type, variables, options) do
      {:ok, Map.put(result, :spr_output, spr_output)}
    else
      false -> {:error, "workspace.ttl or query file not found"}
      error -> error
    end
  end

  @doc """
  List available template types

  Returns all registered template generators that can be used with generate/3.
  """
  def available_templates do
    Registry.list_templates()
  end

  @doc """
  Get template metadata (required variables, description, etc.)
  """
  def template_info(template_type) do
    Registry.get_template_info(template_type)
  end

  # Private

  defp validate_variables(template, variables) do
    required = Map.get(template, :required_vars, [])

    missing =
      Enum.filter(required, fn var ->
        not Map.has_key?(variables, var)
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required variables: #{Enum.join(missing, ", ")}"}
    end
  end

  defp write_files(rendered, options) do
    if Keyword.get(options, :dry_run, false) do
      :ok
    else
      output_dir = Keyword.get(options, :output_dir, ".")
      File.mkdir_p(output_dir)

      Enum.each(Map.get(rendered, :files, []), fn {path, content} ->
        full_path = Path.join(output_dir, path)
        full_path |> Path.dirname() |> File.mkdir_p()
        File.write(full_path, content)
      end)

      :ok
    end
  end

  defp execute_sparql_construct(workspace_rdf_path, query_path) do
    # This would integrate with an RDF store (Oxigraph via SPARQL)
    # For now, return a placeholder
    query_content = File.read!(query_path)
    Logger.info("Executing SPARQL CONSTRUCT from #{Path.basename(query_path)}")

    {:ok, %{
      type: "sparql_result",
      query: query_content,
      source: workspace_rdf_path
    }}
  end

  defp extract_variables_from_spr(spr_output) do
    # Extract template variables from SPR output
    # (modules.json, deps.json, patterns.json)
    {:ok, Map.get(spr_output, :variables, %{})}
  end
end
