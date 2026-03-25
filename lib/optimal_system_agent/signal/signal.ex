defmodule OptimalSystemAgent.Signal do
  @moduledoc """
  Top-level Signal Theory module — wraps the 5-tuple signal struct.

  A Signal `S = (M, G, T, F, W)` encodes intent with maximal signal-to-noise
  ratio. All five dimensions must be resolved for a signal to be valid.

  ## Dimensions

  * `mode`     — operational action class: `:execute | :build | :analyze | :maintain | :assist`
  * `genre`    — communicative purpose: `:direct | :inform | :commit | :decide | :express`
  * `type`     — domain category string (e.g. `"question"`, `"request"`, `"issue"`)
  * `format`   — encoding container: `:text | :code | :json | :markdown | :binary`
  * `weight`   — informational density 0.0–1.0

  Reference: Luna, R. (2026). Signal Theory: The Architecture of Optimal
  Intent Encoding in Communication Systems. https://zenodo.org/records/18774174
  """

  @type signal_mode :: :execute | :build | :analyze | :maintain | :assist
  @type signal_genre :: :direct | :inform | :commit | :decide | :express
  @type signal_type :: :question | :request | :issue | :scheduling | :summary | :report | :general
  @type signal_format :: :text | :code | :json | :markdown | :binary

  @type t :: %__MODULE__{
          mode: signal_mode(),
          genre: signal_genre(),
          type: signal_type(),
          format: signal_format(),
          weight: float(),
          content: String.t(),
          metadata: map()
        }

  defstruct mode: :assist,
            genre: :direct,
            type: :general,
            format: :text,
            weight: 0.5,
            content: "",
            metadata: %{}

  @doc "Construct a signal from an attribute map."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc "Return `true` when all five dimensions hold valid enum values."
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{mode: m, genre: g, type: t, format: f})
      when m in [:execute, :build, :analyze, :maintain, :assist] and
             g in [:direct, :inform, :commit, :decide, :express] and
             t in [:question, :request, :issue, :scheduling, :summary, :report, :general] and
             f in [:text, :code, :json, :markdown, :binary],
      do: true

  def valid?(_), do: false

  @doc "Encode the signal as a minimal CloudEvents envelope."
  @spec to_cloud_event(t()) :: map()
  def to_cloud_event(%__MODULE__{} = signal) do
    %{
      specversion: "1.0",
      type: "com.osa.signal.#{signal.mode}",
      source: "osa-agent",
      id: :erlang.unique_integer([:positive]) |> to_string(),
      data: Map.from_struct(signal)
    }
  end

  @doc "Decode a signal from a CloudEvents envelope (best-effort)."
  @spec from_cloud_event(map()) :: t()
  def from_cloud_event(%{"data" => data}) when is_map(data) do
    new(for {k, v} <- data, into: %{}, do: {String.to_existing_atom(k), v})
  rescue
    _ -> new(%{})
  end

  def from_cloud_event(%{data: data}) when is_map(data) do
    new(for {k, v} <- data, into: %{}, do: {to_atom_key(k), v})
  rescue
    _ -> new(%{})
  end

  def from_cloud_event(_), do: new(%{})

  defp to_atom_key(k) when is_atom(k), do: k
  defp to_atom_key(k) when is_binary(k), do: String.to_existing_atom(k)

  @doc "Return the signal weight (proxy for signal-to-noise ratio)."
  @spec measure_sn_ratio(t()) :: float()
  def measure_sn_ratio(%__MODULE__{weight: w}), do: w
  def measure_sn_ratio(_), do: 0.5
end
