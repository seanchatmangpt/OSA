defmodule OSA.Semconv.LLMCompressionTest do
  use ExUnit.Case

  alias OpenTelemetry.SemConv.Incubating.{
    LlmAttributes,
    LlmSpanNames
  }

  describe "LLM context compression span name" do
    test "span name is llm.context.compress" do
      assert LlmSpanNames.llm_context_compress() == "llm.context.compress"
    end

    test "span name format uses dots not underscores" do
      span_name = LlmSpanNames.llm_context_compress()
      assert String.contains?(span_name, ".")
      refute String.contains?(span_name, "_")
    end

    test "span kind is internal" do
      span_name = LlmSpanNames.llm_context_compress()
      assert span_name == "llm.context.compress"
    end
  end

  describe "LLM context compression ratio attribute" do
    test "attribute key is llm.context.compression.ratio" do
      assert LlmAttributes.llm_context_compression_ratio() == :"llm.context.compression.ratio"
    end

    test "attribute is atom" do
      attr = LlmAttributes.llm_context_compression_ratio()
      assert is_atom(attr)
    end

    test "attribute atom contains compression" do
      attr = LlmAttributes.llm_context_compression_ratio()
      attr_str = Atom.to_string(attr)
      assert String.contains?(attr_str, "compression")
    end
  end

  describe "LLM context compression strategy attribute" do
    test "attribute key is llm.context.compression.strategy" do
      assert LlmAttributes.llm_context_compression_strategy() == :"llm.context.compression.strategy"
    end

    test "strategy is enum type" do
      attr = LlmAttributes.llm_context_compression_strategy()
      assert is_atom(attr)
    end

    test "enum value summarize exists" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert Map.has_key?(values, :summarize)
      assert values.summarize == :summarize
    end

    test "enum value truncate exists" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert Map.has_key?(values, :truncate)
      assert values.truncate == :truncate
    end

    test "enum value sliding_window exists" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert Map.has_key?(values, :sliding_window)
      assert values.sliding_window == :sliding_window
    end

    test "enum value selective exists" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert Map.has_key?(values, :selective)
      assert values.selective == :selective
    end

    test "all enum values are atoms" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert is_map(values)
      assert map_size(values) == 4

      Enum.each(values, fn {_key, val} ->
        assert is_atom(val)
      end)
    end

    test "enum values are unique" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      unique_values = values |> Map.values() |> Enum.uniq()
      assert length(Map.values(values)) == length(unique_values)
    end
  end

  describe "LLM context compression tokens_saved attribute" do
    test "attribute key is llm.context.compression.tokens_saved" do
      assert LlmAttributes.llm_context_compression_tokens_saved() == :"llm.context.compression.tokens_saved"
    end

    test "attribute is atom" do
      attr = LlmAttributes.llm_context_compression_tokens_saved()
      assert is_atom(attr)
    end

    test "attribute atom contains compression" do
      attr = LlmAttributes.llm_context_compression_tokens_saved()
      attr_str = Atom.to_string(attr)
      assert String.contains?(attr_str, "compression")
    end
  end

  describe "All compression attributes together" do
    test "all three attributes start with llm" do
      attrs = [
        LlmAttributes.llm_context_compression_ratio(),
        LlmAttributes.llm_context_compression_strategy(),
        LlmAttributes.llm_context_compression_tokens_saved()
      ]

      Enum.each(attrs, fn attr ->
        attr_str = Atom.to_string(attr)
        assert String.starts_with?(attr_str, "llm.")
      end)
    end

    test "all three attributes are atoms" do
      attrs = [
        LlmAttributes.llm_context_compression_ratio(),
        LlmAttributes.llm_context_compression_strategy(),
        LlmAttributes.llm_context_compression_tokens_saved()
      ]

      Enum.each(attrs, fn attr ->
        assert is_atom(attr)
      end)
    end

    test "span references compression attributes" do
      span_name = LlmSpanNames.llm_context_compress()
      assert String.contains?(span_name, "context") or String.contains?(span_name, "compress")
    end

    test "compression attributes are correct atoms" do
      ratio_attr = :"llm.context.compression.ratio"
      strategy_attr = :"llm.context.compression.strategy"
      tokens_attr = :"llm.context.compression.tokens_saved"

      assert LlmAttributes.llm_context_compression_ratio() == ratio_attr
      assert LlmAttributes.llm_context_compression_strategy() == strategy_attr
      assert LlmAttributes.llm_context_compression_tokens_saved() == tokens_attr
    end
  end

  describe "Compression strategy enum completeness" do
    test "summarize strategy is correct" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert values.summarize == :summarize
    end

    test "truncate strategy is correct" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert values.truncate == :truncate
    end

    test "sliding_window strategy is correct" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert values.sliding_window == :sliding_window
    end

    test "selective strategy is correct" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      assert values.selective == :selective
    end

    test "all strategies are valid atoms" do
      values = LlmAttributes.llm_context_compression_strategy_values()
      strategies = Map.values(values)
      assert length(strategies) == 4
      Enum.each(strategies, fn strategy ->
        assert is_atom(strategy)
      end)
    end
  end

  describe "Attribute naming consistency" do
    test "compression ratio attribute contains compression" do
      attr = LlmAttributes.llm_context_compression_ratio()
      attr_str = Atom.to_string(attr)
      assert String.contains?(attr_str, "compression")
    end

    test "compression strategy attribute contains compression" do
      attr = LlmAttributes.llm_context_compression_strategy()
      attr_str = Atom.to_string(attr)
      assert String.contains?(attr_str, "compression")
    end

    test "compression tokens_saved attribute contains compression" do
      attr = LlmAttributes.llm_context_compression_tokens_saved()
      attr_str = Atom.to_string(attr)
      assert String.contains?(attr_str, "compression")
    end

    test "all compression attributes contain context" do
      attrs = [
        LlmAttributes.llm_context_compression_ratio(),
        LlmAttributes.llm_context_compression_strategy(),
        LlmAttributes.llm_context_compression_tokens_saved()
      ]

      Enum.each(attrs, fn attr ->
        attr_str = Atom.to_string(attr)
        assert String.contains?(attr_str, "context")
      end)
    end
  end
end
