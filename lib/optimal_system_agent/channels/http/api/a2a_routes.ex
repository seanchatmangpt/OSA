defmodule OptimalSystemAgent.Channels.HTTP.API.A2ARoutes do
  @moduledoc """
  A2A (Agent-to-Agent) protocol routes.

  Exposes OSA as an A2A-compliant agent endpoint, enabling other systems
  (Canopy, BusinessOS, external agents) to discover and communicate with
  OSA agents via the A2A protocol.

  Endpoints:
    GET  /a2a/agent-card          -- Return OSA's A2A agent card
    POST /a2a                    -- A2A JSON-RPC endpoint (task creation)
    GET  /a2a/agents             -- List discoverable agents
    GET  /a2a/tools              -- List tools available via A2A
    POST /a2a/tools/:name        -- Execute a tool via A2A
    GET  /a2a/servers            -- List connected MCP servers
    GET  /a2a/stream/:task_id    -- SSE stream for a specific task
    GET  /a2a/stream             -- SSE stream for all A2A tasks
  """
  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Tools.Registry, as: Tools
  alias OptimalSystemAgent.A2A.TaskStream

  plug :match
  plug :dispatch

  # ── GET /agent-card ──────────────────────────────────────────────

  get "/agent-card" do
    card = build_agent_card()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(card))
  end

  # ── POST / ──────────────────────────────────────────────────────
  # A2A JSON-RPC endpoint for task creation and management.

  post "/" do
    case conn.body_params do
      %{"jsonrpc" => "2.0", "method" => method, "id" => id} = req ->
        handle_json_rpc(conn, method, id, Map.get(req, "params", %{}))

      %{"message" => message} ->
        handle_task(conn, message)

      _ ->
        json_error(conn, 400, "invalid_request", "Expected A2A JSON-RPC or task request")
    end
  end

  # ── GET /agents ──────────────────────────────────────────────────

  get "/agents" do
    agents = list_a2a_agents()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{agents: agents}))
  end

  # ── GET /tools ───────────────────────────────────────────────────

  get "/tools" do
    tools =
      Tools.list_tools_direct()
      |> Enum.map(fn tool ->
        %{
          name: tool.name,
          description: tool.description,
          input_schema: tool.parameters
        }
      end)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{tools: tools}))
  end

  # ── POST /tools/:name ────────────────────────────────────────────

  post "/tools/:name" do
    tool_name = conn.path_params["name"]
    arguments = conn.body_params

    case Tools.execute(tool_name, arguments) do
      {:ok, result} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{status: "success", result: result}))

      {:error, reason} ->
        json_error(conn, 422, "tool_error", "Tool #{tool_name} failed: #{inspect(reason)}")
    end
  end

  # ── GET /servers ─────────────────────────────────────────────────

  get "/servers" do
    servers = list_mcp_servers()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{servers: servers}))
  end

  # ── GET /stream/:task_id ─────────────────────────────────────────
  # SSE endpoint for streaming updates of a specific A2A task.

  get "/stream/:task_id" do
    task_id = conn.path_params["task_id"]
    TaskStream.stream(conn, task_id)
  end

  # ── GET /stream ──────────────────────────────────────────────────
  # SSE endpoint for streaming updates of all A2A tasks.

  get "/stream" do
    TaskStream.stream_all(conn)
  end

  # ── Catch-all ────────────────────────────────────────────────────

  match _ do
    json_error(conn, 404, "not_found", "A2A endpoint not found")
  end

  # ── Private: Agent Card ──────────────────────────────────────────

  defp build_agent_card do
    %{
      name: "osa-agent",
      display_name: "OSA Agent",
      description:
        "Optimal System Architecture agent with ReAct loop, tool execution, " <>
          "multi-agent orchestration, and MCP tool integration.",
      version: Application.spec(:optimal_system_agent, :vsn) |> to_string(),
      url: a2a_base_url(),
      capabilities: ["streaming", "tools", "stateless"],
      input_schema: %{
        type: "object",
        properties: %{
          message: %{type: "string", description: "User message to process"}
        },
        required: ["message"]
      }
    }
  end

  defp a2a_base_url do
    port = Application.get_env(:optimal_system_agent, :http_port, 8089)
    "http://localhost:#{port}/api/v1/a2a"
  end

  # ── Private: JSON-RPC Handler ────────────────────────────────────

  defp handle_json_rpc(conn, "agent/card", id, _params) do
    card = build_agent_card()

    response = %{
      jsonrpc: "2.0",
      id: id,
      result: card
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  defp handle_json_rpc(conn, "task/create", id, params) do
    message = params["message"] || params["input"]["message"]

    case process_a2a_task(message, params) do
      {:ok, result} ->
        response = %{
          jsonrpc: "2.0",
          id: id,
          result: %{
            status: "completed",
            output: result
          }
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(response))

      {:error, reason} ->
        response = %{
          jsonrpc: "2.0",
          id: id,
          error: %{code: -32000, message: to_string(reason)}
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(response))
    end
  end

  defp handle_json_rpc(conn, "tools/list", id, _params) do
    tools =
      Tools.list_tools_direct()
      |> Enum.map(fn tool ->
        %{
          name: tool.name,
          description: tool.description,
          input_schema: tool.parameters
        }
      end)

    response = %{
      jsonrpc: "2.0",
      id: id,
      result: %{tools: tools}
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  defp handle_json_rpc(conn, "tools/call", id, params) do
    tool_name = params["name"]
    arguments = params["arguments"] || %{}

    case Tools.execute(tool_name, arguments) do
      {:ok, result} ->
        response = %{
          jsonrpc: "2.0",
          id: id,
          result: %{content: [%{type: "text", text: inspect(result)}]}
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(response))

      {:error, reason} ->
        response = %{
          jsonrpc: "2.0",
          id: id,
          error: %{code: -32001, message: "Tool error: #{inspect(reason)}"}
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(response))
    end
  end

  defp handle_json_rpc(conn, method, id, _params) do
    response = %{
      jsonrpc: "2.0",
      id: id,
      error: %{code: -32601, message: "Method not found: #{method}"}
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(response))
  end

  # ── Private: Task Handler ────────────────────────────────────────

  defp handle_task(conn, message) do
    case process_a2a_task(message, %{}) do
      {:ok, result} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{status: "completed", output: result}))

      {:error, reason} ->
        json_error(conn, 500, "task_error", "Task failed: #{inspect(reason)}")
    end
  end

  defp process_a2a_task(message, params) when is_binary(message) do
    session_id = "a2a_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
    task_id = session_id
    user_id = params["user_id"] || "a2a"
    start_time = System.monotonic_time(:microsecond)

    # Publish initial task state
    TaskStream.publish(task_id, "created", %{message: message, user_id: user_id})

    case OptimalSystemAgent.Agent.Loop.start_link(
           session_id: session_id,
           user_id: user_id,
           channel: :a2a,
           permission_tier: :read_only
         ) do
      {:ok, _pid} ->
        TaskStream.publish(task_id, "running", %{})

        result =
          OptimalSystemAgent.Agent.Loop.process_message(
            session_id,
            message,
            timeout: 60_000
          )

        duration = System.monotonic_time(:microsecond) - start_time

        case result do
          {:ok, output} ->
            TaskStream.publish(task_id, "completed", %{output: output})

            :telemetry.execute(
              [:osa, :a2a, :agent_call],
              %{duration: duration},
              %{task_id: task_id, status: :ok, channel: :a2a}
            )

            {:ok, output}

          {:error, reason} ->
            TaskStream.publish(task_id, "failed", %{reason: inspect(reason)})

            :telemetry.execute(
              [:osa, :a2a, :agent_call],
              %{duration: duration},
              %{task_id: task_id, status: :error, reason: inspect(reason), channel: :a2a}
            )

            {:error, reason}
        end

      {:error, reason} ->
        TaskStream.publish(task_id, "failed", %{reason: inspect(reason)})

        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:osa, :a2a, :agent_call],
          %{duration: duration},
          %{task_id: task_id, status: :error, reason: inspect(reason), channel: :a2a}
        )

        {:error, {:agent_start_failed, reason}}
    end
  end

  defp process_a2a_task(_, _), do: {:error, :invalid_message}

  # ── Private: Agent Listing ──────────────────────────────────────

  defp list_a2a_agents do
    base_url = a2a_base_url()

    [
      %{
        name: "osa-main",
        display_name: "OSA Main Agent",
        url: base_url,
        capabilities: ["streaming", "tools", "stateless"]
      }
    ]
  end

  # ── Private: MCP Server Listing ─────────────────────────────────

  defp list_mcp_servers do
    case Process.whereis(OptimalSystemAgent.MCP.Client) do
      nil -> []
      _pid -> OptimalSystemAgent.MCP.Client.list_servers()
    end
  end
end
