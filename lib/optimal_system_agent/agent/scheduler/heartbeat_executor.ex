defmodule OptimalSystemAgent.Agent.Scheduler.HeartbeatExecutor do
  @moduledoc """
  Paperclip-style heartbeat execution engine for scheduled tasks.

  Flow: create run → acquire lock → budget check → execute → capture → persist → emit
  """
  use GenServer
  require Logger

  alias OptimalSystemAgent.Agent.Scheduler.JobExecutor
  alias OptimalSystemAgent.Events.Bus
  alias OptimalSystemAgent.Store.Repo

  @default_timeout_ms 300_000
  @max_timeout_ms 1_800_000
  @circuit_breaker_limit 3

  defstruct locks: %{}, runs: %{}, failures: %{}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def execute(scheduled_task, trigger_type \\ :schedule) do
    GenServer.call(__MODULE__, {:execute, scheduled_task, trigger_type}, 35_000)
  end

  def get_run(run_id) do
    GenServer.call(__MODULE__, {:get_run, run_id})
  end

  def list_runs(task_id, opts \\ []) do
    GenServer.call(__MODULE__, {:list_runs, task_id, opts})
  end

  def failure_count(task_id) do
    GenServer.call(__MODULE__, {:failure_count, task_id})
  end

  def reset_failures(task_id) do
    GenServer.cast(__MODULE__, {:reset_failures, task_id})
  end

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call({:execute, task, trigger_type}, _from, state) do
    agent_name = task["agent_name"] || task["name"] || "unknown"
    task_id = task["id"]

    cond do
      circuit_open?(state, task_id) ->
        {:reply, {:error, :circuit_open}, state}

      Map.has_key?(state.locks, agent_name) ->
        {:reply, {:error, :locked}, state}

      true ->
        state = %{state | locks: Map.put(state.locks, agent_name, true)}
        run = build_run(task, trigger_type)
        state = %{state | runs: Map.put(state.runs, run.id, run)}

        emit_event(:system_event, %{
          event: :task_run_started,
          task_id: task_id,
          run_id: run.id,
          agent_name: agent_name,
          trigger_type: trigger_type
        })

        case check_budget() do
          :ok ->
            {result, run} = execute_task(task, run)
            state = record_result(state, agent_name, task_id, run)
            {:reply, {result, run}, state}

          {:error, :budget_exceeded} ->
            run = finish_run(run, "failed", "Budget exceeded")
            state = record_result(state, agent_name, task_id, run)
            {:reply, {:error, :budget_exceeded}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_run, run_id}, _from, state) do
    {:reply, Map.get(state.runs, run_id), state}
  end

  @impl true
  def handle_call({:list_runs, task_id, opts}, _from, state) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    runs =
      state.runs
      |> Map.values()
      |> Enum.filter(&(&1.scheduled_task_id == task_id))
      |> Enum.sort_by(& &1.started_at, {:desc, DateTime})
      |> Enum.drop((page - 1) * per_page)
      |> Enum.take(per_page)

    {:reply, runs, state}
  end

  @impl true
  def handle_call({:failure_count, task_id}, _from, state) do
    {:reply, Map.get(state.failures, task_id, 0), state}
  end

  @impl true
  def handle_cast({:reset_failures, task_id}, state) do
    {:noreply, %{state | failures: Map.delete(state.failures, task_id)}}
  end

  # ── Execution ────────────────────────────────────────────────────

  defp execute_task(task, run) do
    timeout_ms = min(task["timeout_ms"] || @default_timeout_ms, @max_timeout_ms)
    prompt = task["prompt"] || task["job"] || task["name"]
    session_id = "scheduled_#{task["id"]}_#{System.unique_integer([:positive])}"

    exec_task = Task.async(fn -> JobExecutor.execute_task(prompt, session_id) end)

    case Task.yield(exec_task, timeout_ms) || Task.shutdown(exec_task, :brutal_kill) do
      {:ok, {:ok, output}} ->
        run = finish_run(run, "succeeded", nil, truncate_output(output))

        emit_event(:system_event, %{
          event: :task_run_completed,
          run_id: run.id,
          status: "succeeded",
          duration_ms: run.duration_ms,
          token_usage: run.token_usage
        })

        {:ok, run}

      {:ok, {:error, reason}} ->
        run = finish_run(run, "failed", to_string(reason))
        emit_run_failed(run)
        {:error, run}

      nil ->
        run = finish_run(run, "timed_out", "Timed out after #{timeout_ms}ms")
        emit_run_failed(run)
        {:error, run}
    end
  rescue
    e ->
      run = finish_run(run, "failed", Exception.message(e))
      emit_run_failed(run)
      {:error, run}
  end

  defp record_result(state, agent_name, task_id, run) do
    state = %{state |
      locks: Map.delete(state.locks, agent_name),
      runs: Map.put(state.runs, run.id, run)
    }

    persist_run(run)
    track_failure(state, task_id, run.status)
  end

  defp track_failure(state, task_id, "succeeded") do
    %{state | failures: Map.delete(state.failures, task_id)}
  end

  defp track_failure(state, task_id, _failed_status) do
    count = Map.get(state.failures, task_id, 0) + 1

    if count >= @circuit_breaker_limit do
      Logger.warning("[HeartbeatExecutor] Circuit breaker opened for #{task_id} after #{count} failures")
    end

    %{state | failures: Map.put(state.failures, task_id, count)}
  end

  # ── Run Lifecycle ────────────────────────────────────────────────

  defp build_run(task, trigger_type) do
    %{
      id: generate_run_id(),
      scheduled_task_id: task["id"],
      agent_name: task["agent_name"] || task["name"] || "unknown",
      status: "running",
      trigger_type: to_string(trigger_type),
      started_at: DateTime.utc_now(),
      completed_at: nil,
      duration_ms: nil,
      exit_code: nil,
      stdout: nil,
      stderr: nil,
      token_usage: %{},
      session_state: %{},
      error_message: nil,
      metadata: %{}
    }
  end

  defp finish_run(run, status, error_message, stdout \\ nil) do
    now = DateTime.utc_now()

    %{run |
      status: status,
      completed_at: now,
      duration_ms: DateTime.diff(now, run.started_at, :millisecond),
      error_message: error_message,
      stdout: stdout,
      exit_code: if(status == "succeeded", do: 0, else: 1)
    }
  end

  defp circuit_open?(state, task_id) do
    Map.get(state.failures, task_id, 0) >= @circuit_breaker_limit
  end

  # ── Budget ───────────────────────────────────────────────────────

  defp check_budget do
    if Code.ensure_loaded?(OptimalSystemAgent.Agent.Treasury) and
       function_exported?(OptimalSystemAgent.Agent.Treasury, :get_balance, 0) do
      case OptimalSystemAgent.Agent.Treasury.get_balance() do
        {:ok, %{available: available}} when available > 0 -> :ok
        {:ok, _} -> {:error, :budget_exceeded}
        _ -> :ok
      end
    else
      :ok
    end
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  # ── Persistence ──────────────────────────────────────────────────

  defp persist_run(run) do
    Repo.insert_all("scheduled_runs", [
      %{
        scheduled_task_id: run.scheduled_task_id,
        agent_name: run.agent_name,
        status: run.status,
        trigger_type: run.trigger_type,
        started_at: run.started_at,
        completed_at: run.completed_at,
        duration_ms: run.duration_ms,
        exit_code: run.exit_code,
        stdout: run.stdout,
        stderr: run.stderr,
        token_usage: Jason.encode!(run.token_usage),
        session_state: Jason.encode!(run.session_state),
        error_message: run.error_message,
        metadata: Jason.encode!(run.metadata),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  rescue
    e -> Logger.warning("[HeartbeatExecutor] Failed to persist run: #{Exception.message(e)}")
  end

  # ── Events ───────────────────────────────────────────────────────

  defp emit_run_failed(run) do
    emit_event(:system_event, %{
      event: :task_run_failed,
      run_id: run.id,
      error_message: run.error_message
    })
  end

  defp emit_event(type, payload) do
    Bus.emit(type, payload)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  # ── Helpers ──────────────────────────────────────────────────────

  defp truncate_output(nil), do: nil
  defp truncate_output(output) when byte_size(output) > 10_240 do
    :zlib.gzip(output) |> Base.encode64()
  end
  defp truncate_output(output), do: output

  defp generate_run_id do
    "run_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end
end
