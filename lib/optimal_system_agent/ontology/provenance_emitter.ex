defmodule OptimalSystemAgent.Ontology.ProvenanceEmitter do
  @moduledoc """
  Provenance triple emission to Oxigraph

  After each agent action, emits PROV-O (W3C Provenance Ontology) triples
  to create an audit trail of who did what, when, where, and why.

  Uses SPARQL INSERT triples to store provenance in Oxigraph.
  Enables post-hoc investigation, compliance auditing, and causal reasoning.

  Signal Theory: S=(data,audit,record,ttl,triple)
  """

  require Logger
  alias OptimalSystemAgent.Ontology.OxigraphClient

  @doc """
  Emit a provenance record for an agent action

  ## Parameters:
    - action_id: unique ID for the action (e.g., "a2a_call_12345")
    - agent_id: ID of agent performing action
    - action_type: type of action (e.g., "query_execution", "decision", "healing")
    - resource_id: what resource was affected
    - details: map with :input, :output, :duration_ms, etc.

  Returns :ok or {:error, reason}

  Example:
    emit_action("a2a_1", "agent_7", "query_execution", "ontology_query", %{
      input: "SELECT ...",
      output: "5 rows",
      duration_ms: 245
    })
  """
  @spec emit_action(String.t(), String.t(), String.t(), String.t(), map()) :: :ok | {:error, term()}
  def emit_action(action_id, agent_id, action_type, resource_id, details \\ %{}) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    # Build SPARQL INSERT triples using PROV-O
    sparql = build_provenance_insert(
      action_id,
      agent_id,
      action_type,
      resource_id,
      timestamp,
      details
    )

    case OxigraphClient.query_construct(sparql) do
      {:ok, _triples} ->
        Logger.debug("[ProvenanceEmitter] Recorded action: #{action_id}")
        :ok

      {:error, reason} ->
        Logger.error("[ProvenanceEmitter] Failed to emit provenance: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get provenance chain for a resource

  Returns all actions that affected a given resource, in chronological order.

  Returns {:ok, actions} or {:error, reason}
  """
  @spec get_provenance_chain(String.t()) :: {:ok, list(map())} | {:error, term()}
  def get_provenance_chain(resource_id) do
    query = """
    PREFIX prov: <http://www.w3.org/ns/prov#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>

    SELECT ?action ?agent ?type ?timestamp WHERE {
      ?action prov:wasAssociatedWith ?agent ;
              prov:used ?resource ;
              chatman:actionType ?type ;
              dcterms:issued ?timestamp .

      FILTER (?resource = <https://ontology.chatmangpt.com/resource/#{resource_id}>)
    }
    ORDER BY ?timestamp
    """

    case OxigraphClient.query_select(query) do
      {:ok, rows} ->
        actions =
          Enum.map(rows, fn row ->
            %{
              action_id: Map.get(row, "action"),
              agent_id: Map.get(row, "agent"),
              action_type: Map.get(row, "type"),
              timestamp: Map.get(row, "timestamp")
            }
          end)

        {:ok, actions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Query provenance by time range

  Returns all actions executed between start_time and end_time (ISO8601 strings).

  Returns {:ok, actions} or {:error, reason}
  """
  @spec query_provenance_by_time(String.t(), String.t()) :: {:ok, list(map())} | {:error, term()}
  def query_provenance_by_time(start_time, end_time) do
    query = """
    PREFIX prov: <http://www.w3.org/ns/prov#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>

    SELECT ?action ?agent ?resource ?type ?timestamp WHERE {
      ?action prov:wasAssociatedWith ?agent ;
              prov:used ?resource ;
              chatman:actionType ?type ;
              dcterms:issued ?timestamp .

      FILTER (?timestamp >= "#{start_time}"^^xsd:dateTime &&
              ?timestamp <= "#{end_time}"^^xsd:dateTime)
    }
    ORDER BY ?timestamp
    """

    case OxigraphClient.query_select(query) do
      {:ok, rows} ->
        actions =
          Enum.map(rows, fn row ->
            %{
              action_id: Map.get(row, "action"),
              agent_id: Map.get(row, "agent"),
              resource_id: Map.get(row, "resource"),
              action_type: Map.get(row, "type"),
              timestamp: Map.get(row, "timestamp")
            }
          end)

        {:ok, actions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private

  defp build_provenance_insert(action_id, agent_id, action_type, resource_id, timestamp, details) do
    action_uri = "<https://ontology.chatmangpt.com/action/#{action_id}>"
    agent_uri = "<https://ontology.chatmangpt.com/agent/#{agent_id}>"
    resource_uri = "<https://ontology.chatmangpt.com/resource/#{resource_id}>"

    triples = [
      "#{action_uri} a <http://www.w3.org/ns/prov#Activity> .",
      "#{action_uri} <http://www.w3.org/ns/prov#wasAssociatedWith> #{agent_uri} .",
      "#{action_uri} <http://www.w3.org/ns/prov#used> #{resource_uri} .",
      "#{action_uri} <https://ontology.chatmangpt.com/core#actionType> \"#{action_type}\" .",
      "#{action_uri} <http://purl.org/dc/terms/issued> \"#{timestamp}\"^^<http://www.w3.org/2001/XMLSchema#dateTime> ."
    ]

    # Add details as triples if present
    details_triples =
      if Map.get(details, :input) do
        ["#{action_uri} <https://ontology.chatmangpt.com/core#hasInput> \"#{Map.get(details, :input)}\" ."]
      else
        []
      end ++
        if Map.get(details, :output) do
          ["#{action_uri} <https://ontology.chatmangpt.com/core#hasOutput> \"#{Map.get(details, :output)}\" ."]
        else
          []
        end ++
        if Map.get(details, :duration_ms) do
          ["#{action_uri} <https://ontology.chatmangpt.com/core#duration_ms> #{Map.get(details, :duration_ms)} ."]
        else
          []
        end

    all_triples = triples ++ details_triples

    """
    PREFIX prov: <http://www.w3.org/ns/prov#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

    INSERT DATA {
      #{Enum.join(all_triples, "\n      ")}
    }
    """
  end
end
