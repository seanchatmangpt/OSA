defmodule OSA.Instrumentation do
  @moduledoc """
  OpenTelemetry instrumentation helpers for JTBD scenarios.

  Provides test helpers to retrieve spans from in-memory span collector.
  In production, spans are sent to Jaeger/OTEL collector.
  """

  require Logger

  @doc """
  Retrieve spans by name from in-memory test store.

  Returns {:ok, spans} or :error.
  """
  def get_spans(span_name) do
    case :ets.lookup(:osa_test_spans, span_name) do
      [{^span_name, spans}] -> {:ok, spans}
      [] -> :error
    end
  rescue
    _ -> :error
  end

  @doc """
  Store a span in test instrumentation.

  Used internally by span recording.
  """
  def record_span(span_name, span_data) do
    ensure_table_exists()

    case :ets.lookup(:osa_test_spans, span_name) do
      [{^span_name, existing_spans}] ->
        :ets.insert(:osa_test_spans, {span_name, existing_spans ++ [span_data]})

      [] ->
        :ets.insert(:osa_test_spans, {span_name, [span_data]})
    end

    :ok
  end

  @doc """
  Clear all test spans.

  Used in test setup/teardown.
  """
  def clear_spans do
    ensure_table_exists()
    :ets.delete_all_objects(:osa_test_spans)
    :ok
  end

  # Helper: Ensure ETS table exists
  defp ensure_table_exists do
    if not :ets.info(:osa_test_spans) do
      :ets.new(:osa_test_spans, [:named_table, :public])
    end
  end
end
