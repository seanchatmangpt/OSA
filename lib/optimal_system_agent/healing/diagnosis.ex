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
  """

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
end
