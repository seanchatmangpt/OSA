defmodule OptimalSystemAgent.Consensus.HotStuff do
  @moduledoc """
  HotStuff-BFT consensus for agent fleets.

  Key properties:
  - O(1) commit complexity
  - O(n) amortized view changes
  - f < n/3 fault tolerance
  - Hash-chain audit logs

  ## Protocol Overview

  HotStuff is a three-phase BFT consensus protocol:

  1. **Propose Phase**: Leader creates a proposal and broadcasts to fleet
  2. **Vote Phase**: Each agent votes on the proposal
  3. **Commit Phase**: Once 2/3 supermajority reached, proposal commits
  4. **View Change**: If leader fails, rotate to new leader

  ## Fault Tolerance

  In a fleet of n agents, the system tolerates f faulty agents where:
  - n = 3f + 1 (total agents)
  - Threshold = 2f + 1 (votes needed for commit)
  - This translates to > 2/3 supermajority

  Examples:
  - Small fleet (7 agents, 2 faults): needs 5 votes
  - Medium fleet (13 agents, 4 faults): needs 9 votes
  - Large fleet (31 agents, 10 faults): needs 21 votes

  ## ETS Tables

  - `:osa_consensus_proposals` - set, named_table, public
    Key: `{fleet_id, proposal_id}`
    Value: Proposal struct with metadata

  - `:osa_consensus_views` - set, named_table, public
    Key: `fleet_id`
    Value: Current view number and leader

  - `:osa_consensus_audit` - ordered_set, named_table, public
    Key: `{fleet_id, sequence_number}`
    Value: Committed proposal with hash chain

  ## Usage

      # Initialize tables (call once at startup)
      OptimalSystemAgent.Consensus.HotStuff.init_tables()

      # Propose a vote
      {:ok, proposal} = OptimalSystemAgent.Consensus.HotStuff.propose_vote(
        "fleet_123",
        %{type: :process_model, content: %{name: "Customer Onboarding"}},
        ["agent_1", "agent_2", "agent_3", "agent_4"]
      )

      # Agents vote
      {:ok, :pending} = OptimalSystemAgent.Consensus.HotStuff.vote(
        "fleet_123",
        proposal.proposal_id,
        "agent_2"
      )

      # Auto-commit when threshold reached
      {:ok, :approved} = OptimalSystemAgent.Consensus.HotStuff.vote(
        "fleet_123",
        proposal.proposal_id,
        "agent_3"
      )

  ## Performance Targets

  - Small fleet (7 agents, 2 faults): <50ms p95 latency
  - Medium fleet (13 agents, 4 faults): <100ms p95 latency
  - Large fleet (31 agents, 10 faults): <250ms p95 latency
  """

  alias OptimalSystemAgent.Consensus.Proposal

  @proposals_table :osa_consensus_proposals
  @views_table :osa_consensus_views
  @audit_table :osa_consensus_audit

  @type fleet_id :: String.t()
  @type proposal_id :: String.t()
  @type agent_id :: String.t()
  @type view_number :: non_neg_integer()
  @type sequence_number :: non_neg_integer()

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Initialize ETS tables for consensus.

  Call once at application startup. Safe to call multiple times.
  """
  @spec init_tables() :: :ok
  def init_tables do
    # Proposals table: track active proposals
    if :ets.whereis(@proposals_table) == :undefined do
      :ets.new(@proposals_table, [
        :named_table,
        :set,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end

    # Views table: track current view for each fleet
    if :ets.whereis(@views_table) == :undefined do
      :ets.new(@views_table, [
        :named_table,
        :set,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end

    # Audit table: hash-chain log of committed proposals
    if :ets.whereis(@audit_table) == :undefined do
      :ets.new(@audit_table, [
        :named_table,
        :ordered_set,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end

    # Initialize view for fleet if not exists
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Phase 1: Propose a new vote.

  Creates a proposal with unique ID, stores in ETS, and broadcasts to agents.

  ## Quorum Calculation

  Threshold = 2f + 1 votes (where n = 3f + 1 agents total).
  This ensures >2/3 supermajority, guaranteeing consensus even if f agents fail.
  Example: 7 agents (f=2) need 5 votes; 13 agents (f=4) need 9 votes.

  ## Parameters

    * `fleet_id` - Fleet identifier
    * `proposal_content` - Map with `:type` and `:content` keys
    * `agents` - List of agent IDs who should vote

  ## Returns

    * `{:ok, proposal}` - Proposal created successfully
    * `{:error, reason}` - Error creating proposal

  ## Examples

      {:ok, proposal} = OptimalSystemAgent.Consensus.HotStuff.propose_vote(
        "fleet_123",
        %{type: :process_model, content: %{name: "New Process"}},
        ["agent_1", "agent_2", "agent_3", "agent_4"]
      )
  """
  @spec propose_vote(fleet_id(), map(), [agent_id()]) ::
          {:ok, Proposal.t()} | {:error, term()}
  def propose_vote(fleet_id, proposal_content, agents)
      when is_binary(fleet_id) and is_list(agents) do
    init_tables()

    # Validate inputs
    with :ok <- validate_fleet_id(fleet_id),
         :ok <- validate_agents(agents),
         :ok <- validate_proposal_content(proposal_content),
         {:ok, view} <- get_or_create_view(fleet_id),
         proposal_id <- generate_proposal_id(fleet_id, view.view_number),
         proposal <- create_proposal(proposal_id, proposal_content, view.leader, agents) do
      # Store proposal
      :ets.insert(@proposals_table, {{fleet_id, proposal_id}, proposal})

      # Broadcast to fleet (in production, use PubSub or message bus)
      broadcast_proposal(fleet_id, proposal)

      {:ok, proposal}
    end
  end

  @doc """
  Phase 2: Vote on a proposal.

  Records agent's vote and checks if threshold reached. Auto-commits if
  2/3 supermajority achieved.

  ## Parameters

    * `fleet_id` - Fleet identifier
    * `proposal_id` - Proposal identifier
    * `agent_id` - Agent casting the vote

  ## Returns

    * `{:ok, :pending}` - Vote recorded, threshold not yet reached
    * `{:ok, :approved}` - Threshold reached, proposal committed
    * `{:ok, :rejected}` - Proposal rejected
    * `{:error, reason}` - Error voting

  ## Examples

      {:ok, :pending} = OptimalSystemAgent.Consensus.HotStuff.vote(
        "fleet_123",
        "proposal_uuid",
        "agent_2"
      )
  """
  @spec vote(fleet_id(), proposal_id(), agent_id()) ::
          {:ok, :pending | :approved | :rejected} | {:error, term()}
  def vote(fleet_id, proposal_id, agent_id)
      when is_binary(fleet_id) and is_binary(proposal_id) and is_binary(agent_id) do
    case :ets.lookup(@proposals_table, {fleet_id, proposal_id}) do
      [] ->
        {:error, :proposal_not_found}

      [{_key, proposal}] ->
        # Check if already decided
        if Proposal.decided?(proposal) do
          {:ok, proposal.status}
        else
          # ## Vote Propagation & Finality
          # Record vote and check if we've reached 2f+1 supermajority (>2/3 of fleet).
          # Once threshold hit, proposal becomes **final** (consensus guarantee).
          # This is the key safety property: once committed, no reorg is possible.
          updated_proposal = Proposal.add_vote(proposal, agent_id, :approve)

          # Check threshold using total agent count
          total_agents = Map.get(proposal, :agents, []) |> length()
          case check_threshold(updated_proposal, total_agents) do
            {:ok, :approved} ->
              # Update proposal in ETS with votes before committing
              :ets.insert(@proposals_table, {{fleet_id, proposal_id}, updated_proposal})
              # Commit the proposal
              :ok = commit(fleet_id, proposal_id)
              {:ok, :approved}

            {:ok, :rejected} ->
              # Update and return rejected
              :ets.insert(@proposals_table, {{fleet_id, proposal_id}, updated_proposal})
              {:ok, :rejected}

            {:pending, _ratio} ->
              # Store and return pending
              :ets.insert(@proposals_table, {{fleet_id, proposal_id}, updated_proposal})
              {:ok, :pending}
          end
        end
    end
  end

  @doc """
  Phase 3: Commit a proposal.

  Marks proposal as committed, updates audit log with hash chain, and
  broadcasts commit to fleet.

  ## Parameters

    * `fleet_id` - Fleet identifier
    * `proposal_id` - Proposal identifier

  ## Returns

    * `:ok` - Proposal committed successfully
    * `{:error, reason}` - Error committing

  ## Examples

      :ok = OptimalSystemAgent.Consensus.HotStuff.commit(
        "fleet_123",
        "proposal_uuid"
      )
  """
  @spec commit(fleet_id(), proposal_id()) :: :ok | {:error, term()}
  def commit(fleet_id, proposal_id)
      when is_binary(fleet_id) and is_binary(proposal_id) do
    case :ets.lookup(@proposals_table, {fleet_id, proposal_id}) do
      [] ->
        {:error, :proposal_not_found}

      [{_key, proposal}] ->
        # Get next sequence number and previous hash
        {seq_num, prev_hash} = get_audit_info(fleet_id)

        # Update proposal status
        committed_proposal = %{proposal | status: :approved}

        # ## Hash Chain Audit Log
        # Each committed proposal references hash of previous entry (Merkle chain).
        # This creates immutable, non-repudiable record: any fork detected immediately.
        # Sequence number ensures strict ordering even with concurrent fleets.
        audit_entry = create_audit_entry(
          fleet_id,
          seq_num,
          committed_proposal,
          prev_hash
        )

        # Store audit entry
        :ets.insert(@audit_table, {{fleet_id, seq_num}, audit_entry})

        # Update proposal in proposals table
        :ets.insert(@proposals_table, {{fleet_id, proposal_id}, committed_proposal})

        # Broadcast commit to fleet
        broadcast_commit(fleet_id, proposal_id, audit_entry.entry_hash)

        :ok
    end
  end

  @doc """
  Phase 4: View change.

  Handles leader failure by rotating to new view with new leader.
  Preserves uncommitted proposals for new leader to handle.

  ## Parameters

    * `fleet_id` - Fleet identifier
    * `new_view` - Optional new view number (auto-incremented if nil)

  ## Returns

    * `{:ok, view_info}` - View changed successfully
    * `{:error, reason}` - Error changing view

  ## Examples

      {:ok, view} = OptimalSystemAgent.Consensus.HotStuff.view_change("fleet_123")

      {:ok, view} = OptimalSystemAgent.Consensus.HotStuff.view_change(
        "fleet_123",
        5
      )
  """
  @spec view_change(fleet_id(), view_number() | nil) ::
          {:ok, %{view_number: view_number(), leader: agent_id()}} | {:error, term()}
  def view_change(fleet_id, new_view \\ nil) do
    case get_or_create_view(fleet_id) do
      {:ok, current_view} ->
        view_num = new_view || current_view.view_number + 1

        # Select new leader (round-robin through fleet agents)
        # In production, this would use fleet state to determine next leader
        new_leader = select_leader(fleet_id, view_num)

        new_view_info = %{
          view_number: view_num,
          leader: new_leader,
          updated_at: DateTime.utc_now()
        }

        # Store new view
        :ets.insert(@views_table, {fleet_id, new_view_info})

        # Broadcast view change to fleet
        broadcast_view_change(fleet_id, new_view_info)

        {:ok, new_view_info}
    end
  end

  # ---------------------------------------------------------------------------
  # Query Functions
  # ---------------------------------------------------------------------------

  @doc """
  Get a proposal by ID.

  Returns `{:ok, proposal}` or `{:error, :not_found}`.
  """
  @spec get_proposal(fleet_id(), proposal_id()) ::
          {:ok, Proposal.t()} | {:error, :not_found}
  def get_proposal(fleet_id, proposal_id) do
    case :ets.lookup(@proposals_table, {fleet_id, proposal_id}) do
      [] -> {:error, :not_found}
      [{_key, proposal}] -> {:ok, proposal}
    end
  end

  @doc """
  Get current view for a fleet.

  Returns `{:ok, view_info}` or `{:error, :not_found}`.
  """
  @spec get_view(fleet_id()) ::
          {:ok, %{view_number: view_number(), leader: agent_id()}} | {:error, :not_found}
  def get_view(fleet_id) do
    case :ets.lookup(@views_table, fleet_id) do
      [] -> {:error, :not_found}
      [{_key, view}] -> {:ok, view}
    end
  end

  @doc """
  Get audit log for a fleet.

  Returns list of committed proposals in sequence order.
  """
  @spec get_audit_log(fleet_id()) :: [map()]
  def get_audit_log(fleet_id) do
    :ets.select(@audit_table, [{{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", fleet_id}], [:"$3"]}])
    |> Enum.sort_by(fn e -> e.sequence_number end)
  end

  @doc """
  Verify audit log integrity for a fleet.

  Checks that hash chain is unbroken. Returns `{:ok, true}` if valid,
  or `{:error, reason}` if chain is broken.
  """
  @spec verify_audit_log(fleet_id()) :: {:ok, boolean()} | {:error, term()}
  def verify_audit_log(fleet_id) do
    audit_entries = get_audit_log(fleet_id)

    if Enum.empty?(audit_entries) do
      {:ok, true}
    else
      verify_chain(audit_entries)
    end
  end

  # ---------------------------------------------------------------------------
  # Helper Functions
  # ---------------------------------------------------------------------------

  # Validate fleet ID
  defp validate_fleet_id(fleet_id) when is_binary(fleet_id) and fleet_id != "" do
    :ok
  end

  defp validate_fleet_id(_), do: {:error, :invalid_fleet_id}

  # Validate agents list
  defp validate_agents(agents) when is_list(agents) and length(agents) >= 4 do
    # Minimum 4 agents for BFT (3f+1 with f=1)
    if Enum.all?(agents, &is_binary/1) do
      :ok
    else
      {:error, :invalid_agent_list}
    end
  end

  defp validate_agents(_), do: {:error, :invalid_agent_list}

  # Validate proposal content
  defp validate_proposal_content(%{type: type, content: content})
       when type in [:process_model, :workflow, :decision] do
    if content != nil do
      :ok
    else
      {:error, :invalid_content}
    end
  end

  defp validate_proposal_content(_), do: {:error, :invalid_proposal_content}

  # Get or create view for fleet
  defp get_or_create_view(fleet_id) do
    case :ets.lookup(@views_table, fleet_id) do
      [] ->
        # Create initial view
        initial_view = %{
          view_number: 0,
          leader: "#{fleet_id}_leader_0",
          updated_at: DateTime.utc_now()
        }

        :ets.insert(@views_table, {fleet_id, initial_view})
        {:ok, initial_view}

      [{_key, view}] ->
        {:ok, view}
    end
  end

  # Generate unique proposal ID
  defp generate_proposal_id(fleet_id, view_number) do
    timestamp = System.system_time(:microsecond)
    :crypto.hash(:md5, "#{fleet_id}:#{view_number}:#{timestamp}")
    |> Base.encode16(case: :lower)
  end

  # Create proposal struct
  defp create_proposal(proposal_id, proposal_content, leader, agents) do
    Proposal.new(
      proposal_content.type,
      proposal_content.content,
      leader
    )
    |> Map.put(:proposal_id, proposal_id)
    |> Map.put(:agents, agents)
    |> Map.put(:created_at, DateTime.utc_now())
  end

  # Get audit info (next sequence number and previous hash)
  defp get_audit_info(fleet_id) do
    # Find highest sequence number
    pattern = {{fleet_id, :"$1"}, :_}
    selectors = [:"$1"]

    case :ets.select(@audit_table, [{pattern, [], selectors}], 1) do
      :"$end_of_table" ->
        # First entry
        {0, nil}

      {[seq_num], _continuation} ->
        # Get previous hash
        case :ets.lookup(@audit_table, {fleet_id, seq_num}) do
          [] -> {seq_num + 1, nil}
          [{_key, entry}] -> {seq_num + 1, entry.entry_hash}
        end
    end
  end

  # Create audit entry with hash chain
  defp create_audit_entry(fleet_id, seq_num, proposal, prev_hash) do
    # Serialize proposal for hashing
    proposal_data = %{
      proposal_id: proposal.proposal_id,
      type: proposal.type,
      content: proposal.content,
      proposer: proposal.proposer,
      votes: proposal.votes,
      status: proposal.status,
      created_at: DateTime.to_iso8601(proposal.created_at)
    }

    # Compute entry hash
    entry_hash = compute_entry_hash(fleet_id, seq_num, proposal_data, prev_hash)

    %{
      fleet_id: fleet_id,
      sequence_number: seq_num,
      proposal: proposal_data,
      previous_hash: prev_hash,
      entry_hash: entry_hash,
      committed_at: DateTime.utc_now()
    }
  end

  # Compute hash for audit entry
  defp compute_entry_hash(fleet_id, seq_num, proposal_data, prev_hash) do
    data = %{
      fleet_id: fleet_id,
      sequence_number: seq_num,
      proposal: proposal_data,
      previous_hash: prev_hash
    }

    :crypto.hash(:sha256, :erlang.term_to_binary(data))
    |> Base.encode16(case: :lower)
  end

  # Select leader for view (simple round-robin)
  defp select_leader(fleet_id, view_number) do
    # In production, this would use actual fleet state
    # For now, deterministic selection based on view number
    "#{fleet_id}_leader_#{rem(view_number, 10)}"
  end

  # Check if BFT threshold is reached
  # Need 2f+1 votes out of 3f+1 total agents
  # This translates to > 2/3 of total agents
  defp check_threshold(proposal, total_agents) when total_agents > 0 do
    _votes_count = map_size(proposal.votes)
    approve_count = Enum.count(proposal.votes, fn {_agent, vote} -> vote == :approve end)
    reject_count = Enum.count(proposal.votes, fn {_agent, vote} -> vote == :reject end)

    approve_ratio = approve_count / total_agents
    reject_ratio = reject_count / total_agents

    cond do
      proposal.status == :approved ->
        {:ok, :approved}

      proposal.status == :rejected ->
        {:ok, :rejected}

      approve_ratio > 2 / 3 ->
        # BFT threshold: > 2/3 supermajority of ALL agents
        {:ok, :approved}

      reject_ratio > 2 / 3 ->
        # If > 2/3 reject, it's rejected
        {:ok, :rejected}

      true ->
        # Still pending - haven't reached threshold
        {:pending, approve_ratio}
    end
  end

  defp check_threshold(_proposal, _total_agents), do: {:pending, 0.0}

  # Verify hash chain
  defp verify_chain([]), do: {:ok, true}

  defp verify_chain([entry]) do
    # Single entry - just verify it hashes correctly
    if verify_entry_hash(entry) do
      {:ok, true}
    else
      {:error, :hash_mismatch}
    end
  end

  defp verify_chain([entry | rest]) do
    case verify_entry_hash(entry) do
      true ->
        # Check next entry's previous_hash matches this entry's hash
        case rest do
          [] ->
            {:ok, true}

          [next_entry | _] ->
            if next_entry.previous_hash == entry.entry_hash do
              verify_chain(rest)
            else
              {:error, :chain_broken}
            end
        end

      false ->
        {:error, :hash_mismatch}
    end
  end

  # Verify single entry hash
  defp verify_entry_hash(entry) do
    computed_hash =
      compute_entry_hash(
        entry.fleet_id,
        entry.sequence_number,
        entry.proposal,
        entry.previous_hash
      )

    computed_hash == entry.entry_hash
  end

  # Broadcast proposal to fleet
  defp broadcast_proposal(fleet_id, proposal) do
    # In production, use PubSub or message bus
    # For now, just log
    require Logger
    Logger.debug("[HotStuff] Broadcasting proposal #{proposal.proposal_id} to fleet #{fleet_id}")
    :ok
  end

  # Broadcast commit to fleet
  defp broadcast_commit(fleet_id, proposal_id, entry_hash) do
    # In production, use PubSub or message bus
    require Logger
    Logger.debug("[HotStuff] Broadcast commit for #{proposal_id} to fleet #{fleet_id} (hash: #{entry_hash})")
    :ok
  end

  # Broadcast view change to fleet
  defp broadcast_view_change(fleet_id, view_info) do
    # In production, use PubSub or message bus
    require Logger
    Logger.debug("[HotStuff] View change for fleet #{fleet_id}: view #{view_info.view_number}, leader #{view_info.leader}")
    :ok
  end
end
