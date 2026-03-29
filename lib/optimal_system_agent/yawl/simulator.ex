defmodule OptimalSystemAgent.Yawl.Simulator do
  @moduledoc """
  Concurrent YAWL user simulator.

  Launches N independent Tasks, each running a full YAWL case lifecycle:
  launch → list_workitems → start → complete, looping until the case finishes
  or a budget is exceeded.

  ## Quickstart

      # 3 users on basic WCP patterns (WCP-1..5), no YAWL server needed for stubs
      alias OptimalSystemAgent.Yawl.Simulator
      result = Simulator.run(spec_set: :basic_wcp, user_count: 3)
      IO.inspect(result.summary)

  ## Options

  | Key             | Default              | Description                                   |
  |-----------------|----------------------|-----------------------------------------------|
  | `:spec_set`     | `:basic_wcp`         | `:basic_wcp`, `:wcp_patterns`, `:real_data`, `:all` |
  | `:user_count`   | `3`                  | Number of concurrent simulated users          |
  | `:timeout_ms`   | `30_000`             | Per-user budget (ms). Exceeding → `:timeout`. |
  | `:max_steps`    | `50`                 | Max drain-loop iterations per user.           |
  | `:max_concurrency` | `10`              | Task.async_stream concurrency cap.            |
  | `:lifecycle_mod` | `CaseLifecycle`    | Inject alternative module for unit tests.     |

  ## Armstrong / WvdA compliance

  - No Shared State: each Task has a unique `case_id`; no ETS or global mutation.
  - Let-It-Crash at boundary: `rescue` in `run_one/4` converts exceptions to
    `%UserResult{status: :error}` — the exception is not re-raised.
  - Supervision: `CaseLifecycle` is already supervised; Tasks are transient.
  - Boundedness: `@default_max_steps` + `timeout_ms` guard the drain loop.
  - `cancel_case` is called in an `after` block — cleanup even on error/timeout.
  """

  alias OptimalSystemAgent.Yawl.CaseLifecycle
  alias OptimalSystemAgent.Yawl.SpecLibrary

  # ---------------------------------------------------------------------------
  # Constants (WvdA soundness budgets)
  # ---------------------------------------------------------------------------

  @default_timeout_ms 30_000
  @default_max_steps 50
  @default_max_concurrency 10
  @basic_wcp_ids ["WCP-1", "WCP-2", "WCP-3", "WCP-4", "WCP-5"]

  # ---------------------------------------------------------------------------
  # Structs
  # ---------------------------------------------------------------------------

  defmodule UserResult do
    @moduledoc "Result for a single simulated user."
    @enforce_keys [:user_id, :case_id, :spec_id, :status]
    defstruct [
      :user_id,
      :case_id,
      :spec_id,
      :status,
      :steps_completed,
      :duration_ms,
      :error
    ]

    @type status :: :completed | :error | :timeout

    @type t :: %__MODULE__{
            user_id: pos_integer(),
            case_id: String.t(),
            spec_id: String.t(),
            status: status(),
            steps_completed: non_neg_integer() | nil,
            duration_ms: non_neg_integer() | nil,
            error: term() | nil
          }
  end

  defmodule SimulationResult do
    @moduledoc "Aggregated result for a full simulation run."
    @enforce_keys [:spec_set, :user_count, :results]
    defstruct [
      :spec_set,
      :user_count,
      :results,
      :total_duration_ms,
      :completed_count,
      :error_count,
      :timeout_count,
      :summary
    ]

    @type t :: %__MODULE__{
            spec_set: atom(),
            user_count: non_neg_integer(),
            results: [UserResult.t()],
            total_duration_ms: non_neg_integer() | nil,
            completed_count: non_neg_integer(),
            error_count: non_neg_integer(),
            timeout_count: non_neg_integer(),
            summary: String.t()
          }
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Run a simulation.

  Returns a `%SimulationResult{}`. Never raises — errors are captured per-user
  in `%UserResult{status: :error}` entries.
  """
  @spec run(keyword()) :: SimulationResult.t()
  def run(opts \\ []) do
    spec_set = Keyword.get(opts, :spec_set, :basic_wcp)
    user_count = Keyword.get(opts, :user_count, 3)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    max_concurrency = Keyword.get(opts, :max_concurrency, @default_max_concurrency)

    wall_start = System.monotonic_time(:millisecond)

    specs = load_specs_for(spec_set)

    if specs == [] do
      empty_result(spec_set, user_count, wall_start, "No specs found for spec_set=#{spec_set}")
    else
      assignments = assign_specs(specs, user_count)

      stream_opts = [
        max_concurrency: max_concurrency,
        timeout: timeout_ms + 1_000,
        on_timeout: :kill_task,
        ordered: false
      ]

      results =
        Task.async_stream(
          assignments,
          fn {user_id, spec_id, xml} -> run_one(user_id, spec_id, xml, opts) end,
          stream_opts
        )
        |> Enum.map(fn
          {:ok, %UserResult{} = r} ->
            r

          {:exit, :timeout} ->
            %UserResult{
              user_id: 0,
              case_id: "unknown",
              spec_id: "unknown",
              status: :timeout,
              steps_completed: nil,
              duration_ms: timeout_ms,
              error: :task_stream_timeout
            }

          {:exit, reason} ->
            %UserResult{
              user_id: 0,
              case_id: "unknown",
              spec_id: "unknown",
              status: :error,
              steps_completed: nil,
              duration_ms: nil,
              error: {:task_exit, reason}
            }
        end)

      total_ms = System.monotonic_time(:millisecond) - wall_start
      build_result(spec_set, user_count, results, total_ms)
    end
  end

  # ---------------------------------------------------------------------------
  # Per-user task
  # ---------------------------------------------------------------------------

  @doc false
  def run_one(user_id, spec_id, xml, opts) do
    case_id = "sim-u#{user_id}-#{:erlang.unique_integer([:positive, :monotonic])}"
    start_ms = System.monotonic_time(:millisecond)
    lifecycle = Keyword.get(opts, :lifecycle_mod, CaseLifecycle)

    try do
      case lifecycle.launch_case(xml, case_id, nil) do
        {:ok, _} ->
          drain_loop(lifecycle, case_id, spec_id, user_id, start_ms, opts, 0)

        {:error, reason} ->
          %UserResult{
            user_id: user_id,
            case_id: case_id,
            spec_id: spec_id,
            status: :error,
            steps_completed: 0,
            duration_ms: elapsed_ms(start_ms),
            error: {:launch_failed, reason}
          }
      end
    rescue
      e ->
        %UserResult{
          user_id: user_id,
          case_id: case_id,
          spec_id: spec_id,
          status: :error,
          steps_completed: nil,
          duration_ms: elapsed_ms(start_ms),
          error: {:exception, Exception.message(e)}
        }
    after
      lifecycle.cancel_case(case_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Drain loop (WvdA bounded)
  # ---------------------------------------------------------------------------

  defp drain_loop(lifecycle, case_id, spec_id, user_id, start_ms, opts, steps) do
    max_steps = Keyword.get(opts, :max_steps, @default_max_steps)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    now_ms = elapsed_ms(start_ms)

    cond do
      steps >= max_steps ->
        %UserResult{
          user_id: user_id,
          case_id: case_id,
          spec_id: spec_id,
          status: :error,
          steps_completed: steps,
          duration_ms: now_ms,
          error: :max_steps_exceeded
        }

      now_ms >= timeout_ms ->
        %UserResult{
          user_id: user_id,
          case_id: case_id,
          spec_id: spec_id,
          status: :timeout,
          steps_completed: steps,
          duration_ms: now_ms,
          error: :timeout
        }

      true ->
        case lifecycle.list_workitems(case_id) do
          {:ok, []} ->
            # No active work items — case completed normally
            %UserResult{
              user_id: user_id,
              case_id: case_id,
              spec_id: spec_id,
              status: :completed,
              steps_completed: steps,
              duration_ms: elapsed_ms(start_ms),
              error: nil
            }

          {:error, :not_found} ->
            # Case removed from YAWL registry after auto-completion (e.g. WCP-4 XOR)
            %UserResult{
              user_id: user_id,
              case_id: case_id,
              spec_id: spec_id,
              status: :completed,
              steps_completed: steps,
              duration_ms: elapsed_ms(start_ms),
              error: nil
            }

          {:error, reason} ->
            %UserResult{
              user_id: user_id,
              case_id: case_id,
              spec_id: spec_id,
              status: :error,
              steps_completed: steps,
              duration_ms: elapsed_ms(start_ms),
              error: {:list_workitems_failed, reason}
            }

          {:ok, items} when is_list(items) ->
            new_steps = execute_batch(lifecycle, case_id, items, steps)
            drain_loop(lifecycle, case_id, spec_id, user_id, start_ms, opts, new_steps)
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Batch execution (handles AND-splits)
  # ---------------------------------------------------------------------------

  defp execute_batch(lifecycle, case_id, items, steps) do
    enabled = Enum.filter(items, fn item -> item["status"] == "Enabled" end)

    Enum.reduce(enabled, steps, fn item, acc_steps ->
      wid = item["id"]

      case lifecycle.start_workitem(case_id, wid) do
        {:ok, started} ->
          child_id = started["id"]

          case lifecycle.complete_workitem(case_id, child_id, "<data/>") do
            {:ok, _} -> acc_steps + 1
            # Count error as a step so max_steps still bounds
            {:error, _} -> acc_steps + 1
          end

        {:error, _} ->
          acc_steps + 1
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Spec loading
  # ---------------------------------------------------------------------------

  @doc false
  def load_specs_for(:basic_wcp) do
    @basic_wcp_ids
    |> Enum.flat_map(fn id ->
      case SpecLibrary.load_spec(id) do
        {:ok, xml} -> [{id, xml}]
        {:error, _} -> []
      end
    end)
  end

  def load_specs_for(:wcp_patterns) do
    SpecLibrary.list_patterns()
    |> Enum.flat_map(fn %{id: id} ->
      case SpecLibrary.load_spec(id) do
        {:ok, xml} -> [{id, xml}]
        {:error, _} -> []
      end
    end)
  end

  def load_specs_for(:real_data) do
    SpecLibrary.list_real_data()
    |> Enum.flat_map(fn %{name: name} ->
      case SpecLibrary.load_real_data(name) do
        {:ok, xml} -> [{name, xml}]
        {:error, _} -> []
      end
    end)
  end

  def load_specs_for(:all) do
    load_specs_for(:wcp_patterns) ++ load_specs_for(:real_data)
  end

  def load_specs_for(unknown) do
    require Logger
    Logger.warning("Simulator.load_specs_for/1 — unknown spec_set: #{inspect(unknown)}")
    []
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Round-robin assign specs to users: [{user_id, spec_id, xml}, ...]
  defp assign_specs(specs, user_count) do
    spec_count = length(specs)

    Enum.map(1..user_count, fn user_id ->
      {spec_id, xml} = Enum.at(specs, rem(user_id - 1, spec_count))
      {user_id, spec_id, xml}
    end)
  end

  defp elapsed_ms(start_ms), do: System.monotonic_time(:millisecond) - start_ms

  defp build_result(spec_set, user_count, results, total_ms) do
    completed = Enum.count(results, &(&1.status == :completed))
    errors = Enum.count(results, &(&1.status == :error))
    timeouts = Enum.count(results, &(&1.status == :timeout))
    actual_count = length(results)

    summary =
      "spec_set=#{spec_set} users=#{actual_count} " <>
        "completed=#{completed} errors=#{errors} timeouts=#{timeouts} " <>
        "total_ms=#{total_ms}"

    %SimulationResult{
      spec_set: spec_set,
      user_count: user_count,
      results: results,
      total_duration_ms: total_ms,
      completed_count: completed,
      error_count: errors,
      timeout_count: timeouts,
      summary: summary
    }
  end

  defp empty_result(spec_set, user_count, wall_start, reason) do
    total_ms = System.monotonic_time(:millisecond) - wall_start

    %SimulationResult{
      spec_set: spec_set,
      user_count: user_count,
      results: [],
      total_duration_ms: total_ms,
      completed_count: 0,
      error_count: 0,
      timeout_count: 0,
      summary: "No specs loaded — #{reason}"
    }
  end
end
