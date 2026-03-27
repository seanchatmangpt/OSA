defmodule OptimalSystemAgent.Resilience.CircuitBreaker do
  @moduledoc """
  Circuit breaker for ProcessMining.Client (Armstrong backpressure pattern).

  Implements the circuit breaker pattern to prevent cascading failures when
  ProcessMining service becomes unavailable. Tracks failure rates and transitions
  through three states: CLOSED (normal) → OPEN (too many errors) → HALF_OPEN
  (testing recovery) → CLOSED.

  ## States

  - **CLOSED**: Normal operation. All calls pass through. Failures are tracked.
    Transitions to OPEN when failure rate exceeds threshold (5+ errors in 60s).

  - **OPEN**: Circuit is tripped. All calls immediately fail with `{:error, :circuit_open}`.
    Waits for `open_timeout_ms` (default 30s) before transitioning to HALF_OPEN.
    Timestamps and error details logged.

  - **HALF_OPEN**: Testing if the service has recovered. Allows a limited number
    of test calls (3 successes closes the circuit). Any failure reopens immediately.
    Tracks these test calls separately.

  ## Failure Tracking

  In CLOSED state, tracks failures in a sliding window:
  - Window duration: 60 seconds
  - Threshold: 5+ errors in the window → transition to OPEN
  - Errors include network timeouts, HTTP errors, and malformed responses

  ## Integration

  Used as a wrapper around ProcessMining.Client calls:

      {:ok, result} = CircuitBreaker.call(fn ->
        ProcessMining.Client.check_deadlock_free(process_id)
      end)

  Or with explicit process name for testing:

      {:ok, result} = CircuitBreaker.call(name, fn ->
        ProcessMining.Client.check_deadlock_free(process_id)
      end)

  ## Armstrong Backpressure

  This implements backpressure by rejecting calls when downstream service is
  unavailable, following Joe Armstrong's "fail fast" principle. The circuit
  breaker is supervised and crashes are logged; callers must handle the
  `{:error, :circuit_open}` response.
  """

  use GenServer
  require Logger

  # Public API

  @doc """
  Start the circuit breaker GenServer.

  Options:
  - `name`: Process name (defaults to `__MODULE__`)
  - `failure_threshold`: Number of errors to trigger open (default: 5)
  - `window_duration_ms`: Time window for counting errors (default: 60_000)
  - `open_timeout_ms`: Time to wait in OPEN state (default: 30_000)
  - `success_threshold`: Number of successes in HALF_OPEN to close (default: 3)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Execute a function wrapped by the circuit breaker.

  Returns `{:ok, result}` if successful, `{:error, :circuit_open}` if circuit
  is open, or `{:error, reason}` if the function fails.

  The circuit breaker process name defaults to `OptimalSystemAgent.Resilience.CircuitBreaker`.
  """
  def call(fun) do
    call(__MODULE__, fun)
  end

  @doc """
  Execute a function wrapped by the circuit breaker with explicit process name.

  Used for testing with custom circuit breaker instances.
  """
  def call(name, fun) when is_function(fun, 0) do
    GenServer.call(name, {:call, fun}, 15_000)
  catch
    :exit, {:timeout, _} ->
      Logger.error("CircuitBreaker timeout on call")
      {:error, :timeout}
  end

  @doc """
  Get the current state of the circuit breaker.

  Returns `:CLOSED`, `:OPEN`, or `:HALF_OPEN`.
  """
  def status(name \\ __MODULE__) do
    GenServer.call(name, :status, 5_000)
  catch
    :exit, {:timeout, _} ->
      :unknown
  end

  @doc """
  Reset the circuit breaker to CLOSED state.

  Used in testing to reset state between test cases.
  """
  def reset(name \\ __MODULE__) do
    GenServer.call(name, :reset, 5_000)
  catch
    :exit, {:timeout, _} ->
      {:error, :timeout}
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      status: :CLOSED,
      failure_threshold: Keyword.get(opts, :failure_threshold, 5),
      window_duration_ms: Keyword.get(opts, :window_duration_ms, 60_000),
      open_timeout_ms: Keyword.get(opts, :open_timeout_ms, 30_000),
      success_threshold: Keyword.get(opts, :success_threshold, 3),
      # List of {timestamp_ms, reason}
      failures: [],
      # Timestamp when circuit opened
      opened_at_ms: nil,
      # Counter for successes in HALF_OPEN state
      half_open_successes: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:call, fun}, _from, state) do
    try do
      case state.status do
        :CLOSED ->
          handle_closed_call(fun, state)

        :OPEN ->
          case should_transition_to_half_open?(state) do
            true ->
              Logger.info("CircuitBreaker: OPEN → HALF_OPEN (testing recovery)")
              new_state = %{state | status: :HALF_OPEN, half_open_successes: 0}
              handle_half_open_call(fun, new_state)

            false ->
              {:reply, {:error, :circuit_open}, state}
          end

        :HALF_OPEN ->
          handle_half_open_call(fun, state)
      end
    catch
      # Handle throw() from within the case statement
      kind, reason ->
        Logger.error("CircuitBreaker: Caught unexpected error: #{kind} #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  def handle_call(:reset, _from, state) do
    Logger.info("CircuitBreaker: Reset to CLOSED")

    new_state = %{
      state
      | status: :CLOSED,
        failures: [],
        opened_at_ms: nil,
        half_open_successes: 0
    }

    {:reply, :ok, new_state}
  end

  # Private helpers

  defp handle_closed_call(fun, state) do
    try do
      result = fun.()
      # Reset failures on success (sliding window restarts)
      new_state = %{state | failures: []}
      {:reply, {:ok, result}, new_state}
    rescue
      e ->
        handle_failure(e, state)
    catch
      :throw, reason ->
        handle_failure(reason, state)

      :exit, reason ->
        handle_failure(reason, state)
    end
  end

  defp handle_failure(reason, state) do
    now_ms = System.monotonic_time(:millisecond)

    new_failures = [
      {now_ms, reason}
      | Enum.filter(state.failures, fn {ts, _} ->
          now_ms - ts < state.window_duration_ms
        end)
    ]

    Logger.warning(
      "CircuitBreaker: Failure recorded (#{length(new_failures)}/#{state.failure_threshold}): #{inspect(reason)}"
    )

    new_state = %{state | failures: new_failures}

    if length(new_failures) >= state.failure_threshold do
      Logger.error(
        "CircuitBreaker: CLOSED → OPEN (#{length(new_failures)} failures in #{state.window_duration_ms}ms)"
      )

      {:reply, {:error, :circuit_open},
       %{new_state | status: :OPEN, opened_at_ms: now_ms, failures: []}}
    else
      {:reply, {:error, reason}, new_state}
    end
  end

  defp handle_half_open_call(fun, state) do
    try do
      result = fun.()
      new_successes = state.half_open_successes + 1

      if new_successes >= state.success_threshold do
        Logger.info(
          "CircuitBreaker: HALF_OPEN → CLOSED (#{new_successes}/#{state.success_threshold} successes)"
        )

        new_state = %{
          state
          | status: :CLOSED,
            half_open_successes: 0,
            failures: [],
            opened_at_ms: nil
        }

        {:reply, {:ok, result}, new_state}
      else
        new_state = %{state | half_open_successes: new_successes}

        Logger.info(
          "CircuitBreaker: HALF_OPEN success (#{new_successes}/#{state.success_threshold})"
        )

        {:reply, {:ok, result}, new_state}
      end
    rescue
      e ->
        Logger.error("CircuitBreaker: HALF_OPEN → OPEN (failure on test call): #{inspect(e)}")

        {:reply, {:error, :circuit_open},
         %{
           state
           | status: :OPEN,
             opened_at_ms: System.monotonic_time(:millisecond),
             half_open_successes: 0
         }}
    catch
      :throw, reason ->
        Logger.error(
          "CircuitBreaker: HALF_OPEN → OPEN (failure on test call): #{inspect(reason)}"
        )

        {:reply, {:error, :circuit_open},
         %{
           state
           | status: :OPEN,
             opened_at_ms: System.monotonic_time(:millisecond),
             half_open_successes: 0
         }}

      :exit, reason ->
        Logger.error(
          "CircuitBreaker: HALF_OPEN → OPEN (failure on test call): #{inspect(reason)}"
        )

        {:reply, {:error, :circuit_open},
         %{
           state
           | status: :OPEN,
             opened_at_ms: System.monotonic_time(:millisecond),
             half_open_successes: 0
         }}
    end
  end

  defp should_transition_to_half_open?(state) do
    case state.opened_at_ms do
      nil ->
        false

      opened_at_ms ->
        now_ms = System.monotonic_time(:millisecond)
        now_ms - opened_at_ms >= state.open_timeout_ms
    end
  end
end
