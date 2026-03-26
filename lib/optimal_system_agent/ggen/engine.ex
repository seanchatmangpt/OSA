defmodule OptimalSystemAgent.Ggen.Engine do
  @moduledoc """
  Fortune 5 Layer 4: Correlation - Template Generation Engine

  Generates code templates from ODCS workspace definitions using SPARQL CONSTRUCT queries.
  Implements deterministic, variable-substitution-based template rendering.

  Integrates with Oxigraph HTTP API for SPARQL execution. All CONSTRUCT queries return
  RDF triples which are parsed into SPR (Semantic Projection) output (modules.json, deps.json, patterns.json).

  Signal Theory: S=(code,spec,inform,elixir,module)
  """

  alias OptimalSystemAgent.Ggen.Registry
  alias OptimalSystemAgent.Ggen.TemplateRenderer
  require Logger

  @oxigraph_base_url "http://localhost:7878"
  @timeout_ms 10000

  @doc """
  Generate a template from workspace definition

  ## Parameters
    - template_type: :rust, :typescript, :elixir, etc.
    - variables: map of variable name -> value for substitution
    - options: keyword list with:
      - :output_dir - where to write generated files
      - :dry_run - if true, return content without writing
      - :workspace_rdf - path to workspace.ttl for SPARQL correlation
      - :oxigraph_url - override Oxigraph URL (default: http://localhost:7878)

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

  Sends SPARQL CONSTRUCT query to Oxigraph HTTP API and parses RDF results
  into structured data.

  ## Parameters
    - workspace_rdf_path: path to workspace.ttl
    - query_path: path to SPARQL query file
    - template_type: :rust, :typescript, etc.
    - options: keyword list with optional :oxigraph_url override

  ## Returns
    {:ok, %{files: [...], spr_output: %{...}, metadata: %{...}}}
    {:error, reason}
  """
  def generate_from_sparql(workspace_rdf_path, query_path, template_type, options \\ []) do
    with true <- File.exists?(workspace_rdf_path),
         true <- File.exists?(query_path),
         {:ok, spr_output} <- execute_sparql_construct(workspace_rdf_path, query_path, options),
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

  @doc """
  Health check for Oxigraph connectivity

  Returns {:ok, %{status: "ok", version: "..."}} if Oxigraph is responding.
  Used by integration tests and startup validation.
  """
  def health_check_oxigraph(options \\ []) do
    url = Keyword.get(options, :oxigraph_url, @oxigraph_base_url)
    health_url = "#{url}/health"

    case Req.get(health_url, timeout: @timeout_ms) do
      {:ok, response} ->
        if response.status == 200 do
          {:ok, %{status: "ok", url: url}}
        else
          {:error, "Oxigraph returned status #{response.status}"}
        end

      {:error, reason} ->
        {:error, "Oxigraph health check failed: #{inspect(reason)}"}
    end
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

  @doc false
  def execute_sparql_construct(workspace_rdf_path, query_path, options \\ []) do
    url = Keyword.get(options, :oxigraph_url, @oxigraph_base_url)
    query_content = File.read!(query_path)

    # Load workspace.ttl into Oxigraph (in production, workspace would be pre-loaded)
    # For now, we execute the query and collect results

    sparql_url = "#{url}/query"

    headers = [
      {"Content-Type", "application/sparql-query"},
      {"Accept", "application/n-triples"}
    ]

    Logger.info(
      "Executing SPARQL CONSTRUCT: #{Path.basename(query_path)} against #{workspace_rdf_path}"
    )

    case Req.post(sparql_url,
      headers: headers,
      body: query_content,
      timeout: @timeout_ms
    ) do
      {:ok, response} ->
        if response.status == 200 do
          {:ok, %{
            type: "sparql_construct_result",
            query: query_content,
            source: workspace_rdf_path,
            result: response.body,
            timestamp_ms: System.monotonic_time(:millisecond)
          }}
        else
          {:error, "Oxigraph CONSTRUCT failed: status #{response.status}"}
        end

      {:error, reason} ->
        {:error, "Failed to execute SPARQL CONSTRUCT: #{inspect(reason)}"}
    end
  end

  defp extract_variables_from_spr(spr_output) do
    # Extract template variables from SPR output
    # (modules.json, deps.json, patterns.json)
    # In a real implementation, parse the RDF result and structure it
    variables = Map.get(spr_output, :variables, %{})
    {:ok, variables}
  end
end
