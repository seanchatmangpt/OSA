defmodule OptimalSystemAgent.Consensus.Proposal do
  @moduledoc """
  Consensus proposal format.

  What agents vote on in Byzantine Fault Tolerance (BFT) consensus.

  ## Fields

    * `:type` - Atom: `:process_model | :workflow | :decision` - What kind of proposal
    * `:content` - Any: The proposal data (can be a map, struct, or other data)
    * `:proposer` - String: Agent ID who proposed this
    * `:votes` - Map: `%{agent_id => vote}` where vote is `:approve | :reject`
    * `:status` - Atom: `:pending | :approved | :rejected` - Current proposal status

  ## Usage

      iex> proposal = OptimalSystemAgent.Consensus.Proposal.new(
      ...>   :process_model,
      ...>   %{name: "Customer Onboarding", steps: [...]},
      ...>   "agent_123"
      ...> )
      iex> proposal = OptimalSystemAgent.Consensus.Proposal.add_vote(proposal, "agent_456", :approve)
      iex> OptimalSystemAgent.Consensus.Proposal.calculate_result(proposal)
      {:ok, :approved}

  ## BFT Consensus Context

  This proposal structure is used in Phase 2 BFT consensus implementation for
  agent fleets. Proposals circulate through the fleet, each agent votes,
  and the result is calculated once all votes are collected or a threshold
  is reached.

  See: `OptimalSystemAgent.Consensus.HotStuff` for the BFT consensus engine.
  """

  # ---------------------------------------------------------------------------
  # Struct Definition
  # ---------------------------------------------------------------------------

  @type proposal_type :: :process_model | :workflow | :decision
  @type vote :: :approve | :reject
  @type status :: :pending | :approved | :rejected

  @type t :: %__MODULE__{
          type: proposal_type(),
          content: any(),
          proposer: String.t(),
          votes: %{String.t() => vote()},
          status: status(),
          created_at: DateTime.t(),
          workflow_id: String.t() | nil
        }

  defstruct type: :process_model,
            content: nil,
            proposer: "",
            votes: %{},
            status: :pending,
            created_at: nil,
            workflow_id: nil

  # ---------------------------------------------------------------------------
  # Constructor
  # ---------------------------------------------------------------------------

  @doc """
  Create a new proposal.

  ## Parameters

    * `type` - The proposal type (`:process_model`, `:workflow`, or `:decision`)
    * `content` - The proposal data (any format)
    * `proposer` - Agent ID of the proposer
    * `opts` - Optional keyword arguments

  ## Options

    * `:votes` - Initial votes map (default: `%{}`)
    * `:status` - Initial status (default: `:pending`)
    * `:workflow_id` - Optional workflow identifier

  ## Examples

      iex> proposal = OptimalSystemAgent.Consensus.Proposal.new(
      ...>   :process_model,
      ...>   %{name: "Customer Onboarding"},
      ...>   "agent_123"
      ...> )
      iex> proposal.type
      :process_model
      iex> proposal.content
      %{name: "Customer Onboarding"}
      iex> proposal.proposer
      "agent_123"
      iex> proposal.workflow_id
      nil
  """
  @spec new(proposal_type(), any(), String.t(), keyword()) :: t()
  def new(type, content, proposer, opts \\ []) when type in [:process_model, :workflow, :decision] do
    %__MODULE__{
      type: type,
      content: content,
      proposer: proposer,
      votes: Keyword.get(opts, :votes, %{}),
      status: Keyword.get(opts, :status, :pending),
      created_at: DateTime.utc_now(),
      workflow_id: Keyword.get(opts, :workflow_id)
    }
  end

  # ---------------------------------------------------------------------------
  # Vote Management
  # ---------------------------------------------------------------------------

  @doc """
  Add a vote to the proposal.

  ## Parameters

    * `proposal` - The proposal struct
    * `agent_id` - ID of the agent voting
    * `vote` - `:approve` or `:reject`

  ## Examples

      iex> proposal = OptimalSystemAgent.Consensus.Proposal.new(:process_model, %{}, "agent_1")
      iex> OptimalSystemAgent.Consensus.Proposal.add_vote(proposal, "agent_2", :approve)
      %OptimalSystemAgent.Consensus.Proposal{votes: %{"agent_2" => :approve}}
  """
  @spec add_vote(t(), String.t(), vote()) :: t()
  def add_vote(%__MODULE__{} = proposal, agent_id, vote) when vote in [:approve, :reject] do
    %{proposal | votes: Map.put(proposal.votes, agent_id, vote)}
  end

  @doc """
  Remove a vote from the proposal.

  Useful for vote re-voting or correcting mistakes.
  """
  @spec remove_vote(t(), String.t()) :: t()
  def remove_vote(%__MODULE__{} = proposal, agent_id) do
    %{proposal | votes: Map.delete(proposal.votes, agent_id)}
  end

  @doc """
  Check if a specific agent has voted.
  """
  @spec has_voted?(t(), String.t()) :: boolean()
  def has_voted?(%__MODULE__{} = proposal, agent_id) do
    Map.has_key?(proposal.votes, agent_id)
  end

  @doc """
  Get the vote of a specific agent.

  Returns `:approve`, `:reject`, or `nil` if the agent hasn't voted.
  """
  @spec get_vote(t(), String.t()) :: vote() | nil
  def get_vote(%__MODULE__{} = proposal, agent_id) do
    Map.get(proposal.votes, agent_id)
  end

  # ---------------------------------------------------------------------------
  # Result Calculation
  # ---------------------------------------------------------------------------

  @doc """
  Calculate the result of the proposal based on current votes.

  Returns `{:ok, :approved}` if more than 2/3 of votes are approve,
  `{:ok, :rejected}` if more than 1/3 are reject,
  or `{:pending, continue}` if the threshold hasn't been reached yet.

  The 2/3 threshold is the standard for Byzantine Fault Tolerance:
  - In a system of 3f+1 nodes, we need 2f+1 agreeing votes to guarantee safety
  - This translates to > 2/3 supermajority

  ## Examples

      iex> proposal = OptimalSystemAgent.Consensus.Proposal.new(:process_model, %{}, "agent_1")
      iex> proposal = OptimalSystemAgent.Consensus.Proposal.add_vote(proposal, "agent_2", :approve)
      iex> proposal = OptimalSystemAgent.Consensus.Proposal.add_vote(proposal, "agent_3", :approve)
      iex> OptimalSystemAgent.Consensus.Proposal.calculate_result(proposal)
      {:ok, :approved}
  """
  @spec calculate_result(t()) :: {:ok, :approved | :rejected} | {:pending, float()}
  def calculate_result(%__MODULE__{votes: votes}) when map_size(votes) == 0 do
    {:pending, 0.0}
  end

  def calculate_result(%__MODULE__{votes: votes, status: status}) do
    total_votes = map_size(votes)
    approve_count = Enum.count(votes, fn {_agent, vote} -> vote == :approve end)
    approve_ratio = approve_count / total_votes

    cond do
      status == :approved ->
        {:ok, :approved}

      status == :rejected ->
        {:ok, :rejected}

      approve_ratio > 2 / 3 ->
        # BFT threshold: > 2/3 supermajority
        {:ok, :approved}

      approve_ratio < 1 / 3 ->
        # If less than 1/3 approve, it's rejected
        {:ok, :rejected}

      true ->
        # Still pending - haven't reached threshold
        {:pending, approve_ratio}
    end
  end

  @doc """
  Update the proposal status based on current votes.

  Returns the proposal with updated status if the threshold is reached,
  or the unchanged proposal if still pending.
  """
  @spec update_status(t()) :: t()
  def update_status(%__MODULE__{} = proposal) do
    case calculate_result(proposal) do
      {:ok, :approved} -> %{proposal | status: :approved}
      {:ok, :rejected} -> %{proposal | status: :rejected}
      {:pending, _ratio} -> proposal
    end
  end

  # ---------------------------------------------------------------------------
  # Query Functions
  # ---------------------------------------------------------------------------

  @doc """
  Get vote counts: `{approve_count, reject_count}`.
  """
  @spec vote_counts(t()) :: {non_neg_integer(), non_neg_integer()}
  def vote_counts(%__MODULE__{votes: votes}) do
    approve_count = Enum.count(votes, fn {_agent, vote} -> vote == :approve end)
    reject_count = Enum.count(votes, fn {_agent, vote} -> vote == :reject end)
    {approve_count, reject_count}
  end

  @doc """
  Get the list of agents who have voted.
  """
  @spec voters(t()) :: [String.t()]
  def voters(%__MODULE__{votes: votes}) do
    Map.keys(votes)
  end

  @doc """
  Check if the proposal has reached a decision (approved or rejected).
  """
  @spec decided?(t()) :: boolean()
  def decided?(%__MODULE__{status: status}) do
    status in [:approved, :rejected]
  end

  @doc """
  Check if the proposal is still pending.
  """
  @spec pending?(t()) :: boolean()
  def pending?(%__MODULE__{status: status}) do
    status == :pending
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  @doc """
  Validate a proposal struct.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = proposal) do
    cond do
      not is_binary(proposal.proposer) or proposal.proposer == "" ->
        {:error, :invalid_proposer}

      proposal.type not in [:process_model, :workflow, :decision] ->
        {:error, :invalid_type}

      proposal.content == nil ->
        {:error, :invalid_content}

      proposal.status not in [:pending, :approved, :rejected] ->
        {:error, :invalid_status}

      not valid_votes?(proposal.votes) ->
        {:error, :invalid_votes}

      true ->
        :ok
    end
  end

  defp valid_votes?(votes) when is_map(votes) do
    Enum.all?(votes, fn
      {_agent, vote} when vote in [:approve, :reject] -> true
      _ -> false
    end)
  end

  defp valid_votes?(_), do: false

  # ---------------------------------------------------------------------------
  # Serialization
  # ---------------------------------------------------------------------------

  @doc """
  Convert proposal to a map for serialization (e.g., JSON encoding).

  DateTime is converted to ISO8601 string.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = proposal) do
    %{
      "type" => proposal.type,
      "content" => proposal.content,
      "proposer" => proposal.proposer,
      "votes" => proposal.votes,
      "status" => proposal.status,
      "created_at" => DateTime.to_iso8601(proposal.created_at),
      "workflow_id" => proposal.workflow_id
    }
  end

  @doc """
  Create a proposal from a map (e.g., from JSON decoding).

  Returns `{:ok, proposal}` or `{:error, reason}`.
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(map) when is_map(map) do
    with {:ok, created_at} <- parse_datetime(Map.get(map, "created_at")),
         proposal <- %__MODULE__{
           type: Map.get(map, "type"),
           content: Map.get(map, "content"),
           proposer: Map.get(map, "proposer"),
           votes: Map.get(map, "votes", %{}),
           status: Map.get(map, "status", :pending),
           created_at: created_at,
           workflow_id: Map.get(map, "workflow_id")
         },
         :ok <- validate(proposal) do
      {:ok, proposal}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_map}
    end
  end

  defp parse_datetime(nil), do: {:ok, DateTime.utc_now()}
  defp parse_datetime(iso8601) when is_binary(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, _} -> {:error, :invalid_datetime}
    end
  end
  defp parse_datetime(_), do: {:error, :invalid_datetime}
end
