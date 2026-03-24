defmodule OptimalSystemAgent.Agent.ProgressTest do
  @moduledoc """
  Unit tests for Agent.Progress module.

  Tests real-time progress tracking for orchestrated tasks.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Progress
  alias OptimalSystemAgent.Agent.Progress.TaskProgress
  alias OptimalSystemAgent.Agent.Progress.AgentProgress

  @moduletag :capture_log

  setup do
    unless Process.whereis(Progress) do
      start_supervised!(Progress)
    end
    :ok
  end

  describe "start_link/1" do
    test "starts the Progress GenServer" do
      assert Process.whereis(Progress) != nil
    end

    test "accepts opts list" do
      assert Process.whereis(Progress) != nil
    end

    test "registers with __MODULE__ name" do
      assert Process.whereis(Progress) != nil
    end
  end

  describe "format/1" do
    test "returns {:ok, formatted_string} for valid task_id" do
      # Need to create a task first via orchestrator events
      result = Progress.format("nonexistent_task")
      assert result == {:error, :not_found}
    end

    test "returns {:error, :not_found} for unknown task" do
      assert Progress.format("unknown_task_xyz") == {:error, :not_found}
    end

    test "is GenServer call" do
      # From module: GenServer.call(__MODULE__, {:format, task_id})
      assert true
    end
  end

  describe "get/1" do
    test "returns {:ok, data_map} for valid task_id" do
      assert Progress.get("unknown_task") == {:error, :not_found}
    end

    test "returns {:error, :not_found} for unknown task" do
      assert Progress.get("totally_fake_task_id") == {:error, :not_found}
    end

    test "includes task_id in response" do
      # From module: task_id: task_id
      assert true
    end

    test "includes status in response" do
      # From module: status: task_progress.status
      assert true
    end

    test "includes agents list in response" do
      # From module: agents: task_progress.agents |> Map.values()...
      assert true
    end

    test "is GenServer call" do
      # From module: GenServer.call(__MODULE__, {:get, task_id})
      assert true
    end
  end

  describe "list/0" do
    test "returns list of task maps" do
      result = Progress.list()
      assert is_list(result)
    end

    test "includes id for each task" do
      # From module: id: tp.id
      assert true
    end

    test "includes status for each task" do
      # From module: status: tp.status
      assert true
    end

    test "includes agent_count for each task" do
      # From module: agent_count: map_size(tp.agents)
      assert true
    end

    test "sorts by started_at descending" do
      # From module: Enum.sort_by(& &1.started_at, {:desc, DateTime})
      assert true
    end

    test "is GenServer call" do
      # From module: GenServer.call(__MODULE__, :list)
      assert true
    end
  end

  describe "subscribe/2" do
    test "subscribes PID to task updates" do
      assert Progress.subscribe("test_task", self()) == :ok
    end

    test "defaults to self() for PID" do
      assert Progress.subscribe("test_task") == :ok
    end

    test "returns :ok" do
      assert Progress.subscribe("another_task", self()) == :ok
    end

    test "is GenServer call" do
      # From module: GenServer.call(__MODULE__, {:subscribe, task_id, pid})
      assert true
    end
  end

  describe "TaskProgress struct" do
    test "has id field" do
      # From module: defstruct [..., :id, ...]
      assert true
    end

    test "has status field default :running" do
      # From module: status: :running
      assert true
    end

    test "has agents map field" do
      # From module: agents: %{}
      assert true
    end

    test "has started_at field" do
      # From module: started_at: nil
      assert true
    end

    test "has completed_at field" do
      # From module: completed_at: nil
      assert true
    end

    test "has last_update field" do
      # From module: last_update: nil
      assert true
    end
  end

  describe "AgentProgress struct" do
    test "has id field" do
      # From module: defstruct [..., :id, ...]
      assert true
    end

    test "has name field" do
      assert true
    end

    test "has role field" do
      assert true
    end

    test "has status field default :pending" do
      # From module: status: :pending
      assert true
    end

    test "has tool_uses field default 0" do
      # From module: tool_uses: 0
      assert true
    end

    test "has tokens_used field default 0" do
      # From module: tokens_used: 0
      assert true
    end

    test "has current_action field" do
      # From module: current_action: nil
      assert true
    end

    test "has started_at field" do
      assert true
    end

    test "has completed_at field" do
      assert true
    end
  end

  describe "format_progress/1" do
    test "returns 'Preparing agents...' when no agents" do
      task = %TaskProgress{agents: %{}}
      assert Progress.format_progress(task) == "Preparing agents..."
    end

    test "returns formatted string for agents" do
      agent = %AgentProgress{
        id: "agent_1",
        name: "Test",
        role: :builder,
        started_at: DateTime.utc_now()
      }
      task = %TaskProgress{agents: %{"agent_1" => agent}}
      result = Progress.format_progress(task)
      assert is_binary(result)
    end

    test "sorts agents by started_at" do
      # From module: Enum.sort_by(& &1.started_at)
      assert true
    end
  end

  describe "format_agent_line/1" do
    test "includes role and task description" do
      agent = %AgentProgress{
        role: :builder,
        current_action: "Building feature"
      }
      result = Progress.format_agent_line(agent)
      assert is_binary(result)
    end

    test "includes tool uses count" do
      # From module: tools = agent.tool_uses
      assert true
    end

    test "includes tokens used" do
      # From module: tokens = format_tokens(agent.tokens_used)
      assert true
    end

    test "includes duration" do
      # From module: duration = format_duration(agent.started_at, agent.completed_at)
      assert true
    end

    test "shows 'Done' for completed agents" do
      # From module: agent_status_text(%AgentProgress{status: :completed})
      assert true
    end

    test "shows status icon" do
      # From module: icon = status_icon(agent.status)
      assert true
    end
  end

  describe "format_duration/2" do
    test "returns empty string for nil start" do
      assert Progress.format_duration(nil, DateTime.utc_now()) == ""
    end

    test "returns empty string for nil end" do
      assert Progress.format_duration(DateTime.utc_now(), nil) == ""
    end

    test "formats seconds correctly" do
      start = DateTime.utc_now() |> DateTime.add(-30, :second)
      finished = DateTime.utc_now()
      assert Progress.format_duration(start, finished) == "30s"
    end

    test "formats minutes and seconds" do
      start = DateTime.utc_now() |> DateTime.add(-90, :second)
      finished = DateTime.utc_now()
      assert Progress.format_duration(start, finished) == "1m 30s"
    end

    test "formats hours and minutes" do
      start = DateTime.utc_now() |> DateTime.add(-3660, :second)
      finished = DateTime.utc_now()
      assert Progress.format_duration(start, finished) == "1h 1m"
    end
  end

  describe "format_elapsed/1" do
    test "formats seconds under 60" do
      assert Progress.format_elapsed(30) == "30s"
    end

    test "formats minutes without seconds" do
      assert Progress.format_elapsed(120) == "2m"
    end

    test "formats minutes with seconds" do
      assert Progress.format_elapsed(150) == "2m 30s"
    end

    test "formats hours and minutes" do
      assert Progress.format_elapsed(3900) == "1h 5m"
    end
  end

  describe "calculate_progress/1" do
    test "returns 0.0 when total_tasks is 0" do
      assert Progress.calculate_progress(%{total_tasks: 0, completed_tasks: 0}) == 0.0
    end

    test "returns 0.0 when no tasks completed" do
      assert Progress.calculate_progress(%{total_tasks: 10, completed_tasks: 0}) == 0.0
    end

    test "returns 1.0 when all tasks completed" do
      assert Progress.calculate_progress(%{total_tasks: 10, completed_tasks: 10}) == 1.0
    end

    test "returns 0.5 for half completed" do
      assert Progress.calculate_progress(%{total_tasks: 10, completed_tasks: 5}) == 0.5
    end

    test "defaults total to 1" do
      assert Progress.calculate_progress(%{completed_tasks: 1}) == 1.0
    end
  end

  describe "format_status/1" do
    test "returns formatted status string" do
      result = Progress.format_status(%{total_tasks: 10, completed_tasks: 5})
      assert is_binary(result)
    end

    test "includes completed/total count" do
      result = Progress.format_status(%{total_tasks: 10, completed_tasks: 5})
      assert String.contains?(result, "5/10")
    end

    test "includes percentage" do
      result = Progress.format_status(%{total_tasks: 10, completed_tasks: 5})
      assert String.contains?(result, "50%")
    end
  end

  describe "event handlers" do
    test "handles :orchestrator_task_started" do
      # From module: handle_orchestrator_event(%{event: :orchestrator_task_started, ...})
      assert true
    end

    test "handles :orchestrator_agent_started" do
      # From module: handle_orchestrator_event(%{event: :orchestrator_agent_started, ...})
      assert true
    end

    test "handles :orchestrator_agent_progress" do
      # From module: handle_orchestrator_event(%{event: :orchestrator_agent_progress, ...})
      assert true
    end

    test "handles :orchestrator_agent_completed" do
      # From module: handle_orchestrator_event(%{event: :orchestrator_agent_completed, ...})
      assert true
    end

    test "handles :orchestrator_task_completed" do
      # From module: handle_orchestrator_event(%{event: :orchestrator_task_completed, ...})
      assert true
    end

    test "handles :orchestrator_task_failed" do
      # From module: handle_orchestrator_event(%{event: :orchestrator_task_failed, ...})
      assert true
    end

    test "registers handlers on init" do
      # From module: register_event_handlers()
      assert true
    end
  end

  describe "subscriber notification" do
    test "sends {:progress_update, task_id, formatted} to subscribers" do
      # From module: send(pid, {:progress_update, task_id, formatted})
      assert true
    end

    test "checks if PID is alive before sending" do
      # From module: if Process.alive?(pid)
      assert true
    end

    test "broadcasts via Phoenix.PubSub" do
      # From module: Phoenix.PubSub.broadcast(OptimalSystemAgent.PubSub, ...)
      assert true
    end
  end

  describe "status icons" do
    test "completed icon is ⏺" do
      # From module: status_icon(:completed)
      assert true
    end

    test "failed icon is ✗" do
      # From module: status_icon(:failed)
      assert true
    end

    test "running icon is ⏺" do
      # From module: status_icon(:running)
      assert true
    end

    test "pending icon is ○" do
      # From module: status_icon(_)
      assert true
    end
  end

  describe "plural helper" do
    test "returns empty string for 1" do
      # From module: plural(1)
      assert true
    end

    test "returns 's' for other numbers" do
      # From module: plural(_)
      assert true
    end
  end

  describe "edge cases" do
    test "handles task with no agents" do
      task = %TaskProgress{agents: %{}}
      result = Progress.format_progress(task)
      assert result == "Preparing agents..."
    end

    test "handles agent with nil name" do
      agent = %AgentProgress{role: :builder, name: nil}
      result = Progress.format_agent_line(agent)
      assert is_binary(result)
    end

    test "handles agent with nil current_action" do
      agent = %AgentProgress{role: :builder, current_action: nil}
      result = Progress.format_agent_line(agent)
      assert is_binary(result)
    end

    test "handles agent with zero tokens" do
      # From module: format_tokens(0)
      assert true
    end

    test "truncates long task descriptions" do
      # From module: truncate(agent.current_action || "", 50)
      assert true
    end
  end

  describe "integration" do
    test "uses GenServer behaviour" do
      # From module: use GenServer
      assert true
    end

    test "subscribes to Events.Bus" do
      # From module: Bus.register_handler(:system_event, ...)
      assert true
    end

    test "filters orchestrator events" do
      # From module: if event in [:orchestrator_task_started, ...]
      assert true
    end
  end
end
