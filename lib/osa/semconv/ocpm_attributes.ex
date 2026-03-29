defmodule OpenTelemetry.SemConv.Incubating.OcpmAttributes do
  @moduledoc """
  Ocpm semantic convention attributes.

  Namespace: `ocpm`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Overall conformance fitness score [0.0-1.0]

  Attribute: `ocpm.conformance.fitness`
  Type: `double`
  Stability: `development`
  Requirement: `required`
  Examples: `0.0`, `0.85`, `1.0`
  """
  @spec ocpm_conformance_fitness() :: :"ocpm.conformance.fitness"
  def ocpm_conformance_fitness, do: :"ocpm.conformance.fitness"

  @doc """
  Total number of directly-follows edges in the OCDFG

  Attribute: `ocpm.dfg.edge.count`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `0`, `5`, `42`
  """
  @spec ocpm_dfg_edge_count() :: :"ocpm.dfg.edge.count"
  def ocpm_dfg_edge_count, do: :"ocpm.dfg.edge.count"

  @doc """
  Object type for which the DFG was computed

  Attribute: `ocpm.dfg.object_type`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `order`, `item`
  """
  @spec ocpm_dfg_object_type() :: :"ocpm.dfg.object_type"
  def ocpm_dfg_object_type, do: :"ocpm.dfg.object_type"

  @doc """
  Whether the LLM answer was grounded in real OCEL process data (vs offline fallback)

  Attribute: `ocpm.llm.grounded`
  Type: `boolean`
  Stability: `development`
  Requirement: `required`
  Examples: `true`, `false`
  """
  @spec ocpm_llm_grounded() :: :"ocpm.llm.grounded"
  def ocpm_llm_grounded, do: :"ocpm.llm.grounded"

  @doc """
  Number of bottleneck edges detected

  Attribute: `ocpm.performance.bottleneck.count`
  Type: `int`
  Stability: `development`
  Requirement: `required`
  Examples: `0`, `1`, `5`
  """
  @spec ocpm_performance_bottleneck_count() :: :"ocpm.performance.bottleneck.count"
  def ocpm_performance_bottleneck_count, do: :"ocpm.performance.bottleneck.count"

  @doc """
  Object type for which performance was computed

  Attribute: `ocpm.performance.object_type`
  Type: `string`
  Stability: `development`
  Requirement: `required`
  Examples: `order`, `item`
  """
  @spec ocpm_performance_object_type() :: :"ocpm.performance.object_type"
  def ocpm_performance_object_type, do: :"ocpm.performance.object_type"

  @doc """
  Mean end-to-end throughput time in seconds for this object type

  Attribute: `ocpm.performance.throughput_mean_secs`
  Type: `double`
  Stability: `development`
  Requirement: `required`
  Examples: `0.0`, `120.5`, `86400.0`
  """
  @spec ocpm_performance_throughput_mean_secs() :: :"ocpm.performance.throughput_mean_secs"
  def ocpm_performance_throughput_mean_secs, do: :"ocpm.performance.throughput_mean_secs"

  @doc """
  Type of conformance deviation detected

  Attribute: `ocpm.conformance.deviation_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `missing_token`, `remaining_token`, `missing_activity`
  """
  @spec ocpm_conformance_deviation_type() :: :"ocpm.conformance.deviation_type"
  def ocpm_conformance_deviation_type, do: :"ocpm.conformance.deviation_type"

  @doc """
  Enumerated values for `ocpm.conformance.deviation_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `missing_token` | `"missing_token"` | Token replay found missing tokens (activity executed without prerequisite) |
  | `remaining_token` | `"remaining_token"` | Token replay found remaining tokens after final state (incomplete execution) |
  | `missing_activity` | `"missing_activity"` | Required activity was absent from the object lifecycle |
  """
  @spec ocpm_conformance_deviation_type_values() :: %{
    missing_token: :missing_token,
    remaining_token: :remaining_token,
    missing_activity: :missing_activity
  }
  def ocpm_conformance_deviation_type_values do
    %{
      missing_token: :missing_token,
      remaining_token: :remaining_token,
      missing_activity: :missing_activity
    }
  end

  defmodule OcpmConformanceDeviationTypeValues do
    @moduledoc """
    Typed constants for the `ocpm.conformance.deviation_type` attribute.
    """

    @doc "Token replay found missing tokens (activity executed without prerequisite)"
    @spec missing_token() :: :missing_token
    def missing_token, do: :missing_token

    @doc "Token replay found remaining tokens after final state (incomplete execution)"
    @spec remaining_token() :: :remaining_token
    def remaining_token, do: :remaining_token

    @doc "Required activity was absent from the object lifecycle"
    @spec missing_activity() :: :missing_activity
    def missing_activity, do: :missing_activity

  end

  @doc """
  Object type for per-type fitness score

  Attribute: `ocpm.conformance.object_type`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `order`, `item`
  """
  @spec ocpm_conformance_object_type() :: :"ocpm.conformance.object_type"
  def ocpm_conformance_object_type, do: :"ocpm.conformance.object_type"

  @doc """
  Activity name associated with the OCEL event

  Attribute: `ocpm.event.activity`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `create_order`, `approve`, `ship`, `deliver`
  """
  @spec ocpm_event_activity() :: :"ocpm.event.activity"
  def ocpm_event_activity, do: :"ocpm.event.activity"

  @doc """
  Number of events in the OCEL log processed by this operation

  Attribute: `ocpm.event.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `100`, `10000`
  """
  @spec ocpm_event_count() :: :"ocpm.event.count"
  def ocpm_event_count, do: :"ocpm.event.count"

  @doc """
  Number of tokens in the OCEL context injected as system message

  Attribute: `ocpm.llm.context_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `512`, `2048`
  """
  @spec ocpm_llm_context_tokens() :: :"ocpm.llm.context_tokens"
  def ocpm_llm_context_tokens, do: :"ocpm.llm.context_tokens"

  @doc """
  LLM model used to answer the process intelligence query

  Attribute: `ocpm.llm.model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `openai/gpt-oss-20b`, `llama3-70b-8192`
  """
  @spec ocpm_llm_model() :: :"ocpm.llm.model"
  def ocpm_llm_model, do: :"ocpm.llm.model"

  @doc """
  Unique identifier of the object instance

  Attribute: `ocpm.object_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `order_001`, `item_42`, `inv_2026-03-28`
  """
  @spec ocpm_object_id() :: :"ocpm.object_id"
  def ocpm_object_id, do: :"ocpm.object_id"

  @doc """
  Object type name in the OCEL 2.0 log (e.g. 'order', 'item', 'invoice')

  Attribute: `ocpm.object_type`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `order`, `item`, `invoice`, `shipment`
  """
  @spec ocpm_object_type() :: :"ocpm.object_type"
  def ocpm_object_type, do: :"ocpm.object_type"

  @doc """
  Number of distinct object types in the OCEL log

  Attribute: `ocpm.object_type.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `7`
  """
  @spec ocpm_object_type_count() :: :"ocpm.object_type.count"
  def ocpm_object_type_count, do: :"ocpm.object_type.count"

end