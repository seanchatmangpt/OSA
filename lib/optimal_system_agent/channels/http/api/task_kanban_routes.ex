defmodule OptimalSystemAgent.Channels.HTTP.API.TaskKanbanRoutes do
  @moduledoc """
  Kanban-specific task operations against the task_queue table.
  Forwarded from /tasks/kanban in the main API router.
  """
  use Plug.Router
  import Ecto.Query
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Store.Repo

  plug :match
  plug :dispatch

  @valid_statuses ~w(backlog todo in_progress in_review done blocked cancelled)

  post "/:id/checkout" do
    with {:ok, task_id} <- parse_id(id),
         %{"agent_name" => agent_name} when is_binary(agent_name) and agent_name != "" <-
           conn.body_params do
      {count, _} =
        Repo.update_all(
          from(t in "task_queue",
            where: t.id == ^task_id and t.status == "todo" and is_nil(t.checkout_lock)
          ),
          set: [
            assignee_agent: agent_name,
            status: "in_progress",
            checkout_lock: DateTime.utc_now()
          ]
        )

      case count do
        0 -> json_error(conn, 409, "already_assigned", "Task is not available for checkout")
        _ -> json(conn, 200, %{checked_out: true})
      end
    else
      {:error, :bad_id} -> json_error(conn, 400, "invalid_request", "Invalid task ID")
      _ -> json_error(conn, 400, "invalid_request", "Missing required field: agent_name")
    end
  end

  post "/:id/release" do
    with {:ok, task_id} <- parse_id(id) do
      {count, _} =
        Repo.update_all(
          from(t in "task_queue", where: t.id == ^task_id),
          set: [checkout_lock: nil, status: "todo", assignee_agent: nil]
        )

      case count do
        0 -> json_error(conn, 404, "not_found", "Task not found")
        _ -> json(conn, 200, %{released: true})
      end
    else
      {:error, :bad_id} -> json_error(conn, 400, "invalid_request", "Invalid task ID")
    end
  end

  put "/:id/status" do
    with {:ok, task_id} <- parse_id(id),
         %{"status" => status} when is_binary(status) <- conn.body_params,
         true <- status in @valid_statuses do
      {count, _} =
        Repo.update_all(
          from(t in "task_queue", where: t.id == ^task_id),
          set: [status: status]
        )

      case count do
        0 -> json_error(conn, 404, "not_found", "Task not found")
        _ -> json(conn, 200, %{status: status})
      end
    else
      {:error, :bad_id} -> json_error(conn, 400, "invalid_request", "Invalid task ID")
      false -> json_error(conn, 400, "invalid_status", "Status must be one of: #{Enum.join(@valid_statuses, ", ")}")
      _ -> json_error(conn, 400, "invalid_request", "Missing required field: status")
    end
  end

  put "/:id/priority" do
    valid = ~w(low medium high critical)

    with {:ok, task_id} <- parse_id(id),
         %{"priority" => priority} when is_binary(priority) <- conn.body_params,
         true <- priority in valid do
      {count, _} =
        Repo.update_all(
          from(t in "task_queue", where: t.id == ^task_id),
          set: [priority: priority]
        )

      case count do
        0 -> json_error(conn, 404, "not_found", "Task not found")
        _ -> json(conn, 200, %{priority: priority})
      end
    else
      {:error, :bad_id} -> json_error(conn, 400, "invalid_request", "Invalid task ID")
      false -> json_error(conn, 400, "invalid_priority", "Priority must be one of: low, medium, high, critical")
      _ -> json_error(conn, 400, "invalid_request", "Missing required field: priority")
    end
  end

  put "/:id/assign" do
    with {:ok, task_id} <- parse_id(id),
         %{"agent_name" => agent_name} when is_binary(agent_name) and agent_name != "" <-
           conn.body_params do
      {count, _} =
        Repo.update_all(
          from(t in "task_queue", where: t.id == ^task_id),
          set: [assignee_agent: agent_name]
        )

      case count do
        0 -> json_error(conn, 404, "not_found", "Task not found")
        _ -> json(conn, 200, %{assigned_to: agent_name})
      end
    else
      {:error, :bad_id} -> json_error(conn, 400, "invalid_request", "Invalid task ID")
      _ -> json_error(conn, 400, "invalid_request", "Missing required field: agent_name")
    end
  end

  match _ do
    json_error(conn, 404, "not_found", "Endpoint not found")
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> {:ok, n}
      _ -> {:error, :bad_id}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}
end
