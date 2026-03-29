defmodule OpenTelemetry.SemConv.Incubating.RdfSpanNames do
  @moduledoc """
  Rdf semantic convention span names.

  Namespace: `rdf`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  SPARQL CONSTRUCT query — produces an RDF graph from an Oxigraph triplestore.

  Span: `span.rdf.construct`
  Kind: `client`
  Stability: `development`
  """
  @spec rdf_construct() :: String.t()
  def rdf_construct, do: "rdf.construct"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      rdf_construct()
    ]
  end
end