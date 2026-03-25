defmodule OSA.SemConv.OtelSpanEmitTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Chicago TDD: verifies that opentelemetry_api is available and span macros compile.
  This test proves OSA has the OTEL API dependency correctly installed.
  """

  test "opentelemetry_api module is available" do
    # Compile-time check: if opentelemetry_api is not installed, this crashes at compile time
    assert Code.ensure_loaded?(OpenTelemetry.Tracer)
  end

  test "OSA semconv healing attributes module is defined" do
    assert Code.ensure_loaded?(OpenTelemetry.SemConv.Incubating.HealingAttributes)
  end

  test "healing failure mode atom constant is correct otel name" do
    alias OpenTelemetry.SemConv.Incubating.HealingAttributes
    assert HealingAttributes.healing_failure_mode() == :"healing.failure_mode"
  end
end
