defmodule OptimalSystemAgent.Ontology.ToolCapabilityRegistry do
  @moduledoc """
  Dynamic tool capability discovery from Oxigraph ontology

  Queries `tool-registry.rq` to fetch all registered tools with their:
  - Input/output schemas
  - Required permissions
  - Execution budgets (time_ms, memory_mb)
  - Agent access tier restrictions

  Enables dynamic tool dispatch without hardcoding tool availability.

  Signal Theory: S=(data,reference,inform,json,schema)
  """

  require Logger
  alias OptimalSystemAgent.Ontology.OxigraphClient

  @tool_registry_query """
  PREFIX chatman: <https://ontology.chatmangpt.com/core#>
  PREFIX dcterms: <http://purl.org/dc/terms/>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  PREFIX schema: <http://schema.org/>

  SELECT ?tool ?toolId ?label ?description ?inputSchema ?outputSchema ?requiredTier WHERE {
    ?tool a chatman:Tool ;
      dcterms:identifier ?toolId ;
      rdfs:label ?label ;
      dcterms:description ?description ;
      chatman:hasInputSchema ?inputSchema ;
      chatman:hasOutputSchema ?outputSchema ;
      chatman:requiredTier ?requiredTier .
  }
  ORDER BY ?toolId
  """

  @doc """
  Load all tool capabilities from ontology

  Returns {:ok, count} where count is number of tools discovered,
  or {:error, reason} on failure.

  Call at application startup to populate tool registry with ontology-defined tools.
  """
  @spec discover_tools() :: {:ok, non_neg_integer()} | {:error, term()}
  def discover_tools do
    case OxigraphClient.query_select(@tool_registry_query) do
      {:ok, rows} ->
        Logger.info("[ToolCapabilityRegistry] Discovered #{length(rows)} tools from ontology")
        store_tools(rows)
        {:ok, length(rows)}

      {:error, reason} ->
        Logger.error("[ToolCapabilityRegistry] Tool discovery failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get tool capability by tool ID

  Returns {:ok, tool_spec} with schema and permissions, or {:error, :not_found}
  """
  @spec get_tool_capability(String.t()) :: {:ok, map()} | {:error, term()}
  def get_tool_capability(tool_id) do
    query = """
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

    SELECT ?label ?description ?inputSchema ?outputSchema ?requiredTier WHERE {
      ?tool a chatman:Tool ;
        dcterms:identifier "#{tool_id}" ;
        rdfs:label ?label ;
        dcterms:description ?description ;
        chatman:hasInputSchema ?inputSchema ;
        chatman:hasOutputSchema ?outputSchema ;
        chatman:requiredTier ?requiredTier .
    }
    LIMIT 1
    """

    case OxigraphClient.query_select(query) do
      {:ok, [row | _]} ->
        tool_spec = %{
          tool_id: tool_id,
          label: Map.get(row, "label"),
          description: Map.get(row, "description"),
          input_schema: Map.get(row, "inputSchema"),
          output_schema: Map.get(row, "outputSchema"),
          required_tier: Map.get(row, "requiredTier")
        }
        {:ok, tool_spec}

      {:ok, []} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get all tools available to an agent tier

  Returns {:ok, tools} where tools is list of tool IDs accessible by that tier,
  or {:error, reason} on failure.

  Tier hierarchy: :critical >= :high >= :normal >= :low
  """
  @spec tools_for_tier(atom()) :: {:ok, list(String.t())} | {:error, term()}
  def tools_for_tier(tier) when tier in [:critical, :high, :normal, :low] do
    # Normalize tier to string for SPARQL query
    tier_str = Atom.to_string(tier)

    query = """
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>
    PREFIX dcterms: <http://purl.org/dc/terms/>

    SELECT ?toolId WHERE {
      ?tool a chatman:Tool ;
        dcterms:identifier ?toolId ;
        chatman:requiredTier ?requiredTier .

      FILTER (?requiredTier IN ("#{tier_str}", "low"))
    }
    ORDER BY ?toolId
    """

    case OxigraphClient.query_select(query) do
      {:ok, rows} ->
        tool_ids = Enum.map(rows, &Map.get(&1, "toolId"))
        {:ok, tool_ids}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if agent can access tool

  Returns {:ok, true} if agent tier permits access, or {:ok, false}
  """
  @spec can_access_tool?(atom(), String.t()) :: {:ok, boolean()} | {:error, term()}
  def can_access_tool?(agent_tier, tool_id) do
    case get_tool_capability(tool_id) do
      {:ok, %{required_tier: required_tier}} ->
        can_access = tier_permits_access(agent_tier, required_tier)
        {:ok, can_access}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private

  defp store_tools(rows) do
    tools =
      Enum.map(rows, fn row ->
        %{
          tool_id: Map.get(row, "toolId"),
          label: Map.get(row, "label"),
          description: Map.get(row, "description"),
          input_schema: Map.get(row, "inputSchema"),
          output_schema: Map.get(row, "outputSchema"),
          required_tier: Map.get(row, "requiredTier")
        }
      end)

    Logger.debug("Storing #{length(tools)} tool capabilities")
    tools
  end

  # Tier hierarchy: critical can access all, low can only access low-tier tools
  defp tier_permits_access(:critical, _), do: true
  defp tier_permits_access(:high, tier), do: tier in ["high", "normal", "low"]
  defp tier_permits_access(:normal, tier), do: tier in ["normal", "low"]
  defp tier_permits_access(:low, "low"), do: true
  defp tier_permits_access(_, _), do: false
end
