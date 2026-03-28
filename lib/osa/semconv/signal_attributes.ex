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
  @spec signal_bandwidth() :: :signal_bandwidth
  def signal_bandwidth, do: :signal_bandwidth

  @doc """
  Number of signals dropped during batch aggregation due to capacity limits.

  Attribute: `signal.batch.drop_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `12`
  """
  @spec signal_batch_drop_count() :: :signal_batch_drop_count
  def signal_batch_drop_count, do: :signal_batch_drop_count

  @doc """
  Number of signals in the batch aggregate.

  Attribute: `signal.batch.size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `50`, `200`
  """
  @spec signal_batch_size() :: :signal_batch_size
  def signal_batch_size, do: :signal_batch_size

  @doc """
  Time window in milliseconds over which signals are batched.

  Attribute: `signal.batch.window_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `1000`
  """
  @spec signal_batch_window_ms() :: :signal_batch_window_ms
  def signal_batch_window_ms, do: :signal_batch_window_ms

  @doc """
  The identifier of the channel this signal is transmitted through.

  Attribute: `signal.channel.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `chan-001`, `priority-queue-high`, `broadcast-main`
  """
  @spec signal_channel_id() :: :signal_channel_id
  def signal_channel_id, do: :signal_channel_id

  @doc """
  The classifier module or model that analyzed and scored the signal.

  Attribute: `signal.classifier`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `osa.signal.classifier`, `canopy.signal_router`, `bos.signal_gate`
  """
  @spec signal_classifier() :: :signal_classifier
  def signal_classifier, do: :signal_classifier

  @doc """
  Compression ratio applied to the signal [0.0, 1.0]. 1.0 = no compression.

  Attribute: `signal.compression.ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0`, `0.7`, `0.3`
  """
  @spec signal_compression_ratio() :: :signal_compression_ratio
  def signal_compression_ratio, do: :signal_compression_ratio

  @doc """
  Wire encoding format used to serialize the signal payload.

  Attribute: `signal.encoding`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `json`, `protobuf`
  """
  @spec signal_encoding() :: :signal_encoding
  def signal_encoding, do: :signal_encoding

  @doc """
  Enumerated values for `signal.encoding`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `json` | `"json"` | json |
  | `protobuf` | `"protobuf"` | protobuf |
  | `msgpack` | `"msgpack"` | msgpack |
  | `plain` | `"plain"` | plain |
  """
  @spec signal_encoding_values() :: %{
    json: :json,
    protobuf: :protobuf,
    msgpack: :msgpack,
    plain: :plain
  }
  def signal_encoding_values do
    %{
      json: :json,
      protobuf: :protobuf,
      msgpack: :msgpack,
      plain: :plain
    }
  end

  defmodule SignalEncodingValues do
    @moduledoc """
    Typed constants for the `signal.encoding` attribute.
    """

    @doc "json"
    @spec json() :: :json
    def json, do: :json

    @doc "protobuf"
    @spec protobuf() :: :protobuf
    def protobuf, do: :protobuf

    @doc "msgpack"
    @spec msgpack() :: :msgpack
    def msgpack, do: :msgpack

    @doc "plain"
    @spec plain() :: :plain
    def plain, do: :plain

  end

  @doc """
  The format component (F) of the signal — the container or serialization format.

  Attribute: `signal.format`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `markdown`, `json`, `yaml`
  """
  @spec signal_format() :: :signal_format
  def signal_format, do: :signal_format

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
  @spec signal_genre() :: :signal_genre
  def signal_genre, do: :signal_genre

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
  Number of routing hops the signal traversed before reaching the final destination.

  Attribute: `signal.hop_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec signal_hop_count() :: :signal_hop_count
  def signal_hop_count, do: :signal_hop_count

  @doc """
  Signal propagation latency in milliseconds from generation to delivery.

  Attribute: `signal.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `12`, `250`, `1500`
  """
  @spec signal_latency_ms() :: :signal_latency_ms
  def signal_latency_ms, do: :signal_latency_ms

  @doc """
  The mode component (M) of the signal — how information is encoded.

  Attribute: `signal.mode`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `linguistic`, `code`, `data`
  """
  @spec signal_mode() :: :signal_mode
  def signal_mode, do: :signal_mode

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
  @spec signal_noise_level() :: :signal_noise_level
  def signal_noise_level, do: :signal_noise_level

  @doc """
  Priority level of the signal for queue ordering and routing decisions.

  Attribute: `signal.priority`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `critical`, `high`
  """
  @spec signal_priority() :: :signal_priority
  def signal_priority, do: :signal_priority

  @doc """
  Enumerated values for `signal.priority`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `critical` | `"critical"` | critical |
  | `high` | `"high"` | high |
  | `normal` | `"normal"` | normal |
  | `low` | `"low"` | low |
  """
  @spec signal_priority_values() :: %{
    critical: :critical,
    high: :high,
    normal: :normal,
    low: :low
  }
  def signal_priority_values do
    %{
      critical: :critical,
      high: :high,
      normal: :normal,
      low: :low
    }
  end

  defmodule SignalPriorityValues do
    @moduledoc """
    Typed constants for the `signal.priority` attribute.
    """

    @doc "critical"
    @spec critical() :: :critical
    def critical, do: :critical

    @doc "high"
    @spec high() :: :high
    def high, do: :high

    @doc "normal"
    @spec normal() :: :normal
    def normal, do: :normal

    @doc "low"
    @spec low() :: :low
    def low, do: :low

  end

  @doc """
  Whether signal quality has degraded below acceptable threshold.

  Attribute: `signal.quality.degraded`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec signal_quality_degraded() :: :signal_quality_degraded
  def signal_quality_degraded, do: :signal_quality_degraded

  @doc """
  Composite quality score for the signal, range [0.0, 1.0]. Combines S/N ratio, bandwidth, and latency metrics.

  Attribute: `signal.quality.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.72`, `0.5`
  """
  @spec signal_quality_score() :: :signal_quality_score
  def signal_quality_score, do: :signal_quality_score

  @doc """
  The configured S/N quality threshold below which signals are rejected. Default is 0.7.

  Attribute: `signal.quality.threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.7`, `0.8`, `0.9`
  """
  @spec signal_quality_threshold() :: :signal_quality_threshold
  def signal_quality_threshold, do: :signal_quality_threshold

  @doc """
  Number of retransmission retries attempted for this signal.

  Attribute: `signal.retry.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec signal_retry_count() :: :signal_retry_count
  def signal_retry_count, do: :signal_retry_count

  @doc """
  Shannon signal-to-noise ratio score in range [0.0, 1.0]. Values >= 0.7 pass the S/N gate for transmission.

  Attribute: `signal.sn_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.92`, `0.71`, `0.35`
  """
  @spec signal_sn_ratio() :: :signal_sn_ratio
  def signal_sn_ratio, do: :signal_sn_ratio

  @doc """
  The source channel through which the signal was received.

  Attribute: `signal.source`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `http`, `websocket`, `telegram`, `discord`, `slack`, `cli`
  """
  @spec signal_source() :: :signal_source
  def signal_source, do: :signal_source

  @doc """
  Time-to-live for the signal in milliseconds — signal expires if not consumed.

  Attribute: `signal.ttl_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1000`, `30000`, `300000`
  """
  @spec signal_ttl_ms() :: :signal_ttl_ms
  def signal_ttl_ms, do: :signal_ttl_ms

  @doc """
  The type component (T) of the signal — the speech act or communicative intent.

  Attribute: `signal.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `direct`, `inform`, `decide`
  """
  @spec signal_type() :: :signal_type
  def signal_type, do: :signal_type

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
  @spec signal_weight() :: :signal_weight
  def signal_weight, do: :signal_weight

end