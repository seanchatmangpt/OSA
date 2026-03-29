defmodule OptimalSystemAgent.Healing.Diagnosis do
  @moduledoc """
  Failure mode detector that classifies errors into 11 systematic failure modes.

  Maps errors to Shannon/Ashby/Beer/Wiener + 7 derived combinations:

  1. **Shannon** — Information loss (missing data, truncation, incomplete)
  2. **Ashby** — Regulatory failure (wrong setpoint, oscillation, drift)
  3. **Beer** — Complexity overload (too many variables, state explosion)
  4. **Wiener** — Feedback instability (overcorrection, hunting, oscillation)
  5. **Deadlock** — Circular wait condition
  6. **Cascade** — Failure spreads to downstream components
  7. **Byzantine** — Compromised or malicious component
  8. **Starvation** — Resource exhaustion or priority inversion
  9. **Livelock** — Agents conflict without making progress
  10. **Timeout** — Operation exceeds deadline
  11. **Inconsistent** — State mismatch across systems

  Returns: `{mode, description, root_cause}` where:
  - `mode` is an atom (:shannon, :ashby, :beer, :wiener, :deadlock, :cascade, :byzantine, :starvation, :livelock, :timeout, :inconsistent, or :unknown)
  - `description` is a human-readable string
  - `root_cause` is a string explaining the specific error

  ## OTEL span emission via `classify/1`

  Use `classify/1` for the span-emitting entry point. It wraps `diagnose/2` and
  records a `"healing.diagnosis"` span via `OptimalSystemAgent.Observability.Telemetry`.
  The span carries semconv attributes defined in `OtelBridge`:
  - `healing.failure_mode` — the classified mode atom as a string
  - `healing.agent_id`     — always `"osa"`
  - `healing.confidence`   — numeric confidence score

  Armstrong: NO try/rescue around the ETS call inside `start_span/end_span`.
  If the `:telemetry_spans` table is missing the process crashes and the supervisor
  recreates it with a clean ETS table.
  """

  alias OptimalSystemAgent.Observability.Telemetry
  alias OptimalSystemAgent.ProcessMining.OcelCollector

  @type failure_mode ::
          :shannon
          | :ashby
          | :beer
          | :wiener
          | :deadlock
          | :cascade
          | :byzantine
          | :starvation
          | :livelock
          | :timeout
          | :inconsistent
          | :unknown

  @type diagnosis :: {failure_mode(), String.t(), String.t()}

  @doc """
  Classify an error, emit a `"healing.diagnosis"` OTEL span, and return a result map.

  This is the primary span-emitting entry point for the healing domain. It calls
  `diagnose/2` internally and wraps the execution in a `Telemetry.start_span` /
  `Telemetry.end_span` pair so that every classification is observable in Jaeger
  (or any compatible OTEL backend) and in the `:telemetry_spans` ETS table.

  ## Span attributes (semconv from OtelBridge)

  | Key                   | Value                           |
  |-----------------------|---------------------------------|
  | `healing.failure_mode`| classified mode atom as string  |
  | `healing.agent_id`    | `"osa"`                         |
  | `healing.confidence`  | numeric confidence score [0, 1] |

  ## Returns

  `{:ok, %{failure_mode: atom, description: string, root_cause: string, confidence: float}}`

  ## Armstrong rule

  No try/rescue wraps the `Telemetry` calls here. If `:telemetry_spans` is missing
  the process will crash, the supervisor will restart it, and the ETS table will be
  recreated. That is the correct OTP behaviour.
  """
  @spec classify(term()) :: {:ok, map()}
  def classify(error) do
    {:ok, span_ctx} =
      Telemetry.start_span("healing.diagnosis", %{
        "healing.agent_id" => "osa"
      })

    {mode, description, root_cause} = diagnose(error)

    confidence = failure_mode_confidence(mode)

    # Update the span with post-classification attributes before closing it
    updated_span = Map.update!(span_ctx, "attributes", fn attrs ->
      attrs
      |> Map.put("healing.failure_mode", to_string(mode))
      |> Map.put("healing.confidence", confidence)
    end)

    :ets.insert(:telemetry_spans, {updated_span["span_id"], updated_span})

    :ok = Telemetry.end_span(updated_span, :ok)

    result = %{
      failure_mode: mode,
      description: description,
      root_cause: root_cause,
      confidence: confidence
    }

    {:ok, result}
  end

  @doc """
  Classify an error with OCPM context — adjusts confidence based on real OCEL process evidence.

  Retrieves the OCEL event lifecycle for `session_id` from `OcelCollector`, computes a local
  conformance score from those events, then adjusts the base confidence:

      adjusted_confidence = base_confidence * (0.5 + conformance_score * 0.5)

  This grounds Connection 4 (GenAI/RAG) by anchoring diagnosis confidence to observable
  process data rather than static weights alone. When no lifecycle events exist the
  conformance score defaults to 0.5 (neutral), preserving 75% of the base confidence.

  Existing `classify/1` is unchanged (backward compatibility).

  ## Parameters
  - `error` — same as `classify/1`
  - `session_id` — session or agent id to look up in the OCEL event history

  ## Returns
  `{:ok, %{failure_mode: atom, description: string, root_cause: string, confidence: float}}`
  where confidence has been adjusted by the local OCEL conformance score.
  """
  @spec classify_with_ocpm_context(term(), String.t()) :: {:ok, map()}
  def classify_with_ocpm_context(error, session_id) do
    {:ok, result} = classify(error)

    events = OcelCollector.get_object_lifecycle(session_id, "session")

    conformance_score = compute_local_conformance(result.failure_mode, events)

    adjusted_confidence = result.confidence * (0.5 + conformance_score * 0.5)

    {:ok, %{result | confidence: adjusted_confidence}}
  end

  # Confidence scores by failure mode — higher for well-defined structural failures
  defp failure_mode_confidence(:deadlock), do: 0.92
  defp failure_mode_confidence(:timeout), do: 0.90
  defp failure_mode_confidence(:cascade), do: 0.85
  defp failure_mode_confidence(:livelock), do: 0.85
  defp failure_mode_confidence(:starvation), do: 0.80
  defp failure_mode_confidence(:byzantine), do: 0.80
  defp failure_mode_confidence(:shannon), do: 0.78
  defp failure_mode_confidence(:ashby), do: 0.75
  defp failure_mode_confidence(:beer), do: 0.75
  defp failure_mode_confidence(:wiener), do: 0.73
  defp failure_mode_confidence(:inconsistent), do: 0.70
  defp failure_mode_confidence(:unknown), do: 0.40

  @doc """
  Diagnose an error and classify it into a failure mode.

  ## Parameters

  - `error` — the error term (can be a tuple, map, atom, string, or exception struct)
  - `context` — optional map with additional context (component, attempt, etc.)

  ## Returns

  A tuple `{mode, description, root_cause}` where:
  - `mode` is one of the 11 failure modes or `:unknown`
  - `description` is a human-readable explanation
  - `root_cause` is the specific error message or reason

  ## Examples

      iex> Diagnosis.diagnose({:error, :truncated_message})
      {:shannon, "information loss", "truncated_message"}

      iex> Diagnosis.diagnose({:error, :oscillation})
      {:ashby, "regulatory failure", "oscillation"}

      iex> Diagnosis.diagnose({:error, :state_explosion})
      {:beer, "complexity overload", "state_explosion"}
  """
  @spec diagnose(term(), map()) :: diagnosis()
  def diagnose(error, context \\ %{})

  # ---- Tuple patterns {type, reason} ----

  def diagnose({:error, reason}, context) when is_atom(reason) do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    :otel_tracer.with_span(tracer, "diagnosis.classify", %{}, fn span_ctx ->
      result = diagnose_reason(reason, context)

      :otel_span.set_attributes(span_ctx, [
        {"error_type", "atom"},
        {"reason", inspect(reason)},
        {"diagnosis_mode", inspect(elem(result, 0))},
        {"chatmangpt.run.correlation_id", get_correlation_id()}
      ])

      result
    end)
  rescue
    _ ->
      diagnose_reason(reason, context)
  catch
    _, _ ->
      diagnose_reason(reason, context)
  end

  def diagnose({:error, message}, _context) when is_binary(message) do
    result = diagnose_string(message, %{})
    # Ensure the original message is preserved in the cause
    case result do
      {:unknown, desc, _} -> {:unknown, desc, message}
      {mode, desc, _cause} -> {mode, desc, message}
    end
  end

  def diagnose({:ok, _}, _context) do
    {:unknown, "successful result", "no error"}
  end

  # ---- Map patterns ----

  def diagnose(%{error: reason}, context) when is_atom(reason) do
    diagnose_reason(reason, context)
  end

  def diagnose(%{error: message}, context) when is_binary(message) do
    diagnose_string(message, context)
  end

  def diagnose(%{reason: reason}, context) when is_atom(reason) do
    diagnose_reason(reason, context)
  end

  def diagnose(%{reason: message}, context) when is_binary(message) do
    diagnose_string(message, context)
  end

  def diagnose(%{message: message}, context) when is_binary(message) do
    diagnose_string(message, context)
  end

  # ---- Atom patterns ----

  def diagnose(reason, context) when is_atom(reason) do
    diagnose_reason(reason, context)
  end

  # ---- String patterns ----

  def diagnose(message, context) when is_binary(message) do
    diagnose_string(message, context)
  end

  # ---- Struct/exception patterns ----

  def diagnose(%{__struct__: _struct_mod} = error, context) do
    message = Map.get(error, :message, inspect(error))
    diagnose_string(message, context)
  end

  # ---- Catch-all ----

  def diagnose(error, _context) do
    {:unknown, "unrecognized error format", inspect(error)}
  end

  # ========== SHANNON: Information Loss ==========

  defp diagnose_reason(reason, context) when reason in [:truncated, :truncated_message] do
    diagnose_mode(:shannon, "truncated message", context)
  end

  defp diagnose_reason(:incomplete, context) do
    diagnose_mode(:shannon, "incomplete data", context)
  end

  defp diagnose_reason(:missing_data, context) do
    diagnose_mode(:shannon, "missing data", context)
  end

  # ========== ASHBY: Regulatory Failure ==========

  defp diagnose_reason(:drift_detected, context) do
    diagnose_mode(:ashby, "drift detected in setpoint", context)
  end

  defp diagnose_reason(:oscillation, context) do
    diagnose_mode(:ashby, "oscillatory behavior detected", context)
  end

  defp diagnose_reason(:wrong_setpoint, context) do
    diagnose_mode(:ashby, "wrong setpoint configuration", context)
  end

  # ========== BEER: Complexity Overload ==========

  defp diagnose_reason(:state_explosion, context) do
    diagnose_mode(:beer, "state space explosion", context)
  end

  defp diagnose_reason(:too_many_vars, context) do
    diagnose_mode(:beer, "too many variables to track", context)
  end

  # ========== WIENER: Feedback Instability ==========

  defp diagnose_reason(:overcorrection, context) do
    diagnose_mode(:wiener, "overcorrection in feedback loop", context)
  end

  defp diagnose_reason(:hunting, context) do
    diagnose_mode(:wiener, "hunting behavior in control loop", context)
  end

  # ========== DEADLOCK: Circular Wait ==========

  defp diagnose_reason(:circular_wait, context) do
    diagnose_mode(:deadlock, "circular dependency detected", context)
  end

  # ========== CASCADE: Failure Spread ==========

  defp diagnose_reason(:cascading_failure, context) do
    diagnose_mode(:cascade, "cascading failure in dependencies", context)
  end

  # ========== BYZANTINE: Compromised Component ==========

  defp diagnose_reason(:malicious_input, context) do
    diagnose_mode(:byzantine, "malicious input detected", context)
  end

  defp diagnose_reason(:compromised, context) do
    diagnose_mode(:byzantine, "component may be compromised", context)
  end

  # ========== STARVATION: Resource Exhaustion ==========

  defp diagnose_reason(:starvation, context) do
    diagnose_mode(:starvation, "resource starvation", context)
  end

  defp diagnose_reason(:priority_inversion, context) do
    diagnose_mode(:starvation, "priority inversion detected", context)
  end

  # ========== LIVELOCK: Conflict Without Progress ==========

  defp diagnose_reason(:livelock, context) do
    diagnose_mode(:livelock, "agents in livelock", context)
  end

  # ========== TIMEOUT: Operation Exceeds Deadline ==========

  defp diagnose_reason(:timeout, context) do
    diagnose_mode(:timeout, "operation timed out", context)
  end

  defp diagnose_reason(:deadline_exceeded, context) do
    diagnose_mode(:timeout, "deadline exceeded", context)
  end

  # ========== INCONSISTENT: State Mismatch ==========

  defp diagnose_reason(:state_mismatch, context) do
    diagnose_mode(:inconsistent, "state mismatch detected", context)
  end

  defp diagnose_reason(:consistency_violation, context) do
    diagnose_mode(:inconsistent, "consistency violation", context)
  end

  # ========== UNKNOWN: Fallback ==========

  defp diagnose_reason(reason, _context) do
    {:unknown, "unknown error type", inspect(reason)}
  end

  # ========== STRING MESSAGE PATTERN MATCHING ==========

  defp diagnose_string(message, context) do
    lower = String.downcase(message)

    cond do
      # SHANNON: Information loss
      contains_any?(lower, ["not found", "missing", "truncated", "incomplete"]) ->
        diagnose_mode(:shannon, "information loss in message", context)

      # ASHBY: Regulatory failure
      contains_any?(lower, ["drift", "oscillation", "setpoint"]) ->
        diagnose_mode(:ashby, "regulatory failure detected", context)

      # BEER: Complexity overload
      contains_any?(lower, ["state explosion", "too many vars"]) ->
        diagnose_mode(:beer, "complexity overload detected", context)

      # WIENER: Feedback instability
      contains_any?(lower, ["hunting", "overcorrection", "feedback"]) and
        contains_any?(lower, ["loop", "control"]) ->
        diagnose_mode(:wiener, "feedback instability detected", context)

      # DEADLOCK: Circular wait
      contains_any?(lower, ["deadlock", "circular wait", "circular dependency"]) ->
        diagnose_mode(:deadlock, "deadlock detected", context)

      # CASCADE: Failure spread
      contains_any?(lower, ["cascade", "downstream"]) ->
        diagnose_mode(:cascade, "cascading failure detected", context)

      # BYZANTINE: Compromised component
      contains_any?(lower, ["byzantine", "malicious", "compromised"]) ->
        diagnose_mode(:byzantine, "byzantine fault detected", context)

      # STARVATION: Resource exhaustion
      contains_any?(lower, ["starvation", "resource exhaustion", "priority inversion"]) ->
        diagnose_mode(:starvation, "resource starvation detected", context)

      # LIVELOCK: Conflict without progress
      contains_any?(lower, ["livelock", "continuously retry"]) ->
        diagnose_mode(:livelock, "livelock detected", context)

      # TIMEOUT: Operation exceeds deadline
      contains_any?(lower, ["timeout", "timed out", "deadline"]) ->
        diagnose_mode(:timeout, "timeout detected", context)

      # INCONSISTENT: State mismatch
      contains_any?(lower, ["state mismatch", "consistency", "replica", "mismatch"]) ->
        diagnose_mode(:inconsistent, "state inconsistency detected", context)

      true ->
        {:unknown, "unknown error in message", message}
    end
  end

  # ========== OCPM CONFORMANCE HELPERS ==========

  # Compute a local conformance score [0.0, 1.0] from OCEL lifecycle events.
  # Pure ETS read — no HTTP, no external calls. Neutral 0.5 when events absent.
  #
  # :deadlock — high unmatched tool_call:tool_result ratio signals circular wait evidence
  # :timeout  — high unmatched llm_request:llm_response ratio signals deadline miss
  # :cascade  — event count correlates with failure spread across components
  # other     — neutral 0.5 (no domain-specific evidence pattern available)

  defp compute_local_conformance(_mode, []), do: 0.5

  defp compute_local_conformance(:deadlock, events) do
    tool_calls = Enum.count(events, fn {_eid, act, _ts} -> act == "tool_call" end)
    tool_results = Enum.count(events, fn {_eid, act, _ts} -> act == "tool_result" end)

    if tool_calls == 0 do
      0.5
    else
      unmatched_ratio = max(0.0, (tool_calls - tool_results) / tool_calls)
      Float.round(unmatched_ratio * 1.0, 4)
    end
  end

  defp compute_local_conformance(:timeout, events) do
    llm_requests = Enum.count(events, fn {_eid, act, _ts} -> act == "llm_request" end)
    llm_responses = Enum.count(events, fn {_eid, act, _ts} -> act == "llm_response" end)

    if llm_requests == 0 do
      0.5
    else
      unmatched_ratio = max(0.0, (llm_requests - llm_responses) / llm_requests)
      Float.round(unmatched_ratio * 1.0, 4)
    end
  end

  defp compute_local_conformance(:cascade, events) do
    count = length(events)

    cond do
      count >= 10 -> 0.9
      count >= 5 -> 0.7
      count >= 1 -> 0.5
      true -> 0.5
    end
  end

  defp compute_local_conformance(_mode, _events), do: 0.5

  # ========== HELPERS ==========

  defp diagnose_mode(mode, _description, context) do
    cause = build_cause_string(mode, context)
    {mode, diagnosis_description(mode), cause}
  end

  defp diagnosis_description(:shannon), do: "information loss"
  defp diagnosis_description(:ashby), do: "regulatory failure"
  defp diagnosis_description(:beer), do: "complexity overload"
  defp diagnosis_description(:wiener), do: "feedback instability"
  defp diagnosis_description(:deadlock), do: "circular wait condition"
  defp diagnosis_description(:cascade), do: "failure spreads to downstream components"
  defp diagnosis_description(:byzantine), do: "compromised or malicious component"
  defp diagnosis_description(:starvation), do: "resource exhaustion or priority inversion"
  defp diagnosis_description(:livelock), do: "agents conflict without making progress"
  defp diagnosis_description(:timeout), do: "operation exceeds deadline"
  defp diagnosis_description(:inconsistent), do: "state mismatch across systems"
  defp diagnosis_description(:unknown), do: "error of unknown type"

  defp build_cause_string(mode, context) do
    base = "#{mode} failure"

    if map_size(context) > 0 do
      context_str =
        context
        |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
        |> Enum.join(", ")

      "#{base} (context: #{context_str})"
    else
      base
    end
  end

  defp contains_any?(string, substrings) do
    Enum.any?(substrings, &String.contains?(string, &1))
  end

  # Retrieve correlation ID for span attributes.
  # Reads from process dictionary, then env var, then generates a fallback.
  defp get_correlation_id do
    case Process.get(:chatmangpt_correlation_id) do
      nil ->
        id = System.get_env("CHATMANGPT_CORRELATION_ID") || generate_correlation_id()
        Process.put(:chatmangpt_correlation_id, id)
        id

      id ->
        id
    end
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
