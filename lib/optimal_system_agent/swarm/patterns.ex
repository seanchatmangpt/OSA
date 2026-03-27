defmodule OptimalSystemAgent.Swarm.Patterns do
  @moduledoc """
  Four swarm execution patterns + named preset loader.

  Patterns:
    :parallel    — all agents work independently, results merged
    :pipeline    — each agent's output feeds the next
    :debate      — N-1 proposers in parallel, last agent is the critic
    :review_loop — worker + reviewer iterate until APPROVED or max_iterations

  ## YAWL Topology Validation

  `parallel/3` and `pipeline/3` perform a WvdA soundness gate before spawning
  agents.  The gate builds a minimal YAWL XML spec via `SpecBuilder` and
  verifies it with `Yawl.Client.check_conformance/2`.

  Graceful degradation rules:
    - YAWL engine unreachable → log warning and proceed (never block spawning)
    - fitness == 0.0           → return `{:error, :unsound_topology}`
    - fitness > 0.0            → proceed normally
  """
  require Logger

  alias OptimalSystemAgent.Orchestrator
  alias OptimalSystemAgent.Yawl.SpecBuilder

  @presets_path "priv/swarms/patterns.json"
  @yawl_timeout_ms 5_000

  # ---------------------------------------------------------------------------
  # Parallel
  # ---------------------------------------------------------------------------

  @doc """
  All agents work simultaneously on their assigned sub-tasks.
  Returns results in the same order as configs.

  Performs a YAWL WCP-2 (AND-split) soundness check before spawning agents.
  If the YAWL engine is unreachable the gate is skipped (graceful degradation).
  If the spec is structurally unsound (fitness == 0.0) the call returns
  `{:error, :unsound_topology}` without spawning any agent.
  """
  def parallel(parent_id, configs, _opts \\ []) do
    Logger.info("[Swarm.Patterns] parallel — #{length(configs)} agents")

    agent_names = Enum.map(configs, fn c -> Map.get(c, :role, "agent") end)

    case validate_yawl_topology(:parallel, agent_names) do
      {:error, :unsound_topology} ->
        {:error, :unsound_topology}

      _ ->
        results =
          OptimalSystemAgent.TaskSupervisor
          |> Task.Supervisor.async_stream_nolink(
            configs,
            fn config ->
              Orchestrator.run_subagent(Map.put(config, :parent_session_id, parent_id))
            end,
            max_concurrency: length(configs),
            timeout: 600_000,
            on_timeout: :kill_task
          )
          |> Enum.map(fn
            {:ok, result} -> result
            {:exit, :timeout} -> {:ok, "[Agent timed out]"}
            {:exit, reason} -> {:error, inspect(reason)}
          end)

        {:ok, results}
    end
  end

  # ---------------------------------------------------------------------------
  # Pipeline
  # ---------------------------------------------------------------------------

  @doc """
  Sequential chain. Each agent receives the previous agent's output prepended
  to its task, enabling iterative refinement.

  Performs a YAWL WCP-1 (sequence) soundness check before spawning agents.
  If the YAWL engine is unreachable the gate is skipped (graceful degradation).
  If the spec is structurally unsound (fitness == 0.0) the call returns
  `{:error, :unsound_topology}` without spawning any agent.
  """
  def pipeline(parent_id, configs, _opts \\ []) do
    Logger.info("[Swarm.Patterns] pipeline — #{length(configs)} agents")

    step_names = Enum.map(configs, fn c -> Map.get(c, :role, "step") end)

    case validate_yawl_topology(:pipeline, step_names) do
      {:error, :unsound_topology} ->
        {:error, :unsound_topology}

      _ ->
        {results, _} =
          Enum.map_reduce(configs, nil, fn config, prev_output ->
            task =
              if prev_output do
                "## Previous step output\n#{prev_output}\n\n## Your task\n#{config.task}"
              else
                config.task
              end

            config = Map.put(config, :parent_session_id, parent_id) |> Map.put(:task, task)
            result = Orchestrator.run_subagent(config)

            output =
              case result do
                {:ok, text} -> text
                {:error, _} -> nil
              end

            {result, output}
          end)

        {:ok, results}
    end
  end

  # ---------------------------------------------------------------------------
  # Debate
  # ---------------------------------------------------------------------------

  @doc """
  First N-1 agents propose in parallel. Last agent is the critic/evaluator
  and receives all proposals. Falls back to parallel if fewer than 2 agents.
  """
  def debate(parent_id, configs, _opts \\ []) do
    Logger.info("[Swarm.Patterns] debate — #{length(configs)} agents")

    if length(configs) < 2 do
      Logger.warning("[Swarm.Patterns] debate requires ≥2 agents, falling back to parallel")
      parallel(parent_id, configs)
    else
      {proposers, [evaluator_config]} = Enum.split(configs, length(configs) - 1)

      # Run proposers in parallel
      proposer_results =
        OptimalSystemAgent.TaskSupervisor
        |> Task.Supervisor.async_stream_nolink(
          proposers,
          fn config -> Orchestrator.run_subagent(Map.put(config, :parent_session_id, parent_id)) end,
          max_concurrency: length(proposers),
          timeout: 600_000,
          on_timeout: :kill_task
        )
        |> Enum.map(fn
          {:ok, {:ok, text}} -> text
          {:ok, {:error, _}} -> "[Agent failed]"
          _ -> "[Agent failed]"
        end)

      # Build evaluator task with all proposals
      proposals_text =
        proposers
        |> Enum.zip(proposer_results)
        |> Enum.with_index(1)
        |> Enum.map_join("\n\n", fn {{config, text}, idx} ->
          role = Map.get(config, :role, "Agent #{idx}")
          "### Proposal #{idx} (#{role})\n#{text}"
        end)

      evaluator_task =
        "## Proposals to evaluate\n\n#{proposals_text}\n\n## Your task\n#{evaluator_config.task}"

      evaluator_config =
        evaluator_config
        |> Map.put(:parent_session_id, parent_id)
        |> Map.put(:task, evaluator_task)

      evaluator_result = Orchestrator.run_subagent(evaluator_config)

      all_results = Enum.map(proposer_results, &{:ok, &1}) ++ [evaluator_result]
      {:ok, all_results}
    end
  end

  # ---------------------------------------------------------------------------
  # Review Loop
  # ---------------------------------------------------------------------------

  @doc """
  Two-agent loop: worker produces/revises, reviewer critiques.
  Iterates until reviewer says "APPROVED" or max_iterations is reached.
  """
  def review_loop(parent_id, configs, opts \\ []) do
    max_iterations = Keyword.get(opts, :max_iterations, 3)
    Logger.info("[Swarm.Patterns] review_loop max_iterations=#{max_iterations}")

    case configs do
      [worker_config, reviewer_config | _] ->
        run_review_loop(parent_id, worker_config, reviewer_config, max_iterations)
      [single | _] ->
        Logger.warning("[Swarm.Patterns] review_loop needs ≥2 agents, running single")
        result = Orchestrator.run_subagent(Map.put(single, :parent_session_id, parent_id))
        {:ok, [result]}
      [] ->
        {:error, :no_agents}
    end
  end

  @doc """
  Four-argument variant of review_loop/3 that accepts additional options.
  Delegates to review_loop/3 with opts properly structured.
  """
  def review_loop(parent_id, worker_config, reviewer_config, opts) when is_list(opts) do
    review_loop(parent_id, [worker_config, reviewer_config], opts)
  end

  defp run_review_loop(_parent_id, _worker_cfg, _reviewer_cfg, max_iter) when max_iter < 1 do
    Logger.warning("[Swarm.Patterns] review_loop max_iterations=#{max_iter} < 1, returning empty result")
    {:ok, [{:ok, "[no iterations]"}]}
  end

  defp run_review_loop(parent_id, worker_cfg, reviewer_cfg, max_iter) do
    {final_output, _iterations, approved} =
      Enum.reduce_while(1..max_iter, {nil, 0, false}, fn iteration, {prev_output, _iter, _approved} ->
        # Worker task (with reviewer feedback if this is a revision)
        worker_task =
          if prev_output do
            "## Reviewer feedback\n#{prev_output}\n\n## Your task (revision #{iteration})\n#{worker_cfg.task}"
          else
            worker_cfg.task
          end

        worker_result =
          worker_cfg
          |> Map.put(:parent_session_id, parent_id)
          |> Map.put(:task, worker_task)
          |> Orchestrator.run_subagent()

        worker_output = case worker_result do
          {:ok, text} -> text
          {:error, reason} -> "[Worker failed: #{inspect(reason)}]"
        end

        # Reviewer evaluates worker output
        reviewer_task =
          "## Worker output (iteration #{iteration})\n#{worker_output}\n\n## Your task\n#{reviewer_cfg.task}\n\nIf approved, start your response with 'APPROVED:'. Otherwise provide specific feedback."

        reviewer_result =
          reviewer_cfg
          |> Map.put(:parent_session_id, parent_id)
          |> Map.put(:task, reviewer_task)
          |> Orchestrator.run_subagent()

        reviewer_output = case reviewer_result do
          {:ok, text} -> text
          {:error, _} -> "[Reviewer failed]"
        end

        # Require "approved:" (with colon) to avoid matching "approves"/"approval"/"approvingly"
        approved? = reviewer_output |> String.downcase() |> String.starts_with?("approved:")

        if approved? or iteration == max_iter do
          {:halt, {worker_output, iteration, approved?}}
        else
          {:cont, {reviewer_output, iteration, false}}
        end
      end)

    note =
      if approved,
        do: "",
        else: "\n\n[Note: max iterations (#{max_iter}) reached without explicit approval]"

    {:ok, [{:ok, final_output <> note}]}
  end

  # ---------------------------------------------------------------------------
  # BFT Consensus
  # ---------------------------------------------------------------------------

  @doc """
  Byzantine Fault Tolerant consensus pattern for critical decisions.

  All agents in the fleet vote on a proposal. Requires 2/3 supermajority
  for approval. Uses HotStuff-BFT protocol for fault tolerance.

  Fleet size must be at least 3 agents to achieve BFT properties.
  Fault tolerance: f < n/3 where n is fleet size.
  """
  def bft_consensus(parent_id, configs, opts \\ []) do
    Logger.info("[Swarm.Patterns] bft_consensus #{length(configs)} agents")

    fleet_size = length(configs)

    cond do
      fleet_size < 3 ->
        Logger.warning("[Swarm.Patterns] bft_consensus requires ≥3 agents, falling back to parallel")
        parallel(parent_id, configs, opts)

      true ->
        run_bft_consensus(parent_id, configs, opts)
    end
  end

  defp run_bft_consensus(parent_id, configs, opts) do
    try do
      # Ensure HotStuff-BFT module is available
      if Code.ensure_loaded?(OptimalSystemAgent.Consensus.HotStuff) do
        # Create proposal for voting
        proposal_type = Keyword.get(opts, :proposal_type, :decision)
        proposal_content = Keyword.get(opts, :proposal_content, %{})
        proposer_id = Keyword.get(opts, :proposer_id, "system")

        # Initialize proposal
        proposal = OptimalSystemAgent.Consensus.Proposal.new(
          proposal_type,
          proposal_content,
          proposer_id
        )

        Logger.info("[Swarm.Patterns] Created BFT proposal #{proposal.workflow_id}")

        # Phase 1: Propose - Broadcast proposal to all agents
        fleet_id = "fleet-#{parent_id}"

        case OptimalSystemAgent.Consensus.HotStuff.propose_vote(fleet_id, proposal, configs) do
          {:ok, _proposal} ->
            # Phase 2: Vote - Each agent votes
            vote_results =
              Enum.map(configs, fn config ->
                agent_id = Map.get(config, :role, "agent")
                task_with_proposal = """
## Proposal for BFT Consensus

You are voting on the following proposal:

**Type:** #{proposal_type}
**Content:** #{inspect(proposal_content)}
**Proposal ID:** #{proposal.workflow_id}

Instructions:
1. Evaluate the proposal on its merits
2. Cast your vote: respond with either "APPROVE:" or "REJECT:"
3. Provide brief reasoning for your vote

Your task: Evaluate and vote on this proposal.
"""

                result = config
                         |> Map.put(:parent_session_id, parent_id)
                         |> Map.put(:task, task_with_proposal)
                         |> Orchestrator.run_subagent()

                {agent_id, result}
              end)

            # Tally votes
            votes = Enum.reduce(vote_results, %{}, fn {agent_id, result}, acc ->
              vote = case result do
                {:ok, response} when is_binary(response) ->
                  cond do
                    String.contains?(String.upcase(response), "APPROVE") -> :approve
                    String.contains?(String.upcase(response), "REJECT") -> :reject
                    true -> :reject  # Default to reject on unclear response
                  end

                _ -> :reject  # Failed agents vote reject
              end

              Map.put(acc, agent_id, vote)
            end)

            Logger.info("[Swarm.Patterns] BFT votes collected: #{inspect(votes)}")

            # Add votes to proposal
            proposal_with_votes = Enum.reduce(votes, proposal, fn {agent_id, vote}, prop ->
              OptimalSystemAgent.Consensus.Proposal.add_vote(prop, agent_id, vote)
            end)

            # Phase 3: Check if consensus reached
            case OptimalSystemAgent.Consensus.Proposal.calculate_result(proposal_with_votes) do
              {:ok, :approved} ->
                # Phase 4: Commit the proposal
                _commit_result = OptimalSystemAgent.Consensus.HotStuff.commit(fleet_id, proposal_with_votes)

                Logger.info("[Swarm.Patterns] BFT consensus reached: APPROVED")

                # Collect all agent results with approval notice
                results_with_notice = Enum.map(vote_results, fn {_agent_id, {:ok, response}} ->
                  response_with_notice = response <> "\n\n[BFT CONSENSUS: APPROVED - 2/3 supermajority reached]"
                  {:ok, response_with_notice}
                end)

                {:ok, results_with_notice}

              {:ok, :rejected} ->
                Logger.info("[Swarm.Patterns] BFT consensus: REJECTED")

                results_with_notice = Enum.map(vote_results, fn {_agent_id, {:ok, response}} ->
                  response_with_notice = response <> "\n\n[BFT CONSENSUS: REJECTED - supermajority not reached]"
                  {:ok, response_with_notice}
                end)

                {:ok, results_with_notice}

              {:pending, ratio} ->
                Logger.warning("[Swarm.Patterns] BFT consensus pending: #{Float.round(ratio * 100, 1)}% approval")

                # Return results with pending notice
                results_with_notice = Enum.map(vote_results, fn {_agent_id, {:ok, response}} ->
                  response_with_notice = response <> "\n\n[BFT CONSENSUS: PENDING - #{Float.round(ratio * 100, 1)}% approval, need 66.7%]"
                  {:ok, response_with_notice}
                end)

                {:ok, results_with_notice}
            end

          {:error, reason} ->
            Logger.error("[Swarm.Patterns] BFT propose failed: #{inspect(reason)}")
            {:error, reason}
        end

      else
        Logger.warning("[Swarm.Patterns] HotStuff-BFT not available, falling back to parallel")
        parallel(parent_id, configs, opts)
      end

    rescue
      e ->
        Logger.error("[Swarm.Patterns] BFT consensus error: #{Exception.message(e)}")
        {:error, Exception.message(e)}
    end
  end

  # ---------------------------------------------------------------------------
  # Named Presets
  # ---------------------------------------------------------------------------

  @doc "Load a named preset config from priv/swarms/patterns.json."
  def get_pattern(name) when is_binary(name) do
    case load_presets() do
      {:ok, presets} ->
        case Map.get(presets, name) do
          nil -> {:error, :not_found}
          config -> {:ok, config}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "List all available named patterns."
  def list_patterns do
    case load_presets() do
      {:ok, presets} -> {:ok, Map.keys(presets)}
      err -> err
    end
  end

  defp load_presets do
    path = Application.app_dir(:optimal_system_agent, @presets_path)

    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      {:ok, data}
    else
      _ ->
        # Try relative path (dev mode)
        case File.read(@presets_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, data} -> {:ok, data}
              _ -> {:error, :invalid_json}
            end
          _ -> {:error, :not_found}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # YAWL Topology Validation (private)
  # ---------------------------------------------------------------------------

  # Validate a swarm topology against the YAWL engine before spawning agents.
  #
  # Returns:
  #   :ok                        — spec is sound (fitness > 0.0)
  #   {:error, :yawl_unavailable} — engine not running; caller should proceed
  #   {:error, :unsound_topology} — fitness == 0.0; caller should abort
  #
  # All GenServer calls are wrapped in try/catch to handle the case where
  # YawlClient process is not running (WvdA deadlock-freedom requirement).
  defp validate_yawl_topology(pattern, names) do
    spec =
      case pattern do
        :parallel -> SpecBuilder.parallel_split("dispatch", names)
        :pipeline -> SpecBuilder.sequence(names)
      end

    result =
      try do
        GenServer.call(
          OptimalSystemAgent.Yawl.Client,
          {:check_conformance, spec, "[]"},
          @yawl_timeout_ms
        )
      catch
        :exit, _ -> {:error, :yawl_unavailable}
      end

    case result do
      {:error, :yawl_unavailable} ->
        Logger.warning(
          "[Swarm.Patterns] YAWL engine unreachable — skipping #{pattern} topology check"
        )

        {:error, :yawl_unavailable}

      {:error, reason} ->
        Logger.warning(
          "[Swarm.Patterns] YAWL check failed (#{inspect(reason)}) — proceeding with #{pattern}"
        )

        {:error, :yawl_unavailable}

      {:ok, %{fitness: fitness}} when fitness == 0.0 ->
        Logger.error(
          "[Swarm.Patterns] YAWL soundness gate rejected #{pattern} topology (fitness=0.0)"
        )

        {:error, :unsound_topology}

      {:ok, %{fitness: fitness}} ->
        Logger.debug(
          "[Swarm.Patterns] YAWL #{pattern} topology sound (fitness=#{fitness})"
        )

        :ok
    end
  end
end
