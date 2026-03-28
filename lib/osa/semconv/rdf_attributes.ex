defmodule OpenTelemetry.SemConv.Incubating.RdfAttributes do
  @moduledoc """
  Rdf semantic convention attributes.

  Namespace: `rdf`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Number of RDF triples produced by a CONSTRUCT query result.

  Attribute: `rdf.result.triple_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `150`, `5000`
  """
  @spec rdf_result_triple_count() :: :"rdf.result.triple_count"
  def rdf_result_triple_count, do: :"rdf.result.triple_count"

  @doc """
  Base URL of the SPARQL/Oxigraph endpoint receiving the operation.

  Attribute: `rdf.sparql.endpoint`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `http://localhost:7878`, `http://oxigraph:7878`
  """
  @spec rdf_sparql_endpoint() :: :"rdf.sparql.endpoint"
  def rdf_sparql_endpoint, do: :"rdf.sparql.endpoint"

  @doc """
  Type of SPARQL query or update operation being executed.

  Attribute: `rdf.sparql.query_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `SELECT`, `CONSTRUCT`, `ASK`
  """
  @spec rdf_sparql_query_type() :: :"rdf.sparql.query_type"
  def rdf_sparql_query_type, do: :"rdf.sparql.query_type"

  @doc """
  Enumerated values for `rdf.sparql.query_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `select` | `"SELECT"` | SELECT |
  | `construct` | `"CONSTRUCT"` | CONSTRUCT |
  | `ask` | `"ASK"` | ASK |
  | `describe` | `"DESCRIBE"` | DESCRIBE |
  | `insert` | `"INSERT"` | INSERT |
  """
  @spec rdf_sparql_query_type_values() :: %{
    select: :SELECT,
    construct: :CONSTRUCT,
    ask: :ASK,
    describe: :DESCRIBE,
    insert: :INSERT
  }
  def rdf_sparql_query_type_values do
    %{
      select: :SELECT,
      construct: :CONSTRUCT,
      ask: :ASK,
      describe: :DESCRIBE,
      insert: :INSERT
    }
  end

  defmodule RdfSparqlQueryTypeValues do
    @moduledoc """
    Typed constants for the `rdf.sparql.query_type` attribute.
    """

    @doc "SELECT"
    @spec select() :: :SELECT
    def select, do: :SELECT

    @doc "CONSTRUCT"
    @spec construct() :: :CONSTRUCT
    def construct, do: :CONSTRUCT

    @doc "ASK"
    @spec ask() :: :ASK
    def ask, do: :ASK

    @doc "DESCRIBE"
    @spec describe() :: :DESCRIBE
    def describe, do: :DESCRIBE

    @doc "INSERT"
    @spec insert() :: :INSERT
    def insert, do: :INSERT

  end

  @doc """
  Number of result rows returned by a SPARQL SELECT or ASK query.

  Attribute: `rdf.sparql.result_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `42`, `500`
  """
  @spec rdf_sparql_result_count() :: :"rdf.sparql.result_count"
  def rdf_sparql_result_count, do: :"rdf.sparql.result_count"

  @doc """
  Timeout in milliseconds applied to the SPARQL query or update.

  Attribute: `rdf.sparql.timeout_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `3000`, `5000`, `10000`
  """
  @spec rdf_sparql_timeout_ms() :: :"rdf.sparql.timeout_ms"
  def rdf_sparql_timeout_ms, do: :"rdf.sparql.timeout_ms"

  @doc """
  MIME type of the RDF serialization format used for write operations.

  Attribute: `rdf.write.format`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `text/turtle`, `application/n-triples`
  """
  @spec rdf_write_format() :: :"rdf.write.format"
  def rdf_write_format, do: :"rdf.write.format"

  @doc """
  Enumerated values for `rdf.write.format`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `turtle` | `"text/turtle"` | text/turtle |
  | `ntriples` | `"application/n-triples"` | application/n-triples |
  | `jsonld` | `"application/ld+json"` | application/ld+json |
  """
  @spec rdf_write_format_values() :: %{
    turtle: :"text/turtle",
    ntriples: :"application/n-triples",
    jsonld: :"application/ld+json"
  }
  def rdf_write_format_values do
    %{
      turtle: :"text/turtle",
      ntriples: :"application/n-triples",
      jsonld: :"application/ld+json"
    }
  end

  defmodule RdfWriteFormatValues do
    @moduledoc """
    Typed constants for the `rdf.write.format` attribute.
    """

    @doc "text/turtle"
    @spec turtle() :: :"text/turtle"
    def turtle, do: :"text/turtle"

    @doc "application/n-triples"
    @spec ntriples() :: :"application/n-triples"
    def ntriples, do: :"application/n-triples"

    @doc "application/ld+json"
    @spec jsonld() :: :"application/ld+json"
    def jsonld, do: :"application/ld+json"

  end

  @doc """
  Number of RDF triples written in the store operation.

  Attribute: `rdf.write.triple_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `50`, `1000`
  """
  @spec rdf_write_triple_count() :: :"rdf.write.triple_count"
  def rdf_write_triple_count, do: :"rdf.write.triple_count"

end