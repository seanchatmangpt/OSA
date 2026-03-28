defmodule OpenTelemetry.SemConv.Incubating.OsaAttributes do
  @moduledoc """
  Osa semantic convention attributes.

  Namespace: `osa`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Wall-clock duration in milliseconds for the provider call.

  Attribute: `osa.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `120`, `450`, `2300`
  """
  @spec osa_duration_ms() :: :"osa.duration_ms"
  def osa_duration_ms, do: :"osa.duration_ms"

  @doc """
  Model identifier used for this chat completion.

  Attribute: `osa.model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-3-5-sonnet-20241022`, `llama3.2`, `command-r`
  """
  @spec osa_model() :: :"osa.model"
  def osa_model, do: :"osa.model"

  @doc """
  LLM provider used for this chat completion.

  Attribute: `osa.provider`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `anthropic`, `ollama`, `cohere`
  """
  @spec osa_provider() :: :"osa.provider"
  def osa_provider, do: :"osa.provider"

  @doc """
  Enumerated values for `osa.provider`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `anthropic` | `"anthropic"` | anthropic |
  | `ollama` | `"ollama"` | ollama |
  | `cohere` | `"cohere"` | cohere |
  | `google` | `"google"` | google |
  | `replicate` | `"replicate"` | replicate |
  | `openai` | `"openai"` | openai |
  """
  @spec osa_provider_values() :: %{
    anthropic: :anthropic,
    ollama: :ollama,
    cohere: :cohere,
    google: :google,
    replicate: :replicate,
    openai: :openai
  }
  def osa_provider_values do
    %{
      anthropic: :anthropic,
      ollama: :ollama,
      cohere: :cohere,
      google: :google,
      replicate: :replicate,
      openai: :openai
    }
  end

  defmodule OsaProviderValues do
    @moduledoc """
    Typed constants for the `osa.provider` attribute.
    """

    @doc "anthropic"
    @spec anthropic() :: :anthropic
    def anthropic, do: :anthropic

    @doc "ollama"
    @spec ollama() :: :ollama
    def ollama, do: :ollama

    @doc "cohere"
    @spec cohere() :: :cohere
    def cohere, do: :cohere

    @doc "google"
    @spec google() :: :google
    def google, do: :google

    @doc "replicate"
    @spec replicate() :: :replicate
    def replicate, do: :replicate

    @doc "openai"
    @spec openai() :: :openai
    def openai, do: :openai

  end

end