defmodule OptimalSystemAgent.Workspace.TaskJournal do
  @moduledoc """
  ETS-based task journal for tracking agent task execution.

  Real ETS operations, no mocks. Tracks task lifecycle: start, complete, fail.
  """

  require Logger
  alias OptimalSystemAgent.Workspace.Store

  @journal_table :osa_task_journal
  @valid_actions ~w(created assigned started paused completed failed reassigned)a

  # ── ETS Initialization ────────────────────────────────────────────────────

  @doc "Create the task journal ETS table. Called from application start."
  def init_table do
    :ets.new(@journal_table, [:named_table, :public, :set])
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Return the ETS table name."
  def table_name, do: @journal_table

  # ── Task Lifecycle ────────────────────────────────────────────────────────

  @doc "Start a task and record it in the journal. Returns task_id."
  def start_task(agent_id, task_type, metadata \\ %{}) do
    task_id = "task_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

    record = %{
      task_id: task_id,
      agent_id: agent_id,
      task_type: task_type,
      status: :running,
      metadata: metadata,
      started_at: DateTime.utc_now(),
      completed_at: nil,
      result: nil,
      error: nil,
      stacktrace: nil,
      duration_ms: nil
    }

    :ets.insert(@journal_table, {task_id, record})
    task_id
  rescue
    _ -> "task_error"
  end

  @doc "Complete a task with a result."
  def complete_task(task_id, result) do
    case :ets.lookup(@journal_table, task_id) do
      [{^task_id, record}] ->
        now = DateTime.utc_now()
        duration_ms = DateTime.diff(now, record.started_at, :millisecond)

        updated = %{
          record
          | status: :completed,
            completed_at: now,
            result: result,
            duration_ms: duration_ms
        }

        :ets.insert(@journal_table, {task_id, updated})
        :ok

      [] ->
        :ok
    end
  rescue
    _ -> :ok
  end

  @doc "Mark a task as failed with error and stacktrace."
  def fail_task(task_id, error, stacktrace) do
    case :ets.lookup(@journal_table, task_id) do
      [{^task_id, record}] ->
        now = DateTime.utc_now()

        updated = %{
          record
          | status: :failed,
            completed_at: now,
            error: error,
            stacktrace: stacktrace
        }

        :ets.insert(@journal_table, {task_id, updated})
        :ok

      [] ->
        :ok
    end
  rescue
    _ -> :ok
  end

  @doc "Get a task record by ID."
  def get_task(task_id) do
    case :ets.lookup(@journal_table, task_id) do
      [{^task_id, record}] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @doc "List all tasks for an agent, sorted by started_at descending."
  def list_tasks(agent_id) do
    :ets.match_object(@journal_table, {:_, %{agent_id: agent_id}})
    |> Enum.map(fn {_, record} -> record end)
    |> Enum.sort_by(& &1.started_at, {:desc, DateTime})
  rescue
    _ -> []
  end

  @doc "Get active (running) tasks for an agent."
  def active_tasks(agent_id) do
    agent_id
    |> list_tasks()
    |> Enum.filter(&(&1.status == :running))
  end

  @doc "Count total tasks for an agent."
  def task_count(agent_id) do
    agent_id |> list_tasks() |> length()
  end

  @doc "Clean up tasks older than cutoff datetime."
  def cleanup_old_tasks(cutoff) do
    :ets.match_object(@journal_table, {:_, :_})
    |> Enum.each(fn {task_id, record} ->
      if DateTime.compare(record.started_at, cutoff) == :lt do
        :ets.delete(@journal_table, task_id)
      end
    end)

    :ok
  rescue
    _ -> :ok
  end

  # Legacy API for Store compatibility

  @doc """
  Append a task state change to the journal (legacy Store API).

  ## Parameters
  - `workspace_id` — owning workspace
  - `entry`        — map with required keys `:task_id`, `:agent_id`, `:action`
                     and optional `:details`

  Returns `:ok` or `{:error, reason}`.
  """
  @spec append(String.t(), map()) :: :ok | {:error, term()}
  def append(workspace_id, %{action: action} = entry)
      when action in @valid_actions do
    record = %{
      workspace_id: workspace_id,
      task_id: Map.get(entry, :task_id, ""),
      agent_id: Map.get(entry, :agent_id, ""),
      action: action,
      details: Map.get(entry, :details, %{}),
      timestamp: DateTime.utc_now()
    }

    case Store.append_journal(record) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("[TaskJournal] Failed to append #{action} for task #{record.task_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def append(workspace_id, %{action: action} = entry) do
    # Try to coerce string actions to atoms for forward-compat
    case safe_to_action_atom(action) do
      {:ok, atom} -> append(workspace_id, %{entry | action: atom})
      :error -> {:error, "Unknown journal action: #{inspect(action)}. Valid: #{inspect(@valid_actions)}"}
    end
  end

  def append(_workspace_id, entry) do
    {:error, "Journal entry missing :action — got: #{inspect(Map.keys(entry))}"}
  end

  @doc """
  Retrieve journal entries for a workspace (legacy Store API).

  ## Options
  - `:task_id`  — filter to a specific task
  - `:agent_id` — filter to a specific agent
  - `:action`   — filter to a specific action atom
  - `:since`    — ISO8601 string lower bound
  - `:until`    — ISO8601 string upper bound
  - `:limit`    — max entries returned (default: 500)

  Returns a list of entry maps in chronological order.
  """
  @spec get_journal(String.t(), keyword()) :: [map()]
  def get_journal(workspace_id, opts \\ []) do
    Store.query_journal(workspace_id, opts)
  end

  @doc """
  Get the full history for a single task (legacy Store API).
  Shorthand for `get_journal/2` with `task_id` filter.
  """
  @spec task_history(String.t(), String.t()) :: [map()]
  def task_history(workspace_id, task_id) do
    get_journal(workspace_id, task_id: task_id)
  end

  @doc """
  Get all actions performed by a specific agent in this workspace (legacy Store API).
  """
  @spec agent_activity(String.t(), String.t()) :: [map()]
  def agent_activity(workspace_id, agent_id) do
    get_journal(workspace_id, agent_id: agent_id)
  end

  @doc """
  Returns a compact summary of task statuses derived from the journal (legacy Store API).

  Replays the journal to find the last action for each task_id.
  Useful for verifying current state matches the audit trail.
  """
  @spec task_summary(String.t()) :: %{String.t() => atom()}
  def task_summary(workspace_id) do
    workspace_id
    |> get_journal()
    |> Enum.reduce(%{}, fn entry, acc ->
      Map.put(acc, entry.task_id, entry.action)
    end)
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp safe_to_action_atom(action) when is_atom(action) do
    if action in @valid_actions, do: {:ok, action}, else: :error
  end

  defp safe_to_action_atom(action) when is_binary(action) do
    atom = String.to_existing_atom(action)
    if atom in @valid_actions, do: {:ok, atom}, else: :error
  rescue
    ArgumentError -> :error
  end

  defp safe_to_action_atom(_), do: :error
end
