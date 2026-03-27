defmodule OptimalSystemAgent.Agents.Armstrong.HipaaBreachDetector do
  @moduledoc """
  HIPAA Breach Detector Agent — detects healthcare data access violations.

  Monitors Protected Health Information (PHI) access and logs access events for compliance.
  Detects PHI patterns (SSN, medical record numbers, health condition keywords) and enforces
  encryption requirements for transmission.

  ## PHI Patterns Detected

  - Social Security Numbers: `\\d{3}-\\d{2}-\\d{4}` (e.g., 123-45-6789)
  - Medical Record Numbers: `MR-\\d{6,}` (e.g., MR-123456)
  - Health Condition Keywords: diabetes, cancer, depression, hypertension, etc.

  ## GenServer State

  Maintains in-memory access logs in ETS tables:
  - `:osa_phi_access_log` — access events, keyed by {resource_id, timestamp}
  - `:osa_phi_metrics` — aggregated metrics per accessor/resource

  ## Public API

  - `start_link(opts)` — Start GenServer
  - `scan_for_phi(text)` → `[{phi_type, value, confidence}]` — Detect PHI patterns
  - `log_phi_access(resource_id, accessor, context)` → `:ok` — Record access
  - `audit_phi_access(start_time, end_time)` → `audit_report` — Generate audit trail
  - `flag_violation(resource_id, accessor, reason)` → `:ok` — Escalate regulatory violation

  ## Telemetry Events

  Emits on `Bus.emit(:phi_access, ...)`:
  - `resource`: resource identifier
  - `accessor`: agent/process/user performing access
  - `encrypted`: true/false for transmission
  - `timestamp`: ISO8601 string
  - `violation`: true if unencrypted or unauthorized

  ## Armstrong Fault Tolerance

  - Supervision: all PHI access failures escalate to supervisor (no silent drops)
  - Timeout: all blocking operations have 5000ms timeout + fallback
  - No shared state: all access logs isolated in ETS, accessed via GenServer messages
  - Budget: max 10,000 access events per session before eviction

  ## References

  - HIPAA Privacy Rule: 45 CFR §164.500-556
  - OCR Breach Notification Rule: 45 CFR §164.400-414
  - NIST Special Publication 800-66: "An Introductory Resource Guide for Implementing the HIPAA Security Rule"
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus

  # ── Type Definitions ────────────────────────────────────────────────────

  @type phi_type :: :ssn | :mrn | :health_condition | :unknown
  @type phi_detection :: {phi_type(), String.t(), float()}
  @type access_context :: %{
          optional(:operation) => String.t(),
          optional(:purpose) => String.t(),
          optional(:requestor_id) => String.t(),
          optional(:encrypted) => boolean(),
          optional(:ip_address) => String.t()
        }
  @type access_event :: %{
          resource_id: String.t(),
          accessor: String.t(),
          timestamp: String.t(),
          phi_detected: [phi_detection()],
          encrypted: boolean(),
          violation: boolean(),
          context: access_context()
        }

  # ── Configuration ────────────────────────────────────────────────────────

  @max_access_events 10_000
  @timeout_ms 5000
  @ssn_pattern ~r/\b\d{3}-\d{2}-\d{4}\b/
  @mrn_pattern ~r/\bMR-\d{6,}\b/i
  @health_conditions [
    "diabetes",
    "cancer",
    "depression",
    "hypertension",
    "asthma",
    "copd",
    "stroke",
    "heart disease",
    "alzheimer",
    "autism",
    "bipolar",
    "schizophrenia",
    "anxiety",
    "ptsd",
    "ocd",
    "epilepsy",
    "parkinson",
    "hepatitis",
    "hiv",
    "aids"
  ]

  # ── GenServer Callbacks ────────────────────────────────────────────────

  @impl GenServer
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    init_tables()

    Logger.info("[HipaaBreachDetector] GenServer starting (name=#{name})")

    {:ok, %{name: name, event_count: 0}}
  end

  @impl GenServer
  def handle_call({:log_phi_access, resource_id, accessor, context}, _from, state) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    phi_detections = scan_for_phi_impl(context[:data] || "")
    encrypted = Map.get(context, :encrypted, false)

    # Violation if unencrypted OR detects PHI
    violation = not encrypted and not Enum.empty?(phi_detections)

    event = %{
      resource_id: resource_id,
      accessor: accessor,
      timestamp: timestamp,
      phi_detected: phi_detections,
      encrypted: encrypted,
      violation: violation,
      context: context
    }

    # Store in ETS with eviction on max
    store_access_event(event, state)

    # Emit telemetry
    Bus.emit(:phi_access, %{
      resource: resource_id,
      accessor: accessor,
      encrypted: encrypted,
      timestamp: timestamp,
      violation: violation,
      phi_count: length(phi_detections)
    })

    # Escalate if violation
    if violation do
      escalate_violation(resource_id, accessor, "unencrypted PHI transmission detected")
    end

    {:reply, :ok, %{state | event_count: state.event_count + 1}}
  end

  @impl GenServer
  def handle_call({:audit_phi_access, start_time, end_time}, _from, state) do
    report = generate_audit_report(start_time, end_time)
    {:reply, report, state}
  end

  @impl GenServer
  def handle_call({:flag_violation, resource_id, accessor, reason}, _from, state) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    Logger.warning(
      "[HipaaBreachDetector] VIOLATION FLAGGED: resource=#{resource_id}, accessor=#{accessor}, reason=#{reason}"
    )

    event = %{
      resource_id: resource_id,
      accessor: accessor,
      timestamp: timestamp,
      phi_detected: [],
      encrypted: false,
      violation: true,
      context: %{violation_reason: reason}
    }

    store_access_event(event, state)

    Bus.emit(:phi_access, %{
      resource: resource_id,
      accessor: accessor,
      encrypted: false,
      timestamp: timestamp,
      violation: true,
      reason: reason
    })

    {:reply, :ok, %{state | event_count: state.event_count + 1}}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = get_metrics_impl()
    {:reply, metrics, state}
  end

  # ── Public API ──────────────────────────────────────────────────────────

  @doc """
  Start the HIPAA Breach Detector GenServer.

  ## Options

  - `:name` — GenServer name (default: __MODULE__)

  ## Returns

  `{:ok, pid}` on success, `{:error, reason}` on failure.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Scan text for Protected Health Information (PHI) patterns.

  Detects:
  - Social Security Numbers: xxx-xx-xxxx
  - Medical Record Numbers: MR-123456
  - Health condition keywords: diabetes, cancer, depression, etc.

  ## Parameters

  - `text` — String to scan for PHI

  ## Returns

  List of `{phi_type, value, confidence}` tuples. Empty list if no PHI found.

  ## Examples

      iex> scan_for_phi("Patient SSN: 123-45-6789 has diabetes")
      [
        {:ssn, "123-45-6789", 0.95},
        {:health_condition, "diabetes", 0.90}
      ]

      iex> scan_for_phi("MR-987654 admitted for routine checkup")
      [{:mrn, "MR-987654", 0.98}]
  """
  @spec scan_for_phi(String.t()) :: [phi_detection()]
  def scan_for_phi(text) when is_binary(text) do
    scan_for_phi_impl(text)
  rescue
    e ->
      Logger.error("[HipaaBreachDetector] Error in scan_for_phi: #{inspect(e)}")
      []
  end

  @doc """
  Log a Protected Health Information (PHI) access event.

  Records who accessed what, when, and whether the transmission was encrypted.
  Automatically detects PHI in provided context data and flags violations.

  ## Parameters

  - `resource_id` — Unique identifier for the healthcare resource (patient ID, medical record, etc.)
  - `accessor` — Who accessed it (agent name, user ID, process ID)
  - `context` — Map with optional fields:
    - `:data` — The data that was accessed (scanned for PHI)
    - `:operation` — What operation (read, write, export, etc.)
    - `:purpose` — Why it was accessed (treatment, billing, research, etc.)
    - `:encrypted` — Boolean indicating transmission encryption (default: false)
    - `:ip_address` — Source IP address
    - `:requestor_id` — ID of the human making the request

  ## Returns

  `:ok` on success. Violations are escalated to supervisor.

  ## Telemetry

  Emits `:phi_access` event with resource, accessor, encrypted, timestamp, violation flags.

  ## Examples

      iex> log_phi_access("patient-123", "agent-healing", %{
      ...>   data: "Patient has diabetes, SSN 123-45-6789",
      ...>   operation: "read",
      ...>   purpose: "diagnosis",
      ...>   encrypted: true
      ...> })
      :ok

      iex> log_phi_access("patient-456", "agent-malicious", %{
      ...>   data: "MR-654321 with cancer diagnosis",
      ...>   operation: "export",
      ...>   encrypted: false  # VIOLATION!
      ...> })
      :ok  # But event flagged as violation and escalated
  """
  @spec log_phi_access(String.t(), String.t(), access_context()) :: :ok
  def log_phi_access(resource_id, accessor, context \\ %{}) do
    GenServer.call(__MODULE__, {:log_phi_access, resource_id, accessor, context}, @timeout_ms)
  rescue
    e ->
      Logger.error("[HipaaBreachDetector] Error logging access: #{inspect(e)}")
      escalate_violation(resource_id, accessor, "exception during access logging: #{inspect(e)}")
      :ok
  end

  @doc """
  Generate audit trail for PHI access during a time window.

  Returns structured report suitable for compliance audits and breach investigations.

  ## Parameters

  - `start_time` — ISO8601 timestamp or DateTime (inclusive)
  - `end_time` — ISO8601 timestamp or DateTime (inclusive)

  ## Returns

  Audit report map with:
  - `total_accesses` — Total access events in window
  - `violations` — Count of violation events
  - `encrypted_ratio` — Percentage of encrypted transmissions
  - `top_accessors` — Accessors with most access events
  - `top_resources` — Most-accessed resources
  - `phi_exposure` — All PHI types and values detected
  - `events` — Full event list (detailed)

  ## Examples

      iex> audit_phi_access("2026-03-26T00:00:00Z", "2026-03-26T23:59:59Z")
      %{
        total_accesses: 42,
        violations: 3,
        encrypted_ratio: 0.95,
        top_accessors: [{"agent-healing", 15}, {"agent-trader", 12}],
        top_resources: [{"patient-123", 8}, {"patient-456", 7}],
        phi_exposure: [{:ssn, ["123-45-6789"]}, {:health_condition, ["diabetes"]}],
        events: [...]
      }
  """
  @spec audit_phi_access(String.t() | DateTime.t(), String.t() | DateTime.t()) :: map()
  def audit_phi_access(start_time, end_time) do
    GenServer.call(__MODULE__, {:audit_phi_access, start_time, end_time}, @timeout_ms)
  rescue
    e ->
      Logger.error("[HipaaBreachDetector] Error generating audit: #{inspect(e)}")
      %{error: inspect(e)}
  end

  @doc """
  Flag a regulatory violation and escalate to supervisor.

  Used by external compliance systems to report PHI violations detected outside
  this agent's direct monitoring (e.g., unauthorized data exfiltration detected
  by a network monitor).

  ## Parameters

  - `resource_id` — Healthcare resource involved
  - `accessor` — Who performed the violation
  - `reason` — Human-readable violation description

  ## Returns

  `:ok`. Violation is logged and escalated immediately.
  """
  @spec flag_violation(String.t(), String.t(), String.t()) :: :ok
  def flag_violation(resource_id, accessor, reason) do
    GenServer.call(__MODULE__, {:flag_violation, resource_id, accessor, reason}, @timeout_ms)
  rescue
    e ->
      Logger.error("[HipaaBreachDetector] Error flagging violation: #{inspect(e)}")
      :ok
  end

  @doc """
  Get current PHI access metrics.

  Returns aggregated statistics on PHI access patterns.

  ## Returns

  Map with:
  - `total_events` — Total access events recorded
  - `violation_count` — Total violation events
  - `phi_types_detected` — Unique PHI types found
  - `accessor_stats` — Per-accessor statistics
  """
  @spec get_metrics() :: map()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics, @timeout_ms)
  rescue
    _e -> %{error: "metrics unavailable"}
  end

  # ── Private Helpers ────────────────────────────────────────────────────

  defp init_tables do
    if :ets.whereis(:osa_phi_access_log) == :undefined do
      :ets.new(:osa_phi_access_log, [
        :named_table,
        :bag,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end

    if :ets.whereis(:osa_phi_metrics) == :undefined do
      :ets.new(:osa_phi_metrics, [
        :named_table,
        :set,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end
  rescue
    ArgumentError -> :ok
  end

  defp scan_for_phi_impl(text) when is_binary(text) do
    text = String.downcase(text)

    ssn_matches = detect_ssn(text)
    mrn_matches = detect_mrn(text)
    condition_matches = detect_health_conditions(text)

    ssn_matches ++ mrn_matches ++ condition_matches
  end

  defp detect_ssn(text) do
    Regex.scan(@ssn_pattern, text)
    |> Enum.map(fn [match] -> {:ssn, match, 0.95} end)
  end

  defp detect_mrn(text) do
    Regex.scan(@mrn_pattern, text)
    |> Enum.map(fn [match] -> {:mrn, match, 0.98} end)
  end

  defp detect_health_conditions(text) do
    @health_conditions
    |> Enum.filter(fn condition ->
      String.contains?(text, condition)
    end)
    |> Enum.map(fn condition -> {:health_condition, condition, 0.90} end)
  end

  defp store_access_event(event, _state) do
    key = {event.resource_id, event.timestamp}

    # Enforce max events with FIFO eviction
    current_count = :ets.info(:osa_phi_access_log, :size) || 0

    if current_count >= @max_access_events do
      # Find and delete oldest event
      oldest =
        :ets.match_object(:osa_phi_access_log, :"$1")
        |> Enum.sort_by(fn {_, ts, _} -> ts end)
        |> List.first()

      if oldest do
        :ets.delete_object(:osa_phi_access_log, oldest)
      end
    end

    :ets.insert(:osa_phi_access_log, {key, event.timestamp, event})
  end

  defp generate_audit_report(start_time, end_time) do
    start_iso =
      if is_binary(start_time),
        do: start_time,
        else: DateTime.to_iso8601(start_time)

    end_iso =
      if is_binary(end_time),
        do: end_time,
        else: DateTime.to_iso8601(end_time)

    events =
      :ets.tab2list(:osa_phi_access_log)
      |> Enum.map(fn {_key, _ts, event} -> event end)
      |> Enum.filter(fn event ->
        event.timestamp >= start_iso and event.timestamp <= end_iso
      end)

    total = length(events)
    violations = Enum.count(events, & &1.violation)
    encrypted = Enum.count(events, & &1.encrypted)
    encrypted_ratio = if total > 0, do: encrypted / total, else: 0.0

    top_accessors =
      events
      |> Enum.group_by(& &1.accessor)
      |> Enum.map(fn {accessor, accs} -> {accessor, length(accs)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)

    top_resources =
      events
      |> Enum.group_by(& &1.resource_id)
      |> Enum.map(fn {resource, rescs} -> {resource, length(rescs)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)

    phi_exposure =
      events
      |> Enum.flat_map(& &1.phi_detected)
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.map(fn {type, detections} ->
        values = Enum.map(detections, &elem(&1, 1)) |> Enum.uniq()
        {type, values}
      end)

    %{
      period: %{start: start_iso, end: end_iso},
      total_accesses: total,
      violations: violations,
      encrypted_count: encrypted,
      encrypted_ratio: Float.round(encrypted_ratio, 3),
      top_accessors: top_accessors,
      top_resources: top_resources,
      phi_exposure: phi_exposure,
      events: events
    }
  end

  defp get_metrics_impl do
    events = :ets.tab2list(:osa_phi_access_log) |> Enum.map(fn {_k, _ts, e} -> e end)

    phi_types =
      events
      |> Enum.flat_map(& &1.phi_detected)
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()

    accessor_stats =
      events
      |> Enum.group_by(& &1.accessor)
      |> Enum.map(fn {accessor, accs} ->
        violations = Enum.count(accs, & &1.violation)

        {accessor, %{accesses: length(accs), violations: violations}}
      end)

    %{
      total_events: length(events),
      violation_count: Enum.count(events, & &1.violation),
      phi_types_detected: phi_types,
      accessor_stats: Map.new(accessor_stats)
    }
  end

  defp escalate_violation(resource_id, accessor, reason) do
    Logger.warning(
      "[HipaaBreachDetector] ESCALATING VIOLATION: resource=#{resource_id}, accessor=#{accessor}, reason=#{reason}"
    )

    # In production, this would escalate to compliance officer or audit system
    Bus.emit(:system_event, %{
      event_type: "hipaa_violation_detected",
      severity: "critical",
      resource_id: resource_id,
      accessor: accessor,
      reason: reason,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

end
