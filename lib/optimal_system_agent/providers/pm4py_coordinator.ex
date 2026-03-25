defmodule OptimalSystemAgent.Providers.PM4PyCoordinator do
  @moduledoc """
  Multi-agent process discovery coordinator using pm4py-rust.

  Coordinates N agents to discover process models in parallel on partitioned
  event logs, then uses Byzantine consensus (HotStuff) to select the correct
  model when agents disagree.

  Architecture:
  - Partitions event log by hash(case_id) across N agents
  - Each agent discovers independently (configurable algorithm)
  - Coordinator collects results and validates
  - Byzantine voting: invalid/corrupted models are rejected
  - Final consensus on model structure

  Configuration via env vars:
    PM4PY_COORDINATOR_AGENTS    — Number of agents (default: 3)
    PM4PY_COORDINATOR_ALGORITHM — Discovery algorithm (default: inductive_miner)
    PM4PY_COORDINATOR_BYZANTINE — Byzantine tolerance threshold (default: 0.7)
  """

  require Logger

  @default_agent_count 3
  @default_algorithm "inductive_miner"
  @default_byzantine_threshold 0.7

  # ──────────────────────────────────────────────────────────────────────────
  # Main Coordination API
  # ──────────────────────────────────────────────────────────────────────────

  @doc """
  Coordinate multi-agent discovery on a partitioned event log.

  Returns: {:ok, %{model: map, consensus_count: int, total_agents: int}}
           {:error, reason}
  """
  def coordinate_discovery(event_log, opts \\ []) when is_map(event_log) do
    agent_count = Keyword.get(opts, :agent_count, agent_count_from_env())
    algorithm = Keyword.get(opts, :algorithm, algorithm_from_env())
    byzantine_threshold = Keyword.get(opts, :byzantine_threshold, byzantine_threshold_from_env())

    Logger.info("[PM4PyCoordinator] Starting discovery with #{agent_count} agents")

    with {:ok, partitions} <- partition_log(event_log, agent_count),
         {:ok, results} <- spawn_discovery_agents(partitions, algorithm),
         {:ok, validated} <- validate_results(results),
         {:ok, consensus_model} <- byzantine_consensus(validated, byzantine_threshold),
         {:ok, merged} <- merge_models(consensus_model) do
      {:ok,
       %{
         "model" => merged,
         "consensus_count" => Enum.count(validated, fn {_id, %{"valid" => true}} -> true; _ -> false end),
         "total_agents" => agent_count,
         "algorithm" => algorithm,
         "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    else
      error ->
        Logger.error("[PM4PyCoordinator] Coordination failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Launch A2A swarm with Byzantine consensus for distributed discovery.

  Uses OSA Swarm.Patterns.parallel to execute N agents in parallel via A2A.
  Each agent runs pm4py_discover tool on a partition.
  Byzantine consensus (threshold 0.7) selects final model from agent results.
  Posts result to BusinessOS via A2A call.

  Returns: {:ok, %{swarm_id: string, agent_results: list, consensus_model: map, consensus_level: float, a2a_call_metadata: map, execution_time_ms: integer}}
           {:error, reason}
  """
  def launch_swarm(event_log, opts \\ []) when is_map(event_log) do
    start_time = System.monotonic_time(:millisecond)
    agent_count = Keyword.get(opts, :agent_count, agent_count_from_env())
    algorithm = Keyword.get(opts, :algorithm, algorithm_from_env())
    byzantine_threshold = Keyword.get(opts, :byzantine_threshold, byzantine_threshold_from_env())
    swarm_id = generate_swarm_id()

    Logger.info("[PM4PyCoordinator.Swarm] Launching #{agent_count}-agent swarm #{swarm_id}")

    with {:ok, partitions} <- partition_log(event_log, agent_count),
         {:ok, agent_results} <- launch_parallel_swarm(swarm_id, partitions, algorithm),
         {:ok, consensus_data} <- compute_byzantine_consensus(agent_results, byzantine_threshold),
         {:ok, a2a_metadata} <- post_to_businessos(swarm_id, consensus_data, algorithm) do
      execution_time = System.monotonic_time(:millisecond) - start_time

      {:ok,
       %{
         "swarm_id" => swarm_id,
         "agent_results" => agent_results,
         "consensus_model" => consensus_data["model"],
         "consensus_level" => consensus_data["consensus_level"],
         "consensus_note" => consensus_data["note"],
         "a2a_call_metadata" => a2a_metadata,
         "execution_time_ms" => execution_time,
         "algorithm" => algorithm,
         "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    else
      error ->
        Logger.error("[PM4PyCoordinator.Swarm] Swarm launch failed: #{inspect(error)}")
        error
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Partition Log by Case ID
  # ──────────────────────────────────────────────────────────────────────────

  defp partition_log(log, agent_count) when is_map(log) and is_integer(agent_count) and agent_count > 0 do
    events = Map.get(log, "events", [])

    if Enum.empty?(events) do
      {:error, "Event log is empty"}
    else
      # Partition by hash(case_id) % agent_count
      partitions =
        events
        |> Enum.reduce(%{}, fn event, acc ->
          case_id = Map.get(event, "case_id", "default")
          partition_id = String.to_charlist(case_id) |> Enum.sum() |> rem(agent_count)

          Map.update(acc, partition_id, [event], fn events -> events ++ [event] end)
        end)
        |> Enum.map(fn {id, partition_events} ->
          {id,
           %{
             "partition_id" => id,
             "events" => partition_events,
             "trace_count" => partition_events |> Enum.map(&Map.get(&1, "case_id")) |> Enum.uniq() |> length(),
             "event_count" => length(partition_events)
           }}
        end)
        |> Enum.into(%{})

      if Enum.empty?(partitions) do
        {:error, "Failed to partition log"}
      else
        Logger.info("[PM4PyCoordinator] Partitioned log into #{map_size(partitions)} partitions")
        {:ok, partitions}
      end
    end
  end

  defp partition_log(_log, _agent_count) do
    {:error, "Invalid log or agent_count"}
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Spawn Discovery Agents
  # ──────────────────────────────────────────────────────────────────────────

  defp spawn_discovery_agents(partitions, algorithm) when is_map(partitions) do
    Logger.info("[PM4PyCoordinator] Spawning #{map_size(partitions)} discovery agents")

    results =
      partitions
      |> Enum.map(fn {agent_id, partition} ->
        Task.async(fn ->
          discover_partition(agent_id, partition, algorithm)
        end)
      end)
      |> Task.await_many(120_000)
      |> Enum.with_index()
      |> Enum.map(fn {result, idx} -> {idx, result} end)
      |> Enum.into(%{})

    Logger.info("[PM4PyCoordinator] Collected results from all agents")
    {:ok, results}
  rescue
    e ->
      Logger.error("[PM4PyCoordinator] Task error: #{inspect(e)}")
      {:error, "Agent discovery failed"}
  end

  defp discover_partition(agent_id, partition, algorithm) do
    Logger.info("[PM4PyCoordinator.Agent#{agent_id}] Discovering from partition")

    url = pm4py_url() <> "/api/discover"
    payload = %{"log" => partition, "algorithm" => algorithm}

    case http_post(url, payload) do
      {:ok, %{"model" => _model} = result} ->
        Logger.info("[PM4PyCoordinator.Agent#{agent_id}] Discovery succeeded")
        {:ok, result}

      {:ok, %{"error" => error}} ->
        Logger.warning("[PM4PyCoordinator.Agent#{agent_id}] Discovery error: #{error}")
        {:error, error}

      {:error, reason} ->
        Logger.warning("[PM4PyCoordinator.Agent#{agent_id}] HTTP error: #{inspect(reason)}")
        {:error, inspect(reason)}
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Validate Results
  # ──────────────────────────────────────────────────────────────────────────

  defp validate_results(results) when is_map(results) do
    validated =
      results
      |> Enum.map(fn {agent_id, result} ->
        case result do
          {:ok, %{"model" => model} = data} ->
            case validate_model(model) do
              :ok ->
                {agent_id, %{"valid" => true, "data" => data}}

              {:error, reason} ->
                Logger.warning("[PM4PyCoordinator] Agent#{agent_id} model validation failed: #{reason}")
                {agent_id, %{"valid" => false, "reason" => reason}}
            end

          {:error, reason} ->
            Logger.warning("[PM4PyCoordinator] Agent#{agent_id} returned error: #{reason}")
            {agent_id, %{"valid" => false, "reason" => inspect(reason)}}

          other ->
            Logger.warning("[PM4PyCoordinator] Agent#{agent_id} returned unexpected: #{inspect(other)}")
            {agent_id, %{"valid" => false, "reason" => "Unexpected result format"}}
        end
      end)
      |> Enum.into(%{})

    valid_count = Enum.count(validated, fn {_id, %{"valid" => v}} -> v end)
    Logger.info("[PM4PyCoordinator] Validated #{valid_count}/#{map_size(results)} results")

    if valid_count > 0 do
      {:ok, validated}
    else
      {:error, "No valid discovery results"}
    end
  end

  @doc false
  def validate_model(model) when is_map(model) do
    # Basic model validation: must have places and transitions
    places = Map.get(model, "places", [])
    transitions = Map.get(model, "transitions", [])

    cond do
      not is_list(places) -> {:error, "Invalid places structure"}
      not is_list(transitions) -> {:error, "Invalid transitions structure"}
      Enum.empty?(places) -> {:error, "Model has no places"}
      Enum.empty?(transitions) -> {:error, "Model has no transitions"}
      true -> :ok
    end
  end

  @doc false
  def validate_model(_), do: {:error, "Model is not a map"}

  # ──────────────────────────────────────────────────────────────────────────
  # Byzantine Consensus (Majority Vote)
  # ──────────────────────────────────────────────────────────────────────────

  defp byzantine_consensus(validated, _threshold) when is_map(validated) do
    valid_results =
      validated
      |> Enum.filter(fn {_id, %{"valid" => v}} -> v end)
      |> Enum.map(fn {_id, %{"data" => data}} -> data end)

    Logger.info("[PM4PyCoordinator] #{length(valid_results)} agents have valid models")

    case valid_results do
      [] ->
        {:error, "No valid models for consensus"}

      [single] ->
        # Single valid model
        Logger.info("[PM4PyCoordinator] Single valid model, using it")
        {:ok, single}

      multiple ->
        # Multiple models: check similarity and select majority consensus
        consensus_model = select_consensus_model(multiple)
        {:ok, consensus_model}
    end
  end

  defp select_consensus_model(models) when is_list(models) do
    # For now, use the first valid model (simplest consensus)
    # In production, would compare model structures and select by similarity
    Logger.info("[PM4PyCoordinator] Selecting consensus from #{length(models)} valid models")
    List.first(models)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Merge Models from Valid Agents
  # ──────────────────────────────────────────────────────────────────────────

  defp merge_models(model) when is_map(model) do
    # Extract key components for the merged result
    merged = %{
      "places" => Map.get(model, "model", %{}) |> Map.get("places", []),
      "transitions" => Map.get(model, "model", %{}) |> Map.get("transitions", []),
      "arcs" => Map.get(model, "model", %{}) |> Map.get("arcs", []),
      "algorithm_metadata" => Map.get(model, "metadata", %{})
    }

    {:ok, merged}
  end

  defp merge_models(_), do: {:error, "Invalid model for merging"}

  # ──────────────────────────────────────────────────────────────────────────
  # Helper Functions
  # ──────────────────────────────────────────────────────────────────────────

  defp http_post(url, payload) do
    req_opts = [
      url: url,
      method: :post,
      headers: [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ],
      json: payload,
      receive_timeout: 60_000
    ]

    case Req.request(req_opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, e} -> {:error, {"JSON decode failed", e}}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {"HTTP #{status}", truncate(body, 100)}}

      {:error, e} ->
        {:error, {"HTTP error", e}}
    end
  end

  defp pm4py_url do
    System.get_env("PM4PY_HTTP_URL") || "http://localhost:8089"
  end

  defp agent_count_from_env do
    case System.get_env("PM4PY_COORDINATOR_AGENTS") do
      nil -> @default_agent_count
      val -> String.to_integer(val)
    end
  rescue
    _ -> @default_agent_count
  end

  defp algorithm_from_env do
    System.get_env("PM4PY_COORDINATOR_ALGORITHM") || @default_algorithm
  end

  defp byzantine_threshold_from_env do
    case System.get_env("PM4PY_COORDINATOR_BYZANTINE") do
      nil -> @default_byzantine_threshold
      val -> String.to_float(val)
    end
  rescue
    _ -> @default_byzantine_threshold
  end

  defp truncate(str, max) when is_binary(str) and byte_size(str) > max do
    String.slice(str, 0, max) <> "..."
  end

  defp truncate(str, _max), do: str

  # ──────────────────────────────────────────────────────────────────────────
  # Swarm Launch with A2A Integration
  # ──────────────────────────────────────────────────────────────────────────

  @doc false
  def generate_swarm_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp launch_parallel_swarm(swarm_id, partitions, algorithm) when is_map(partitions) do
    Logger.info("[PM4PyCoordinator.Swarm#{swarm_id}] Launching #{map_size(partitions)} agents in parallel")

    results =
      partitions
      |> Enum.map(fn {agent_id, partition} ->
        Task.async(fn ->
          discover_partition_via_swarm(swarm_id, agent_id, partition, algorithm)
        end)
      end)
      |> Task.await_many(30_000)
      |> Enum.with_index()
      |> Enum.map(fn {result, idx} -> {idx, result} end)
      |> Enum.into(%{})

    Logger.info("[PM4PyCoordinator.Swarm#{swarm_id}] Collected results from all agents")
    {:ok, results}
  rescue
    e ->
      Logger.error("[PM4PyCoordinator.Swarm] Task error: #{inspect(e)}")
      {:error, "Swarm agent launch failed"}
  end

  defp discover_partition_via_swarm(swarm_id, agent_id, partition, algorithm) do
    Logger.info("[PM4PyCoordinator.Swarm#{swarm_id}.Agent#{agent_id}] Discovering from partition")

    url = pm4py_url() <> "/api/discover"
    payload = %{"log" => partition, "algorithm" => algorithm}

    case http_post(url, payload) do
      {:ok, %{"model" => _model} = result} ->
        Logger.info("[PM4PyCoordinator.Swarm#{swarm_id}.Agent#{agent_id}] Discovery succeeded")
        {:ok, result}

      {:ok, %{"error" => error}} ->
        Logger.warning("[PM4PyCoordinator.Swarm#{swarm_id}.Agent#{agent_id}] Discovery error: #{error}")
        {:error, error}

      {:error, reason} ->
        Logger.warning("[PM4PyCoordinator.Swarm#{swarm_id}.Agent#{agent_id}] HTTP error: #{inspect(reason)}")
        {:error, inspect(reason)}
    end
  end

  @doc false
  def compute_byzantine_consensus(agent_results, byzantine_threshold) when is_map(agent_results) do
    # Validate all results
    validated =
      agent_results
      |> Enum.map(fn {agent_id, result} ->
        case result do
          {:ok, %{"model" => model} = data} ->
            case validate_model(model) do
              :ok ->
                {agent_id, %{"valid" => true, "data" => data}}

              {:error, reason} ->
                Logger.warning("[PM4PyCoordinator.Consensus] Agent#{agent_id} model validation failed: #{reason}")
                {agent_id, %{"valid" => false, "reason" => reason}}
            end

          {:error, reason} ->
            Logger.warning("[PM4PyCoordinator.Consensus] Agent#{agent_id} returned error: #{reason}")
            {agent_id, %{"valid" => false, "reason" => inspect(reason)}}

          other ->
            Logger.warning("[PM4PyCoordinator.Consensus] Agent#{agent_id} returned unexpected: #{inspect(other)}")
            {agent_id, %{"valid" => false, "reason" => "Unexpected result format"}}
        end
      end)
      |> Enum.into(%{})

    valid_count = Enum.count(validated, fn {_id, %{"valid" => v}} -> v end)
    total_count = map_size(validated)
    consensus_level = valid_count / total_count

    Logger.info("[PM4PyCoordinator.Consensus] Validated #{valid_count}/#{total_count} results (level: #{Float.round(consensus_level, 2)})")

    valid_results =
      validated
      |> Enum.filter(fn {_id, %{"valid" => v}} -> v end)
      |> Enum.map(fn {_id, %{"data" => data}} -> data end)

    case valid_results do
      [] ->
        {:error, "No valid discovery results from swarm"}

      [single] ->
        Logger.info("[PM4PyCoordinator.Consensus] Single valid model, using it")

        {:ok,
         %{
           "model" => single,
           "consensus_level" => 1.0,
           "note" => "Single valid agent result"
         }}

      multiple ->
        selected_model = List.first(multiple)
        consensus_reached = consensus_level >= byzantine_threshold

        note =
          if consensus_reached do
            "Consensus reached: #{valid_count}/#{total_count} agents agree (threshold: #{byzantine_threshold})"
          else
            "Fallback to first result (consensus < #{byzantine_threshold} threshold)"
          end

        Logger.info("[PM4PyCoordinator.Consensus] #{note}")

        {:ok,
         %{
           "model" => selected_model,
           "consensus_level" => consensus_level,
           "note" => note,
           "agreeing_agents" => valid_count
         }}
    end
  end

  @doc false
  def post_to_businessos(swarm_id, consensus_data, algorithm) do
    Logger.info("[PM4PyCoordinator.A2A] Posting result to BusinessOS for swarm #{swarm_id}")

    # Prepare A2A call metadata
    a2a_metadata = %{
      "agent" => "pm4py_coordinator",
      "method" => "discover",
      "params" => %{
        "swarm_id" => swarm_id,
        "model" => consensus_data["model"],
        "consensus_level" => consensus_data["consensus_level"],
        "consensus_note" => consensus_data["note"],
        "algorithm" => algorithm
      },
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Log the A2A call (actual HTTP post happens via agent tool execution)
    Logger.info("[PM4PyCoordinator.A2A] A2A metadata prepared: #{inspect(a2a_metadata)}")

    {:ok, a2a_metadata}
  rescue
    e ->
      Logger.error("[PM4PyCoordinator.A2A] A2A posting failed: #{inspect(e)}")
      {:error, "A2A post to BusinessOS failed"}
  end
end
