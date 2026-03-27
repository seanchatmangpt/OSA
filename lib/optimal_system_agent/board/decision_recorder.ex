defmodule OptimalSystemAgent.Board.DecisionRecorder do
  @moduledoc """
  Records board chair decisions on structural (Conway) violations.

  When a board chair records a decision, this module:
  1. Stores the decision in ETS with timestamp and type
  2. Emits a :system_event with event: :board_decision_recorded
  3. Invalidates the L1 inference cache so next materialization
     re-evaluates the department (InferenceChain.invalidate_from(:l0))

  WvdA: Decision recording closes the process feedback loop.
  Conway violations that have been decided are excluded from future briefings.
  Armstrong: Decisions are permanent facts — stored in ETS + persisted to
  ~/.osa/decisions/<timestamp>.json for durability across restarts.

  ## Decision types
  - :reorganize — board chair restructured the department boundary
  - :add_liaison — board chair added a cross-department liaison role
  - :accept_constraint — board chair accepts the org boundary as-is (stops alerting)
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus
  alias OptimalSystemAgent.Ontology.InferenceChain

  @ets_table :osa_board_decisions
  @decisions_dir Path.expand("~/.osa/decisions")

  @valid_decision_types [:reorganize, :add_liaison, :accept_constraint]

  # Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a board chair decision on a structural violation.

  decision_type: :reorganize | :add_liaison | :accept_constraint
  department: string department identifier
  notes: optional string notes from board chair
  """
  @spec record_decision(String.t(), atom(), String.t()) :: :ok | {:error, term()}
  def record_decision(department, decision_type, notes \\ "") do
    GenServer.call(__MODULE__, {:record, department, decision_type, notes}, 10_000)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @doc "List all recorded decisions."
  @spec list_decisions() :: [map()]
  def list_decisions do
    GenServer.call(__MODULE__, :list, 5_000)
  catch
    :exit, {:timeout, _} -> []
  end

  @doc "Check if a department has an active (unresolved) Conway decision."
  @spec has_active_decision?(String.t()) :: boolean()
  def has_active_decision?(department) do
    case :ets.lookup(@ets_table, {:decision, department}) do
      [{_, _decision}] -> true
      [] -> false
    end
  end

  @doc "Return all departments that have an active decision recorded."
  @spec decided_departments() :: [String.t()]
  def decided_departments do
    :ets.match_object(@ets_table, {{:decision, :_}, :_})
    |> Enum.map(fn {{:decision, dept}, _} -> dept end)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set])
    end

    File.mkdir_p!(@decisions_dir)

    # Load persisted decisions on startup
    load_persisted_decisions()

    Logger.info("[DecisionRecorder] Started — table=#{@ets_table} decisions_dir=#{@decisions_dir}")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:record, department, decision_type, notes}, _from, state) do
    if decision_type not in @valid_decision_types do
      {:reply, {:error, {:invalid_decision_type, decision_type}}, state}
    else
      decision = %{
        department: department,
        type: decision_type,
        notes: notes,
        recorded_at: DateTime.utc_now()
      }

      :ets.insert(@ets_table, {{:decision, department}, decision})

      # Persist to disk
      persist_decision(decision)

      # Invalidate inference cache so next L1 run re-evaluates this department
      try do
        InferenceChain.invalidate_from(:l0)
      rescue
        e ->
          Logger.warning("[DecisionRecorder] InferenceChain invalidation failed: #{inspect(e)}")
      end

      # Emit event for board briefing to pick up
      Bus.emit(:system_event, %{
        event: :board_decision_recorded,
        department: department,
        decision_type: decision_type,
        recorded_at: decision.recorded_at
      }, source: "decision_recorder")

      Logger.info(
        "[DecisionRecorder] Decision recorded: dept=#{department} type=#{decision_type}"
      )

      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    decisions =
      :ets.match_object(@ets_table, {{:decision, :_}, :_})
      |> Enum.map(fn {_key, decision} -> decision end)
      |> Enum.sort_by(& &1.recorded_at, :desc)

    {:reply, decisions, state}
  end

  # Private

  defp persist_decision(decision) do
    filename =
      "#{DateTime.to_unix(decision.recorded_at)}_#{decision.department}_#{decision.type}.json"

    path = Path.join(@decisions_dir, filename)

    serializable = %{
      department: decision.department,
      type: Atom.to_string(decision.type),
      notes: decision.notes,
      recorded_at: DateTime.to_iso8601(decision.recorded_at)
    }

    json = Jason.encode!(serializable, pretty: true)
    File.write!(path, json)
  rescue
    e ->
      Logger.warning("[DecisionRecorder] Failed to persist decision: #{inspect(e)}")
  end

  defp load_persisted_decisions do
    case File.ls(@decisions_dir) do
      {:ok, files} ->
        Enum.each(files, fn file ->
          if String.ends_with?(file, ".json") do
            path = Path.join(@decisions_dir, file)

            with {:ok, json} <- File.read(path),
                 {:ok, raw} <- Jason.decode(json),
                 {:ok, decision} <- decode_persisted(raw) do
              :ets.insert(@ets_table, {{:decision, decision.department}, decision})
            else
              err ->
                Logger.debug("[DecisionRecorder] Skipping #{file}: #{inspect(err)}")
            end
          end
        end)

      _ ->
        :ok
    end
  end

  defp decode_persisted(%{"department" => dept, "type" => type_str} = raw) do
    with {:ok, dt} <- decode_datetime(raw["recorded_at"]),
         {:ok, type_atom} <- decode_decision_type(type_str) do
      {:ok,
       %{
         department: dept,
         type: type_atom,
         notes: Map.get(raw, "notes", ""),
         recorded_at: dt
       }}
    end
  end

  defp decode_persisted(_), do: {:error, :invalid_format}

  defp decode_datetime(nil), do: {:error, :missing_recorded_at}

  defp decode_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> {:ok, dt}
      err -> err
    end
  end

  defp decode_decision_type(str) when is_binary(str) do
    atom = String.to_atom(str)

    if atom in @valid_decision_types do
      {:ok, atom}
    else
      {:error, {:unknown_decision_type, str}}
    end
  end
end
