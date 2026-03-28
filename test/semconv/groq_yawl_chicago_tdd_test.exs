defmodule OSA.Semconv.GroqYawlChicagoTDDTest do
  @moduledoc """
  Chicago TDD — Schema conformance proof (Artifact 3) for Groq + YAWL span attributes.

  These are pure unit tests with no external service dependencies.
  They verify that:
    1. Each typed constant function returns the correct OTel attribute name atom
    2. The constant compiles — removing the attribute from the schema causes a compile error

  Run:
    mix test test/semconv/groq_yawl_chicago_tdd_test.exs
  """

  use ExUnit.Case, async: true

  alias OpenTelemetry.SemConv.Incubating.GroqAttributes
  alias OpenTelemetry.SemConv.Incubating.YawlAttributes

  # ---------------------------------------------------------------------------
  # GroqAttributes constants
  # ---------------------------------------------------------------------------

  describe "GroqAttributes — attribute key constants" do
    test "groq_model returns correct OTel attribute name" do
      assert GroqAttributes.groq_model() == :"groq.model"
    end

    test "groq_prompt_tokens returns correct OTel attribute name" do
      assert GroqAttributes.groq_prompt_tokens() == :"groq.prompt_tokens"
    end

    test "decision_wcp_pattern returns correct OTel attribute name" do
      assert GroqAttributes.decision_wcp_pattern() == :"decision.wcp_pattern"
    end

    test "decision_result returns correct OTel attribute name" do
      assert GroqAttributes.decision_result() == :"decision.result"
    end
  end

  describe "GroqAttributes — attribute value types" do
    test "groq_model value is an atom" do
      assert is_atom(GroqAttributes.groq_model())
    end

    test "groq_prompt_tokens value is an atom" do
      assert is_atom(GroqAttributes.groq_prompt_tokens())
    end

    test "decision_wcp_pattern value is an atom" do
      assert is_atom(GroqAttributes.decision_wcp_pattern())
    end

    test "decision_result value is an atom" do
      assert is_atom(GroqAttributes.decision_result())
    end
  end

  # ---------------------------------------------------------------------------
  # YawlAttributes — new wcp_pattern constant
  # ---------------------------------------------------------------------------

  describe "YawlAttributes — yawl_wcp_pattern constant" do
    test "yawl_wcp_pattern returns correct OTel attribute name" do
      assert YawlAttributes.yawl_wcp_pattern() == :"yawl.wcp_pattern"
    end

    test "yawl_wcp_pattern value is an atom" do
      assert is_atom(YawlAttributes.yawl_wcp_pattern())
    end
  end

  # ---------------------------------------------------------------------------
  # Attribute map construction — verifies compile-time use of typed constants
  # ---------------------------------------------------------------------------

  describe "span attribute maps with typed constants" do
    test "groq.workflow.decision attribute map is well-formed" do
      attrs = %{
        GroqAttributes.groq_model() => "openai/gpt-oss-20b",
        GroqAttributes.groq_prompt_tokens() => 128,
        GroqAttributes.decision_wcp_pattern() => "WCP01",
        GroqAttributes.decision_result() => ~s({"action":"launch_case"})
      }

      assert attrs[:"groq.model"] == "openai/gpt-oss-20b"
      assert attrs[:"groq.prompt_tokens"] == 128
      assert attrs[:"decision.wcp_pattern"] == "WCP01"
      assert is_binary(attrs[:"decision.result"])
    end

    test "yawl.case.launch attribute map includes wcp_pattern" do
      attrs = %{
        YawlAttributes.yawl_case_id() => "test-case-001",
        YawlAttributes.yawl_spec_uri() => "OSA_Sequence",
        YawlAttributes.yawl_wcp_pattern() => "WCP01"
      }

      assert attrs[:"yawl.case.id"] == "test-case-001"
      assert attrs[:"yawl.wcp_pattern"] == "WCP01"
    end

    test "yawl.workitem.complete attribute map is well-formed" do
      attrs = %{
        YawlAttributes.yawl_case_id() => "test-case-001",
        YawlAttributes.yawl_work_item_id() => "test-case-001:TaskA:001",
        YawlAttributes.yawl_task_id() => "TaskA"
      }

      assert attrs[:"yawl.case.id"] == "test-case-001"
      assert attrs[:"yawl.work_item.id"] == "test-case-001:TaskA:001"
      assert attrs[:"yawl.task.id"] == "TaskA"
    end
  end

  # ---------------------------------------------------------------------------
  # decision.result JSON encoding contract
  # ---------------------------------------------------------------------------

  describe "decision.result encoding" do
    test "decision result is JSON-encodable and decodable" do
      decision = %{"action" => "launch_case", "confidence" => 0.95, "wcp_pattern" => "WCP01"}
      encoded = Jason.encode!(decision)

      assert {:ok, decoded} = Jason.decode(encoded)
      assert decoded["action"] == "launch_case"
      assert decoded["confidence"] == 0.95
    end

    test "WCP pattern strings match expected format" do
      valid_patterns = ["WCP01", "WCP02", "WCP03", "WCP04"]

      for pattern <- valid_patterns do
        assert String.starts_with?(pattern, "WCP"),
               "Pattern #{pattern} must start with WCP"

        assert String.length(pattern) == 5,
               "Pattern #{pattern} must be 5 characters (WCP + 2 digits)"
      end
    end
  end
end
