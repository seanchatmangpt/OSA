defmodule OptimalSystemAgent.Integrations.FIBO.Deal do
  @moduledoc """
  FIBO Deal struct — Represents a financial deal with FIBO ontology triples.

  Fields:
    - `id`: Unique deal identifier (String, e.g. "deal_abc123")
    - `name`: Deal name (String)
    - `counterparty`: Counterparty organization (String)
    - `amount_usd`: Deal amount in USD (float)
    - `currency`: Currency code (String, default "USD")
    - `settlement_date`: Settlement/closing date (DateTime)
    - `status`: Deal lifecycle status (atom: :draft, :created, :verified, :active, :closed)
    - `created_at`: Creation timestamp (DateTime)
    - `rdf_triples`: SPARQL CONSTRUCT result as RDF triples (list of Strings)
    - `compliance_checks`: Map of compliance check results (map)

  All fields are populated by `DealCoordinator` after invoking `bos deal create`.
  """

  @enforce_keys [
    :id,
    :name,
    :counterparty,
    :amount_usd,
    :currency,
    :settlement_date,
    :status,
    :created_at,
    :rdf_triples,
    :compliance_checks
  ]

  defstruct [
    :id,
    :name,
    :counterparty,
    :amount_usd,
    :currency,
    :settlement_date,
    :status,
    :created_at,
    :rdf_triples,
    :compliance_checks
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    counterparty: String.t(),
    amount_usd: float(),
    currency: String.t(),
    settlement_date: DateTime.t(),
    status: :draft | :created | :verified | :active | :closed,
    created_at: DateTime.t(),
    rdf_triples: [String.t()],
    compliance_checks: map()
  }

  @doc """
  Create a new Deal struct from input map.

  Used internally by DealCoordinator after CLI call.
  """
  @spec new(map()) :: t()
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Convert Deal to JSON-safe map for HTTP responses.
  """
  @spec to_json(t()) :: map()
  def to_json(deal) do
    %{
      id: deal.id,
      name: deal.name,
      counterparty: deal.counterparty,
      amount_usd: deal.amount_usd,
      currency: deal.currency,
      settlement_date: DateTime.to_iso8601(deal.settlement_date),
      status: Atom.to_string(deal.status),
      created_at: DateTime.to_iso8601(deal.created_at),
      rdf_triple_count: Enum.count(deal.rdf_triples),
      compliance_checks: deal.compliance_checks
    }
  end
end
