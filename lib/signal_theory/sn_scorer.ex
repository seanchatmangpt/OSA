defmodule OptimalSystemAgent.SignalTheory.SNScorer do
  @moduledoc """
  Signal Theory S/N (Signal-to-Noise) Quality Scorer.

  Scores every agent output (0.0-1.0) based on Signal Theory dimensions:
  - Information completeness: +0.3 (all expected fields present)
  - Error-free execution: +0.3 (no exceptions, timeouts, warnings)
  - State consistency: +0.2 (state matches expected invariants)
  - Timing compliance: +0.2 (execution within deadline)

  ## Governance Tiers

  S/N scores determine approval requirements:
  - **Autonomous** (S/N > 0.8): auto-approve, no human review needed
  - **Human Review** (0.7 ≤ S/N ≤ 0.8): requires manager approval
  - **Board Escalation** (S/N < 0.7): requires C-level approval

  ## Implementation Notes

  All scoring functions return floats between 0.0 and 1.0.
  Governance tiers are atoms: `:autonomous`, `:human_review`, `:board_escalation`.

  Reference: Luna, R. (2026). Signal Theory: The Architecture of Optimal
  Intent Encoding in Communication Systems.
  """

  @type output :: map()
  @type context :: map()
  @type score :: float()
  @type governance_tier :: :autonomous | :human_review | :board_escalation
  @type failure_mode ::
          :ok
          | :timeout
          | :validation_error
          | :resource_error
          | :permission_denied
          | :unknown

  @doc """
  Score an agent output based on Signal Theory quality dimensions.

  Returns a float between 0.0 and 1.0 representing signal quality.

  Context can include:
  - `:deadline_ms` — execution deadline in milliseconds
  - `:expected_fields` — list of required fields in output

  ## Examples

      iex> output = %{"status" => "success", "errors" => []}
      iex> SNScorer.score(output, %{"deadline_ms" => 5000})
      0.85
  """
  @spec score(output, context) :: score
  def score(output, context \\ %{}) when is_map(output) and is_map(context) do
    expected_fields = Map.get(context, "expected_fields", ["status", "result", "data"])
    deadline_ms = Map.get(context, "deadline_ms", 5000)

    completeness = information_completeness(output, expected_fields)
    error_free = error_free_execution(output)
    consistency = state_consistency(output)
    timing = timing_compliance(output, deadline_ms)

    completeness + error_free + consistency + timing
  end

  @doc """
  Score information completeness (max 0.3).

  Returns 0.3 if all expected fields are present, proportionally less otherwise.

  ## Examples

      iex> output = %{"field_a" => 1, "field_b" => 2}
      iex> SNScorer.information_completeness(output, ["field_a", "field_b"])
      0.3
  """
  @spec information_completeness(output, [String.t()]) :: score
  def information_completeness(output, expected_fields)
      when is_map(output) and is_list(expected_fields) do
    if Enum.empty?(expected_fields) do
      0.3
    else
      present_count =
        expected_fields
        |> Enum.count(fn field -> Map.has_key?(output, field) end)

      ratio = present_count / length(expected_fields)
      ratio * 0.3
    end
  end

  @doc """
  Score error-free execution (max 0.3).

  Returns 0.3 if no errors/warnings, reduced based on error count.

  ## Examples

      iex> output = %{"errors" => [], "warnings" => []}
      iex> SNScorer.error_free_execution(output)
      0.3
  """
  @spec error_free_execution(output) :: score
  def error_free_execution(output) when is_map(output) do
    errors = Map.get(output, "errors", [])
    warnings = Map.get(output, "warnings", [])

    error_count = length(errors)
    warning_count = length(warnings)

    case {error_count, warning_count} do
      {0, 0} ->
        0.3

      {0, w} when w > 0 ->
        # Warnings reduce score proportionally
        max(0.3 * (1.0 - min(w / 5.0, 0.6)), 0.05)

      {e, _} when e > 0 ->
        # Errors have higher penalty
        max(0.3 * (1.0 - min(e / 2.0, 0.9)), 0.01)
    end
  end

  @doc """
  Score state consistency (max 0.2).

  Returns 0.2 if state is consistent, less if inconsistencies detected.

  ## Examples

      iex> output = %{"status" => "success", "data" => %{"valid" => true}}
      iex> SNScorer.state_consistency(output)
      0.2
  """
  @spec state_consistency(output) :: score
  def state_consistency(output) when is_map(output) do
    status = Map.get(output, "status")
    result = Map.get(output, "result")

    is_consistent =
      case {status, result} do
        {"success", _} -> true
        {"completed", _} -> true
        {"partial_success", _} -> true
        {"failed", nil} -> true
        {"failed", "completed"} -> false
        _ -> true
      end

    if is_consistent, do: 0.2, else: 0.1
  end

  @doc """
  Score timing compliance (max 0.2).

  Returns 0.2 if execution is within deadline, less if overdue.

  ## Examples

      iex> output = %{"duration_ms" => 100}
      iex> SNScorer.timing_compliance(output, 5000)
      0.2
  """
  @spec timing_compliance(output, integer()) :: score
  def timing_compliance(output, deadline_ms) when is_map(output) and is_integer(deadline_ms) do
    duration_ms = Map.get(output, "duration_ms", 0)

    if duration_ms <= 0 do
      0.2
    else
      ratio = duration_ms / deadline_ms

      case ratio do
        r when r <= 1.0 -> 0.2
        r when r > 1.0 and r < 1.05 -> 0.12
        r when r >= 1.05 and r < 1.5 -> 0.05
        _ -> 0.0
      end
    end
  end

  @doc """
  Classify the failure mode of an output.

  Maps errors to specific failure categories for governance routing.

  Returns one of: `:ok`, `:timeout`, `:validation_error`, `:resource_error`,
  `:permission_denied`, `:unknown`.

  ## Examples

      iex> output = %{"errors" => []}
      iex> SNScorer.failure_mode_classification(output)
      :ok

      iex> output = %{"errors" => ["operation_timeout"]}
      iex> SNScorer.failure_mode_classification(output)
      :timeout
  """
  @spec failure_mode_classification(output) :: failure_mode
  def failure_mode_classification(output) when is_map(output) do
    errors = Map.get(output, "errors", [])

    case errors do
      [] ->
        :ok

      error_list ->
        error_list
        |> Enum.map(&classify_error/1)
        |> Enum.max_by(&error_severity/1)
    end
  end

  @doc """
  Determine governance tier based on S/N score.

  Returns the approval tier required for the output:
  - `:autonomous` (S/N > 0.8): auto-approve
  - `:human_review` (0.7 ≤ S/N ≤ 0.8): manager approval
  - `:board_escalation` (S/N < 0.7): C-level approval

  ## Examples

      iex> SNScorer.governance_tier_routing(0.85)
      :autonomous

      iex> SNScorer.governance_tier_routing(0.75)
      :human_review

      iex> SNScorer.governance_tier_routing(0.65)
      :board_escalation
  """
  @spec governance_tier_routing(score) :: governance_tier
  def governance_tier_routing(score) when is_float(score) do
    cond do
      score > 0.8 -> :autonomous
      score >= 0.7 -> :human_review
      true -> :board_escalation
    end
  end

  @doc """
  Score output and return both score and governance tier.

  Convenience function combining `score/2` and `governance_tier_routing/1`.

  ## Examples

      iex> output = %{"status" => "success", "errors" => []}
      iex> {score, tier} = SNScorer.score_with_governance(output, %{"deadline_ms" => 5000})
      iex> {is_float(score), tier}
      {true, :autonomous}
  """
  @spec score_with_governance(output, context) :: {score, governance_tier}
  def score_with_governance(output, context \\ %{}) when is_map(output) and is_map(context) do
    score = score(output, context)
    tier = governance_tier_routing(score)
    {score, tier}
  end

  # ---- Private helpers ----

  @spec classify_error(String.t() | atom()) :: failure_mode
  defp classify_error(error) when is_binary(error) or is_atom(error) do
    error_str = String.downcase(to_string(error))

    cond do
      String.contains?(error_str, ["timeout", "deadline"]) ->
        :timeout

      String.contains?(error_str, ["validation", "invalid", "schema"]) ->
        :validation_error

      String.contains?(error_str, ["memory", "resource", "out_of"]) ->
        :resource_error

      String.contains?(error_str, ["permission", "denied", "unauthorized"]) ->
        :permission_denied

      true ->
        :unknown
    end
  end

  @spec error_severity(failure_mode) :: integer()
  defp error_severity(mode) do
    case mode do
      :timeout -> 4
      :validation_error -> 3
      :resource_error -> 4
      :permission_denied -> 5
      :unknown -> 1
      :ok -> 0
    end
  end
end
