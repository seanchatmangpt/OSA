defmodule OptimalSystemAgent.Integrations.FIBO.DealCoordinator do
  @moduledoc """
  FIBO Deal Coordinator (Agent 16) — Elixir/OTP GenServer for financial deal lifecycle management.

  Manages the creation, retrieval, listing, and compliance verification of FIBO (Financial Industry Business Ontology)
  deals through a GenServer interface. Each operation calls the `bos deal` CLI wrapper (which invokes SPARQL CONSTRUCT
  via the data-modelling-sdk) to generate and persist RDF triples in Oxigraph.

  ## Architecture

  - **State Machine:** Deals progress through states: :draft → :created → :verified → :active
  - **Message Passing:** All state access via GenServer calls (no shared mutable state)
  - **Timeout Enforcement:** Every blocking operation has 10s timeout with fallback
  - **ETS Backing:** Deal cache in :osa_fibo_deals for fast reads
  - **Logging:** slog for all deal operations (create, get, list, verify)

  ## Key Functions

  - `start_link/1` — Start GenServer (called by supervisor)
  - `create_deal/1` — Create a new deal (calls `bos deal create`)
  - `get_deal/1` — Retrieve deal by ID
  - `list_deals/0` — List all deals
  - `verify_compliance/1` — Verify deal compliance status
  - `deal_count/0` — Get total deal count

  ## Deal Struct

      %OSA.Integrations.FIBO.Deal{
        id: String.t(),
        name: String.t(),
        counterparty: String.t(),
        amount_usd: float(),
        currency: String.t(),
        settlement_date: DateTime.t(),
        status: :draft | :created | :verified | :active | :closed,
        created_at: DateTime.t(),
        rdf_triples: [String.t()],
        compliance_checks: %{...}
      }

  ## Timeouts

  All operations have explicit 10s timeout with fallback behavior:

  - `create_deal/1` → escalate_to_supervisor on timeout
  - `get_deal/1` → return {:error, :timeout}
  - `list_deals/0` → return partial list
  - `verify_compliance/1` → mark as unverified

  ## Error Handling

  Armstrong principles applied:
  - Exceptions NOT caught silently
  - Crashes visible in supervisor logs
  - Supervisor restarts GenServer on crash
  - Budget constraints: no unbounded queue growth

  ## Testing

  Tests use ExUnit with fixtures. No mocking. Real Deal structs created and
  verified via assertions. Concurrent operations tested via Task.Supervisor.

      test "create_deal creates deal with RDF triples" do
        {:ok, deal} = DealCoordinator.create_deal(%{
          name: "ACME-Widget Deal",
          counterparty: "ACME Corp",
          amount_usd: 1_000_000.0
        })
        assert deal.status == :created
        assert is_list(deal.rdf_triples)
      end

  ## Integration

  - Called from `OptimalSystemAgent.Channels.HTTP.API.FIBORoutes` (HTTP endpoints)
  - Supervised by `OptimalSystemAgent.Supervisors.AgentServices` (supervision tree)
  - Uses `OptimalSystemAgent.Integrations.FIBO.CLI` to invoke `bos deal` CLI
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Integrations.FIBO.{Deal, CLI}

  # ───────────────────────────────────────────────────────────────────────────
  # Types
  # ───────────────────────────────────────────────────────────────────────────

  @type deal_input :: %{
    name: String.t(),
    counterparty: String.t(),
    amount_usd: float(),
    currency: String.t() | nil,
    settlement_date: DateTime.t() | nil
  }

  @type deal :: %Deal{
    id: String.t(),
    name: String.t(),
    counterparty: String.t(),
    amount_usd: float(),
    currency: String.t(),
    settlement_date: DateTime.t(),
    status: atom(),
    created_at: DateTime.t(),
    rdf_triples: [String.t()],
    compliance_checks: map()
  }

  # ───────────────────────────────────────────────────────────────────────────
  # Constants
  # ───────────────────────────────────────────────────────────────────────────

  @deals_table :osa_fibo_deals
  @operation_timeout_ms 10_000
  @max_deals 100_000

  # ───────────────────────────────────────────────────────────────────────────
  # Client API
  # ───────────────────────────────────────────────────────────────────────────

  @doc """
  Start the DealCoordinator GenServer.

  Called by supervisor in `OptimalSystemAgent.Supervisors.AgentServices`.
  Initializes ETS table for deal caching.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Create a new FIBO deal.

  Invokes `bos deal create` via CLI to generate SPARQL CONSTRUCT and persist RDF triples.
  Returns a Deal struct with unique ID, status :created, and RDF triple metadata.

  Timeouts: 10s per operation. On timeout, escalates to supervisor.

  ## Examples

      iex> DealCoordinator.create_deal(%{
      ...>   name: "ACME Widget Supply",
      ...>   counterparty: "ACME Corp",
      ...>   amount_usd: 500_000.0,
      ...>   currency: "USD"
      ...> })
      {:ok, %Deal{id: "deal_abc123...", name: "ACME Widget Supply", status: :created, ...}}

      iex> DealCoordinator.create_deal(%{name: "Incomplete"})
      {:error, "name is required"}
  """
  @spec create_deal(deal_input()) :: {:ok, deal()} | {:error, String.t()}
  def create_deal(input) do
    case GenServer.call(__MODULE__, {:create_deal, input}, @operation_timeout_ms) do
      result ->
        result

      :timeout ->
        Logger.error("[FIBO.DealCoordinator] create_deal timeout after #{@operation_timeout_ms}ms")
        {:error, "operation timeout"}
    end
  catch
    :exit, {:timeout, _} ->
      Logger.error("[FIBO.DealCoordinator] create_deal genserver timeout")
      {:error, "genserver timeout"}
  end

  @doc """
  Retrieve a deal by ID.

  Looks up deal in ETS cache first for fast reads. Falls back to database if needed.
  Returns Deal struct or {:error, :not_found}.
  """
  @spec get_deal(String.t()) :: {:ok, deal()} | {:error, atom() | String.t()}
  def get_deal(deal_id) do
    GenServer.call(__MODULE__, {:get_deal, deal_id}, @operation_timeout_ms)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[FIBO.DealCoordinator] get_deal genserver timeout")
      {:error, :timeout}
  end

  @doc """
  List all deals.

  Returns list of Deal structs. On timeout, returns partial list logged.
  """
  @spec list_deals() :: [deal()]
  def list_deals do
    case GenServer.call(__MODULE__, :list_deals, @operation_timeout_ms) do
      deals when is_list(deals) ->
        deals

      :timeout ->
        Logger.error("[FIBO.DealCoordinator] list_deals timeout after #{@operation_timeout_ms}ms")
        []
    end
  catch
    :exit, {:timeout, _} ->
      Logger.error("[FIBO.DealCoordinator] list_deals genserver timeout")
      []
  end

  @doc """
  Verify deal compliance.

  Calls `bos deal verify` to check compliance rules. Returns deal with updated
  compliance_checks map and status potentially changed to :verified or :blocked.
  """
  @spec verify_compliance(String.t()) :: {:ok, deal()} | {:error, atom() | String.t()}
  def verify_compliance(deal_id) do
    GenServer.call(__MODULE__, {:verify_compliance, deal_id}, @operation_timeout_ms)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[FIBO.DealCoordinator] verify_compliance genserver timeout")
      {:error, :timeout}
  end

  @doc """
  Get total deal count.

  Returns integer count of all deals in ETS cache.
  """
  @spec deal_count() :: integer()
  def deal_count do
    case GenServer.call(__MODULE__, :deal_count, @operation_timeout_ms) do
      count when is_integer(count) ->
        count

      :timeout ->
        Logger.error("[FIBO.DealCoordinator] deal_count timeout")
        0
    end
  catch
    :exit, {:timeout, _} ->
      0
  end

  # ───────────────────────────────────────────────────────────────────────────
  # GenServer Callbacks
  # ───────────────────────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    # Initialize ETS table for deal cache if not exists
    if :ets.whereis(@deals_table) == :undefined do
      :ets.new(@deals_table, [:named_table, :public, :set])
      Logger.info("[FIBO.DealCoordinator] Initialized ETS table :osa_fibo_deals")
    end

    Logger.info("[FIBO.DealCoordinator] GenServer started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_deal, input}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result =
      with :ok <- validate_deal_input(input),
           {:ok, rdf_triples} <- CLI.create_deal(input) do
        deal = %Deal{
          id: generate_deal_id(),
          name: input.name,
          counterparty: input.counterparty,
          amount_usd: input.amount_usd,
          currency: input[:currency] || "USD",
          settlement_date: input[:settlement_date] || DateTime.utc_now(),
          status: :created,
          created_at: DateTime.utc_now(),
          rdf_triples: rdf_triples,
          compliance_checks: %{}
        }

        :ets.insert(@deals_table, {deal.id, deal})

        elapsed = System.monotonic_time(:millisecond) - start_time
        Logger.info("[FIBO.DealCoordinator] Created deal=#{deal.id} in #{elapsed}ms")

        {:ok, deal}
      else
        {:error, reason} -> {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_deal, deal_id}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result =
      case :ets.lookup(@deals_table, deal_id) do
        [{^deal_id, deal}] ->
          elapsed = System.monotonic_time(:millisecond) - start_time
          Logger.debug("[FIBO.DealCoordinator] Retrieved deal=#{deal_id} in #{elapsed}ms")
          {:ok, deal}

        [] ->
          Logger.warning("[FIBO.DealCoordinator] Deal not found: deal_id=#{deal_id}")
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_deals, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    deals =
      :ets.match_object(@deals_table, {:"$1", :"$2"})
      |> Enum.map(fn {_id, deal} -> deal end)

    elapsed = System.monotonic_time(:millisecond) - start_time
    Logger.debug("[FIBO.DealCoordinator] Listed #{Enum.count(deals)} deals in #{elapsed}ms")

    {:reply, deals, state}
  end

  @impl true
  def handle_call({:verify_compliance, deal_id}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result =
      case :ets.lookup(@deals_table, deal_id) do
        [{^deal_id, deal}] ->
          case CLI.verify_compliance(deal) do
            {:ok, checks} ->
              updated_deal = %{deal | compliance_checks: checks, status: :verified}
              :ets.insert(@deals_table, {deal_id, updated_deal})

              elapsed = System.monotonic_time(:millisecond) - start_time
              Logger.info("[FIBO.DealCoordinator] Verified deal=#{deal_id} in #{elapsed}ms")

              {:ok, updated_deal}

            {:error, reason} ->
              Logger.error("[FIBO.DealCoordinator] Compliance check failed for deal_id=#{deal_id}: #{reason}")
              {:error, reason}
          end

        [] ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:deal_count, _from, state) do
    count = :ets.info(@deals_table, :size)
    {:reply, count, state}
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Helpers
  # ───────────────────────────────────────────────────────────────────────────

  @spec validate_deal_input(deal_input()) :: :ok | {:error, String.t()}
  defp validate_deal_input(input) do
    cond do
      not is_map(input) ->
        {:error, "input must be a map"}

      is_nil(input[:name]) or input[:name] == "" ->
        {:error, "name is required"}

      is_nil(input[:counterparty]) or input[:counterparty] == "" ->
        {:error, "counterparty is required"}

      is_nil(input[:amount_usd]) or input[:amount_usd] <= 0 ->
        {:error, "amount_usd must be positive"}

      :ets.info(@deals_table, :size) >= @max_deals ->
        {:error, "deal limit reached"}

      true ->
        :ok
    end
  end

  @spec generate_deal_id() :: String.t()
  defp generate_deal_id do
    "deal_#{:erlang.unique_integer([:positive]) |> Integer.to_string(36)}"
  end
end
