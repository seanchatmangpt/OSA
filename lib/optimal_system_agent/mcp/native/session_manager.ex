defmodule OptimalSystemAgent.MCP.Native.SessionManager do
  @moduledoc """
  ETS-backed session registry for the native MCP HTTP+SSE server.

  Manages SSE session lifecycle:
  - `create_session/0` — allocates a new session ID, stores with expiry
  - `get_session/1`    — fetches a session by ID (nil if expired/missing)
  - `put_session/2`    — updates session metadata (e.g. SSE pid)
  - `delete_session/1` — explicit removal on disconnect
  - TTL sweep every 5 minutes; max 500 live sessions

  WvdA Boundedness: max 500 sessions prevents unbounded ETS growth.
  Armstrong: let-it-crash; supervisor restarts this GenServer on failure.
  """
  use GenServer
  require Logger

  @table :mcp_native_sessions
  @session_ttl_ms 5 * 60 * 1_000
  @sweep_interval_ms 5 * 60 * 1_000
  @max_sessions 500

  # ── Public API ────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Create a new session. Returns {:ok, session_id} or {:error, :max_sessions}."
  @spec create_session() :: {:ok, String.t()} | {:error, :max_sessions}
  def create_session do
    GenServer.call(__MODULE__, :create_session, 5_000)
  end

  @doc "Fetch a session map by ID. Returns nil if not found or expired."
  @spec get_session(String.t()) :: map() | nil
  def get_session(session_id) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, session}] ->
        if expired?(session), do: nil, else: session

      [] ->
        nil
    end
  end

  @doc "Update session metadata (e.g. SSE pid). No-op if session not found."
  @spec put_session(String.t(), map()) :: :ok
  def put_session(session_id, updates) when is_map(updates) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, existing}] ->
        :ets.insert(@table, {session_id, Map.merge(existing, updates)})
        :ok

      [] ->
        :ok
    end
  end

  @doc "Delete a session by ID."
  @spec delete_session(String.t()) :: :ok
  def delete_session(session_id) do
    :ets.delete(@table, session_id)
    :ok
  end

  # ── GenServer callbacks ───────────────────────────────────────────────

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:create_session, _from, state) do
    current_count = :ets.info(@table, :size)

    if current_count >= @max_sessions do
      {:reply, {:error, :max_sessions}, state}
    else
      session_id = generate_session_id()
      now = System.monotonic_time(:millisecond)

      session = %{
        id: session_id,
        created_at: now,
        expires_at: now + @session_ttl_ms,
        sse_pid: nil
      }

      :ets.insert(@table, {session_id, session})
      {:reply, {:ok, session_id}, state}
    end
  end

  @impl true
  def handle_info(:sweep, state) do
    deleted = sweep_expired_entries()

    if deleted > 0 do
      Logger.debug("[MCP.Native.SessionManager] swept #{deleted} expired sessions")
    end

    schedule_sweep()
    {:noreply, state}
  end

  # ── Private helpers ───────────────────────────────────────────────────

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp expired?(%{expires_at: exp}) do
    System.monotonic_time(:millisecond) > exp
  end

  defp expired?(_), do: true

  defp sweep_expired_entries do
    now = System.monotonic_time(:millisecond)

    expired_keys =
      :ets.foldl(
        fn {key, session}, acc ->
          if Map.get(session, :expires_at, 0) < now, do: [key | acc], else: acc
        end,
        [],
        @table
      )

    Enum.each(expired_keys, &:ets.delete(@table, &1))
    length(expired_keys)
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval_ms)
  end
end
