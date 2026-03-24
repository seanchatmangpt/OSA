defmodule OptimalSystemAgent.MCP.Server do
  @moduledoc """
  Per-MCP-server GenServer handling JSON-RPC 2.0 communication.

  Supports two transports:
  - **stdio**: spawns a subprocess and communicates via stdin/stdout
  - **http**: connects to an HTTP-based MCP server via Req

  On init, sends the "initialize" handshake followed by "tools/list"
  to discover available tools. Stores discovered tools in state.

  ## Reconnection

  Detects disconnected state (port closed, HTTP 503) and auto-reconnects
  with exponential backoff (1s, 2s, 4s). After reconnection, tools are
  re-discovered and a Bus event is emitted to notify subscribers.

  Registered in `OptimalSystemAgent.MCP.Registry` under the server name.
  """

  use GenServer
  require Logger

  @default_timeout 30_000
  @default_name "osa-mcp-client"
  @max_reconnect_attempts 3

  defstruct [
    :name,
    :transport,
    :port,
    :url,
    :headers,
    :request_id,
    :tools,
    :server_capabilities,
    :server_info,
    :command,
    :args,
    :env,
    reconnect_attempt: 0,
    connected: true
  ]

  # ── Public API ────────────────────────────────────────────────────────

  @doc "Start an MCP server process linked to the caller."
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc "Call a tool on this MCP server."
  @spec call_tool(String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def call_tool(server_name, tool_name, arguments) when is_binary(server_name) do
    GenServer.call(via_tuple(server_name), {:call_tool, tool_name, arguments}, @default_timeout)
  end

  @doc "List tools discovered from this MCP server."
  @spec list_tools(String.t()) :: [map()]
  def list_tools(server_name) when is_binary(server_name) do
    GenServer.call(via_tuple(server_name), :list_tools, @default_timeout)
  end

  @doc "Get the PID for a named MCP server."
  def whereis(server_name) when is_binary(server_name) do
    case Registry.lookup(OptimalSystemAgent.MCP.Registry, server_name) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc "Stop an MCP server process."
  def stop(server_name) when is_binary(server_name) do
    case whereis(server_name) do
      {:ok, pid} -> GenServer.stop(pid, :normal, @default_timeout)
      {:error, :not_found} -> :ok
    end
  end

  @doc "Request a manual reconnect of the MCP server."
  @spec reconnect(String.t()) :: :ok | {:error, term()}
  def reconnect(server_name) when is_binary(server_name) do
    GenServer.call(via_tuple(server_name), :reconnect, @default_timeout)
  catch
    :exit, reason -> {:error, {:server_not_available, reason}}
  end

  @doc "Check if the server is currently connected."
  @spec connected?(String.t()) :: boolean()
  def connected?(server_name) when is_binary(server_name) do
    GenServer.call(via_tuple(server_name), :connected?, 5_000)
  catch
    :exit, _ -> false
  end

  # ── GenServer Callbacks ───────────────────────────────────────────────

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    transport = Keyword.get(opts, :transport, "stdio")
    command = Keyword.get(opts, :command)
    args = Keyword.get(opts, :args, [])
    env = Keyword.get(opts, :env, %{})
    url = Keyword.get(opts, :url)
    headers = Keyword.get(opts, :headers, [])

    state = %__MODULE__{
      name: name,
      transport: transport,
      port: nil,
      url: url,
      headers: headers,
      request_id: 0,
      tools: %{},
      server_capabilities: %{},
      server_info: %{},
      command: command,
      args: args,
      env: env,
      reconnect_attempt: 0,
      connected: false
    }

    case setup_transport(state, transport, command, args, env) do
      {:ok, state} ->
        case initialize_server(state) do
          {:ok, state} ->
            case discover_tools(state) do
              {:ok, state} ->
                Logger.info(
                  "[MCP.Server:#{name}] Connected: #{transport}, #{map_size(state.tools)} tools"
                )

                # Emit telemetry event for successful server start
                :telemetry.execute(
                  [:osa, :mcp, :server_start],
                  %{tools_count: map_size(state.tools)},
                  %{server_name: name, transport: transport, status: :connected}
                )

                {:ok, %{state | connected: true}}

              {:error, reason} ->
                Logger.error("[MCP.Server:#{name}] Tool discovery failed: #{inspect(reason)}")

                # Emit telemetry event for server start with tool discovery failure
                :telemetry.execute(
                  [:osa, :mcp, :server_start],
                  %{tools_count: 0},
                  %{server_name: name, transport: transport, status: :partial, reason: inspect(reason)}
                )

                {:ok, %{state | connected: true}}
            end

          {:error, reason} ->
            Logger.error("[MCP.Server:#{name}] Initialization failed: #{inspect(reason)}")

            # Emit telemetry event for server start with initialization failure
            :telemetry.execute(
              [:osa, :mcp, :server_start],
              %{tools_count: 0},
              %{server_name: name, transport: transport, status: :failed, reason: inspect(reason)}
            )

            {:ok, %{state | connected: false}}
        end

      {:error, reason} ->
        Logger.error("[MCP.Server:#{name}] Transport setup failed: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:call_tool, tool_name, arguments}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result =
      if state.connected do
        do_call_tool(state, tool_name, arguments)
      else
        {:error, :disconnected}
      end

    # Emit telemetry event for tool call
    duration = System.monotonic_time(:microsecond) - start_time

    :telemetry.execute(
      [:osa, :mcp, :tool_call],
      %{duration: duration, cached: false},
      %{
        server: state.name,
        tool: tool_name,
        status: elem(result, 0)
      }
    )

    case result do
      {:error, :port_closed} ->
        # Connection lost -- attempt reconnection
        {:reply, {:error, :reconnecting}, state, {:continue, :reconnect}}

      {:error, %{"code" => -32001}} ->
        # Server error that might indicate connectivity issue
        {:reply, result, state, {:continue, :maybe_reconnect}}

      _ ->
        {:reply, result, state}
    end
  end

  def handle_call(:list_tools, _from, state) do
    tools =
      Enum.map(state.tools, fn {name, info} ->
        %{
          name: name,
          description: Map.get(info, :description, ""),
          input_schema: Map.get(info, :input_schema, %{})
        }
      end)

    {:reply, tools, state}
  end

  def handle_call(:connected?, _from, state) do
    {:reply, state.connected, state}
  end

  def handle_call(:reconnect, _from, state) do
    new_state = do_reconnect(%{state | reconnect_attempt: 0})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_continue(:reconnect, state) do
    new_state = do_reconnect(%{state | reconnect_attempt: 0})
    {:noreply, new_state}
  end

  def handle_continue(:maybe_reconnect, state) do
    new_state = do_reconnect(%{state | reconnect_attempt: 0})
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :port, port, _reason}, %{port: port} = state) do
    Logger.warning("[MCP.Server:#{state.name}] Port process exited, reconnecting...")
    {:noreply, %{state | port: nil, connected: false}, {:continue, :reconnect}}
  end

  def handle_info(msg, state) do
    Logger.debug("[MCP.Server:#{state.name}] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.port do
      Port.close(state.port)
    end

    :ok
  end

  # ── Private: Reconnection ─────────────────────────────────────────────

  defp do_reconnect(state) do
    if state.reconnect_attempt >= @max_reconnect_attempts do
      Logger.error(
        "[MCP.Server:#{state.name}] Reconnection failed after #{@max_reconnect_attempts} attempts"
      )

      # Emit telemetry event for failed reconnection
      :telemetry.execute(
        [:osa, :mcp, :server_reconnect],
        %{tools_count: 0},
        %{server_name: state.name, transport: state.transport, status: :failed, attempts: state.reconnect_attempt}
      )

      emit_bus_event(:mcp_reconnect_failed, state.name, %{attempts: state.reconnect_attempt})

      %{state | connected: false, reconnect_attempt: 0}
    else
      delay = trunc(:math.pow(2, state.reconnect_attempt) * 1000)

      Logger.info(
        "[MCP.Server:#{state.name}] Reconnect attempt #{state.reconnect_attempt + 1}/#{@max_reconnect_attempts} in #{delay}ms"
      )

      Process.sleep(delay)

      # Close old port if it exists
      if state.port do
        try do
          Port.close(state.port)
        catch
          _, _ -> :ok
        end
      end

      case setup_transport(state, state.transport, state.command, state.args, state.env) do
        {:ok, state} ->
          case initialize_server(state) do
            {:ok, state} ->
              case discover_tools(state) do
                {:ok, state} ->
                  Logger.info(
                    "[MCP.Server:#{state.name}] Reconnected: #{map_size(state.tools)} tools discovered"
                  )

                  # Emit telemetry event for successful reconnection
                  :telemetry.execute(
                    [:osa, :mcp, :server_reconnect],
                    %{tools_count: map_size(state.tools)},
                    %{server_name: state.name, transport: state.transport, status: :reconnected}
                  )

                  # Invalidate cached tool results for this server
                  OptimalSystemAgent.MCP.Client.invalidate_server_cache(state.name)

                  emit_bus_event(:mcp_reconnected, state.name, %{
                    tools_count: map_size(state.tools)
                  })

                  # Re-register all MCP tools
                  safe_register_tools()

                  %{state | connected: true, reconnect_attempt: 0}

                {:error, reason} ->
                  Logger.warning(
                    "[MCP.Server:#{state.name}] Reconnect tool discovery failed: #{inspect(reason)}"
                  )

                  schedule_next_reconnect(state)
              end

            {:error, reason} ->
              Logger.warning(
                "[MCP.Server:#{state.name}] Reconnect init failed: #{inspect(reason)}"
              )

              schedule_next_reconnect(state)
          end

        {:error, reason} ->
          Logger.warning(
            "[MCP.Server:#{state.name}] Reconnect transport setup failed: #{inspect(reason)}"
          )

          schedule_next_reconnect(state)
      end
    end
  end

  defp schedule_next_reconnect(state) do
    new_attempt = state.reconnect_attempt + 1

    if new_attempt < @max_reconnect_attempts do
      delay = trunc(:math.pow(2, new_attempt) * 1000)
      Process.send_after(self(), :continue_reconnect, delay)
    end

    %{state | connected: false, reconnect_attempt: new_attempt}
  end

  defp emit_bus_event(event_type, server_name, metadata) do
    try do
      OptimalSystemAgent.Events.Bus.emit(:system_event, %{
        subsystem: :mcp,
        event: event_type,
        server_name: server_name,
        metadata: metadata
      })
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp safe_register_tools do
    try do
      if Process.whereis(OptimalSystemAgent.MCP.Client) do
        OptimalSystemAgent.MCP.Client.register_tools()
      end
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  # ── Private: Transport Setup ──────────────────────────────────────────

  defp setup_transport(state, "stdio", command, args, env) do
    unless is_binary(command) and command != "" do
      {:error, :missing_command}
    else
      env_list =
        env
        |> Enum.map(fn {k, v} -> {to_charlist(k), to_charlist(v)} end)

      cmd = to_charlist(command)
      cmd_args = Enum.map(args, &to_charlist/1)

      # Build port options - minimal for :spawn_executable compatibility
      port_opts = [:binary]

      port_opts =
        if cmd_args != [] do
          [{:args, cmd_args} | port_opts]
        else
          port_opts
        end

      port_opts =
        if env_list != [] do
          [{:env, env_list} | port_opts]
        else
          port_opts
        end

      try do
        port = Port.open({:spawn_executable, cmd}, port_opts)
        # Monitor the port for disconnection detection
        Process.monitor(port)
        # Wait briefly for the process to start
        Process.sleep(100)
        {:ok, %{state | port: port}}
      rescue
        e ->
          {:error, "Failed to spawn stdio process: #{Exception.message(e)}"}
      end
    end
  end

  defp setup_transport(state, "http", _command, _args, _env) do
    url = state.url

    unless is_binary(url) and url != "" do
      {:error, :missing_url}
    else
      {:ok, state}
    end
  end

  defp setup_transport(_state, transport, _command, _args, _env) do
    {:error, {:unsupported_transport, transport}}
  end

  # ── Private: MCP Protocol ─────────────────────────────────────────────

  defp initialize_server(state) do
    request =
      build_request("initialize", %{
        protocolVersion: "2024-11-05",
        capabilities: %{},
        clientInfo: %{name: @default_name, version: "0.1.0"}
      })

    case send_request(state, request) do
      {:ok, %{"result" => result}} ->
        capabilities = Map.get(result, "capabilities", %{})
        server_info = Map.get(result, "serverInfo", %{})

        # Send initialized notification (no id = notification)
        notification = build_notification("notifications/initialized")
        send_notification(state, notification)

        {:ok, %{state | server_capabilities: capabilities, server_info: server_info}}

      {:ok, %{"error" => error}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp discover_tools(state) do
    request = build_request("tools/list", %{})

    case send_request(state, request) do
      {:ok, %{"result" => %{"tools" => raw_tools}}} when is_list(raw_tools) ->
        tools =
          raw_tools
          |> Enum.map(fn tool ->
            name = Map.get(tool, "name", "")

            {name,
             %{
               original_name: name,
               description: Map.get(tool, "description", ""),
               input_schema: Map.get(tool, "inputSchema", %{})
             }}
          end)
          |> Map.new()

        {:ok, %{state | tools: tools}}

      {:ok, %{"result" => %{"tools" => tools}}} when is_map(tools) ->
        # Some servers return tools as a map
        tool_list =
          tools
          |> Enum.map(fn {name, tool} ->
            {to_string(name),
             %{
               original_name: to_string(name),
               description: Map.get(tool, "description", ""),
               input_schema: Map.get(tool, "inputSchema", %{})
             }}
          end)
          |> Map.new()

        {:ok, %{state | tools: tool_list}}

      {:ok, _} ->
        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_call_tool(state, tool_name, arguments) do
    request =
      build_request("tools/call", %{
        name: tool_name,
        arguments: arguments || %{}
      })

    case send_request(state, request) do
      {:ok, %{"result" => result}} ->
        {:ok, result}

      {:ok, %{"error" => error}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Private: JSON-RPC 2.0 Message Building ────────────────────────────

  defp build_request(method, params) do
    %{
      "jsonrpc" => "2.0",
      "id" => next_id(),
      "method" => method,
      "params" => params
    }
  end

  defp build_notification(method, params \\ %{}) do
    %{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    }
  end

  defp next_id do
    :persistent_term.get({OptimalSystemAgent.MCP.Client, :request_id}, 0)
    |> Kernel.+(1)
    |> tap(fn id -> :persistent_term.put({OptimalSystemAgent.MCP.Client, :request_id}, id) end)
  end

  # ── Private: Request Sending ──────────────────────────────────────────

  defp send_request(state, request) do
    case state.transport do
      "stdio" -> send_stdio_request(state, request)
      "http" -> send_http_request(state, request)
    end
  end

  defp send_notification(state, notification) do
    case state.transport do
      "stdio" -> send_stdio_notification(state, notification)
      "http" -> send_http_notification(state, notification)
    end
  end

  # ── Private: Stdio Transport ──────────────────────────────────────────

  defp send_stdio_request(state, request) do
    payload = encode_json(request)

    try do
      Port.command(state.port, payload <> "\n")

      case wait_for_response(state.port, request["id"], 30_000) do
        {:ok, response} -> {:ok, response}
        {:error, :timeout} -> {:error, :timeout}
        {:error, :parse_error, data} -> {:error, {:json_decode, %{data: data, context: "stdio"}}}
        {:error, :port_closed} -> {:error, :port_closed}
      end
    rescue
      e ->
        {:error, {:transport_error, %{message: Exception.message(e), transport: :stdio}}}
    catch
      :exit, _ -> {:error, :port_closed}
    end
  end

  defp send_stdio_notification(state, notification) do
    payload = encode_json(notification)

    try do
      Port.command(state.port, payload <> "\n")
      :ok
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end

  defp wait_for_response(port, request_id, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_response(port, request_id, deadline)
  end

  defp do_wait_for_response(port, request_id, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      {:error, :timeout}
    else
      receive do
        {^port, {:data, data}} ->
          data = IO.iodata_to_binary(data)

          case parse_stdio_response(data, request_id) do
            {:ok, response} ->
              {:ok, response}

            {:ignore, partial} when partial != "" ->
              # Partial line or non-matching message, keep waiting
              do_wait_for_response(port, request_id, deadline)

            :ignore ->
              do_wait_for_response(port, request_id, deadline)
          end

        {^port, {:exit_status, _status}} ->
          {:error, :port_closed}
      after
        remaining ->
          {:error, :timeout}
      end
    end
  end

  defp parse_stdio_response(data, request_id) do
    # Handle newline-delimited JSON: split on newlines and process each line
    lines = String.split(data, "\n", trim: true)

    Enum.reduce_while(lines, {:ignore, ""}, fn line, _acc ->
      line = String.trim(line)

      if line == "" do
        {:cont, {:ignore, ""}}
      else
        case Jason.decode(line) do
          {:ok, %{"id" => ^request_id} = response} ->
            {:halt, {:ok, response}}

          {:ok, _other} ->
            # Different request ID or notification, skip
            {:cont, {:ignore, ""}}

          {:error, _} ->
            {:cont, {:ignore, line}}
        end
      end
    end)
  end

  # ── Private: HTTP Transport ───────────────────────────────────────────

  defp send_http_request(state, request) do
    url = state.url

    headers =
      [{"content-type", "application/json"}] ++
        Enum.map(state.headers, fn {k, v} -> {to_string(k), to_string(v)} end)

    try do
      response =
        Req.post!(url,
          json: request,
          headers: headers,
          receive_timeout: 30_000,
          retry: false
        )

      case response.status do
        503 ->
          Logger.warning("[MCP.Server:#{state.name}] HTTP 503 from #{url}")
          {:error, :service_unavailable}

        status when status >= 500 ->
          {:error, {:http_error, %{status: status, url: url}}}

        _ ->
          decode_http_body(response.body)
      end
    rescue
      e ->
        {:error, {:transport_error, %{message: Exception.message(e), transport: :http}}}
    end
  end

  defp send_http_notification(state, notification) do
    headers =
      [{"content-type", "application/json"}] ++
        Enum.map(state.headers, fn {k, v} -> {to_string(k), to_string(v)} end)

    try do
      Req.post!(state.url,
        json: notification,
        headers: headers,
        receive_timeout: 10_000,
        retry: false
      )

      :ok
    rescue
      _ -> :ok
    end
  end

  # ── Private: JSON Helpers ────────────────────────────────────────────

  defp encode_json(data) do
    case Jason.encode(data) do
      {:ok, encoded} ->
        encoded

      {:error, reason} ->
        raise "JSON encode failed: #{inspect(reason)}"
    end
  end

  defp decode_http_body(nil), do: {:error, :empty_response}

  defp decode_http_body(body) when is_map(body), do: {:ok, body}

  defp decode_http_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, reason} ->
        {:error, {:json_decode, %{detail: inspect(reason), context: "http_response"}}}
    end
  end

  # ── Private: Registry Helpers ─────────────────────────────────────────

  defp via_tuple(name) do
    {:via, Registry, {OptimalSystemAgent.MCP.Registry, name}}
  end
end
