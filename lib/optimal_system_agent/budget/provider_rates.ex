defmodule OptimalSystemAgent.Budget.ProviderRates do
  @moduledoc """
  Shared compile-time pricing constants for all LLM providers.

  Rates are in USD per 1M tokens. Both tuple format (for Budget GenServer)
  and map format (for Agent.Budget GenServer) are exposed so all budget
  modules derive from the same source of truth.

  ## Rates (USD per 1M tokens)

  | Provider      | Input  | Output |
  |---------------|--------|--------|
  | `:groq`       | 0.59   | 0.79   |
  | `:anthropic`  | 3.0    | 15.0   |
  | `:openai`     | 2.5    | 10.0   |
  | `:openrouter` | 2.0    | 6.0    |
  | `:ollama`     | 0.0    | 0.0    |
  | `:default`    | 1.0    | 3.0    |
  """

  @rates %{
    groq: {0.59, 0.79},
    anthropic: {3.0, 15.0},
    openai: {2.5, 10.0},
    openrouter: {2.0, 6.0},
    ollama: {0.0, 0.0},
    default: {1.0, 3.0}
  }

  @doc "Returns all provider rates as `%{provider: {input_rate, output_rate}}`."
  @spec as_tuples() :: %{atom() => {float(), float()}}
  def as_tuples, do: @rates

  @doc "Returns all provider rates as `%{provider: %{input: rate, output: rate}}`."
  @spec as_maps() :: %{atom() => %{input: float(), output: float()}}
  def as_maps do
    Map.new(@rates, fn {provider, {input, output}} ->
      {provider, %{input: input, output: output}}
    end)
  end

  @doc "Groq input rate in USD per 1M tokens."
  @spec groq_input() :: float()
  def groq_input do
    {input, _output} = @rates.groq
    input
  end

  @doc "Groq output rate in USD per 1M tokens."
  @spec groq_output() :: float()
  def groq_output do
    {_input, output} = @rates.groq
    output
  end
end
