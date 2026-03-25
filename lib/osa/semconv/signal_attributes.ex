defmodule OpenTelemetry.SemConv.Incubating.SignalAttributes do
  @moduledoc """
  Signal semantic convention attributes.

  Namespace: `signal`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Effective information bandwidth as fraction of total tokens [0.0, 1.0].

  Attribute: `signal.bandwidth`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.6`
  """
  @spec signal_bandwidth() :: :"signal.bandwidth"
  def signal_bandwidth, do: :"signal.bandwidth"

  @doc """
  The classifier module or model that analyzed and scored the signal.

  Attribute: `signal.classifier`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa.signal.classifier`, `canopy.signal_router`, `bos.signal_gate`
  """
  @spec signal_classifier() :: :"signal.classifier"
  def signal_classifier, do: :"signal.classifier"

  @doc """
  The format component (F) of the signal — the container or serialization format.

  Attribute: `signal.format`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `markdown`, `json`, `yaml`
  """
  @spec signal_format() :: :"signal.format"
  def signal_format, do: :"signal.format"

  @doc """
  Enumerated values for `signal.format`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `markdown` | `"markdown"` | Markdown formatted text |
  | `code` | `"code"` | Raw source code |
  | `json` | `"json"` | JSON structured data |
  | `yaml` | `"yaml"` | YAML structured data |
  | `html` | `"html"` | HTML document |
  | `text` | `"text"` | Plain text |
  | `table` | `"table"` | Tabular data |
  | `diagram` | `"diagram"` | Visual diagram description |
  """
  @spec signal_format_values() :: %{
    markdown: :markdown,
    code: :code,
    json: :json,
    yaml: :yaml,
    html: :html,
    text: :text,
    table: :table,
    diagram: :diagram
  }
  def signal_format_values do
    %{
      markdown: :markdown,
      code: :code,
      json: :json,
      yaml: :yaml,
      html: :html,
      text: :text,
      table: :table,
      diagram: :diagram
    }
  end

  defmodule SignalFormatValues do
    @moduledoc """
    Typed constants for the `signal.format` attribute.
    """

    @doc "Markdown formatted text"
    @spec markdown() :: :markdown
    def markdown, do: :markdown

    @doc "Raw source code"
    @spec code() :: :code
    def code, do: :code

    @doc "JSON structured data"
    @spec json() :: :json
    def json, do: :json

    @doc "YAML structured data"
    @spec yaml() :: :yaml
    def yaml, do: :yaml

    @doc "HTML document"
    @spec html() :: :html
    def html, do: :html

    @doc "Plain text"
    @spec text() :: :text
    def text, do: :text

    @doc "Tabular data"
    @spec table() :: :table
    def table, do: :table

    @doc "Visual diagram description"
    @spec diagram() :: :diagram
    def diagram, do: :diagram

  end

  @doc """
  The genre component (G) of the signal — the document or interaction type.

  Attribute: `signal.genre`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `spec`, `adr`, `report`
  """
  @spec signal_genre() :: :"signal.genre"
  def signal_genre, do: :"signal.genre"

  @doc """
  Enumerated values for `signal.genre`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `spec` | `"spec"` | Technical specification document |
  | `brief` | `"brief"` | Short summary or briefing |
  | `report` | `"report"` | Analysis or status report |
  | `plan` | `"plan"` | Execution or project plan |
  | `adr` | `"adr"` | Architecture Decision Record |
  | `email` | `"email"` | Email or message communication |
  | `code_review` | `"code_review"` | Code review feedback |
  | `pitch` | `"pitch"` | Sales pitch or proposal presentation |
  | `decision` | `"decision"` | Formal decision record or ruling |
  | `analysis` | `"analysis"` | Deep-dive analysis or investigation |
  """
  @spec signal_genre_values() :: %{
    spec: :spec,
    brief: :brief,
    report: :report,
    plan: :plan,
    adr: :adr,
    email: :email,
    code_review: :code_review,
    pitch: :pitch,
    decision: :decision,
    analysis: :analysis
  }
  def signal_genre_values do
    %{
      spec: :spec,
      brief: :brief,
      report: :report,
      plan: :plan,
      adr: :adr,
      email: :email,
      code_review: :code_review,
      pitch: :pitch,
      decision: :decision,
      analysis: :analysis
    }
  end

  defmodule SignalGenreValues do
    @moduledoc """
    Typed constants for the `signal.genre` attribute.
    """

    @doc "Technical specification document"
    @spec spec() :: :spec
    def spec, do: :spec

    @doc "Short summary or briefing"
    @spec brief() :: :brief
    def brief, do: :brief

    @doc "Analysis or status report"
    @spec report() :: :report
    def report, do: :report

    @doc "Execution or project plan"
    @spec plan() :: :plan
    def plan, do: :plan

    @doc "Architecture Decision Record"
    @spec adr() :: :adr
    def adr, do: :adr

    @doc "Email or message communication"
    @spec email() :: :email
    def email, do: :email

    @doc "Code review feedback"
    @spec code_review() :: :code_review
    def code_review, do: :code_review

    @doc "Sales pitch or proposal presentation"
    @spec pitch() :: :pitch
    def pitch, do: :pitch

    @doc "Formal decision record or ruling"
    @spec decision() :: :decision
    def decision, do: :decision

    @doc "Deep-dive analysis or investigation"
    @spec analysis() :: :analysis
    def analysis, do: :analysis

  end

  @doc """
  Signal propagation latency in milliseconds from generation to delivery.

  Attribute: `signal.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `12`, `250`, `1500`
  """
  @spec signal_latency_ms() :: :"signal.latency_ms"
  def signal_latency_ms, do: :"signal.latency_ms"

  @doc """
  The mode component (M) of the signal — how information is encoded.

  Attribute: `signal.mode`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `linguistic`, `code`, `data`
  """
  @spec signal_mode() :: :"signal.mode"
  def signal_mode, do: :"signal.mode"

  @doc """
  Enumerated values for `signal.mode`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `linguistic` | `"linguistic"` | Natural language text output |
  | `visual` | `"visual"` | Visual or diagrammatic output |
  | `code` | `"code"` | Source code or executable artifact |
  | `data` | `"data"` | Structured data payload (JSON, YAML, CSV) |
  | `mixed` | `"mixed"` | Combination of multiple modes |
  | `cognitive` | `"cognitive"` | High-level reasoning output |
  | `operational` | `"operational"` | System operation signal |
  | `reactive` | `"reactive"` | Response to stimulus |
  """
  @spec signal_mode_values() :: %{
    linguistic: :linguistic,
    visual: :visual,
    code: :code,
    data: :data,
    mixed: :mixed,
    cognitive: :cognitive,
    operational: :operational,
    reactive: :reactive
  }
  def signal_mode_values do
    %{
      linguistic: :linguistic,
      visual: :visual,
      code: :code,
      data: :data,
      mixed: :mixed,
      cognitive: :cognitive,
      operational: :operational,
      reactive: :reactive
    }
  end

  defmodule SignalModeValues do
    @moduledoc """
    Typed constants for the `signal.mode` attribute.
    """

    @doc "Natural language text output"
    @spec linguistic() :: :linguistic
    def linguistic, do: :linguistic

    @doc "Visual or diagrammatic output"
    @spec visual() :: :visual
    def visual, do: :visual

    @doc "Source code or executable artifact"
    @spec code() :: :code
    def code, do: :code

    @doc "Structured data payload (JSON, YAML, CSV)"
    @spec data() :: :data
    def data, do: :data

    @doc "Combination of multiple modes"
    @spec mixed() :: :mixed
    def mixed, do: :mixed

    @doc "High-level reasoning output"
    @spec cognitive() :: :cognitive
    def cognitive, do: :cognitive

    @doc "System operation signal"
    @spec operational() :: :operational
    def operational, do: :operational

    @doc "Response to stimulus"
    @spec reactive() :: :reactive
    def reactive, do: :reactive

  end

  @doc """
  Noise level of the signal in range [0.0, 1.0]. Complement of signal weight for clean signals.

  Attribute: `signal.noise_level`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.05`, `0.25`, `0.58`
  """
  @spec signal_noise_level() :: :"signal.noise_level"
  def signal_noise_level, do: :"signal.noise_level"

  @doc """
  Shannon signal-to-noise ratio score in range [0.0, 1.0]. Values >= 0.7 pass the S/N gate for transmission.

  Attribute: `signal.sn_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.92`, `0.71`, `0.35`
  """
  @spec signal_sn_ratio() :: :"signal.sn_ratio"
  def signal_sn_ratio, do: :"signal.sn_ratio"

  @doc """
  The source channel through which the signal was received.

  Attribute: `signal.source`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `http`, `websocket`, `telegram`, `discord`, `slack`, `cli`
  """
  @spec signal_source() :: :"signal.source"
  def signal_source, do: :"signal.source"

  @doc """
  The type component (T) of the signal — the speech act or communicative intent.

  Attribute: `signal.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `direct`, `inform`, `decide`
  """
  @spec signal_type() :: :"signal.type"
  def signal_type, do: :"signal.type"

  @doc """
  Enumerated values for `signal.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `direct` | `"direct"` | Direct instruction or command |
  | `inform` | `"inform"` | Information transfer without action required |
  | `commit` | `"commit"` | Commitment or promise of future action |
  | `decide` | `"decide"` | Decision that changes system state |
  | `express` | `"express"` | Expressive or emotive content |
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

  defmodule SignalTypeValues do
    @moduledoc """
    Typed constants for the `signal.type` attribute.
    """

    @doc "Direct instruction or command"
    @spec direct() :: :direct
    def direct, do: :direct

    @doc "Information transfer without action required"
    @spec inform() :: :inform
    def inform, do: :inform

    @doc "Commitment or promise of future action"
    @spec commit() :: :commit
    def commit, do: :commit

    @doc "Decision that changes system state"
    @spec decide() :: :decide
    def decide, do: :decide

    @doc "Expressive or emotive content"
    @spec express() :: :express
    def express, do: :express

  end

  @doc """
  Signal weight (W) — signal-to-noise ratio in range [0.0, 1.0]. Values >= 0.7 pass the S/N gate.

  Attribute: `signal.weight`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.75`, `0.42`
  """
  @spec signal_weight() :: :"signal.weight"
  def signal_weight, do: :"signal.weight"

  @doc """
  Dispatch priority of the signal through the routing layer.

  Attribute: `signal.priority`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `high`, `normal`, `low`
  """
  @spec signal_priority :: :"signal.priority"
  def signal_priority, do: :"signal.priority"

  @doc """
  Enumerated values for `signal.priority`.
  """
  @spec signal_priority_values() :: %{critical: :critical, high: :high, normal: :normal, low: :low}
  def signal_priority_values, do: %{critical: :critical, high: :high, normal: :normal, low: :low}

  @doc """
  Encoding scheme applied to the signal payload.

  Attribute: `signal.encoding`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `utf8`, `base64`, `msgpack`
  """
  @spec signal_encoding :: :"signal.encoding"
  def signal_encoding, do: :"signal.encoding"

  @doc """
  Number of hops the signal has traversed across routing layers.

  Attribute: `signal.hop_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `7`
  """
  @spec signal_hop_count :: :"signal.hop_count"
  def signal_hop_count, do: :"signal.hop_count"

end