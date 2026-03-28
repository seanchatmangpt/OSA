defmodule OptimalSystemAgent.MCP.Native.SessionManagerTest do
  @moduledoc """
  Chicago TDD: SessionManager GenServer contract tests.
  Tests the session lifecycle and ETS-backed state.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.MCP.Native.SessionManager

  setup do
    # Ensure a fresh SessionManager for each test
    case Process.whereis(SessionManager) do
      nil -> start_supervised!({SessionManager, []})
      _pid -> :ok
    end

    :ok
  end

  describe "create_session/0" do
    test "returns {:ok, session_id} with a non-empty binary ID" do
      assert {:ok, session_id} = SessionManager.create_session()
      assert is_binary(session_id)
      assert String.length(session_id) > 0
    end

    test "each create_session returns a unique session_id" do
      {:ok, id1} = SessionManager.create_session()
      {:ok, id2} = SessionManager.create_session()
      refute id1 == id2
    end
  end

  describe "get_session/1" do
    test "returns the session map after creation" do
      {:ok, session_id} = SessionManager.create_session()
      session = SessionManager.get_session(session_id)

      assert is_map(session)
      assert session.id == session_id
    end

    test "returns nil for unknown session ID" do
      assert SessionManager.get_session("nonexistent-id-xyz") == nil
    end
  end

  describe "put_session/2" do
    test "merges updates into the existing session" do
      {:ok, session_id} = SessionManager.create_session()
      :ok = SessionManager.put_session(session_id, %{sse_pid: self()})

      session = SessionManager.get_session(session_id)
      assert session.sse_pid == self()
    end

    test "is a no-op for unknown session" do
      assert :ok = SessionManager.put_session("unknown-session", %{sse_pid: self()})
    end
  end

  describe "delete_session/1" do
    test "removes the session so get_session returns nil" do
      {:ok, session_id} = SessionManager.create_session()
      assert SessionManager.get_session(session_id) != nil

      :ok = SessionManager.delete_session(session_id)
      assert SessionManager.get_session(session_id) == nil
    end

    test "is a no-op for unknown session" do
      assert :ok = SessionManager.delete_session("unknown-session")
    end
  end
end
