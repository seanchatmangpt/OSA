defmodule OptimalSystemAgent.Budget.ProviderRatesTest do
  use ExUnit.Case, async: true
  alias OptimalSystemAgent.Budget.ProviderRates

  describe "groq pricing" do
    test "groq_input is not the stale 0.27 flat rate" do
      refute ProviderRates.groq_input() == 0.27
    end

    test "groq_output is not the stale 0.27 flat rate" do
      refute ProviderRates.groq_output() == 0.27
    end

    test "groq input rate is in expected range" do
      assert ProviderRates.groq_input() >= 0.50
      assert ProviderRates.groq_input() <= 1.00
    end

    test "as_tuples includes groq" do
      rates = ProviderRates.as_tuples()
      assert Map.has_key?(rates, :groq)
      {input, output} = rates.groq
      assert input == ProviderRates.groq_input()
      assert output == ProviderRates.groq_output()
    end

    test "as_maps includes groq" do
      rates = ProviderRates.as_maps()
      assert Map.has_key?(rates, :groq)
      assert rates.groq.input == ProviderRates.groq_input()
    end
  end
end
