defmodule OptimalSystemAgent.Ontology.QualityRecorder do
  @moduledoc """
  Data Quality Vocabulary (DQV) metrics recording to Oxigraph

  Records quality measurements (DQV - W3C Data Quality Vocabulary) for agent outputs.
  Metrics tracked:
    - signal_to_noise (S/N ratio)
    - accuracy
    - relevance
    - completeness
    - latency_ms

  After each agent action, computes and emits DQV measurements to Oxigraph
  for post-hoc quality analysis and SLA tracking.

  Signal Theory: S=(data,metric,inform,json,quality)
  """

  require Logger
  alias OptimalSystemAgent.Ontology.OxigraphClient

  @doc """
  Record quality measurement for an agent action

  ## Parameters:
    - action_id: ID of the action being measured
    - metric_name: name of metric (e.g., "signal_to_noise", "accuracy")
    - value: numeric value
    - dimensions: map of additional context (e.g., %{agent: "agent_7", tier: "critical"})

  Returns :ok or {:error, reason}

  Example:
    record_quality("a2a_123", "signal_to_noise", 0.95, %{agent: "agent_7"})
  """
  @spec record_quality(String.t(), String.t(), number(), map()) :: :ok | {:error, term()}
  def record_quality(action_id, metric_name, value, dimensions \\ %{}) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    sparql = build_dqv_insert(action_id, metric_name, value, timestamp, dimensions)

    case OxigraphClient.query_construct(sparql) do
      {:ok, _triples} ->
        Logger.debug(
          "[QualityRecorder] Recorded #{metric_name}=#{value} for action: #{action_id}"
        )
        :ok

      {:error, reason} ->
        Logger.error("[QualityRecorder] Failed to record quality: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get quality metrics for an action

  Returns {:ok, metrics} where metrics is a list of measurement maps,
  each containing: metric_name, value, timestamp, dimensions.

  Returns {:error, reason} on failure.
  """
  @spec get_action_quality(String.t()) :: {:ok, list(map())} | {:error, term()}
  def get_action_quality(action_id) do
    query = """
    PREFIX dqv: <http://www.w3.org/ns/dqv#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>

    SELECT ?metric ?value ?timestamp WHERE {
      ?measure a dqv:QualityMeasurement ;
               dqv:isMeasurementOf ?metric ;
               rdf:value ?value ;
               dcterms:issued ?timestamp ;
               chatman:forAction <https://ontology.chatmangpt.com/action/#{action_id}> .
    }
    ORDER BY ?timestamp
    """

    case OxigraphClient.query_select(query) do
      {:ok, rows} ->
        metrics =
          Enum.map(rows, fn row ->
            %{
              metric_name: Map.get(row, "metric"),
              value: Map.get(row, "value"),
              timestamp: Map.get(row, "timestamp")
            }
          end)

        {:ok, metrics}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get average quality metric across all actions in time window

  Parameters:
    - metric_name: name of metric to aggregate
    - start_time: ISO8601 start timestamp
    - end_time: ISO8601 end timestamp

  Returns {:ok, %{avg: N, min: N, max: N, count: N}} or {:error, reason}
  """
  @spec aggregate_quality_metric(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def aggregate_quality_metric(metric_name, start_time, end_time) do
    query = """
    PREFIX dqv: <http://www.w3.org/ns/dqv#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

    SELECT (AVG(?value) as ?avg) (MIN(?value) as ?min) (MAX(?value) as ?max) (COUNT(?value) as ?count) WHERE {
      ?measure a dqv:QualityMeasurement ;
               dqv:isMeasurementOf "#{metric_name}" ;
               rdf:value ?value ;
               dcterms:issued ?timestamp .

      FILTER (?timestamp >= "#{start_time}"^^xsd:dateTime &&
              ?timestamp <= "#{end_time}"^^xsd:dateTime)
    }
    """

    case OxigraphClient.query_select(query) do
      {:ok, [result]} ->
        stats = %{
          metric: metric_name,
          avg: parse_value(Map.get(result, "avg")),
          min: parse_value(Map.get(result, "min")),
          max: parse_value(Map.get(result, "max")),
          count: parse_value(Map.get(result, "count"))
        }
        {:ok, stats}

      {:ok, []} ->
        {:error, :no_metrics_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private

  defp build_dqv_insert(action_id, metric_name, value, timestamp, dimensions) do
    measure_id = "#{action_id}_#{metric_name}_#{System.monotonic_time(:second)}"
    measure_uri = "<https://ontology.chatmangpt.com/measure/#{measure_id}>"
    action_uri = "<https://ontology.chatmangpt.com/action/#{action_id}>"

    triples = [
      "#{measure_uri} a <http://www.w3.org/ns/dqv#QualityMeasurement> .",
      "#{measure_uri} <http://www.w3.org/ns/dqv#isMeasurementOf> \"#{metric_name}\" .",
      "#{measure_uri} <http://www.w3.org/1999/02/22-rdf-syntax-ns#value> #{value} .",
      "#{measure_uri} <http://purl.org/dc/terms/issued> \"#{timestamp}\"^^<http://www.w3.org/2001/XMLSchema#dateTime> .",
      "#{measure_uri} <https://ontology.chatmangpt.com/core#forAction> #{action_uri} ."
    ]

    # Add dimension triples
    dimension_triples =
      Enum.map(dimensions, fn {key, val} ->
        "#{measure_uri} <https://ontology.chatmangpt.com/core##{key}> \"#{val}\" ."
      end)

    all_triples = triples ++ dimension_triples

    """
    PREFIX dqv: <http://www.w3.org/ns/dqv#>
    PREFIX dcterms: <http://purl.org/dc/terms/>
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>

    INSERT DATA {
      #{Enum.join(all_triples, "\n      ")}
    }
    """
  end

  defp parse_value(nil), do: 0
  defp parse_value(val) when is_number(val), do: val
  defp parse_value(val) when is_binary(val), do: String.to_float(val)
  defp parse_value(_), do: 0
end
