defmodule OpenTelemetry.SemConv.Incubating.OxigraphSpanNames do
  @moduledoc """
  Oxigraph semantic convention span names.

  Namespace: `oxigraph`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Oxigraph query — runs SPARQL SELECT, ASK, or CONSTRUCT against the /query endpoint.

  Span: `span.oxigraph.query`
  Kind: `client`
  Stability: `development`
  """
  @spec oxigraph_query() :: String.t()
  def oxigraph_query, do: "oxigraph.query"

  @doc """
  Oxigraph write — loads Turtle or N-Triples RDF data into Oxigraph via HTTP POST /store.

  Span: `span.oxigraph.write`
  Kind: `client`
  Stability: `development`
  """
  @spec oxigraph_write() :: String.t()
  def oxigraph_write, do: "oxigraph.write"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      oxigraph_query(),
      oxigraph_write()
    ]
  end
end