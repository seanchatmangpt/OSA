defmodule OptimalSystemAgent.Agent.Hooks.AuditTrailTest do
  @moduledoc """
  Unit tests for Hash-Chain Audit Trail (Innovation 3).

  Tests the public API: append_entry, verify_chain, export_chain, merkle_root.
  These work with the running OSA application's ETS tables.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Hooks.AuditTrail

  @unique_prefix "audit-test-#{:erlang.unique_integer([:positive])}-"

  describe "append_entry/1" do
    test "appends an entry and returns it with hash" do
      session = @unique_prefix <> "append"

      entry = %{
        session_id: session,
        tool_name: "web_search",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        signal: %{mode: "execute", genre: "tool_call", type: "http_get"}
      }

      assert {:ok, stored} = AuditTrail.append_entry(entry)
      assert is_binary(stored.entry_hash)
      assert String.length(stored.entry_hash) == 64
      assert stored.session_id == session
    end

    test "creates linked chain across multiple entries" do
      session = @unique_prefix <> "chain"

      {:ok, e1} = AuditTrail.append_entry(%{
        session_id: session,
        tool_name: "step_1",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      {:ok, e2} = AuditTrail.append_entry(%{
        session_id: session,
        tool_name: "step_2",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      refute e1.entry_hash == e2.entry_hash
      assert e2.previous_hash == e1.entry_hash
    end
  end

  describe "verify_chain/1" do
    test "returns valid for a fresh chain" do
      session = @unique_prefix <> "verify"

      for i <- 1..3 do
        AuditTrail.append_entry(%{
          session_id: session,
          tool_name: "tool_#{i}",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
      end

      assert {:ok, true} = AuditTrail.verify_chain(session)
    end

    test "returns valid for empty session" do
      empty = "empty-audit-#{:erlang.unique_integer([:positive])}"
      assert {:ok, true} = AuditTrail.verify_chain(empty)
    end
  end

  describe "export_chain/1" do
    test "returns all entries for a session in order" do
      session = @unique_prefix <> "export"

      for i <- 1..3 do
        AuditTrail.append_entry(%{
          session_id: session,
          tool_name: "export_tool_#{i}",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
      end

      entries = AuditTrail.export_chain(session)
      assert length(entries) == 3
      # Entries should be in order
      indices = Enum.map(entries, & &1.index)
      assert indices == Enum.sort(indices)
    end

    test "returns empty list for unknown session" do
      assert [] = AuditTrail.export_chain("nonexistent-#{:erlang.unique_integer([:positive])}")
    end
  end

  describe "merkle_root/1" do
    test "returns consistent root for same chain" do
      session = @unique_prefix <> "merkle"

      for i <- 1..5 do
        AuditTrail.append_entry(%{
          session_id: session,
          tool_name: "merkle_tool_#{i}",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
      end

      root1 = AuditTrail.merkle_root(session)
      root2 = AuditTrail.merkle_root(session)
      assert root1 == root2
      assert is_binary(root1)
    end
  end
end
