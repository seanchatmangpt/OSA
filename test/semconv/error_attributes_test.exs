defmodule OpenTelemetry.SemConv.ErrorAttributesTest do
  @moduledoc """
  Chicago TDD validation tests for ErrorAttributes semconv constants.

  These tests enforce schema drift prevention for the error domain:
  - Compile error if semconv renames error.type attribute
  - Enum value removal caught by undefined function error at compile time
  - Documents the contract for error classification OTel attributes
  - Used in healing diagnosis and fault tolerance spans

  This is the third proof layer in the verification standard:
    1. OTEL span (execution proof)
    2. Test assertion (behavior proof)
    3. Schema conformance (weaver check + typed constants used here)

  Run with: mix test test/semconv/error_attributes_test.exs
  """
  use ExUnit.Case, async: true

  alias OpenTelemetry.SemConv.Incubating.ErrorAttributes

  # ============================================================
  # ErrorAttributes — attribute key constant
  # ============================================================

  describe "ErrorAttributes — attribute keys" do
    @tag :unit
    test "error_type returns correct OTel attribute name" do
      assert ErrorAttributes.error_type() == :"error.type"
    end

    @tag :unit
    test "error_type attribute name is a namespaced atom" do
      key = ErrorAttributes.error_type()
      assert is_atom(key)
      assert key |> Atom.to_string() |> String.starts_with?("error.")
    end
  end

  # ============================================================
  # ErrorAttributes — error.type enum values
  # ============================================================

  describe "ErrorAttributes — error.type enum values" do
    @tag :unit
    test "timeout error type value matches schema" do
      assert ErrorAttributes.error_type_values().timeout == :timeout
    end

    @tag :unit
    test "cancelled error type value matches schema" do
      assert ErrorAttributes.error_type_values().cancelled == :cancelled
    end

    @tag :unit
    test "internal error type value matches schema" do
      assert ErrorAttributes.error_type_values().internal == :internal
    end

    @tag :unit
    test "unavailable error type value matches schema" do
      assert ErrorAttributes.error_type_values().unavailable == :unavailable
    end

    @tag :unit
    test "all 4 error type values are defined in schema" do
      values = ErrorAttributes.error_type_values()
      assert map_size(values) == 4
    end
  end

  # ============================================================
  # ErrorAttributes — typed submodule constants (compile-time enforcement)
  # ============================================================

  describe "ErrorAttributes — ErrorTypeValues submodule" do
    @tag :unit
    test "ErrorTypeValues.timeout returns :timeout atom" do
      assert ErrorAttributes.ErrorTypeValues.timeout() == :timeout
    end

    @tag :unit
    test "ErrorTypeValues.cancelled returns :cancelled atom" do
      assert ErrorAttributes.ErrorTypeValues.cancelled() == :cancelled
    end

    @tag :unit
    test "ErrorTypeValues.internal returns :internal atom" do
      assert ErrorAttributes.ErrorTypeValues.internal() == :internal
    end

    @tag :unit
    test "ErrorTypeValues.unavailable returns :unavailable atom" do
      assert ErrorAttributes.ErrorTypeValues.unavailable() == :unavailable
    end
  end

  # ============================================================
  # ErrorAttributes — module presence (schema completeness)
  # ============================================================

  describe "ErrorAttributes — module is loaded" do
    @tag :unit
    test "ErrorAttributes module is compiled and available" do
      assert Code.ensure_loaded?(OpenTelemetry.SemConv.Incubating.ErrorAttributes)
    end

    @tag :unit
    test "ErrorTypeValues submodule is compiled and available" do
      assert Code.ensure_loaded?(OpenTelemetry.SemConv.Incubating.ErrorAttributes.ErrorTypeValues)
    end

    @tag :unit
    test "error_type/0 returns the correct atom when called" do
      assert ErrorAttributes.error_type() == :"error.type"
    end

    @tag :unit
    test "error_type_values/0 returns a map with 4 entries when called" do
      values = ErrorAttributes.error_type_values()
      assert is_map(values)
      assert map_size(values) == 4
    end
  end
end
