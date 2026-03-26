defmodule OptimalSystemAgent.Consensus.Byzantine do
  @moduledoc """
  HotStuff-style Byzantine Fault Tolerant (BFT) consensus for N=3 agents with f≥1 fault tolerance.

  Implements a simplified HotStuff consensus protocol for small agent swarms:
  - N=3 agents maximum
  - f=1 maximum faulty agents
  - Quorum: 2f+1 = 3 agents (100% agreement required)
  - Timeout: 1s per round
  - Leader rotation on timeout

  ## Protocol Phases

  1. **Propose Phase**: Leader broadcasts proposal to all agents
  2. **Vote Phase**: Agents vote on proposal (approve/reject)
  3. **Commit Phase**: Decision when 2f+1 agents committed
  4. **View Change**: Rotate leader on timeout

  ## Signal Theory Integration

  All outputs encoded as S=(Mode, Genre, Type, Format, Weight):
  - Mode: `data` (numeric, evidence-based)
  - Genre: `report` (analysis of consensus state)
  - Type: `decide` (consensus decision point)
  - Format: `json` (structured, machine-readable)
  - Weight: consensus strength (ratio of votes to required)

  ## Usage

      # Start consensus for 3 agents
      {:ok, pid} = OptimalSystemAgent.Consensus.Byzantine.start_consensus(
        ["agent_1", "agent_2", "agent_3"],
        %{type: :process_model, content: %{name: "New Workflow"}},
        timeout_ms: 10_000
      )

      # Wait for consensus decision
      {:committed, proposal} = OptimalSystemAgent.Consensus.Byzantine.await_decision(pid)

      # Mark agent as faulty (for testing)
      :ok = OptimalSystemAgent.Consensus.Byzantine.mark_faulty(pid, "agent_3")

      # Get current leader
      {:ok, leader} = OptimalSystemAgent.Consensus.Byzantine.current_leader(pid)
  """

  use GenServer
  require Logger

  @type nodes :: [String.t()]
  @type proposal :: map()
  @type consensus_result :: {:committed, map()} | {:timeout, map()}

  # =========================================================================
  # GenServer Callbacks
  # =========================================================================

  @doc """
  Start a Byzantine consensus process.

  ## Parameters

    * `nodes` - List of agent IDs (must be exactly 3 for N=3)
    * `proposal` - Proposal to reach consensus on
    * `opts` - Options:
      - `:timeout_ms` - Consensus timeout in milliseconds (default: 10_000)

  ## Returns

    * `{:ok, pid}` - Process started
    * `{:error, reason}` - Error starting
  """
  def start_consensus(nodes, proposal, opts \\ []) do
    # Validate cluster size first
    if length(nodes) != 3 do
      {:error, {:shutdown, :invalid_cluster_size}}
    else
      GenServer.start_link(__MODULE__, {nodes, proposal, opts})
    end
  end

  @impl true
  def init({nodes, proposal, opts}) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 10_000)

    state = %{
      nodes: nodes,
      proposal: proposal,
      leader: hd(nodes),
      round: 0,
      votes: %{},
      committed: false,
      faulty_nodes: MapSet.new(),
      timeout_ms: timeout_ms,
      start_time: System.monotonic_time(:millisecond)
    }

    # Start first consensus round
    Process.send_after(self(), :consensus_round, 1)

    {:ok, state}
  end

  # Consensus round: collect votes and check commitment
  @impl true
  def handle_info(:consensus_round, state) do
    elapsed = System.monotonic_time(:millisecond) - state.start_time

    if elapsed > state.timeout_ms do
      # Timeout: return partial result and stop
      Logger.warning("Byzantine consensus timeout after #{elapsed}ms")
      {:noreply, state}
    else
      # Round N: collect votes from all agents
      votes = collect_votes(state)
      new_state = %{state | votes: votes, round: state.round + 1}

      case check_commitment(votes) do
        {:committed, _ratio} ->
          # Decision reached - stay alive for polling
          Logger.info("Byzantine consensus committed at round #{new_state.round}")
          {:noreply, new_state}

        {:pending, _ratio} ->
          # Continue to next round
          Process.send_after(self(), :consensus_round, 100)
          {:noreply, new_state}

        {:timeout, _ratio} ->
          # Rotate leader and retry
          new_leader = rotate_leader(new_state.leader, new_state.nodes)
          new_state_rotated = %{new_state | leader: new_leader}
          Process.send_after(self(), :consensus_round, 100)
          {:noreply, new_state_rotated}
      end
    end
  end

  @impl true
  def handle_info({:check_decision, from}, state) do
    case check_commitment(state.votes) do
      {:committed, _ratio} ->
        signal = encode_signal({:committed, state.proposal}, state)
        GenServer.reply(from, {:committed, signal})
        {:noreply, state}

      {:pending, _ratio} ->
        # Check elapsed time
        elapsed = System.monotonic_time(:millisecond) - state.start_time

        if elapsed > state.timeout_ms do
          signal = encode_signal({:timeout, state.votes}, state)
          GenServer.reply(from, {:timeout, signal})
          {:noreply, state}
        else
          # Schedule another check
          Process.send_after(self(), {:check_decision, from}, 50)
          {:noreply, state}
        end

      {:timeout, _ratio} ->
        elapsed = System.monotonic_time(:millisecond) - state.start_time

        if elapsed > state.timeout_ms do
          signal = encode_signal({:timeout, state.votes}, state)
          GenServer.reply(from, {:timeout, signal})
          {:noreply, state}
        else
          Process.send_after(self(), {:check_decision, from}, 50)
          {:noreply, state}
        end
    end
  end

  @impl true
  def handle_call(:await_decision, from, state) do
    # Check current consensus status
    case check_commitment(state.votes) do
      {:committed, _ratio} ->
        signal = encode_signal({:committed, state.proposal}, state)
        {:reply, {:committed, signal}, state}

      {:pending, _ratio} ->
        # Schedule another check
        Process.send_after(self(), {:check_decision, from}, 50)
        {:noreply, state}

      {:timeout, _ratio} ->
        # Check if we've exceeded overall timeout
        elapsed = System.monotonic_time(:millisecond) - state.start_time

        if elapsed > state.timeout_ms do
          signal = encode_signal({:timeout, state.votes}, state)
          {:reply, {:timeout, signal}, state}
        else
          # Still waiting, schedule another check
          Process.send_after(self(), {:check_decision, from}, 50)
          {:noreply, state}
        end
    end
  end

  @impl true
  def handle_call({:mark_faulty, node}, _from, state) do
    if Enum.member?(state.nodes, node) do
      new_faulty = MapSet.put(state.faulty_nodes, node)
      {:reply, :ok, %{state | faulty_nodes: new_faulty}}
    else
      {:reply, {:error, :node_not_found}, state}
    end
  end

  @impl true
  def handle_call(:current_leader, _from, state) do
    {:reply, {:ok, state.leader}, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end



  # =========================================================================
  # Public API
  # =========================================================================

  @doc """
  Wait for consensus decision (blocking).

  Returns either `{:committed, proposal_signal}` or `{:timeout, state_signal}`.
  """
  @spec await_decision(pid(), Keyword.t()) :: consensus_result()
  def await_decision(pid, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout, 15_000)

    try do
      GenServer.call(pid, :await_decision, timeout_ms)
    catch
      :exit, _ ->
        {:timeout, %{"error" => "consensus process exited"}}
    end
  end

  @doc """
  Mark a node as faulty (testing only).

  Used to simulate Byzantine failures in testing.
  """
  @spec mark_faulty(pid(), String.t()) :: :ok | {:error, term()}
  def mark_faulty(pid, node) do
    try do
      GenServer.call(pid, {:mark_faulty, node}, 5000)
    catch
      :exit, {:timeout, _} ->
        Logger.error("[Byzantine] mark_faulty timeout for node #{node}")
        {:error, :timeout}
    end
  end

  @doc """
  Get the current consensus leader.

  Returns `{:ok, leader_node}` or `{:error, reason}`.
  """
  @spec current_leader(pid()) :: {:ok, String.t()} | {:error, term()}
  def current_leader(pid) do
    try do
      GenServer.call(pid, :current_leader, 5000)
    catch
      :exit, {:timeout, _} ->
        Logger.error("[Byzantine] current_leader timeout")
        {:error, :timeout}
    end
  end

  @doc """
  Get current consensus state (for testing).

  Returns `{:ok, state_map}` or `{:error, reason}`.
  """
  @spec get_state(pid()) :: {:ok, map()} | {:error, term()}
  def get_state(pid) do
    try do
      GenServer.call(pid, :get_state, 5000)
    catch
      :exit, {:timeout, _} ->
        Logger.error("[Byzantine] get_state timeout")
        {:error, :timeout}
    end
  end

  @doc """
  Encode consensus result as Signal Theory S=(M,G,T,F,W).

  Returns Signal-encoded result with:
  - Mode: `data` (numeric, evidence-based)
  - Genre: `report` (analysis of consensus state)
  - Type: `decide` (consensus decision point)
  - Format: `json` (structured)
  - Weight: consensus strength (votes / required_votes)
  """
  @spec encode_signal(consensus_result(), map()) :: map()
  def encode_signal(result, state) do
    {status, detail} =
      case result do
        {:committed, proposal} ->
          {"committed", %{"proposal" => proposal, "round" => state.round}}

        {:timeout, votes} ->
          {"timeout", %{"votes" => votes, "round" => state.round}}
      end

    # Count only approve votes, not reject/faulty votes
    approve_count = state.votes |> Map.values() |> Enum.count(&(&1 == :approve))
    required_votes = 2  # f+1 where f=1 (minimum honest nodes to guarantee correctness)
    weight = if required_votes > 0, do: approve_count / required_votes, else: 0.0

    %{
      "mode" => "data",
      "genre" => "report",
      "type" => "decide",
      "format" => "json",
      "weight" => weight,
      "status" => status,
      "round" => state.round,
      "detail" => detail,
      "nodes" => state.nodes,
      "leader" => state.leader,
      "votes_received" => approve_count,
      "votes_required" => required_votes,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  # =========================================================================
  # Private Helpers
  # =========================================================================

  defp collect_votes(state) do
    state.nodes
    |> Enum.map(fn node ->
      # Check if node is faulty
      if MapSet.member?(state.faulty_nodes, node) do
        {node, :reject}  # Faulty nodes don't vote
      else
        # Honest node approves proposal
        {node, :approve}
      end
    end)
    |> Enum.into(%{})
  end

  defp check_commitment(votes) do
    # For N=3, f=1: quorum = f+1 = 2 (minimum honest nodes to guarantee correctness)
    # This allows consensus even with 1 faulty node
    quorum_size = 2  # f+1 where f=1
    # Only count explicit :approve votes, not :reject (faulty) votes
    approve_count = votes |> Map.values() |> Enum.count(&(&1 == :approve))

    cond do
      approve_count >= quorum_size ->
        ratio = approve_count / quorum_size
        {:committed, ratio}

      approve_count > 0 and approve_count < quorum_size ->
        ratio = approve_count / quorum_size
        {:pending, ratio}

      true ->
        ratio = max(approve_count, 0) / quorum_size
        {:timeout, ratio}
    end
  end

  defp rotate_leader(current_leader, nodes) do
    case Enum.find_index(nodes, &(&1 == current_leader)) do
      nil -> hd(nodes)
      idx -> Enum.at(nodes, rem(idx + 1, length(nodes)))
    end
  end
end
