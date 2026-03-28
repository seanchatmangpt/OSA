defmodule OptimalSystemAgent.MCP.Native.Router do
  @moduledoc """
  Plug.Router for the native MCP HTTP+SSE server.

  Implements MCP 2024-11-05 HTTP transport:

  `GET /mcp`
    Opens an SSE stream. Sends the first SSE event to tell the client
    which endpoint to POST to:
      event: endpoint
      data: /mcp?session=SESSION_ID

  `POST /mcp`
    Accepts JSON-RPC 2.0 requests. Session ID is read from the
    `Mcp-Session-Id` header (or `session` query param).
    Dispatches to `RequestHandler` and returns the JSON-RPC response.

  Claude Desktop config:
    { "mcpServers": { "osa": { "url": "http://localhost:8089/mcp" } } }
  """
  use Plug.Router
  require Logger

  alias OptimalSystemAgent.MCP.Native.SessionManager
  alias OptimalSystemAgent.MCP.Native.RequestHandler

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  # ── GET /mcp — SSE session establishment ──────────────────────────────

  get "/" do
    case SessionManager.create_session() do
      {:ok, session_id} ->
        # Register this SSE connection's pid in the session
        SessionManager.put_session(session_id, %{sse_pid: self()})

        conn =
          conn
          |> put_resp_header("content-type", "text/event-stream")
          |> put_resp_header("cache-control", "no-cache")
          |> put_resp_header("x-accel-buffering", "no")
          |> send_chunked(200)

        # Send the endpoint event as required by MCP HTTP+SSE spec
        endpoint_event = "event: endpoint\ndata: /mcp?session=#{session_id}\n\n"
        {:ok, conn} = chunk(conn, endpoint_event)

        # Keep alive until the session is cleaned up or client disconnects
        sse_loop(conn, session_id)

      {:error, :max_sessions} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{error: "mcp_session_limit_reached"}))
    end
  end

  # ── POST /mcp — JSON-RPC dispatch ────────────────────────────────────

  post "/" do
    conn = Plug.Conn.fetch_query_params(conn)
    session_id = get_session_id(conn)

    if is_nil(session_id) || is_nil(SessionManager.get_session(session_id)) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        400,
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: nil,
          error: %{code: -32_600, message: "Missing or invalid Mcp-Session-Id"}
        })
      )
    else
      response = RequestHandler.handle(conn.body_params)

      if is_nil(response) do
        # Notification — return 202 Accepted with no body
        send_resp(conn, 202, "")
      else
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(response))
      end
    end
  end

  # ── Catch-all ─────────────────────────────────────────────────────────

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "mcp_endpoint_not_found"}))
  end

  # ── Private helpers ───────────────────────────────────────────────────

  defp get_session_id(conn) do
    # Prefer header, fall back to query param
    case get_req_header(conn, "mcp-session-id") do
      [id | _] when is_binary(id) and id != "" -> id
      _ -> conn.query_params["session"]
    end
  end

  defp sse_loop(conn, session_id) do
    # Send a keepalive comment every 30 seconds to prevent proxy timeouts
    receive do
      :close ->
        SessionManager.delete_session(session_id)
        conn

    after
      30_000 ->
        case chunk(conn, ": keepalive\n\n") do
          {:ok, conn} ->
            sse_loop(conn, session_id)

          {:error, _reason} ->
            SessionManager.delete_session(session_id)
            conn
        end
    end
  end
end
