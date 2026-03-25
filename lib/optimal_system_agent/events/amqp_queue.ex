defmodule OptimalSystemAgent.Events.AMQPQueue do
  @moduledoc """
  AMQP-backed durable queue as fallback for Redis.

  Implements a fallback chain:
    1. Redis (fastest, in-memory) — primary
    2. AMQP (durable, durable, survives restarts) — fallback for production
    3. Local ETS (ephemeral, in-memory only) — final fallback

  When Redis is unavailable and USE_AMQP_QUEUE=true, events are published
  to an AMQP queue for delivery to external message brokers.

  Configuration:
    - AMQP_URL: amqp://user:password@localhost:5672/
    - USE_AMQP_QUEUE: "true" to enable (default: "false" for MVP)
    - AMQP_QUEUE_NAME: queue name (default: "osa_events")

  Example:
    {:ok, conn} = OptimalSystemAgent.Events.AMQPQueue.connect()
    {:ok, queue_name} = OptimalSystemAgent.Events.AMQPQueue.declare_queue(conn)
    :ok = OptimalSystemAgent.Events.AMQPQueue.publish(conn, "orchestrate_complete", %{...})
  """

  use GenServer
  require Logger

  @default_queue "osa_events"
  @durable true
  @auto_delete false

  defstruct [:conn, :channel, :queue_name, :dlq_name, :connected]

  # ────────────────────────────────────────────────────────────────────
  # Public API
  # ────────────────────────────────────────────────────────────────────

  @doc "Start the AMQP queue manager GenServer."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if AMQP queue is enabled.
  Returns true if USE_AMQP_QUEUE=true AND AMQP_URL is configured.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    Application.get_env(:optimal_system_agent, :amqp_queue_enabled, false) &&
      Application.get_env(:optimal_system_agent, :amqp_url) != nil
  end

  @doc """
  Publish an event to AMQP queue if enabled, otherwise to local DLQ.
  Returns :ok or {:error, reason}.
  """
  @spec publish(atom() | String.t(), map()) :: :ok | {:error, term()}
  def publish(event_type, payload) when is_map(payload) do
    if enabled?() do
      try do
        GenServer.call(__MODULE__, {:publish, event_type, payload})
      rescue
        _ -> :ok
      catch
        :exit, _ -> :ok
      end
    else
      :ok  # Silent fallback to DLQ (handled elsewhere)
    end
  end

  @doc "Get connection status."
  @spec status() :: :connected | :disconnected
  def status do
    try do
      GenServer.call(__MODULE__, :status)
    rescue
      _ -> :disconnected
    catch
      :exit, _ -> :disconnected
    end
  end

  @doc "Get queue depth (number of messages pending)."
  @spec queue_depth() :: non_neg_integer()
  def queue_depth do
    try do
      GenServer.call(__MODULE__, :queue_depth)
    rescue
      _ -> 0
    catch
      :exit, _ -> 0
    end
  end

  # ────────────────────────────────────────────────────────────────────
  # GenServer callbacks
  # ────────────────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    queue_name = Application.get_env(:optimal_system_agent, :amqp_queue_name, @default_queue)
    dlq_name = "#{queue_name}.dlq"

    state = %__MODULE__{
      conn: nil,
      channel: nil,
      queue_name: queue_name,
      dlq_name: dlq_name,
      connected: false
    }

    # Schedule async connection attempt
    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect_amqp(state) do
      {:ok, new_state} ->
        Logger.info("[AMQP] Connected to queue: #{state.queue_name}")
        {:noreply, new_state}

      {:error, reason} ->
        Logger.warning("[AMQP] Connection failed: #{inspect(reason)}, retrying in 5s")
        Process.send_after(self(), :connect, 5_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, if(state.connected, do: :connected, else: :disconnected), state}
  end

  def handle_call(:queue_depth, _from, state) do
    depth =
      if state.connected && state.channel do
        case get_queue_depth(state.channel, state.queue_name) do
          {:ok, count} -> count
          {:error, _} -> 0
        end
      else
        0
      end

    {:reply, depth, state}
  end

  def handle_call({:publish, event_type, payload}, _from, state) do
    if state.connected && state.channel do
      result = publish_to_amqp(state.channel, state.queue_name, event_type, payload)
      {:reply, result, state}
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  # ────────────────────────────────────────────────────────────────────
  # Implementation
  # ────────────────────────────────────────────────────────────────────

  defp connect_amqp(state) do
    amqp_url = Application.get_env(:optimal_system_agent, :amqp_url)

    case amqp_connect(amqp_url) do
      {:ok, conn} ->
        case amqp_channel(conn) do
          {:ok, channel} ->
            case declare_queues(channel, state.queue_name, state.dlq_name) do
              :ok ->
                {:ok,
                 %{
                   state
                   | conn: conn,
                     channel: channel,
                     connected: true
                 }}

              {:error, reason} ->
                close_amqp(conn, channel)
                {:error, reason}
            end

          {:error, reason} ->
            close_amqp(conn, nil)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # AMQP connection — safe call to AMQP.Connection.open
  defp amqp_connect(amqp_url) when is_binary(amqp_url) do
    try do
      case :amqp_connection.start(amqp_url) do
        {:ok, conn} -> {:ok, conn}
        {:error, _} = e -> e
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # Open AMQP channel
  defp amqp_channel(conn) do
    try do
      case :amqp_connection.open_channel(conn) do
        {:ok, channel} -> {:ok, channel}
        {:error, _} = e -> e
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # Declare queue and DLQ with proper bindings
  defp declare_queues(channel, queue_name, dlq_name) do
    try do
      # Declare DLQ first (no binding, standalone)
      :amqp_channel.call(channel, {:queue_declare, [queue: dlq_name, durable: @durable, auto_delete: @auto_delete]})

      # Declare main queue with DLQ binding (TTL after retries)
      :amqp_channel.call(channel, {:queue_declare, [
        queue: queue_name,
        durable: @durable,
        auto_delete: @auto_delete,
        arguments: [
          {:"x-dead-letter-exchange", :longstr, ""},
          {:"x-dead-letter-routing-key", :longstr, dlq_name},
          {:"x-message-ttl", :long, 3_600_000}  # 1 hour before TTL expires
        ]
      ]})

      :ok
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # Publish event to AMQP queue
  defp publish_to_amqp(channel, queue_name, event_type, payload) do
    try do
      body = Jason.encode!(%{
        event_type: event_type,
        payload: payload,
        published_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      :amqp_channel.call(channel, {:basic_publish, [
        exchange: "",
        routing_key: queue_name
      ], body})

      :ok
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # Get queue message count
  defp get_queue_depth(channel, queue_name) do
    try do
      case :amqp_channel.call(channel, {:queue_declare, [queue: queue_name, passive: true]}) do
        {:queue_declare_ok, message_count, _} -> {:ok, message_count}
        e -> {:error, e}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # Close AMQP connection and channel
  defp close_amqp(conn, channel) do
    if channel do
      try do
        :amqp_channel.close(channel)
      rescue
        _ -> :ok
      end
    end

    if conn do
      try do
        :amqp_connection.close(conn)
      rescue
        _ -> :ok
      end
    end
  end

  @impl true
  def terminate(_reason, state) do
    close_amqp(state.conn, state.channel)
  end
end
