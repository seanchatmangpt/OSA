defmodule OSA.SemConv.WeaverLiveCheckOtlpTest do
  @moduledoc """
  When `WEAVER_LIVE_CHECK=true`, emits a completed span so Weaver's OTLP receiver
  gets proof before `mix test` exits. Normal test runs use `traces_exporter: :none`;
  this test is a no-op export-wise but still validates the tracer path.
  """
  use ExUnit.Case, async: false

  test "completes healing.diagnosis span for OTLP live-check" do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    attrs = [
      {:"healing.failure_mode", "deadlock"},
      {:"healing.confidence", 0.95}
    ]

    span_opts = %{attributes: attrs, kind: :internal}
    ctx = :otel_tracer.start_span(tracer, "healing.diagnosis", span_opts)
    :otel_span.end_span(ctx)

    assert ctx != :undefined
  end
end
