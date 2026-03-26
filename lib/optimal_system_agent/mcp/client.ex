defmodule OptimalSystemAgent.MCP.Client do
  @moduledoc """
  MCP client manager -- reads config, starts MCP server child processes,
  and provides a unified API for tool discovery and invocation.

  Reads server definitions from `~/.osa/mcp.json` (or the path configured
  via `Application.get_env(:optimal_system_agent, :mcp_config_path)`).

  Each server is started as a child of `OptimalSystemAgent.MCP.Supervisor`
  (DynamicSupervisor) and registered in `OptimalSystemAgent.MCP.Registry`.

  Discovered tools are loaded into `:persistent_term` under
  `{OptimalSystemAgent.Tools.Registry, :mcp_tools}` so that the
  existing Tools.Registry direct-execution path can route MCP calls
  without GenServer round-trips.

  ## Tool Caching

  Tool call results are cached with a configurable TTL (default 60s).
  The cache uses `:persistent_term` for fast reads and an ETS table
  for cache metadata (expiry timestamps). Cache is invalidated on
  server reconnect or config reload.

  ## Error Handling

  - JSON decode failures return descriptive `{:error, {:json_decode, detail}}` tuples
  - Tool calls include timeout handling with configurable deadline
  - Connection failures trigger exponential backoff retry (max 3 retries: 1s, 2s, 4s)
  - All errors include structured metadata for observability
  """

  use GenServer
  require Logger

  @default_config_path "~/.osa/mcp.json"
  @max_retries 3
  @default_tool_cache_ttl 60_000

  defstruct [:config_path, :servers]

  # ── Public API ────────────────────────────────────────────────────────

  @doc "Start the MCP client manager."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "List all configured MCP server names."
  @spec list_servers() :: [String.t()]
  def list_servers do
    GenServer.call(__MODULE__, :list_servers)
  end

  @doc "List tools from a specific MCP server."
  @spec list_tools(String.t()) :: [map()] | {:error, String.t()}
  def list_tools(server_name) when is_binary(server_name) do
    GenServer.call(__MODULE__, {:list_tools, server_name})
  end

  @doc "Call a tool on a specific MCP server."
  @spec call_tool(String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def call_tool(server_name, tool_name, arguments) when is_binary(server_name) do
    GenServer.call(__MODULE__, {:call_tool, server_name, tool_name, arguments})
  end

  @doc "Reload servers from config file. Stops removed servers, starts new ones."
  @spec reload_servers() :: :ok
  def reload_servers do
    GenServer.call(__MODULE__, :reload_servers)
  end

  @doc """
  Register all MCP tools into :persistent_term.

  Called by OptimalSystemAgent.Tools.Registry.register_mcp_tools/0.
  Collects tools from all running MCP servers and stores them as:

      {:"mcp_\#{server_name}_\#{tool_name}", %{
        original_name: tool_name,
        description: desc,
        input_schema: schema,
        server_name: server_name
      }}
  """
  @spec register_tools() :: :ok
  def register_tools do
    GenServer.call(__MODULE__, :register_tools)
  end

  @doc """
  Validate a single MCP server config.

  Delegates to `OptimalSystemAgent.MCP.ConfigValidator.validate_config/1`.
  """
  @spec validate_config(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_config(config) do
    OptimalSystemAgent.MCP.ConfigValidator.validate_config(config)
  end

  @doc """
  Validate the full mcp.json config file structure.

  Delegates to `OptimalSystemAgent.MCP.ConfigValidator.validate_config_file/1`.
  """
  @spec validate_config_file(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_config_file(config) do
    OptimalSystemAgent.MCP.ConfigValidator.validate_config_file(config)
  end

  # ── Tool Cache API ───────────────────────────────────────────────────

  @doc """
  Get a cached tool call result, if still valid.

  Returns `{:ok, result}` if a cached result exists and has not expired.
  Returns `:miss` if no cache entry exists or the entry has expired.
  """
  @spec get_cached_tool_result(String.t(), String.t(), map()) ::
          {:ok, map()} | :miss
  def get_cached_tool_result(server_name, tool_name, arguments) do
    cache_key = cache_key(server_name, tool_name, arguments)
    arg_hash = :erlang.phash2(arguments)

    case :ets.lookup(:mcp_tool_cache, {cache_key, arg_hash}) do
      [{{^cache_key, ^arg_hash}, result, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, result}
        else
          :ets.delete(:mcp_tool_cache, {cache_key, arg_hash})
          :miss
        end

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  @doc """
  Store a tool call result in the cache.

  Returns `:ok`.
  """
  @spec put_cached_tool_result(String.t(), String.t(), map(), map()) :: :ok
  def put_cached_tool_result(server_name, tool_name, arguments, result) do
    cache_key = cache_key(server_name, tool_name, arguments)
    arg_hash = :erlang.phash2(arguments)
    ttl = Application.get_env(:optimal_system_agent, :mcp_tool_cache_ttl, @default_tool_cache_ttl)
    expires_at = System.monotonic_time(:millisecond) + ttl

    :ets.insert(:mcp_tool_cache, {{cache_key, arg_hash}, result, expires_at})
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Invalidate all cached tool results for a specific server.

  Called on server reconnect or removal.
  """
  @spec invalidate_server_cache(String.t()) :: :ok
  def invalidate_server_cache(server_name) do
    :ets.match_delete(:mcp_tool_cache, {{{server_name, :_}, :_}, :_, :_})
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Clear the entire tool result cache.

  Called on config reload.
  """
  @spec clear_tool_cache() :: :ok
  def clear_tool_cache do
    :ets.delete_all_objects(:mcp_tool_cache)
  rescue
    ArgumentError -> :ok
  end

  # ── Retry with Exponential Backoff ────────────────────────────────────

  @doc """
  Execute a function with exponential backoff retry.

  Retries up to `max_retries` times with delays of 1s, 2s, 4s.
  Logs each retry with structured metadata.
  """
  @spec with_retry(keyword(), (-> result)) :: result when result: var
  def with_retry(opts \\ [], fun) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @max_retries)
    context = Keyword.get(opts, :context, "mcp")
    retry_with_backoff(fun, context, max_retries, 0)
  end

  defp retry_with_backoff(fun, context, max_retries, attempt) do
    case fun.() do
      {:ok, _} = success ->
        success

      {:error, %{"code" => -32600}} = error ->
        # Invalid request -- do not retry
        error

      {:error, %{"code" => -32601}} = error ->
        # Method not found -- do not retry
        error

      {:error, %{"code" => -32602}} = error ->
        # Invalid params -- do not retry
        error

      {:error, reason} when attempt < max_retries ->
        delay = trunc(:math.pow(2, attempt) * 1000)

        Logger.warning(
          "[MCP.Client] #{context} attempt #{attempt + 1}/#{max_retries + 1} failed: " <>
            "#{inspect(reason)}. Retrying in #{delay}ms",
          metadata: %{
            context: context,
            attempt: attempt + 1,
            max_retries: max_retries + 1,
            delay_ms: delay,
            reason: inspect(reason)
          }
        )

        Process.sleep(delay)
        retry_with_backoff(fun, context, max_retries, attempt + 1)

      {:error, reason} ->
        Logger.error(
          "[MCP.Client] #{context} failed after #{max_retries + 1} attempts: #{inspect(reason)}",
          metadata: %{
            context: context,
            attempts: max_retries + 1,
            reason: inspect(reason)
          }
        )

        {:error, {:max_retries_exceeded, reason}}
    end
  end

  # ── GenServer Callbacks ───────────────────────────────────────────────

  @impl true
  def init(_opts) do
    # Ensure the request ID counter exists in persistent_term
    unless :persistent_term.get({__MODULE__, :request_id}, nil) do
      :persistent_term.put({__MODULE__, :request_id}, 0)
    end

    # Create tool result cache table
    create_tool_cache_table()

    config_path = resolve_config_path()

    state = %__MODULE__{
      config_path: config_path,
      servers: %{}
    }

    case load_and_start_servers(state) do
      {:ok, state} ->
        Logger.info(
          "[MCP.Client] Started with #{map_size(state.servers)} servers from #{config_path}"
        )

        {:ok, state}

      {:error, reason, state} ->
        Logger.warning("[MCP.Client] Init with issues: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl true
  def handle_call(:list_servers, _from, state) do
    server_names = Map.keys(state.servers)
    {:reply, server_names, state}
  end

  def handle_call({:list_tools, server_name}, _from, state) do
    result =
      case Map.get(state.servers, server_name) do
        nil ->
          {:error, "Unknown MCP server: #{server_name}"}

        _pid ->
          try do
            OptimalSystemAgent.MCP.Server.list_tools(server_name)
          rescue
            e ->
              {:error,
               {:server_error,
                %{
                  server: server_name,
                  operation: :list_tools,
                  message: Exception.message(e),
                  kind: :rescue
                }}}
          catch
            :exit, reason ->
              {:error,
               {:server_exited,
                %{
                  server: server_name,
                  operation: :list_tools,
                  reason: inspect(reason),
                  kind: :exit
                }}}
          end
      end

    {:reply, result, state}
  end

  def handle_call({:call_tool, server_name, tool_name, arguments}, _from, state) do
    result =
      case Map.get(state.servers, server_name) do
        nil ->
          {:error, "Unknown MCP server: #{server_name}"}

        _pid ->
          # Check tool cache first
          case get_cached_tool_result(server_name, tool_name, arguments) do
            {:ok, cached} ->
              # Emit telemetry event for cache hit
              :telemetry.execute(
                [:osa, :mcp, :tool_call],
                %{duration: 0, cached: true},
                %{server: server_name, tool: tool_name, status: :ok}
              )

              {:ok, Map.put(cached, :_cached, true)}

            :miss ->
              do_call_with_retry(server_name, tool_name, arguments)
          end
      end

    {:reply, result, state}
  end

  def handle_call(:reload_servers, _from, state) do
    # Stop all existing servers
    stop_all_servers(state)

    # Clear tool cache on reload
    clear_tool_cache()

    # Reload config and start fresh
    case load_and_start_servers(%{state | servers: %{}}) do
      {:ok, new_state} ->
        Logger.info("[MCP.Client] Reloaded: #{map_size(new_state.servers)} servers")
        {:reply, :ok, new_state}

      {:error, reason, new_state} ->
        Logger.warning("[MCP.Client] Reload issues: #{inspect(reason)}")
        {:reply, :ok, new_state}
    end
  end

  def handle_call(:register_tools, _from, state) do
    tools = collect_all_tools(state)
    :persistent_term.put({OptimalSystemAgent.Tools.Registry, :mcp_tools}, tools)
    Logger.info("[MCP.Client] Registered #{map_size(tools)} MCP tools in persistent_term")
    {:reply, :ok, state}
  end

  # ── Private: Tool Call with Retry ────────────────────────────────────

  defp do_call_with_retry(server_name, tool_name, arguments) do
    context = "call_tool/#{server_name}/#{tool_name}"
    start_time = System.monotonic_time(:microsecond)

    with_retry([context: context], fn ->
        try do
          case OptimalSystemAgent.MCP.Server.call_tool(server_name, tool_name, arguments) do
            {:ok, result} ->
              # Cache successful results
              put_cached_tool_result(server_name, tool_name, arguments, result)

              # Emit telemetry event
              duration_us = System.monotonic_time(:microsecond) - start_time
              duration_ms = div(duration_us, 1000)

              :telemetry.execute(
                [:osa, :mcp, :tool_call],
                %{duration: duration_us, cached: false},
                %{server: server_name, tool: tool_name, status: :ok}
              )

              {:ok, result}

          {:error, reason} ->
            # Emit telemetry event for error
            duration = System.monotonic_time(:microsecond) - start_time
            duration_ms = div(duration, 1000)

            :telemetry.execute(
              [:osa, :mcp, :tool_call],
              %{duration: duration, cached: false},
              %{server: server_name, tool: tool_name, status: :error, reason: inspect(reason)}
            )

            {:error, reason}
        end
      rescue
        e ->
          {:error,
           {:server_error,
            %{
              server: server_name,
              tool: tool_name,
              message: Exception.message(e),
              kind: :rescue
            }}}
      catch
        :exit, reason ->
          {:error,
           {:server_exited,
            %{
              server: server_name,
              tool: tool_name,
              reason: inspect(reason),
              kind: :exit
            }}}
      end
    end)
  end

  # ── Private: Config Loading ───────────────────────────────────────────

  defp resolve_config_path do
    Application.get_env(:optimal_system_agent, :mcp_config_path, @default_config_path)
    |> Path.expand()
  end

  defp load_and_start_servers(state) do
    config_path = state.config_path

    unless File.exists?(config_path) do
      Logger.info("[MCP.Client] No config file at #{config_path}, starting with no servers")
      {:ok, state}
    else
      case read_config(config_path) do
        {:ok, server_configs} ->
          start_servers(state, server_configs)

        {:error, reason} ->
          Logger.error("[MCP.Client] Failed to read config: #{inspect(reason)}")
          {:error, {:config_read, reason}, state}
      end
    end
  end

  defp read_config(path) do
    content = File.read!(path)

    case Jason.decode(content) do
      {:ok, %{"mcpServers" => servers}} when is_map(servers) ->
        {:ok, servers}

      {:ok, %{"mcp_servers" => servers}} when is_map(servers) ->
        {:ok, servers}

      {:ok, servers} when is_map(servers) ->
        # Backward compat: top-level map of server configs
        {:ok, servers}

      {:error, reason} ->
        {:error,
         {:json_decode,
          %{
            path: path,
            detail: inspect(reason)
          }}}
    end
  rescue
    e ->
      {:error,
       {:file_read,
        %{
          path: path,
          detail: Exception.message(e)
        }}}
  end

  # ── Private: Server Lifecycle ─────────────────────────────────────────

  defp start_servers(state, server_configs) do
    results =
      Enum.reduce(server_configs, {:ok, state}, fn {name, config}, {:ok, acc_state} ->
        case start_single_server(name, config) do
          {:ok, pid} ->
            {:ok, %{acc_state | servers: Map.put(acc_state.servers, name, pid)}}

          {:error, reason} ->
            Logger.warning("[MCP.Client] Failed to start server '#{name}': #{inspect(reason)}")
            {:ok, acc_state}
        end
      end)

    case results do
      {:ok, final_state} ->
        # Register tools into persistent_term
        tools = collect_all_tools(final_state)
        :persistent_term.put({OptimalSystemAgent.Tools.Registry, :mcp_tools}, tools)

        {:ok, final_state}
    end
  end

  defp start_single_server(_name, []) do
    # Empty config - skip server startup
    {:error, :empty_config}
  end

  defp start_single_server(name, config) when is_map(config) do
    transport = Map.get(config, "transport", "stdio")

    opts =
      [
        name: name,
        transport: transport
      ] ++
        case transport do
          "stdio" ->
            command = Map.get(config, "command")
            args = Map.get(config, "args", [])
            env = Map.get(config, "env", %{})

            if is_binary(command) and command != "" do
              [command: command, args: args, env: env]
            else
              [{:error, :missing_command}]
            end

          "http" ->
            url = Map.get(config, "url")
            headers = Map.get(config, "headers", [])

            if is_binary(url) and url != "" do
              [url: url, headers: headers]
            else
              [{:error, :missing_url}]
            end
        end

    case Keyword.has_key?(opts, :error) do
      true ->
        {:error, Keyword.get(opts, :error)}

      false ->
        spec = {OptimalSystemAgent.MCP.Server, opts}

        case DynamicSupervisor.start_child(OptimalSystemAgent.MCP.Supervisor, spec) do
          {:ok, pid} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp stop_all_servers(state) do
    Enum.each(state.servers, fn {name, pid} ->
      DynamicSupervisor.terminate_child(OptimalSystemAgent.MCP.Supervisor, pid)

      Logger.debug("[MCP.Client] Stopped server: #{name}")
    end)

    # Clear persistent_term
    :persistent_term.put({OptimalSystemAgent.Tools.Registry, :mcp_tools}, %{})
  end

  # ── Private: Tool Collection ──────────────────────────────────────────

  defp collect_all_tools(state) do
    state.servers
    |> Enum.flat_map(fn {server_name, _pid} ->
      try do
        OptimalSystemAgent.MCP.Server.list_tools(server_name)
      rescue
        _ -> []
      catch
        :exit, _ -> []
      end
      |> Enum.map(fn tool ->
        prefixed_name = "mcp_#{server_name}_#{tool.name}"

        {String.to_atom(prefixed_name),
         %{
           original_name: tool.name,
           description: Map.get(tool, :description, ""),
           input_schema: Map.get(tool, :input_schema, %{}),
           server_name: server_name
         }}
      end)
    end)
    |> Map.new()
  end

  # ── Private: Tool Cache ───────────────────────────────────────────────

  defp create_tool_cache_table do
    if :ets.whereis(:mcp_tool_cache) != :undefined do
      :ets.delete(:mcp_tool_cache)
    end

    :ets.new(:mcp_tool_cache, [:named_table, :public, :set, read_concurrency: true])
  end

  defp cache_key(server_name, tool_name, _arguments) do
    {server_name, tool_name}
  end
end
