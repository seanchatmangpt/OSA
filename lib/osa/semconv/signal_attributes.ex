defmodule OpenTelemetry.SemConv.Incubating.SignalAttributes do
  @moduledoc """
  Signal semantic convention attributes.

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with `weaver registry generate elixir`.
  """

  @doc """
  The classifier module or model that analyzed and scored the signal.

  Stability: `development`
  """
  @spec signal_classifier() :: :"signal.classifier"
  def signal_classifier, do: :"signal.classifier"

  @doc """
  The format component (F) of the signal — the container or serialization format.

  Stability: `development`
  """
  @spec signal_format() :: :"signal.format"
  def signal_format, do: :"signal.format"

  @doc """
  Values for `signal.format`.
  """
  @spec signal_format_values() :: %{
    markdown: :markdown,
    code: :code,
    json: :json,
    yaml: :yaml,
    html: :html,
    text: :text
  }
  def signal_format_values do
    %{
      markdown: :markdown,
      code: :code,
      json: :json,
      yaml: :yaml,
      html: :html,
      text: :text
    }
  end

  @doc """
  The genre component (G) of the signal — the document or interaction type.

  Stability: `development`
  """
  @spec signal_genre() :: :"signal.genre"
  def signal_genre, do: :"signal.genre"

  @doc """
  Values for `signal.genre`.
  """
  @spec signal_genre_values() :: %{
    spec: :spec,
    brief: :brief,
    report: :report,
    plan: :plan,
    adr: :adr,
    email: :email,
    code_review: :code_review
  }
  def signal_genre_values do
    %{
      spec: :spec,
      brief: :brief,
      report: :report,
      plan: :plan,
      adr: :adr,
      email: :email,
      code_review: :code_review
    }
  end

  @doc """
  The mode component (M) of the signal — how information is encoded.

  Stability: `development`
  """
  @spec signal_mode() :: :"signal.mode"
  def signal_mode, do: :"signal.mode"

  @doc """
  Values for `signal.mode`.
  """
  @spec signal_mode_values() :: %{
    linguistic: :linguistic,
    visual: :visual,
    code: :code,
    data: :data,
    mixed: :mixed
  }
  def signal_mode_values do
    %{
      linguistic: :linguistic,
      visual: :visual,
      code: :code,
      data: :data,
      mixed: :mixed
    }
  end

  @doc """
  Noise level of the signal in range [0.0, 1.0]. Complement of signal weight for clean signals.

  Stability: `development`
  """
  @spec signal_noise_level() :: :"signal.noise_level"
  def signal_noise_level, do: :"signal.noise_level"

  @doc """
  The source channel through which the signal was received.

  Stability: `development`
  """
  @spec signal_source() :: :"signal.source"
  def signal_source, do: :"signal.source"

  @doc """
  The type component (T) of the signal — the speech act or communicative intent.

  Stability: `development`
  """
  @spec signal_type() :: :"signal.type"
  def signal_type, do: :"signal.type"

  @doc """
  Values for `signal.type`.
  """
  @spec signal_type_values() :: %{
    direct: :direct,
    inform: :inform,
    commit: :commit,
    decide: :decide,
    express: :express
  }
  def signal_type_values do
    %{
      direct: :direct,
      inform: :inform,
      commit: :commit,
      decide: :decide,
      express: :express
    }
  end

  @doc """
  Signal weight (W) — signal-to-noise ratio in range [0.0, 1.0]. Values >= 0.7 pass the S/N gate.

  Stability: `development`
  """
  @spec signal_weight() :: :"signal.weight"
  def signal_weight, do: :"signal.weight"
end