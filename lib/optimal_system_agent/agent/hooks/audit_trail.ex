defmodule OptimalSystemAgent.Agent.Hooks.AuditTrail do
  @moduledoc """
  Hash-chain audit trail for Zero-Touch Compliance (Innovation 3).

  Every tool call is logged as an immutable entry in a cryptographic hash chain.
  Each entry contains the hash of the previous entry, creating a tamper-evident
  audit trail that can be verified at any time.

  ## Chain Design

      entry[N] = {
        index: N,
        timestamp: ISO8601,
        session_id: "...",
        tool_name: "...",
        arguments_hash: SHA256(arguments),
        result_hash: SHA256(result),
        duration_ms: ...,
        provider: "...",
        model: "...",
        previous_hash: hash(entry[N-1]),
        entry_hash: SHA256(all_above_fields)
      }

  ## ETS Tables

  - `:osa_audit_chain` — set, named_table, public. Keyed by `{session_id, index}`.
  - `:osa_audit_head` — set, named_table, public. Maps `session_id -> latest_hash`.

  ## Usage

      # Register the hook (call once at startup)
      OptimalSystemAgent.Agent.Hooks.AuditTrail.register()

      # Verify chain integrity for a session
      {:ok, true} = OptimalSystemAgent.Agent.Hooks.AuditTrail.verify_chain("session_id")

      # Export full chain
      entries = OptimalSystemAgent.Agent.Hooks.AuditTrail.export_chain("session_id")

      # Compute Merkle root
      root = OptimalSystemAgent.Agent.Hooks.AuditTrail.merkle_root("session_id")
  """

  @chain_table :osa_audit_chain
  @head_table :osa_audit_head

  require Logger

  # ── Registration ────────────────────────────────────────────────────

  @doc """
  Register the audit trail hook on `:post_tool_use` at priority 85.

  This must be called after the Hooks GenServer has started. The hook
  creates its ETS tables if they do not already exist.
  """
  @spec register() :: :ok
  def register do
    init_tables()

    OptimalSystemAgent.Agent.Hooks.register(
      :post_tool_use,
      "audit_trail",
      &handle_post_tool/1,
      priority: 85
    )

    Logger.info("[AuditTrail] Hook registered at priority 85")
  end

  # ── ETS Initialization ──────────────────────────────────────────────

  defp init_tables do
    if :ets.whereis(@chain_table) == :undefined do
      :ets.new(@chain_table, [
        :named_table,
        :set,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end

    if :ets.whereis(@head_table) == :undefined do
      :ets.new(@head_table, [
        :named_table,
        :set,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end
  rescue
    ArgumentError -> :ok
  end

  # ── Hook Handler ────────────────────────────────────────────────────

  @doc false
  def handle_post_tool(%{session_id: session_id} = payload) when is_binary(session_id) do
    init_tables()

    tool_name = Map.get(payload, :tool_name, "unknown")
    arguments = Map.get(payload, :arguments, %{})
    result = Map.get(payload, :result, "")
    duration_ms = Map.get(payload, :duration_ms, 0)
    provider = Map.get(payload, :provider) || "unknown"
    model = Map.get(payload, :model) || "unknown"

    append_entry(%{
      session_id: session_id,
      tool_name: tool_name,
      arguments: arguments,
      result: result,
      duration_ms: duration_ms,
      provider: provider,
      model: model
    })
  rescue
    e ->
      Logger.error("[AuditTrail] Failed to record entry: #{Exception.message(e)}")
      {:ok, payload}
  end

  def handle_post_tool(payload), do: {:ok, payload}

  # ── Chain Operations ────────────────────────────────────────────────

  @doc """
  Append a new entry to the hash chain for a session.

  Returns `{:ok, entry}` on success or `{:error, reason}` on failure.
  """
  @spec append_entry(map()) :: {:ok, map()} | {:error, term()}
  def append_entry(attrs) do
    session_id = Map.fetch!(attrs, :session_id)

    # Determine next index
    next_index = next_index_for_session(session_id)

    # Get previous hash
    previous_hash = get_head(session_id)

    # Compute content hashes
    arguments_hash = hash_data(Map.get(attrs, :arguments, %{}))
    result_hash = hash_data(Map.get(attrs, :result, ""))

    # Build the entry (without entry_hash)
    entry = %{
      index: next_index,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      session_id: session_id,
      tool_name: Map.get(attrs, :tool_name, "unknown"),
      arguments_hash: arguments_hash,
      result_hash: result_hash,
      duration_ms: Map.get(attrs, :duration_ms, 0),
      provider: Map.get(attrs, :provider) || "unknown",
      model: Map.get(attrs, :model) || "unknown",
      previous_hash: previous_hash,
      entry_hash: nil
    }

    # Compute entry hash over all fields (with entry_hash set to "")
    entry_hash = compute_entry_hash(Map.put(entry, :entry_hash, ""))
    entry = Map.put(entry, :entry_hash, entry_hash)

    # Write to ETS
    try do
      :ets.insert(@chain_table, {{session_id, next_index}, entry})
      :ets.insert(@head_table, {session_id, entry_hash})
      {:ok, entry}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Verify the integrity of the hash chain for a session.

  Walks every entry and confirms:
  - Each entry's `previous_hash` matches the prior entry's `entry_hash`
  - Each entry's `entry_hash` is correctly computed from its fields

  Returns `{:ok, true}` if the chain is valid, `{:ok, false}` if tampered,
  or `{:error, reason}` on failure.
  """
  @spec verify_chain(String.t()) :: {:ok, boolean()} | {:error, term()}
  def verify_chain(session_id) do
    entries = export_chain(session_id)

    case entries do
      [] ->
        {:ok, true}

      [_single] ->
        # Single entry chain: verify genesis previous_hash and entry_hash
        [entry] = entries

        valid =
          entry.previous_hash == "genesis" and
            entry.entry_hash == compute_entry_hash(Map.put(entry, :entry_hash, ""))

        {:ok, valid}

      chain ->
        # Verify first entry has genesis previous_hash
        first = hd(chain)

        if first.previous_hash != "genesis" do
          {:ok, false}
        else
          # Verify each entry in sequence
          valid =
            chain
            |> Enum.chunk_every(2, 1, :discard)
            |> Enum.all?(fn [prev, curr] ->
              curr.previous_hash == prev.entry_hash and
                curr.entry_hash == compute_entry_hash(Map.put(curr, :entry_hash, ""))
            end)

          # Also verify the last entry's own hash
          last = List.last(chain)
          last_valid = last.entry_hash == compute_entry_hash(Map.put(last, :entry_hash, ""))

          {:ok, valid and last_valid}
        end
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Export the full hash chain for a session as a list of maps.

  Returns entries in ascending index order.
  """
  @spec export_chain(String.t()) :: [map()]
  def export_chain(session_id) do
    try do
      @chain_table
      |> :ets.match_object({{session_id, :_}, :_})
      |> Enum.sort_by(fn {{_sid, index}, _entry} -> index end)
      |> Enum.map(fn {_key, entry} -> entry end)
    rescue
      ArgumentError -> []
    end
  end

  @doc """
  Compute the Merkle root hash for the entire chain of a session.

  Uses a simple binary tree construction: pair up hashes, concatenate
  and hash each pair, repeat until a single root remains. If the number
  of leaves is odd, the last leaf is duplicated (padded) to form a pair.

  Returns `nil` for an empty chain.
  """
  @spec merkle_root(String.t()) :: String.t() | nil
  def merkle_root(session_id) do
    entries = export_chain(session_id)

    case entries do
      [] -> nil
      chain -> merkle_root_from_hashes(Enum.map(chain, & &1.entry_hash))
    end
  end

  # ── Private Helpers ─────────────────────────────────────────────────

  defp next_index_for_session(session_id) do
    try do
      @chain_table
      |> :ets.match_object({{session_id, :_}, :_})
      |> Enum.map(fn {_key, _value} -> 1 end)
      |> Enum.sum()
    rescue
      _ -> 0
    end
  end

  defp get_head(session_id) do
    try do
      case :ets.lookup(@head_table, session_id) do
        [{^session_id, hash}] -> hash
        [] -> "genesis"
      end
    rescue
      ArgumentError -> "genesis"
    end
  end

  defp hash_data(data) do
    json = Jason.encode!(data)
    :crypto.hash(:sha256, json) |> Base.encode16(case: :lower)
  end

  defp compute_entry_hash(entry) do
    # Serialize in a deterministic field order for consistent hashing.
    # Use a plain map (not keyword list) to avoid Jason tuple-encoding issues.

    idx = case Map.get(entry, :index) do
      i when is_integer(i) -> i
      _ -> 0
    end

    canonical = %{
      "index" => idx,
      "timestamp" => to_string(Map.get(entry, :timestamp, "")),
      "session_id" => to_string(Map.get(entry, :session_id, "")),
      "tool_name" => to_string(Map.get(entry, :tool_name, "")),
      "arguments_hash" => to_string(Map.get(entry, :arguments_hash, "")),
      "result_hash" => to_string(Map.get(entry, :result_hash, "")),
      "duration_ms" => to_string(Map.get(entry, :duration_ms, 0)),
      "provider" => to_string(Map.get(entry, :provider, "")),
      "model" => to_string(Map.get(entry, :model, "")),
      "previous_hash" => to_string(Map.get(entry, :previous_hash, "")),
      "entry_hash" => to_string(Map.get(entry, :entry_hash, ""))
    }

    json = Jason.encode!(canonical)
    :crypto.hash(:sha256, json) |> Base.encode16(case: :lower)
  end

  # Merkle tree: reduce list of hashes to a single root
  defp merkle_root_from_hashes([single]), do: single

  defp merkle_root_from_hashes(hashes) do
    padded = if rem(length(hashes), 2) != 0, do: hashes ++ [List.last(hashes)], else: hashes

    next_level =
      padded
      |> Enum.chunk_every(2)
      |> Enum.map(fn [left, right] ->
        :crypto.hash(:sha256, left <> right) |> Base.encode16(case: :lower)
      end)

    merkle_root_from_hashes(next_level)
  end
end
