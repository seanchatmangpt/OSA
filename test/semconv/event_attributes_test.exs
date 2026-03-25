defmodule OpenTelemetry.SemConv.EventAttributesTest do
  @moduledoc """
  Chicago TDD validation tests for EventAttributes semconv constants.

  These tests enforce schema drift prevention:
  - Compile error if semconv renames an event attribute
  - Enum value removal caught by undefined function error at compile time
  - Documents the contract for event domain OTel attributes

  This is the third proof layer in the verification standard:
    1. OTEL span (execution proof)
    2. Test assertion (behavior proof)
    3. Schema conformance (weaver check + typed constants used here)

  Run with: mix test test/semconv/event_attributes_test.exs
  """
  use ExUnit.Case, async: true

  alias OpenTelemetry.SemConv.Incubating.EventAttributes

  # ============================================================
  # EventAttributes — attribute key constants
  # ============================================================

  describe "EventAttributes — attribute keys" do
    @tag :unit
    test "event_name returns correct OTel attribute name" do
      assert EventAttributes.event_name() == :"event.name"
    end

    @tag :unit
    test "event_domain returns correct OTel attribute name" do
      assert EventAttributes.event_domain() == :"event.domain"
    end

    @tag :unit
    test "event_severity returns correct OTel attribute name" do
      assert EventAttributes.event_severity() == :"event.severity"
    end

    @tag :unit
    test "event_source returns correct OTel attribute name" do
      assert EventAttributes.event_source() == :"event.source"
    end

    @tag :unit
    test "event_correlation_id returns correct OTel attribute name" do
      assert EventAttributes.event_correlation_id() == :"event.correlation_id"
    end
  end

  # ============================================================
  # EventAttributes — event.domain enum values
  # ============================================================

  describe "EventAttributes — event.domain enum values" do
    @tag :unit
    test "agent domain value matches schema" do
      assert EventAttributes.event_domain_values().agent == :agent
    end

    @tag :unit
    test "compliance domain value matches schema" do
      assert EventAttributes.event_domain_values().compliance == :compliance
    end

    @tag :unit
    test "healing domain value matches schema" do
      assert EventAttributes.event_domain_values().healing == :healing
    end

    @tag :unit
    test "workflow domain value matches schema" do
      assert EventAttributes.event_domain_values().workflow == :workflow
    end

    @tag :unit
    test "system domain value matches schema" do
      assert EventAttributes.event_domain_values().system == :system
    end

    @tag :unit
    test "all 5 domain values are defined in schema" do
      values = EventAttributes.event_domain_values()
      assert map_size(values) == 5
    end
  end

  # ============================================================
  # EventAttributes — event.severity enum values
  # ============================================================

  describe "EventAttributes — event.severity enum values" do
    @tag :unit
    test "debug severity value matches schema" do
      assert EventAttributes.event_severity_values().debug == :debug
    end

    @tag :unit
    test "info severity value matches schema" do
      assert EventAttributes.event_severity_values().info == :info
    end

    @tag :unit
    test "warn severity value matches schema" do
      assert EventAttributes.event_severity_values().warn == :warn
    end

    @tag :unit
    test "error severity value matches schema" do
      assert EventAttributes.event_severity_values().error == :error
    end

    @tag :unit
    test "fatal severity value matches schema" do
      assert EventAttributes.event_severity_values().fatal == :fatal
    end

    @tag :unit
    test "all 5 severity values are defined in schema" do
      values = EventAttributes.event_severity_values()
      assert map_size(values) == 5
    end
  end

  # ============================================================
  # EventAttributes — typed submodule constants (compile-time enforcement)
  # ============================================================

  describe "EventAttributes — EventDomainValues submodule" do
    @tag :unit
    test "EventDomainValues.agent returns :agent atom" do
      assert EventAttributes.EventDomainValues.agent() == :agent
    end

    @tag :unit
    test "EventDomainValues.healing returns :healing atom" do
      assert EventAttributes.EventDomainValues.healing() == :healing
    end

    @tag :unit
    test "EventDomainValues.system returns :system atom" do
      assert EventAttributes.EventDomainValues.system() == :system
    end
  end

  describe "EventAttributes — EventSeverityValues submodule" do
    @tag :unit
    test "EventSeverityValues.info returns :info atom" do
      assert EventAttributes.EventSeverityValues.info() == :info
    end

    @tag :unit
    test "EventSeverityValues.error returns :error atom" do
      assert EventAttributes.EventSeverityValues.error() == :error
    end

    @tag :unit
    test "EventSeverityValues.fatal returns :fatal atom" do
      assert EventAttributes.EventSeverityValues.fatal() == :fatal
    end
  end
end
