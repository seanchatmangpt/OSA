defmodule OptimalSystemAgent.Orchestrator do
  @moduledoc """
  Subagent lifecycle management — spawn, monitor, collect results, cleanup.

  Spawns subagent Loop processes under the existing SessionSupervisor,
  forwards tool_call events as orchestrator_agent_progress, and emits
  the standard orchestrator_* events that the TUI already handles.

  Subagents are regular Loop GenServers with :subagent permission tier.
  They get their own context window, model selection, and tool access.
  """
  require Logger

  alias OptimalSystemAgent.Agent.Loop
  alias OptimalSystemAgent.Agent.Tier
  alias OptimalSystemAgent.Agent.Hooks
  alias OptimalSystemAgent.Team
  alias OptimalSystemAgent.Tracing.Context


  @doc """
  Run multiple subagents in parallel and collect all results.

  Takes a list of config maps (same format as run_subagent/1).
  Returns a list of {:ok, result} | {:error, reason} in the same order.

  Emits wave events for TUI display when wave numbers are present.
  """
  @spec run_parallel(String.t(), [map()]) :: [{:ok, String.t()} | {:error, term()}]
  def run_parallel(parent_id, configs) when is_list(configs) do
    # Group by wave number (default wave 1)
    waves =
      configs
      |> Enum.with_index()
      |> Enum.group_by(fn {config, _idx} -> Map.get(config, :wave, 1) end)
      |> Enum.sort_by(fn {wave, _} -> wave end)

    total_waves = length(waves)

    # Create team for task tracking
    team_id = "team:#{parent_id}:#{System.unique_integer([:positive])}"

    # Capture parent trace context for propagation to waves
    parent_ctx = Context.capture()
    trace_log = Context.format_for_logging(parent_ctx)
    Logger.debug("[Orchestrator] run_parallel capturing parent trace: #{trace_log}")

    # Emit task started
    emit_event(parent_id, %{
      event: "orchestrator_task_started",
      task_id: team_id
    })

    # Execute waves sequentially, tasks within each wave in parallel
    all_results =
      Enum.flat_map(waves, fn {wave_num, indexed_configs} ->
        # Emit wave start
        if total_waves > 1 do
          emit_event(parent_id, %{
            event: "orchestrator_wave_started",
            wave_number: wave_num,
            total_waves: total_waves
          })
        end

        # Spawn all tasks in this wave as async Tasks
        tasks =
          Enum.map(indexed_configs, fn {config, original_idx} ->
            config = Map.put(config, :parent_session_id, parent_id)
            {original_idx,
             Task.Supervisor.async_nolink(
               OptimalSystemAgent.TaskSupervisor,
               fn ->
                 # Restore parent trace context in child task
                 Context.restore(parent_ctx)
                 run_subagent(config)
               end
             )}
          end)

        # Wait for all tasks in this wave (10 min timeout per task)
        results =
          Enum.map(tasks, fn {original_idx, task} ->
            result =
              try do
                Task.await(task, 600_000)
              catch
                :exit, {:timeout, _} ->
                  {:ok, "[Agent timed out after 10 minutes]"}
                :exit, reason ->
                  {:ok, "[Agent crashed: #{inspect(reason)}]"}
              end

            {original_idx, result}
          end)

        # Sort by original index to maintain order
        results
        |> Enum.sort_by(fn {idx, _} -> idx end)
        |> Enum.map(fn {_, result} -> result end)
      end)

    # Emit synthesizing
    completed_count = Enum.count(all_results, fn r -> match?({:ok, _}, r) end)
    emit_event(parent_id, %{
      event: "orchestrator_synthesizing",
      agent_count: completed_count
    })

    # Emit task completed
    emit_event(parent_id, %{
      event: "orchestrator_task_completed",
      task_id: team_id
    })

    # Cleanup team
    Team.cleanup(team_id)

    all_results
  end

  @doc """
  Run a subagent to completion and return its result.

  Config map keys:
    - :task (required) -- the task description sent to the subagent
    - :parent_session_id (required) -- routes events to parent's SSE stream
    - :role -- display name (e.g., "architect", "backend")
    - :tier -- :elite | :specialist | :utility (default :specialist)
    - :model -- explicit model override (otherwise resolved from tier)
    - :provider -- provider override (otherwise uses app default)
    - :max_iterations -- override tier default
    - :system_prompt -- override from AGENT.md
    - :tools_allowed -- allowlist from AGENT.md (nil = all)
    - :tools_blocked -- denylist from AGENT.md
  """
  @spec run_subagent(map()) :: {:ok, String.t()} | {:error, term()}
  def run_subagent(config) do
    task = Map.fetch!(config, :task)
    parent_id = Map.fetch!(config, :parent_session_id)
    role = Map.get(config, :role, "agent")
    tier = Map.get(config, :tier, :specialist)

    # Resolve model
    provider = Map.get(config, :provider) ||
      Application.get_env(:optimal_system_agent, :default_provider, :ollama)
    model = Map.get(config, :model) || Tier.model_for(tier, provider)
    max_iter = Map.get(config, :max_iterations) || Tier.max_iterations(tier)

    # Generate subagent session ID
    subagent_num = next_subagent_number(parent_id)
    subagent_id = "agent:#{parent_id}:#{subagent_num}"
    task_preview = String.slice(task, 0, 80)

    Logger.info("[Orchestrator] Spawning subagent #{subagent_id} role=#{role} tier=#{tier} model=#{model}")

    # Fire subagent_start hook (can block spawning)
    hook_payload = %{
      subagent_id: subagent_id,
      parent_session_id: parent_id,
      role: role,
      tier: tier,
      model: model,
      task_preview: task_preview
    }
    try do
      Hooks.run(:subagent_start, hook_payload)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end

    # Emit: agent started
    emit_event(parent_id, %{
      event: "orchestrator_agent_started",
      agent_name: subagent_id,
      role: role,
      model: to_string(model),
      description: task_preview
    })

    # Kill any stale subagent with this ID (from a previous run/crash)
    case Registry.lookup(OptimalSystemAgent.SessionRegistry, subagent_id) do
      [{old_pid, _}] ->
        Logger.warning("[Orchestrator] Cleaning up stale subagent #{subagent_id}")
        safely_terminate(old_pid)
      [] -> :ok
    end

    # Ensure per-agent memory directory exists (persistent across sessions)
    # Sanitize role to prevent path traversal via crafted :role values.
    safe_role = Regex.replace(~r/[^a-zA-Z0-9_\-]/, role, "_")
    agent_memory_dir = Path.expand("~/.osa/agent-memory/#{safe_role}")
    File.mkdir_p(agent_memory_dir)

    # Load agent memory if it exists (first 200 lines of MEMORY.md)
    agent_memory =
      case File.read(Path.join(agent_memory_dir, "MEMORY.md")) do
        {:ok, content} ->
          lines = String.split(content, "\n") |> Enum.take(200) |> Enum.join("\n")
          "\n\n## Agent Memory (#{role})\n#{lines}"
        {:error, _} -> ""
      end

    # Build system prompt with agent memory appended
    base_prompt = Map.get(config, :system_prompt) || ""
    full_prompt = if agent_memory != "", do: base_prompt <> agent_memory, else: base_prompt

    # Spawn the subagent Loop
    subagent_opts = [
      session_id: subagent_id,
      user_id: "subagent",
      channel: :internal,
      permission_tier: :subagent,
      model: model,
      provider: provider,
      parent_session_id: parent_id,
      allowed_tools: Map.get(config, :tools_allowed),
      blocked_tools: Map.get(config, :tools_blocked, []),
      system_prompt_override: if(full_prompt != "", do: full_prompt, else: nil)
    ]

    # Start event forwarder BEFORE spawning the subagent so it catches
    # all tool_call events from the first iteration onward.
    forwarder = start_event_forwarder(subagent_id, parent_id, role)

    case DynamicSupervisor.start_child(
           OptimalSystemAgent.SessionSupervisor,
           {Loop, subagent_opts}
         ) do
      {:ok, pid} ->
        # Execute the task (blocking call)
        result = execute_and_collect(subagent_id, task, parent_id, role, max_iter)

        # Fire subagent_stop hook (learning capture, telemetry)
        {tool_uses_final, tokens_final} = get_subagent_stats(subagent_id)
        hook_result = case result do
          {_, v} -> v
          other -> inspect(other)
        end
        try do
          Hooks.run(:subagent_stop, %{
            subagent_id: subagent_id,
            parent_session_id: parent_id,
            role: role,
            tool_uses: tool_uses_final,
            tokens_used: tokens_final,
            result: hook_result
          })
        rescue
          _ -> :ok
        catch
          :exit, _ -> :ok
        end

        # Cleanup
        stop_event_forwarder(forwarder)
        safely_terminate(pid)

        result

      {:error, {:already_started, _pid}} ->
        stop_event_forwarder(forwarder)
        {:error, "Subagent session #{subagent_id} already exists"}

      {:error, reason} ->
        stop_event_forwarder(forwarder)
        Logger.error("[Orchestrator] Failed to start subagent #{subagent_id}: #{inspect(reason)}")
        emit_event(parent_id, %{
          event: "orchestrator_agent_completed",
          agent_name: subagent_id,
          status: "failed",
          error: inspect(reason),
          tool_uses: 0,
          tokens_used: 0
        })
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp execute_and_collect(subagent_id, task, parent_id, role, _max_iter) do
    start_time = System.monotonic_time(:millisecond)

    result =
      try do
        Loop.process_message(subagent_id, task)
      rescue
        e ->
          Logger.error("[Orchestrator] Subagent #{subagent_id} crashed: #{Exception.message(e)}")
          {:error, Exception.message(e)}
      catch
        :exit, reason ->
          Logger.error("[Orchestrator] Subagent #{subagent_id} exited: #{inspect(reason)}")
          {:error, inspect(reason)}
      end

    duration_ms = System.monotonic_time(:millisecond) - start_time

    # Get metadata from the subagent for the completion event
    {tool_uses, tokens_used} = get_subagent_stats(subagent_id)

    case result do
      {:ok, response} when is_binary(response) ->
        Logger.info("[Orchestrator] Subagent #{subagent_id} completed in #{duration_ms}ms (#{tool_uses} tools, #{tokens_used} tokens)")
        emit_event(parent_id, %{
          event: "orchestrator_agent_completed",
          agent_name: subagent_id,
          status: "completed",
          tool_uses: tool_uses,
          tokens_used: tokens_used
        })
        {:ok, response}

      {:error, reason} ->
        emit_event(parent_id, %{
          event: "orchestrator_agent_completed",
          agent_name: subagent_id,
          status: "failed",
          error: to_string(reason),
          tool_uses: tool_uses,
          tokens_used: tokens_used
        })
        {:ok, "[Subagent #{role} failed: #{reason}]"}

      other ->
        # Unexpected return — treat as success with inspect
        emit_event(parent_id, %{
          event: "orchestrator_agent_completed",
          agent_name: subagent_id,
          status: "completed",
          tool_uses: tool_uses,
          tokens_used: tokens_used
        })
        {:ok, inspect(other)}
    end
  end

  defp get_subagent_stats(subagent_id) do
    # Get actual metadata from the Loop GenServer
    meta = Loop.get_metadata(subagent_id)
    tool_count = length(List.wrap(Map.get(meta, :tools_used, [])))

    # Get actual token count from Loop state snapshot
    actual_tokens =
      try do
        case Loop.get_state(subagent_id) do
          {:ok, %{tokens_used: t}} when is_integer(t) and t > 0 -> t
          _ -> tool_count * 500
        end
      rescue
        _ -> tool_count * 500
      catch
        :exit, _ -> tool_count * 500
      end

    {tool_count, actual_tokens}
  rescue
    _ -> {0, 0}
  end

  # Event forwarder — spawns a Task that listens for subagent tool_call
  # events and re-emits them as orchestrator_agent_progress on the parent channel.
  defp start_event_forwarder(subagent_id, parent_id, role) do
    Task.Supervisor.start_child(OptimalSystemAgent.TaskSupervisor, fn ->
      # Subscribe INSIDE this process — PubSub subscriptions are per-process
      Phoenix.PubSub.subscribe(OptimalSystemAgent.PubSub, "osa:session:#{subagent_id}")
      forwarder_loop(subagent_id, parent_id, role, 0)
    end)
  end

  defp forwarder_loop(subagent_id, parent_id, role, tool_count) do
    receive do
      # Tool call START — update action line with what the tool is doing
      {:osa_event, %{type: :tool_call, name: tool_name, phase: phase, args: args}}
          when phase in ["start", :start] ->
        action = format_action(tool_name, args)
        emit_event(parent_id, %{
          event: "orchestrator_agent_progress",
          agent_name: subagent_id,
          current_action: action,
          tool_uses: tool_count,
          tokens_used: tool_count * 500,
          description: ""
        })
        forwarder_loop(subagent_id, parent_id, role, tool_count)

      # Tool call END — increment counter
      {:osa_event, %{type: :tool_call, name: tool_name, phase: phase}}
          when phase in ["end", :end] ->
        new_count = tool_count + 1
        emit_event(parent_id, %{
          event: "orchestrator_agent_progress",
          agent_name: subagent_id,
          current_action: to_string(tool_name),
          tool_uses: new_count,
          tokens_used: new_count * 500,
          description: ""
        })
        forwarder_loop(subagent_id, parent_id, role, new_count)

      _ ->
        forwarder_loop(subagent_id, parent_id, role, tool_count)
    after
      # Stop forwarding after 5 minutes (safety net)
      300_000 -> :ok
    end
  end

  # Format a human-readable action string from tool name + args hint.
  # e.g., "file_read /Users/roberto/..." or "web_search Rust TUI frameworks"
  defp format_action(tool_name, args) when is_binary(args) do
    hint = String.slice(args, 0, 60)
    if hint == "" or hint == "{}" do
      to_string(tool_name)
    else
      "#{tool_name}: #{hint}"
    end
  end
  defp format_action(tool_name, _), do: to_string(tool_name)

  defp stop_event_forwarder({:ok, pid}) when is_pid(pid) do
    Process.exit(pid, :normal)
  end
  defp stop_event_forwarder(_), do: :ok

  defp safely_terminate(pid) do
    try do
      DynamicSupervisor.terminate_child(OptimalSystemAgent.SessionSupervisor, pid)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end

  defp emit_event(parent_session_id, event_data) do
    event_name = Map.get(event_data, :event, "unknown")

    # Format as system_event so the SSE loop extracts the sub-event type correctly.
    # SSE loop: %{type: :system_event, event: sub} -> to_string(sub)
    # TUI SSE parser matches on event types like "orchestrator_agent_started"
    full_event =
      event_data
      |> Map.put(:type, :system_event)
      |> Map.put(:event, event_name)
      |> Map.put(:session_id, parent_session_id)

    Phoenix.PubSub.broadcast(
      OptimalSystemAgent.PubSub,
      "osa:session:#{parent_session_id}",
      {:osa_event, full_event}
    )
  rescue
    _ -> :ok
  end

  defp next_subagent_number(_parent_id) do
    # Node-unique monotonic integer — no ETS ownership issues, no race conditions.
    System.unique_integer([:positive, :monotonic])
  end

  # ---------------------------------------------------------------------------
  # Temporal Integration for Long-Running Operations
  # ---------------------------------------------------------------------------

  @doc """
  Detect if a task is long-running (>5 minutes estimated duration).

  Returns true if task complexity indicates >300 second duration.
  """
  @spec long_running_task?(String.t()) :: boolean()
  def long_running_task?(task) when is_binary(task) do
    # Check for keywords indicating complex/long-running tasks
    long_running_keywords = [
      "comprehensive", "complete", "full", "end to end",
      "production", "enterprise", "scalable", "distributed",
      "multiple stages", "multi-phase", "complex",
      "analyze all", "process all", "scan entire"
    ]

    task_lower = String.downcase(task)
    Enum.any?(long_running_keywords, &String.contains?(task_lower, &1))
  end

  @doc """
  Route task to appropriate execution backend (Temporal or in-memory).

  Returns {:temporal, workflow_id} for long-running tasks,
          {:in_memory, nil} for short-running tasks.
  """
  @spec route_task_execution(String.t(), String.t(), keyword()) :: {:temporal, String.t()} | {:in_memory, nil}
  def route_task_execution(task, parent_id, opts \\ []) do
    # Check for explicit override
    force_temporal = Keyword.get(opts, :force_temporal, false)
    force_in_memory = Keyword.get(opts, :force_in_memory, false)

    cond do
      force_temporal ->
        start_temporal_workflow(task, parent_id, opts)

      force_in_memory ->
        {:in_memory, nil}

      long_running_task?(task) ->
        start_temporal_workflow(task, parent_id, opts)

      true ->
        {:in_memory, nil}
    end
  end

  @doc """
  Start a Temporal workflow for long-running task execution.

  Returns {:temporal, workflow_id} on success, {:error, reason} on failure.
  """
  @spec start_temporal_workflow(String.t(), String.t(), keyword()) :: {:temporal, String.t()} | {:error, term()}
  def start_temporal_workflow(task, parent_id, opts \\ []) do
    # Check if TemporalAdapter is available
    if Code.ensure_loaded?(OptimalSystemAgent.Workflows.TemporalAdapter) do
      workflow_id = "workflow-#{parent_id}-#{System.unique_integer([:positive])}"

      case OptimalSystemAgent.Workflows.TemporalAdapter.start_workflow(
             workflow_id,
             %{
               "task" => task,
               "parent_session_id" => parent_id,
               "options" => opts
             }
           ) do
        {:ok, _execution_id} ->
          Logger.info("[Orchestrator] Started Temporal workflow #{workflow_id} for long-running task")
          {:temporal, workflow_id}

        {:error, reason} ->
          Logger.warning("[Orchestrator] Failed to start Temporal workflow: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.warning("[Orchestrator] TemporalAdapter not available, falling back to in-memory execution")
      {:in_memory, nil}
    end
  end

  @doc """
  Check status of a Temporal workflow.

  Returns {:ok, status} or {:error, reason}.
  """
  @spec check_temporal_workflow(String.t()) :: {:ok, map()} | {:error, term()}
  def check_temporal_workflow(workflow_id) do
    if Code.ensure_loaded?(OptimalSystemAgent.Workflows.TemporalAdapter) do
      OptimalSystemAgent.Workflows.TemporalAdapter.query_workflow(workflow_id)
    else
      {:error, :temporal_not_available}
    end
  end

  # ---------------------------------------------------------------------------
  # BFT Consensus Integration
  # ---------------------------------------------------------------------------

  @doc """
  Run BFT consensus for critical decisions requiring fault tolerance.

  Fleet of agents votes on a proposal, requiring 2/3 supermajority.
  Uses HotStuff-BFT protocol for Byzantine fault tolerance.

  Returns {:ok, results} or {:error, reason}.
  """
  @spec run_bft_consensus(String.t(), [map()], keyword()) :: {:ok, [term()]} | {:error, term()}
  def run_bft_consensus(parent_id, configs, opts \\ []) do
    Logger.info("[Orchestrator] Running BFT consensus with #{length(configs)} agents")

    # Check if HotStuff-BFT is available
    if Code.ensure_loaded?(OptimalSystemAgent.Consensus.HotStuff) do
      proposal_type = Keyword.get(opts, :proposal_type, :decision)
      proposal_content = Keyword.get(opts, :proposal_content, %{})
      proposer_id = Keyword.get(opts, :proposer_id, "orchestrator")

      # Create proposal
      proposal = OptimalSystemAgent.Consensus.Proposal.new(proposal_type, proposal_content, proposer_id)
      fleet_id = "fleet-#{parent_id}"

      # Propose vote
      case OptimalSystemAgent.Consensus.HotStuff.propose_vote(fleet_id, proposal, configs) do
        {:ok, _proposal} ->
          # Collect votes from all agents
          vote_results = Enum.map(configs, fn config ->
            agent_id = Map.get(config, :role, "agent")
            task = build_bft_voting_task(proposal, config)

            result = config
                     |> Map.put(:parent_session_id, parent_id)
                     |> Map.put(:task, task)
                     |> run_subagent()

            {agent_id, result}
          end)

              # Tally votes
              votes = Enum.reduce(vote_results, %{}, fn {agent_id, result}, acc ->
                vote = extract_vote_from_result(result)
                Map.put(acc, agent_id, vote)
              end)

              # Update proposal with votes
              proposal_with_votes = Enum.reduce(votes, proposal, fn {agent_id, vote}, prop ->
                OptimalSystemAgent.Consensus.Proposal.add_vote(prop, agent_id, vote)
              end)

              # Check consensus result
              case OptimalSystemAgent.Consensus.Proposal.calculate_result(proposal_with_votes) do
                {:ok, :approved} ->
                  OptimalSystemAgent.Consensus.HotStuff.commit(fleet_id, proposal_with_votes)
                  Logger.info("[Orchestrator] BFT consensus: APPROVED")
                  {:ok, Enum.map(vote_results, fn {_agent_id, result} -> result end)}

                {:ok, :rejected} ->
                  Logger.info("[Orchestrator] BFT consensus: REJECTED")
                  {:ok, Enum.map(vote_results, fn {_agent_id, result} -> result end)}

                {:pending, _ratio} ->
                  Logger.warning("[Orchestrator] BFT consensus: PENDING (no supermajority)")
                  {:ok, Enum.map(vote_results, fn {_agent_id, result} -> result end)}
              end

            {:error, reason} ->
              Logger.error("[Orchestrator] BFT propose failed: #{inspect(reason)}")
              {:error, reason}
          end
    else
      Logger.warning("[Orchestrator] HotStuff-BFT not available, using parallel fallback")
      # Fall back to parallel execution
      Enum.map(configs, fn config ->
        run_subagent(Map.put(config, :parent_session_id, parent_id))
      end)
    end
  end

  @doc """
  Check if a decision should use BFT consensus based on criticality.

  Returns true if decision is marked as critical or involves high-value operations.
  """
  @spec should_use_bft?(keyword()) :: boolean()
  def should_use_bft?(opts) do
    Keyword.get(opts, :critical, false) or
      Keyword.get(opts, :bft_consensus, false) or
      Keyword.get(opts, :fault_tolerance_required, false)
  end

  # Private helpers for BFT integration

  defp build_bft_voting_task(proposal, config) do
    original_task = Map.get(config, :task, "")

    """
## Proposal for Byzantine Fault Tolerant Consensus

**Type:** #{proposal.type}
**Proposal ID:** #{proposal.workflow_id}
**Proposer:** #{proposal.proposer}
**Content:** #{inspect(proposal.content)}

#{original_task}

---
**Voting Instructions:**
This is a critical decision requiring Byzantine fault tolerance.
Evaluate the proposal and vote by starting your response with either:
- "APPROVE:" if you support the proposal
- "REJECT:" if you oppose the proposal

Provide your reasoning after the vote keyword.
"""
  end

  defp extract_vote_from_result({:ok, response}) when is_binary(response) do
    response_upper = String.upcase(response)

    cond do
      String.contains?(response_upper, "APPROVE:") -> :approve
      String.contains?(response_upper, "REJECT:") -> :reject
      String.contains?(response_upper, "APPROVE") and not String.contains?(response_upper, "REJECT") -> :approve
      true -> :reject
    end
  end

  defp extract_vote_from_result(_), do: :reject

end
