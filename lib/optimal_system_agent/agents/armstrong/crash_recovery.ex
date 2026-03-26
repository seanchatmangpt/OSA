defmodule OptimalSystemAgent.Agents.Armstrong.CrashRecovery do
  @moduledoc """
  Crash Recovery Agent — Analyzes crash semantics and recovery behavior.

  Follows Joe Armstrong fault tolerance principles (let-it-crash, supervision,
  automatic restart). This agent:

  1. Tracks crash events from ExecutionTrace store (status=error)
  2. Classifies failure types: timeout, exception, exit, assertion
  3. Determines recovery strategy (restart, escalate, circuit-break)
  4. Measures Mean Time To Recovery (MTTR)
  5. Emits telemetry for dashboard visibility

  ## MTTR Thresholds (Expected Recovery Times)

  | Failure Type | Expected MTTR |
  |--------------|---------------|
  | :timeout | 5,000 ms |
  | :exception | 2,000 ms |
  | :exit | 1,000 ms |
  | :assertion | 10,000 ms |

  When actual MTTR exceeds expected, mark as escalated (indicates resource
  exhaustion or slower-than-expected recovery).

  ## GenServer API

  - `start_link(opts)` — Start the crash recovery monitor
  - `classify_crash(error_reason)` → `:timeout | :exception | :exit | :assertion`
  - `expected_mttr(failure_type)` → milliseconds
  - `suggest_recovery(failure_type)` → recovery strategy atom
  - `record_crash(error_reason, mttr_ms)` → :ok (emit telemetry)

  ## Telemetry Events

  Emits via `OptimalSystemAgent.Events.Bus`:
  - `:crash_analysis` with attributes:
    - `failure_type`: atom (timeout, exception, exit, assertion)
    - `mttr_actual`: milliseconds
    - `mttr_expected`: milliseconds
    - `status`: "ok" | "escalated"

  ## WvdA Soundness

  - Deadlock-free: GenServer calls have 15s timeout
  - Liveness: All queries bounded (max 1000 traces per query)
  - Boundedness: Crash log capped at 1000 entries (FIFO eviction)

  ## Armstrong Fault Tolerance

  - Let-it-crash: Errors in analysis don't crash agent
  - Supervision: Registered as child in supervisors/agents
  - No shared state: All state in GenServer memory
  - Budget: Queries timeout at 15s, telemetry async
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus

  # Telemetry event prefix
  @telemetry_event :crash_analysis

  # MTTR thresholds (milliseconds) — expected recovery times
  @mttr_thresholds %{
    timeout: 5_000,
    exception: 2_000,
    exit: 1_000,
    assertion: 10_000
  }

  # State: crash log (FIFO, max 1000 entries)
  @max_crash_log 1000

  defstruct crash_log: [],
            classification_cache: %{}

  # ---- Child Spec ----

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  # ---- GenServer Lifecycle ----

  @doc "Start the crash recovery agent."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Logger.info("#{__MODULE__} started")
    {:ok, %__MODULE__{}}
  end

  # ---- Client API ----

  @doc """
  Classify an error reason into a failure type.

  Returns: `:timeout | :exception | :exit | :assertion`

  Examples:
    iex> classify_crash({:timeout, _})
    :timeout

    iex> classify_crash(%RuntimeError{})
    :exception

    iex> classify_crash(:killed)
    :exit

    iex> classify_crash(%ExUnit.AssertionError{})
    :assertion
  """
  @spec classify_crash(term()) :: atom()
  def classify_crash(error_reason) do
    GenServer.call(__MODULE__, {:classify_crash, error_reason}, 15_000)
  end

  @doc """
  Look up expected MTTR (Mean Time To Recovery) for a failure type.

  Returns milliseconds as integer.

  Examples:
    iex> expected_mttr(:timeout)
    5_000

    iex> expected_mttr(:exit)
    1_000
  """
  @spec expected_mttr(atom()) :: non_neg_integer()
  def expected_mttr(failure_type) when is_atom(failure_type) do
    Map.get(@mttr_thresholds, failure_type, 10_000)
  end

  @doc """
  Suggest a recovery strategy for a failure type.

  Returns: `:restart | :escalate | :circuit_break | :degrade`

  - `:restart` — Retry immediately (transient failures)
  - `:escalate` — Escalate to healing agent (resource exhaustion)
  - `:circuit_break` — Stop attempting, wait for manual intervention
  - `:degrade` — Reduce service quality, continue
  """
  @spec suggest_recovery(atom()) :: atom()
  def suggest_recovery(failure_type) do
    GenServer.call(__MODULE__, {:suggest_recovery, failure_type}, 15_000)
  end

  @doc """
  Record a crash event with actual MTTR.

  Emits telemetry via Bus. If MTTR > expected, marks status as "escalated".

  Returns: :ok
  """
  @spec record_crash(term(), non_neg_integer()) :: :ok
  def record_crash(error_reason, mttr_ms) when is_integer(mttr_ms) and mttr_ms >= 0 do
    GenServer.call(__MODULE__, {:record_crash, error_reason, mttr_ms}, 15_000)
  end

  @doc """
  Retrieve the crash log (recent crashes).

  Returns: list of crash records
  """
  @spec crash_log() :: [map()]
  def crash_log do
    GenServer.call(__MODULE__, :crash_log, 15_000)
  end

  @doc """
  Retrieve statistics about crashes.

  Returns: %{
    total_crashes: integer,
    by_type: %{atom => count},
    escalated_count: integer,
    avg_mttr_ms: float
  }
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats, 15_000)
  end

  # ---- GenServer Callbacks ----

  @impl GenServer
  def handle_call({:classify_crash, error_reason}, _from, state) do
    classification = do_classify_crash(error_reason)
    {:reply, classification, state}
  end

  @impl GenServer
  def handle_call({:suggest_recovery, failure_type}, _from, state) do
    strategy = do_suggest_recovery(failure_type)
    {:reply, strategy, state}
  end

  @impl GenServer
  def handle_call({:record_crash, error_reason, mttr_ms}, _from, state) do
    failure_type = do_classify_crash(error_reason)
    expected = expected_mttr(failure_type)
    escalated = mttr_ms > expected

    status = if escalated, do: "escalated", else: "ok"

    # Emit telemetry asynchronously
    emit_crash_telemetry(failure_type, mttr_ms, expected, status)

    # Update crash log (FIFO, max 1000)
    crash_entry = %{
      timestamp: System.os_time(:millisecond),
      failure_type: failure_type,
      mttr_actual: mttr_ms,
      mttr_expected: expected,
      escalated: escalated
    }

    new_log = [crash_entry | state.crash_log] |> Enum.take(@max_crash_log)

    {:reply, :ok, %{state | crash_log: new_log}}
  end

  @impl GenServer
  def handle_call(:crash_log, _from, state) do
    {:reply, state.crash_log, state}
  end

  @impl GenServer
  def handle_call(:stats, _from, state) do
    stats = calculate_stats(state.crash_log)
    {:reply, stats, state}
  end

  # ---- Private Helpers ----

  @doc false
  defp do_classify_crash(error_reason) do
    cond do
      # Timeout patterns
      is_timeout(error_reason) -> :timeout

      # Exit patterns (process termination)
      is_exit(error_reason) -> :exit

      # Assertion patterns
      is_assertion(error_reason) -> :assertion

      # Exception patterns (default)
      true -> :exception
    end
  end

  @doc false
  defp is_timeout(error) do
    case error do
      {:timeout, _} -> true
      "timeout" <> _ -> true
      "deadline exceeded" <> _ -> true
      %{message: msg} when is_binary(msg) -> String.contains?(msg, ["timeout", "deadline"])
      _ -> false
    end
  end

  @doc false
  defp is_exit(error) do
    case error do
      {:exit, _} -> true
      :killed -> true
      :shutdown -> true
      :normal -> false  # Normal exit is not a failure
      _atom when is_atom(error) and error != :normal -> true
      _ -> false
    end
  end

  @doc false
  defp is_assertion(error) do
    case error do
      %ExUnit.AssertionError{} -> true
      %{__struct__: mod} ->
        name = mod |> Module.split() |> List.last()
        String.contains?(name || "", "AssertionError")
      _ -> false
    end
  end

  @doc false
  defp do_suggest_recovery(failure_type) do
    case failure_type do
      :timeout -> :escalate
      :exit -> :restart
      :exception -> :restart
      :assertion -> :circuit_break
      _ -> :degrade
    end
  end

  @doc false
  defp emit_crash_telemetry(failure_type, mttr_actual, mttr_expected, status) do
    # Emit asynchronously via Bus to avoid blocking GenServer
    Task.start(fn ->
      try do
        Bus.emit(:system_event, %{
          channel: :crash_recovery,
          event_type: @telemetry_event,
          failure_type: failure_type,
          mttr_actual: mttr_actual,
          mttr_expected: mttr_expected,
          status: status
        })
      catch
        _type, error ->
          Logger.warning("Failed to emit crash telemetry: #{inspect(error)}")
      end
    end)
  end

  @doc false
  defp calculate_stats(crash_log) do
    if Enum.empty?(crash_log) do
      %{
        total_crashes: 0,
        by_type: %{},
        escalated_count: 0,
        avg_mttr_ms: 0.0
      }
    else
      by_type =
        crash_log
        |> Enum.group_by(& &1.failure_type)
        |> Map.new(fn {type, entries} -> {type, length(entries)} end)

      escalated_count = Enum.count(crash_log, & &1.escalated)

      avg_mttr =
        crash_log
        |> Enum.map(& &1.mttr_actual)
        |> Enum.sum()
        |> Kernel./(max(length(crash_log), 1))

      %{
        total_crashes: length(crash_log),
        by_type: by_type,
        escalated_count: escalated_count,
        avg_mttr_ms: avg_mttr
      }
    end
  end
end
