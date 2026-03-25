defmodule OptimalSystemAgent.Process.OrgEvolution do
  @moduledoc """
  Self-Evolving Organization -- Innovation 2.

  The system evolves its own organization structure based on execution data.
  Detects process drift, proposes org mutations, optimizes workflows, and
  generates SOPs from observed patterns.

  ## Signal Theory Integration

  Governance follows Signal Theory risk classification:

      Risk score < 0.3   → :auto          (system approves)
      Risk score 0.3-0.7 → :human_review  (queues for operator)
      Risk score > 0.7   → :board_approval (requires explicit approval)

  ## ETS Tables

      :osa_org_snapshots  — periodic org state snapshots
      :osa_org_proposals  — change proposals with status tracking

  ## Public API

      start_link/1           — GenServer lifecycle
      detect_drift/1         — compare expected vs actual execution patterns
      propose_mutation/2     — generate structural change proposals
      optimize_workflow/2    — optimize a workflow from execution history
      generate_sop/2         — generate best-practice SOP from recent runs
      org_health/1           — comprehensive health assessment
      snapshot/1             — persist a point-in-time org snapshot
      list_proposals/0       — list all proposals with status
      approve_proposal/2     — approve a pending proposal
      reject_proposal/2      — reject a pending proposal
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus

  # ── ETS Table Names ─────────────────────────────────────────────────────

  @snapshots_table :osa_org_snapshots
  @proposals_table :osa_org_proposals

  # ── Governance Thresholds (Signal Theory) ──────────────────────────────

  @auto_threshold 0.3
  @board_threshold 0.7

  # ── GenServer State ────────────────────────────────────────────────────

  defstruct drift_analysis_count: 0,
            mutation_count: 0,
            optimization_count: 0,
            sop_count: 0,
            last_snapshot_at: nil

  # ── Child Spec ─────────────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # ── Client API ─────────────────────────────────────────────────────────

  @doc """
  Detect organizational drift by comparing expected vs actual execution patterns.

  Takes an `org_config` map with `:teams`, `:roles`, and `:workflows` keys.
  Returns a drift analysis map with a composite `:drift_score`, typed
  `:drifts` list, and a natural-language `:recommendation`.
  """
  @spec detect_drift(map()) :: map()
  def detect_drift(org_config) when is_map(org_config) do
    GenServer.call(__MODULE__, {:detect_drift, org_config}, 30_000)
  end

  def detect_drift(nil) do
    {:error, :org_config_is_nil}
  end

  @doc """
  Propose structural mutations based on org config and a prior drift analysis.

  Returns a map of `:proposals` (each with confidence, risk_score, and
  justification) and a `:governance` level determined by the highest-risk
  proposal in the set.
  """
  @spec propose_mutation(map(), map()) :: map()
  def propose_mutation(org_config, drift_analysis) when is_map(org_config) and is_map(drift_analysis) do
    GenServer.call(__MODULE__, {:propose_mutation, org_config, drift_analysis}, 30_000)
  end

  @doc """
  Optimize a workflow based on its execution history.

  Takes a `workflow_id` and a list of `execution_history` entries. Returns
  the original metrics, optimized metrics, a list of changes, and the
  percentage improvement.
  """
  @spec optimize_workflow(String.t(), [map()]) :: map()
  def optimize_workflow(workflow_id, execution_history) when is_binary(workflow_id) and is_list(execution_history) do
    GenServer.call(__MODULE__, {:optimize_workflow, workflow_id, execution_history}, 30_000)
  end

  @doc """
  Generate a Standard Operating Procedure from recent process executions.

  Returns a structured SOP with version, step-by-step actions, owners,
  SLA targets, and aggregate metrics.
  """
  @spec generate_sop(String.t(), [map()]) :: map()
  def generate_sop(process_id, recent_executions) when is_binary(process_id) and is_list(recent_executions) do
    GenServer.call(__MODULE__, {:generate_sop, process_id, recent_executions}, 30_000)
  end

  @doc """
  Produce a comprehensive organizational health assessment.

  Returns an `:overall_health` score (0.0-1.0), dimension-level scores,
  and prioritized recommendations.
  """
  @spec org_health(map()) :: map()
  def org_health(org_config) when is_map(org_config) do
    GenServer.call(__MODULE__, {:org_health, org_config}, 30_000)
  end

  @doc """
  Persist a point-in-time snapshot of the organization's state to ETS.
  """
  @spec snapshot(map()) :: :ok
  def snapshot(org_state) when is_map(org_state) do
    GenServer.call(__MODULE__, {:snapshot, org_state})
  end

  @doc """
  List all change proposals, optionally filtered by status.

  Statuses: `:pending`, `:approved`, `:rejected`, `:expired`, `:applied`.
  """
  @spec list_proposals(atom() | nil) :: [map()]
  def list_proposals(status \\ nil) do
    GenServer.call(__MODULE__, {:list_proposals, status})
  end

  @doc """
  Approve a pending proposal by its ID. Applies the governance check.
  """
  @spec approve_proposal(String.t(), String.t() | nil) :: {:ok, map()} | {:error, term()}
  def approve_proposal(proposal_id, approved_by \\ nil) do
    GenServer.call(__MODULE__, {:approve_proposal, proposal_id, approved_by})
  end

  @doc """
  Reject a pending proposal by its ID.
  """
  @spec reject_proposal(String.t(), String.t() | nil) :: {:ok, map()} | {:error, term()}
  def reject_proposal(proposal_id, rejected_by \\ nil) do
    GenServer.call(__MODULE__, {:reject_proposal, proposal_id, rejected_by})
  end

  @doc """
  Initialize ETS tables. Called once from Application startup.
  """
  @spec init_tables() :: :ok
  def init_tables do
    if :ets.whereis(@snapshots_table) != :undefined do
      :ok
    else
      :ets.new(@snapshots_table, [:named_table, :public, :set, read_concurrency: true])
    end

    if :ets.whereis(@proposals_table) != :undefined do
      :ok
    else
      :ets.new(@proposals_table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end

  # ── GenServer Callbacks ───────────────────────────────────────────────

  @impl true
  def init(:ok) do
    init_tables()
    Logger.info("[OrgEvolution] Self-Evolving Organization module started")
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:detect_drift, org_config}, _from, state) do
    result = compute_drift(org_config)

    Bus.emit(:system_event, %{
      event: :org_drift_detected,
      drift_score: result.drift_score,
      drift_count: length(result.drifts)
    })

    updated = %{state | drift_analysis_count: state.drift_analysis_count + 1}
    {:reply, result, updated}
  end

  @impl true
  def handle_call({:propose_mutation, org_config, drift_analysis}, _from, state) do
    result = compute_mutations(org_config, drift_analysis)

    # Persist each proposal to ETS
    Enum.each(result.proposals, fn proposal ->
      proposal_id = generate_id("prop")

      record = %{
        id: proposal_id,
        type: proposal.type,
        from: proposal[:from],
        to: proposal[:to],
        confidence: proposal.confidence,
        risk_score: proposal.risk_score,
        justification: proposal.justification,
        governance: classify_governance(proposal.risk_score),
        status: classify_governance(proposal.risk_score) == :auto && :approved || :pending,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        org_config_snapshot: org_config
      }

      :ets.insert(@proposals_table, {proposal_id, record})
    end)

    Bus.emit(:system_event, %{
      event: :org_mutation_proposed,
      proposal_count: length(result.proposals),
      governance: result.governance
    })

    updated = %{state | mutation_count: state.mutation_count + 1}
    {:reply, result, updated}
  end

  @impl true
  def handle_call({:optimize_workflow, workflow_id, execution_history}, _from, state) do
    result = compute_workflow_optimization(workflow_id, execution_history)

    Bus.emit(:system_event, %{
      event: :workflow_optimized,
      workflow_id: workflow_id,
      savings_pct: result.savings_pct
    })

    updated = %{state | optimization_count: state.optimization_count + 1}
    {:reply, result, updated}
  end

  @impl true
  def handle_call({:generate_sop, process_id, recent_executions}, _from, state) do
    result = compute_sop(process_id, recent_executions)

    Bus.emit(:system_event, %{
      event: :sop_generated,
      process_id: process_id,
      version: result.version
    })

    updated = %{state | sop_count: state.sop_count + 1}
    {:reply, result, updated}
  end

  @impl true
  def handle_call({:org_health, org_config}, _from, state) do
    result = compute_org_health(org_config)

    Bus.emit(:system_event, %{
      event: :org_health_assessed,
      overall_health: result.overall_health
    })

    {:reply, result, state}
  end

  @impl true
  def handle_call({:snapshot, org_state}, _from, state) do
    snapshot_id = generate_id("snap")

    record = %{
      id: snapshot_id,
      org_state: org_state,
      captured_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ets.insert(@snapshots_table, {snapshot_id, record})

    updated = %{state | last_snapshot_at: record.captured_at}

    Logger.debug("[OrgEvolution] Snapshot #{snapshot_id} captured")
    {:reply, :ok, updated}
  end

  @impl true
  def handle_call({:list_proposals, status_filter}, _from, state) do
    proposals =
      :ets.tab2list(@proposals_table)
      |> Enum.map(fn {_id, record} -> record end)
      |> maybe_filter_by_status(status_filter)
      |> Enum.sort_by(& &1.created_at, :desc)

    {:reply, proposals, state}
  end

  @impl true
  def handle_call({:approve_proposal, proposal_id, approved_by}, _from, state) do
    result = update_proposal_status(proposal_id, :approved, approved_by)

    case result do
      {:ok, record} ->
        Bus.emit(:system_event, %{
          event: :org_proposal_approved,
          proposal_id: proposal_id,
          type: record.type,
          approved_by: approved_by
        })

      _ ->
        :ok
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:reject_proposal, proposal_id, rejected_by}, _from, state) do
    result = update_proposal_status(proposal_id, :rejected, rejected_by)

    case result do
      {:ok, _record} ->
        Bus.emit(:system_event, %{
          event: :org_proposal_rejected,
          proposal_id: proposal_id,
          rejected_by: rejected_by
        })

      _ ->
        :ok
    end

    {:reply, result, state}
  end

  # ── Drift Detection ───────────────────────────────────────────────────

  defp compute_drift(org_config) do
    teams = Map.get(org_config, :teams, %{})
    roles = Map.get(org_config, :roles, %{})
    workflows = Map.get(org_config, :workflows, %{})
    execution_data = Map.get(org_config, :execution_data, [])

    drifts =
      []
      |> detect_role_overload(teams, execution_data)
      |> detect_workflow_bypass(workflows, execution_data)
      |> detect_redundant_processes(workflows, execution_data)
      |> detect_skill_gaps(roles, execution_data)
      |> detect_bottlenecks(workflows, execution_data)

    drift_score = calculate_drift_score(drifts)
    recommendation = synthesize_recommendation(drifts, drift_score)

    %{
      drift_score: drift_score,
      drifts: drifts,
      recommendation: recommendation,
      analyzed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp detect_role_overload(drifts, teams, execution_data) do
    team_drifts =
      teams
      |> Enum.map(fn {team_name, team_config} ->
        expected_capacity = Map.get(team_config, :expected_capacity, 1.0)
        actual_load = compute_team_load(team_name, execution_data)

        overload_ratio = actual_load / max(expected_capacity, 0.01)

        if overload_ratio > 1.5 do
          %{
            type: :role_overload,
            entity: team_name,
            severity: classify_severity(overload_ratio, 1.5, 3.0),
            details: "Handling #{Float.round(overload_ratio, 1)}x expected task volume",
            metric: %{expected: expected_capacity, actual: actual_load, ratio: overload_ratio}
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    drifts ++ team_drifts
  end

  defp detect_workflow_bypass(drifts, workflows, execution_data) do
    workflow_drifts =
      workflows
      |> Enum.map(fn {workflow_name, workflow_config} ->
        required = Map.get(workflow_config, :required_steps, [])
        bypass_rate = compute_bypass_rate(workflow_name, required, execution_data)

        if bypass_rate > 0.2 do
          %{
            type: :workflow_bypass,
            entity: workflow_name,
            severity: classify_severity(bypass_rate, 0.2, 0.5),
            details: "#{Float.round(bypass_rate * 100, 0)}% of changes skip #{workflow_name}",
            metric: %{bypass_rate: bypass_rate}
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    drifts ++ workflow_drifts
  end

  defp detect_redundant_processes(drifts, workflows, execution_data) do
    process_drifts =
      workflows
      |> Enum.map(fn {process_name, process_config} ->
        frequency = Map.get(process_config, :frequency, "daily")
        info_yield = compute_information_yield(process_name, execution_data)

        if info_yield < 0.2 do
          %{
            type: :redundant_process,
            entity: process_name,
            severity: classify_severity(1.0 - info_yield, 0.5, 0.8),
            details: "No new information in #{Float.round((1.0 - info_yield) * 100, 0)}% of #{frequency} runs",
            metric: %{information_yield: info_yield}
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    drifts ++ process_drifts
  end

  defp detect_skill_gaps(drifts, roles, execution_data) do
    role_drifts =
      roles
      |> Enum.map(fn {role_name, role_config} ->
        required_skills = Map.get(role_config, :required_skills, [])
        task_match = compute_skill_match_rate(role_name, required_skills, execution_data)

        if task_match < 0.6 do
          %{
            type: :skill_gap,
            entity: role_name,
            severity: classify_severity(1.0 - task_match, 0.3, 0.6),
            details: "Role tasks match only #{Float.round(task_match * 100, 0)}% of required skills",
            metric: %{match_rate: task_match}
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    drifts ++ role_drifts
  end

  defp detect_bottlenecks(drifts, workflows, execution_data) do
    bottleneck_drifts =
      workflows
      |> Enum.map(fn {workflow_name, _workflow_config} ->
        cycle_times = get_cycle_times(workflow_name, execution_data)

        if length(cycle_times) > 2 do
          avg = Enum.sum(cycle_times) / length(cycle_times)
          max_time = Enum.max(cycle_times)
          threshold = avg * 2.0

          if max_time > threshold do
            %{
              type: :bottleneck,
              entity: workflow_name,
              severity: classify_severity(max_time / avg, 2.0, 4.0),
              details: "Worst case #{Float.round(max_time / avg, 1)}x average cycle time",
              metric: %{avg_cycle_time: avg, max_cycle_time: max_time}
            }
          else
            nil
          end
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    drifts ++ bottleneck_drifts
  end

  defp calculate_drift_score([]), do: 0.0

  defp calculate_drift_score(drifts) do
    severity_weights = %{critical: 1.0, high: 0.8, medium: 0.5, low: 0.2}

    weighted_sum =
      Enum.reduce(drifts, 0.0, fn drift, acc ->
        weight = Map.get(severity_weights, drift.severity, 0.3)
        acc + weight
      end)

    # Normalize to 0.0-1.0 range (5+ high-severity drifts = max)
    min(weighted_sum / 5.0, 1.0) |> Float.round(2)
  end

  defp synthesize_recommendation(_drifts, drift_score) when drift_score < 0.2 do
    "Organization structure is aligned with execution patterns"
  end

  defp synthesize_recommendation(drifts, _drift_score) do
    drifts
    |> Enum.filter(fn d -> d.severity in [:high, :critical] end)
    |> Enum.take(3)
    |> Enum.map(fn d -> action_for_drift(d) end)
    |> Enum.join("; ")
  end

  defp action_for_drift(%{type: :role_overload, entity: entity}),
    do: "Consider scaling or splitting #{entity}"

  defp action_for_drift(%{type: :workflow_bypass, entity: entity}),
    do: "Automate or streamline #{entity} to reduce bypass rate"

  defp action_for_drift(%{type: :redundant_process, entity: entity}),
    do: "Consider replacing #{entity} with an async alternative"

  defp action_for_drift(%{type: :skill_gap, entity: entity}),
    do: "Upskill #{entity} or reassign tasks to better-matched roles"

  defp action_for_drift(%{type: :bottleneck, entity: entity}),
    do: "Investigate and parallelize the bottleneck step in #{entity}"

  defp action_for_drift(%{type: _, entity: entity}),
    do: "Review and optimize #{entity}"

  # ── Mutation Proposals ────────────────────────────────────────────────

  defp compute_mutations(org_config, drift_analysis) do
    teams = Map.get(org_config, :teams, %{})
    roles = Map.get(org_config, :roles, %{})
    drifts = Map.get(drift_analysis, :drifts, [])

    proposals =
      []
      |> propose_team_merges(drifts, teams, org_config)
      |> propose_team_splits(drifts, teams, org_config)
      |> propose_role_splits(drifts, roles, org_config)
      |> propose_role_merges(drifts, roles, org_config)
      |> propose_automation(drifts, org_config)
      |> sort_proposals_by_confidence()

    governance = determine_governance_level(proposals)

    %{
      proposals: proposals,
      governance: governance,
      proposed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp propose_team_merges(proposals, drifts, _teams, org_config) do
    overloaded_teams =
      drifts
      |> Enum.filter(&(&1.type == :role_overload and &1.severity in [:high, :critical]))
      |> Enum.map(& &1.entity)

    if length(overloaded_teams) >= 2 do
      merged_name = suggest_merged_name(overloaded_teams)
      cross_functional_rate = compute_cross_functional_rate(overloaded_teams, org_config)

      confidence = min(0.5 + cross_functional_rate * 0.4, 0.95)

      [%{
        type: :merge_teams,
        from: overloaded_teams,
        to: merged_name,
        confidence: Float.round(confidence, 2),
        risk_score: Float.round(1.0 - confidence, 2),
        justification: "Cross-functional work has increased #{Float.round(cross_functional_rate * 100, 0)}% -- overloaded teams share overlapping responsibilities"
      } | proposals]
    else
      proposals
    end
  end

  defp propose_team_splits(proposals, drifts, teams, _org_config) do
    oversized_teams =
      drifts
      |> Enum.filter(&(&1.type == :role_overload))
      |> Enum.filter(&(&1.severity == :critical))
      |> Enum.map(& &1.entity)

    Enum.reduce(oversized_teams, proposals, fn team_name, acc ->
      team_config = Map.get(teams, team_name, %{})
      responsibilities = Map.get(team_config, :responsibilities, [])

      if length(responsibilities) > 4 do
        [_half1, _half2] = Enum.split(responsibilities, div(length(responsibilities), 2))
        name1 = "#{team_name}-core"
        name2 = "#{team_name}-platform"

        [
          %{
            type: :split_team,
            from: team_name,
            to: [name1, name2],
            confidence: 0.70,
            risk_score: 0.35,
            justification: "Team scope (#{length(responsibilities)} responsibilities) exceeds sustainable capacity"
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp propose_role_splits(proposals, drifts, roles, _org_config) do
    skill_gap_drifts =
      drifts
      |> Enum.filter(&(&1.type == :skill_gap and &1.severity in [:medium, :high]))

    Enum.reduce(skill_gap_drifts, proposals, fn drift, acc ->
      role_name = drift.entity
      role_config = Map.get(roles, role_name, %{})
      scope = Map.get(role_config, :scope, [])

      if length(scope) > 3 do
        [_half1, _half2] = Enum.split(scope, div(length(scope), 2))
        name1 = role_name |> String.replace_suffix("-engineer", "-engineer") |> String.replace("devops", "sre")
        name2 = "platform-#{role_name}"

        [
          %{
            type: :split_role,
            from: role_name,
            to: [name1, name2],
            confidence: 0.65,
            risk_score: 0.40,
            justification: "Role scope has diverged into two distinct responsibility areas"
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp propose_role_merges(proposals, drifts, _roles, _org_config) do
    # Merge roles that are frequently co-assigned to the same tasks
    low_utilization_drifts =
      drifts
      |> Enum.filter(&(&1.type == :role_overload and &1.severity == :low))

    if length(low_utilization_drifts) >= 2 do
      entities = Enum.map(low_utilization_drifts, & &1.entity)
      merged = Enum.join(entities, "-") |> String.slice(0, 40)

      [
        %{
          type: :merge_roles,
          from: entities,
          to: merged,
          confidence: 0.55,
          risk_score: 0.30,
          justification: "Roles #{Enum.join(entities, ", ")} have low utilization -- merging reduces coordination overhead"
        }
        | proposals
      ]
    else
      proposals
    end
  end

  defp propose_automation(proposals, drifts, _org_config) do
    bypass_drifts =
      drifts
      |> Enum.filter(&(&1.type == :workflow_bypass and &1.severity in [:medium, :high]))

    Enum.reduce(bypass_drifts, proposals, fn drift, acc ->
      bypass_rate = get_in(drift, [:metric, :bypass_rate]) || 0.5

      [
        %{
          type: :automate_process,
          from: drift.entity,
          to: "automated-#{drift.entity}",
          confidence: min(0.6 + bypass_rate * 0.3, 0.95) |> Float.round(2),
          risk_score: max(0.15, 0.4 - bypass_rate * 0.3) |> Float.round(2),
          justification: "High bypass rate (#{Float.round(bypass_rate * 100, 0)}%) indicates manual process should be automated"
        }
        | acc
      ]
    end)
  end

  defp sort_proposals_by_confidence(proposals) do
    Enum.sort_by(proposals, & &1.confidence, :desc)
  end

  defp determine_governance_level([]), do: :auto

  defp determine_governance_level(proposals) do
    max_risk =
      proposals
      |> Enum.map(& &1.risk_score)
      |> Enum.max(fn -> 0.0 end)

    classify_governance(max_risk)
  end

  defp classify_governance(risk) when risk < @auto_threshold, do: :auto
  defp classify_governance(risk) when risk > @board_threshold, do: :board_approval
  defp classify_governance(_risk), do: :human_review

  # ── Workflow Optimization ─────────────────────────────────────────────

  defp compute_workflow_optimization(workflow_id, execution_history) do
    original = extract_original_metrics(workflow_id, execution_history)
    optimized = compute_optimized_metrics(original, execution_history)
    changes = derive_changes(workflow_id, original, optimized, execution_history)
    savings_pct = compute_savings_pct(original, optimized)

    %{
      workflow_id: workflow_id,
      original: original,
      optimized: optimized,
      changes: changes,
      savings_pct: Float.round(savings_pct, 1),
      optimized_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp extract_original_metrics(_workflow_id, []) do
    %{steps: 0, avg_cycle_time_ms: 0, success_rate: 0.0}
  end

  defp extract_original_metrics(_workflow_id, execution_history) do
    step_counts = Enum.map(execution_history, &Map.get(&1, :step_count, 1))
    cycle_times = Enum.map(execution_history, &Map.get(&1, :cycle_time_ms, 0))
    successes = Enum.count(execution_history, &Map.get(&1, :success, false))

    %{
      steps: Enum.max(step_counts) |> max(1),
      avg_cycle_time_ms: if(cycle_times == [], do: 0, else: round(Enum.sum(cycle_times) / length(cycle_times))),
      success_rate: if(execution_history == [], do: 0.0, else: Float.round(successes / length(execution_history), 2))
    }
  end

  defp compute_optimized_metrics(original, execution_history) do
    # Analyze execution history for removable steps, parallelizable sequences,
    # and missing checks that would catch failures
    removable_steps = count_removable_steps(execution_history)
    parallelizable = count_parallelizable_pairs(execution_history)
    missing_checks = count_missing_checks(execution_history)

    optimized_steps = max(original.steps - removable_steps + missing_checks, 1)
    time_reduction_factor = (removable_steps * 0.15) + (parallelizable * 0.25)
    new_cycle_time = round(original.avg_cycle_time_ms * max(1.0 - time_reduction_factor, 0.3))

    # Estimate improved success rate from added checks
    failure_reduction = missing_checks * 0.05
    new_success_rate = min(original.success_rate + failure_reduction, 1.0) |> Float.round(2)

    %{
      steps: optimized_steps,
      avg_cycle_time_ms: new_cycle_time,
      success_rate: new_success_rate
    }
  end

  defp derive_changes(_workflow_id, _original, _optimized, execution_history) do
    # Detect auto-approvable steps
    approval_skip_rate = compute_approval_auto_rate(execution_history)

    # Detect independent steps that could run in parallel
    independent_pairs = detect_independent_steps(execution_history)

    # Detect missing test coverage
    bug_before_review_rate = compute_bug_before_review_rate(execution_history)

    changes =
      []
      |> maybe_add_change(
        approval_skip_rate > 0.9,
        %{
          type: :remove_step,
          step: "manual_approval",
          reason: "Auto-approved #{Float.round(approval_skip_rate * 100, 0)}% of requests"
        }
      )
      |> then(fn acc ->
        if length(independent_pairs) > 0 do
          [%{
            type: :parallelize,
            steps: hd(independent_pairs),
            reason: "Independent checks detected from execution timing analysis"
          } | acc]
        else
          acc
        end
      end)
      |> maybe_add_change(
        bug_before_review_rate > 0.1,
        %{
          type: :add_step,
          step: "automated_test",
          reason: "Catches #{Float.round(bug_before_review_rate * 100, 0)}% of bugs before review"
        }
      )

    Enum.reverse(changes)
  end

  defp maybe_add_change(acc, true, change), do: [change | acc]
  defp maybe_add_change(acc, false, _change), do: acc

  defp compute_savings_pct(original, optimized) do
    if original.avg_cycle_time_ms == 0 do
      0.0
    else
      (original.avg_cycle_time_ms - optimized.avg_cycle_time_ms) / original.avg_cycle_time_ms * 100
    end
  end

  # ── SOP Generation ────────────────────────────────────────────────────

  defp compute_sop(process_id, recent_executions) do
    steps = derive_sop_steps(process_id, recent_executions)
    version = compute_sop_version(process_id)
    metrics = compute_sop_metrics(recent_executions)

    %{
      title: format_process_title(process_id),
      version: version,
      generated_from: "Last #{length(recent_executions)} executions",
      steps: steps,
      metrics: metrics,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp derive_sop_steps(_process_id, []), do: []

  defp derive_sop_steps(_process_id, recent_executions) do
    # Extract the most common step sequence from recent executions
    step_patterns =
      recent_executions
      |> Enum.map(&Map.get(&1, :steps, []))
      |> Enum.reject(&(&1 == []))

    if step_patterns == [] do
      []
    else
      # Find the median-length execution as the canonical pattern
      sorted = Enum.sort_by(step_patterns, &length/1)
      median_idx = div(length(sorted), 2)
      canonical = Enum.at(sorted, median_idx, hd(sorted))

      # Enrich each step with owner and SLA from execution data
      canonical
      |> Enum.with_index(1)
      |> Enum.map(fn {step, idx} ->
        avg_duration = compute_avg_step_duration(step, recent_executions)

        %{
          step: idx,
          action: Map.get(step, :action, "Step #{idx}"),
          owner: determine_step_owner(step, recent_executions),
          sla_minutes: max(round(avg_duration / 60_000), 1)
        }
      end)
    end
  end

  defp compute_sop_version(process_id) do
    # Count existing SOPs for this process
    existing =
      :ets.tab2list(@snapshots_table)
      |> Enum.filter(fn {_id, record} ->
        record.org_state[:process_id] == process_id and
          Map.has_key?(record.org_state, :sop_version)
      end)

    length(existing) + 1
  end

  defp compute_sop_metrics([]) do
    %{avg_cycle_time: "0min", compliance_rate: "0%", skip_rate: "0%"}
  end

  defp compute_sop_metrics(recent_executions) do
    cycle_times = Enum.map(recent_executions, &Map.get(&1, :cycle_time_ms, 0))
    avg_cycle = if(cycle_times == [], do: 0, else: Enum.sum(cycle_times) / length(cycle_times))

    completed = Enum.count(recent_executions, &Map.get(&1, :completed, false))
    total = length(recent_executions)
    compliance_rate = if(total == 0, do: 0.0, else: completed / total)

    skipped_steps =
      recent_executions
      |> Enum.map(fn exec -> length(Map.get(exec, :skipped_steps, [])) end)
      |> Enum.sum()

    total_steps =
      recent_executions
      |> Enum.map(fn exec -> length(Map.get(exec, :steps, [])) end)
      |> Enum.sum()

    skip_rate = if(total_steps == 0, do: 0.0, else: skipped_steps / total_steps)

    %{
      avg_cycle_time: "#{Float.round(avg_cycle / 60_000, 0)}min",
      compliance_rate: "#{Float.round(compliance_rate * 100, 0)}%",
      skip_rate: "#{Float.round(skip_rate * 100, 0)}%"
    }
  end

  defp format_process_title(process_id) do
    process_id
    |> String.replace("-", " ")
    |> String.split(~r/\s+/)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    |> Kernel.<>(" Process")
  end

  # ── Org Health ────────────────────────────────────────────────────────

  defp compute_org_health(org_config) when not is_map(org_config), do: %{
    overall_health: 0.0, dimensions: %{}, recommendations: [], assessed_at: DateTime.utc_now() |> DateTime.to_iso8601()
  }

  defp compute_org_health(org_config) do
    teams = Map.get(org_config, :teams, %{})
    workflows = Map.get(org_config, :workflows, %{})
    execution_data = Map.get(org_config, :execution_data, [])

    dimensions = %{
      role_utilization: compute_role_utilization(teams, execution_data),
      workflow_efficiency: compute_workflow_efficiency(workflows, execution_data),
      communication_flow: compute_communication_flow(org_config, execution_data),
      process_compliance: compute_process_compliance(workflows, execution_data)
    }

    overall = dimensions |> Map.values() |> Enum.sum() |> Kernel./(map_size(dimensions)) |> Float.round(2)

    recommendations = generate_health_recommendations(dimensions)

    %{
      overall_health: overall,
      dimensions: dimensions,
      recommendations: recommendations,
      assessed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp compute_role_utilization(teams, execution_data) do
    if !is_map(teams) or map_size(teams) == 0 do
      0.5
    else
      utilizations =
        teams
        |> Enum.map(fn {team_name, _config} ->
          load = compute_team_load(team_name, execution_data)
          cond do
            load < 0.3 -> load
            load > 1.5 -> max(0.0, 1.0 - (load - 1.5) * 0.5)
            true -> 1.0 - abs(load - 0.75) * 0.8
          end
        end)

      if utilizations == [], do: 0.5, else: Float.round(Enum.sum(utilizations) / length(utilizations), 2)
    end
  end

  defp compute_workflow_efficiency(workflows, execution_data) do
    if !is_map(workflows) or map_size(workflows) == 0 do
      0.5
    else
      efficiencies =
        workflows
        |> Enum.map(fn {workflow_name, _config} ->
          cycle_times = get_cycle_times(workflow_name, execution_data)

          if length(cycle_times) > 1 do
            avg = Enum.sum(cycle_times) / length(cycle_times)
            variance = cycle_times |> Enum.map(&(&1 - avg)) |> Enum.map(fn x -> x * x end) |> Enum.sum() |> Kernel./(length(cycle_times))
            std_dev = :math.sqrt(variance)
            cv = if avg == 0, do: 1.0, else: std_dev / avg
            max(0.0, 1.0 - cv)
          else
            0.5
          end
        end)

      if efficiencies == [], do: 0.5, else: Float.round(Enum.sum(efficiencies) / length(efficiencies), 2)
    end
  end

  defp compute_communication_flow(org_config, execution_data) do
    teams = Map.get(org_config, :teams, %{})
    teams = if is_map(teams), do: teams, else: %{}

    if map_size(teams) < 2 do
      0.8
    else
      team_names = Map.keys(teams)
      total_interactions = count_cross_team_interactions(team_names, execution_data)
      max_possible = length(team_names) * (length(team_names) - 1)

      if max_possible == 0 do
        0.8
      else
        interaction_ratio = total_interactions / max_possible
        min(interaction_ratio * 2.0, 1.0) |> Float.round(2)
      end
    end
  end

  defp compute_process_compliance(workflows, execution_data) do
    if !is_map(workflows) or map_size(workflows) == 0 do
      0.5
    else
      compliances =
        workflows
        |> Enum.map(fn {workflow_name, workflow_config} ->
          required = Map.get(workflow_config, :required_steps, [])
          bypass_rate = compute_bypass_rate(workflow_name, required, execution_data)
          1.0 - bypass_rate
        end)

      if compliances == [], do: 0.5, else: Float.round(Enum.sum(compliances) / length(compliances), 2)
    end
  end

  defp generate_health_recommendations(dimensions) do
    recommendations = []

    recommendations =
      if dimensions.role_utilization < 0.6 do
        ["Review team capacity allocation -- utilization below healthy threshold" | recommendations]
      else
        recommendations
      end

    recommendations =
      if dimensions.workflow_efficiency < 0.6 do
        ["Investigate workflow variability -- high cycle time deviation detected" | recommendations]
      else
        recommendations
      end

    recommendations =
      if dimensions.communication_flow < 0.6 do
        ["Increase cross-team interaction frequency -- communication silos detected" | recommendations]
      else
        recommendations
      end

    recommendations =
      if dimensions.process_compliance < 0.7 do
        ["Automate process compliance checks -- bypass rate exceeds acceptable threshold" | recommendations]
      else
        recommendations
      end

    Enum.reverse(recommendations)
  end

  # ── Proposal Status Management ────────────────────────────────────────

  defp update_proposal_status(proposal_id, new_status, actor) do
    case :ets.lookup(@proposals_table, proposal_id) do
      [{^proposal_id, record}] ->
        case record.status do
          :pending ->
            updated = Map.merge(record, %{
              status: new_status,
              acted_on_at: DateTime.utc_now() |> DateTime.to_iso8601(),
              acted_by: actor
            })

            :ets.insert(@proposals_table, {proposal_id, updated})
            {:ok, updated}

          current ->
            {:error, {:invalid_status_transition, current, new_status}}
        end

      [] ->
        {:error, :not_found}
    end
  end

  # ── Metric Computation Helpers ────────────────────────────────────────

  defp compute_team_load(team_name, execution_data) when is_list(execution_data) do
    team_tasks =
      execution_data
      |> Enum.filter(&Map.get(&1, :team) == team_name)
      |> length()

    total_tasks = max(length(execution_data), 1)
    team_tasks / total_tasks * map_size_if_teams(execution_data)
  end

  defp compute_team_load(_team_name, _execution_data), do: 0.5

  defp map_size_if_teams(execution_data) do
    teams =
      execution_data
      |> Enum.map(&Map.get(&1, :team))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> length()

    max(teams, 1)
  end

  defp compute_bypass_rate(_workflow_name, required_steps, execution_data) do
    if required_steps == [] or execution_data == [] do
      0.0
    else
      total = length(execution_data)
      bypassed =
        execution_data
        |> Enum.count(fn exec ->
          completed_steps = Map.get(exec, :completed_steps, [])
          required_steps -- completed_steps != []
        end)

      bypassed / total
    end
  end

  defp compute_information_yield(process_name, execution_data) do
    process_execs =
      execution_data
      |> Enum.filter(&Map.get(&1, :process) == process_name)

    if process_execs == [] do
      0.5
    else
      informative =
        process_execs
        |> Enum.count(fn exec ->
          Map.get(exec, :produced_new_info, false) or
            Map.get(exec, :action_items_generated, 0) > 0 or
            Map.get(exec, :decisions_made, 0) > 0
        end)

      informative / length(process_execs)
    end
  end

  defp compute_skill_match_rate(role_name, required_skills, execution_data) do
    if required_skills == [] or execution_data == [] do
      0.8
    else
      role_tasks =
        execution_data
        |> Enum.filter(&Map.get(&1, :role) == role_name)

      if role_tasks == [] do
        0.8
      else
        matched =
          role_tasks
          |> Enum.count(fn task ->
            task_skills = Map.get(task, :skills_used, [])
            Enum.any?(required_skills, &(&1 in task_skills))
          end)

        matched / length(role_tasks)
      end
    end
  end

  defp get_cycle_times(workflow_name, execution_data) do
    execution_data
    |> Enum.filter(&Map.get(&1, :workflow) == workflow_name)
    |> Enum.map(&Map.get(&1, :cycle_time_ms, 0))
    |> Enum.filter(&(&1 > 0))
  end

  defp compute_cross_functional_rate(team_names, org_config) do
    # Estimate based on shared workflows between teams
    workflows = Map.get(org_config, :workflows, %{})

    shared =
      workflows
      |> Enum.count(fn {_name, config} ->
        involved = Map.get(config, :teams_involved, [])
        Enum.any?(team_names, &(&1 in involved))
      end)

    min(shared / max(length(team_names), 1), 1.0)
  end

  defp suggest_merged_name(team_names) do
    case team_names do
      [a, b] ->
        # Extract common suffix/prefix
        a_parts = String.split(a, "-")
        b_parts = String.split(b, "-")
        common = a_parts -- (a_parts -- b_parts)
        core = common ++ Enum.take(a_parts, 1)
        Enum.join(core, "-") |> String.replace_suffix("-", "-team")

      _ ->
        Enum.join(team_names, "-") |> String.slice(0, 30)
    end
  end

  defp count_removable_steps(execution_history) do
    execution_history
    |> Enum.flat_map(&Map.get(&1, :skipped_steps, []))
    |> Enum.uniq()
    |> Enum.count(fn step ->
      skip_count =
        execution_history
        |> Enum.count(fn exec ->
          step in Map.get(exec, :skipped_steps, [])
        end)

      skip_count / max(length(execution_history), 1) > 0.8
    end)
  end

  defp count_parallelizable_pairs(execution_history) do
    execution_history
    |> Enum.flat_map(&Map.get(&1, :sequential_steps, []))
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.count(fn [a, b] ->
      # If two steps often overlap in timing, they can be parallelized
      overlapping =
        execution_history
        |> Enum.count(fn exec ->
          timings = Map.get(exec, :step_timings, %{})
          a_start = Map.get(timings, a, %{}) |> Map.get(:start, 0)
          b_start = Map.get(timings, b, %{}) |> Map.get(:start, 0)
          a_start != 0 and b_start != 0 and abs(a_start - b_start) < 1000
        end)

      overlapping / max(length(execution_history), 1) > 0.5
    end)
  end

  defp count_missing_checks([]), do: 0

  defp count_missing_checks(execution_history) do
    total = length(execution_history)

    failures_after_review =
      execution_history
      |> Enum.count(fn exec ->
        Map.get(exec, :failed_after_review, false)
      end)

    if failures_after_review / total > 0.1, do: 1, else: 0
  end

  defp compute_approval_auto_rate([]), do: 0.0

  defp compute_approval_auto_rate(execution_history) do
    approvals =
      execution_history
      |> Enum.filter(&Map.get(&1, :required_approval, false))

    if approvals == [] do
      0.0
    else
      auto_approved =
        approvals
        |> Enum.count(&Map.get(&1, :auto_approved, false))

      auto_approved / length(approvals)
    end
  end

  defp detect_independent_steps(execution_history) do
    # Find step pairs that have no data dependencies
    timing_overlaps =
      execution_history
      |> Enum.flat_map(fn exec ->
        timings = Map.get(exec, :step_timings, %{})

        timings
        |> Enum.flat_map(fn {name1, t1} ->
          timings
          |> Enum.filter(fn {name2, _t2} -> name1 < name2 end)
          |> Enum.filter(fn {_name2, t2} ->
            # Overlapping timing windows suggest independence
            s1 = Map.get(t1, :start, 0)
            e1 = Map.get(t1, :end, 0)
            s2 = Map.get(t2, :start, 0)
            e2 = Map.get(t2, :end, 0)
            s1 != 0 and s2 != 0 and s1 < e2 and s2 < e1
          end)
          |> Enum.map(fn {name2, _t2} -> [name1, name2] end)
        end)
      end)

    timing_overlaps
    |> Enum.frequencies()
    |> Enum.filter(fn {_pair, count} -> count > div(length(execution_history), 2) end)
    |> Enum.map(fn {pair, _count} -> pair end)
    |> Enum.take(3)
  end

  defp compute_bug_before_review_rate([]), do: 0.0

  defp compute_bug_before_review_rate(execution_history) do
    total = length(execution_history)
    bugs_found =
      execution_history
      |> Enum.count(&Map.get(&1, :bugs_before_review, 0) > 0)

    bugs_found / total
  end

  defp compute_avg_step_duration(step, execution_history) do
    step_name = if is_map(step), do: Map.get(step, :name, ""), else: to_string(step)

    durations =
      execution_history
      |> Enum.map(&Map.get(&1, :step_timings, %{}))
      |> Enum.map(&Map.get(&1, step_name, %{}))
      |> Enum.map(&Map.get(&1, :duration_ms, 0))
      |> Enum.filter(&(&1 > 0))

    if durations == [], do: 60_000, else: Enum.sum(durations) / length(durations)
  end

  defp determine_step_owner(step, execution_history) do
    step_name = if is_map(step), do: Map.get(step, :name, ""), else: to_string(step)

    owners =
      execution_history
      |> Enum.map(&Map.get(&1, :step_owners, %{}))
      |> Enum.map(&Map.get(&1, step_name, nil))
      |> Enum.reject(&is_nil/1)

    if owners == [] do
      "system"
    else
      owners
      |> Enum.frequencies()
      |> Enum.max_by(fn {_owner, count} -> count end)
      |> elem(0)
    end
  end

  defp count_cross_team_interactions(team_names, execution_data) do
    pairs = for a <- team_names, b <- team_names, a < b, do: {a, b}

    Enum.count(pairs, fn {a, b} ->
      Enum.any?(execution_data, fn exec ->
        teams_involved = Map.get(exec, :teams_involved, [])
        a in teams_involved and b in teams_involved
      end)
    end)
  end

  # ── Shared Helpers ───────────────────────────────────────────────────

  defp classify_severity(ratio, low_threshold, high_threshold) do
    cond do
      ratio >= high_threshold -> :critical
      ratio >= low_threshold -> :high
      ratio >= low_threshold * 0.7 -> :medium
      true -> :low
    end
  end

  defp maybe_filter_by_status(proposals, nil), do: proposals

  defp maybe_filter_by_status(proposals, status) do
    Enum.filter(proposals, &(&1.status == status))
  end

  defp generate_id(prefix) do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower) |> then(&"#{prefix}_#{&1}")
  end
end
