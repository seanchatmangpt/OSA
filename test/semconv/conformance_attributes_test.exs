defmodule OpenTelemetry.SemConv.ConformanceAttributesTest do
  @moduledoc """
  Chicago TDD validation tests for ConformanceAttributes semconv constants.

  These tests enforce schema drift prevention for the process conformance domain:
  - Compile error if semconv renames a conformance attribute
  - Documents the contract for conformance checking OTel attributes
  - Supports the pm4py-rust process mining conformance checking spans

  This is the third proof layer in the verification standard:
    1. OTEL span (execution proof)
    2. Test assertion (behavior proof)
    3. Schema conformance (weaver check + typed constants used here)

  Run with: mix test test/semconv/conformance_attributes_test.exs
  """
  use ExUnit.Case, async: true

  alias OpenTelemetry.SemConv.Incubating.ConformanceAttributes

  # ============================================================
  # ConformanceAttributes — attribute key constants
  # ============================================================

  describe "ConformanceAttributes — attribute keys" do
    @tag :unit
    test "conformance_fitness returns correct OTel attribute name" do
      assert ConformanceAttributes.conformance_fitness() == :"conformance.fitness"
    end

    @tag :unit
    test "conformance_precision returns correct OTel attribute name" do
      assert ConformanceAttributes.conformance_precision() == :"conformance.precision"
    end
  end

  # ============================================================
  # ConformanceAttributes — value type and range semantics
  # ============================================================

  describe "ConformanceAttributes — value range contracts" do
    @tag :unit
    test "conformance_fitness attribute name is a namespaced atom" do
      key = ConformanceAttributes.conformance_fitness()
      assert is_atom(key)
      assert key |> Atom.to_string() |> String.starts_with?("conformance.")
    end

    @tag :unit
    test "conformance_precision attribute name is a namespaced atom" do
      key = ConformanceAttributes.conformance_precision()
      assert is_atom(key)
      assert key |> Atom.to_string() |> String.starts_with?("conformance.")
    end

    @tag :unit
    test "conformance attribute keys are two distinct namespaced atoms" do
      fitness = ConformanceAttributes.conformance_fitness()
      precision = ConformanceAttributes.conformance_precision()
      assert fitness == :"conformance.fitness"
      assert precision == :"conformance.precision"
    end
  end

  # ============================================================
  # ConformanceAttributes — module presence (schema completeness)
  # ============================================================

  describe "ConformanceAttributes — module is loaded" do
    @tag :unit
    test "ConformanceAttributes module is compiled and available" do
      assert Code.ensure_loaded?(OpenTelemetry.SemConv.Incubating.ConformanceAttributes)
    end

    @tag :unit
    test "conformance_fitness/0 returns the correct atom when called" do
      assert ConformanceAttributes.conformance_fitness() == :"conformance.fitness"
    end

    @tag :unit
    test "conformance_precision/0 returns the correct atom when called" do
      assert ConformanceAttributes.conformance_precision() == :"conformance.precision"
    end
  end
end
