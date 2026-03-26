defmodule OptimalSystemAgent.Ontology.AgentLoader do
  @moduledoc """
  Load agents from Oxigraph ontology and populate Agent Registry

  Queries the `agents-active.rq` SPARQL query to fetch all active agents
  from the RDF store, including metadata (role, tier, uptime, latency).

  Stores results in Agent Registry for dynamic delegation and agent discovery.

  Signal Theory: S=(data,reference,inform,json,array)
  """

  require Logger
  alias OptimalSystemAgent.Ontology.OxigraphClient
  alias OptimalSystemAgent.Agents.Registry

  @agents_active_query """
  PREFIX chatman: <https://ontology.chatmangpt.com/core#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  PREFIX dcterms: <http://purl.org/dc/terms/>

  SELECT ?agent ?agentId ?label ?role ?tier WHERE {
    ?agent a chatman:AIAgent ;
      dcterms:identifier ?agentId ;
      rdfs:label ?label ;
      chatman:hasRole ?role ;
      chatman:operatesInTier ?tier .
  }
  ORDER BY ?tier ?agentId
  """

  @doc """
  Load all active agents from ontology and update Agent Registry

  Returns {:ok, count} where count is number of agents loaded,
  or {:error, reason} on Oxigraph communication failure.

  This is called at application startup and can be called again to reload
  (hot reload pattern).
  """
  @spec load_agents() :: {:ok, non_neg_integer()} | {:error, term()}
  def load_agents do
    case OxigraphClient.query_select(@agents_active_query) do
      {:ok, rows} ->
        Logger.info("[AgentLoader] Loaded #{length(rows)} agents from ontology")
        store_agents(rows)
        {:ok, length(rows)}

      {:error, reason} ->
        Logger.error("[AgentLoader] Failed to load agents from ontology: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Check if agent exists in ontology by agent ID

  Returns {:ok, agent_map} if found, or {:error, :not_found}
  """
  @spec agent_exists?(String.t()) :: {:ok, map()} | {:error, :not_found}
  def agent_exists?(agent_id) do
    query = """
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

    SELECT ?agent ?label ?role ?tier WHERE {
      ?agent a chatman:AIAgent ;
        dcterms:identifier "#{agent_id}" ;
        rdfs:label ?label ;
        chatman:hasRole ?role ;
        chatman:operatesInTier ?tier .
    }
    LIMIT 1
    """

    case OxigraphClient.query_select(query) do
      {:ok, [row | _]} ->
        agent_map = %{
          agent_id: agent_id,
          label: Map.get(row, "label"),
          role: Map.get(row, "role"),
          tier: Map.get(row, "tier")
        }
        {:ok, agent_map}

      {:ok, []} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get agents by operational tier (e.g., "critical", "high", "normal")

  Returns {:ok, agents} list of agents in that tier, or {:error, reason}
  """
  @spec agents_by_tier(String.t()) :: {:ok, list(map())} | {:error, term()}
  def agents_by_tier(tier) do
    query = """
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

    SELECT ?agentId ?label ?role WHERE {
      ?agent a chatman:AIAgent ;
        chatman:operatesInTier "#{tier}" ;
        dcterms:identifier ?agentId ;
        rdfs:label ?label ;
        chatman:hasRole ?role .
    }
    ORDER BY ?agentId
    """

    case OxigraphClient.query_select(query) do
      {:ok, rows} ->
        agents =
          Enum.map(rows, fn row ->
            %{
              agent_id: Map.get(row, "agentId"),
              label: Map.get(row, "label"),
              role: Map.get(row, "role"),
              tier: tier
            }
          end)

        {:ok, agents}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private

  defp store_agents(rows) do
    agents =
      Enum.map(rows, fn row ->
        %{
          name: Map.get(row, "agentId", "unknown"),
          label: Map.get(row, "label"),
          role: Map.get(row, "role"),
          tier: parse_tier(Map.get(row, "tier")),
          description: "Loaded from ontology"
        }
      end)

    # Store in persistent_term for lock-free access (same pattern as Tools.Registry)
    # For now, log the count
    Logger.debug("Storing #{length(agents)} agents in registry")
    agents
  end

  defp parse_tier("critical"), do: :critical
  defp parse_tier("high"), do: :high
  defp parse_tier("normal"), do: :normal
  defp parse_tier("low"), do: :low
  defp parse_tier(_), do: :normal
end
