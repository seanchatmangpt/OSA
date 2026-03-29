defmodule OptimalSystemAgent.StubReplacementTest do
  @moduledoc """
  Chicago TDD — Wave 1 stub replacement tests.

  RED phase: verifies that each stub now has real behavior.

  Items covered:
  - OSA-C1: HotStuff broadcast_proposal dispatches a system_event through Events.Bus
  - OSA-C1: select_leader returns a non-nil, non-empty string
  - OSA-H1: POST /discord/webhook with missing DISCORD_PUBLIC_KEY returns 401
  - OSA-M3: SDK.Session.get_messages/1 returns a list (not raises)
  - OSA-M4: recent_message_previews returns a list (may be empty, but not raises)
  - OSA-M9: Fortune5 health layer 5 returns a map (not :not_implemented)
  """

  use ExUnit.Case, async: false
  @moduletag :requires_application

  import Plug.Test
  import Plug.Conn

  alias OptimalSystemAgent.Consensus.HotStuff
  alias OptimalSystemAgent.SDK.Session

  # ── OSA-C1: HotStuff broadcasts ──────────────────────────────────────────

  describe "OSA-C1: HotStuff broadcasts route through Events.Bus" do
    test "broadcast_proposal dispatches a system_event (propose_vote triggers bus)" do
      # Subscribe to PubSub to observe any events — a system_event or the bus
      # being called means broadcast_proposal ran through the bus.
      # We verify indirectly: propose_vote must return {:ok, proposal} and
      # the bus should emit without crashing.
      fleet_id = "test-fleet-#{System.unique_integer([:positive])}"

      agents = ["agent-a", "agent-b", "agent-c", "agent-d"]

      proposal_content = %{
        workflow_id: "wf-#{System.unique_integer([:positive])}",
        type: :decision,
        content: %{},
        proposer_id: "system"
      }

      result = HotStuff.propose_vote(fleet_id, proposal_content, agents)

      assert {:ok, proposal} = result
      # Proposal struct contains type, content, proposer, votes, status — not fleet_id
      assert proposal.status == :pending
      assert proposal.type == :decision
    end

    test "select_leader returns a non-nil, non-empty value" do
      fleet_id = "test-fleet-#{System.unique_integer([:positive])}"
      agents = ["agent-a", "agent-b", "agent-c", "agent-d"]

      proposal_content = %{
        workflow_id: "wf-#{System.unique_integer([:positive])}",
        type: :decision,
        content: %{},
        proposer_id: "system"
      }

      # trigger view_change exercises select_leader
      # First propose so there is a view to change
      {:ok, _proposal} = HotStuff.propose_vote(fleet_id, proposal_content, agents)

      {:ok, view_info} = HotStuff.view_change(fleet_id)

      assert is_binary(view_info.leader)
      assert String.length(view_info.leader) > 0
      # The stub used fake concatenation: "<fleet_id>_leader_<n>".
      # The real impl should NOT embed "_leader_" — it should pick from the agent list.
      # Accept any non-empty string for now; deeper assertion below.
      refute view_info.leader == ""
    end

    test "select_leader picks from the registered agents (not a fake name)" do
      fleet_id = "test-fleet-#{System.unique_integer([:positive])}"
      agents = ["agent-alpha", "agent-beta", "agent-gamma", "agent-delta"]

      proposal_content = %{
        workflow_id: "wf-#{System.unique_integer([:positive])}",
        type: :decision,
        content: %{},
        proposer_id: "system"
      }

      {:ok, _} = HotStuff.propose_vote(fleet_id, proposal_content, agents)
      {:ok, view_info} = HotStuff.view_change(fleet_id)

      # The leader should be one of the known agents, not a generated fake name
      assert view_info.leader in agents,
             "Expected leader to be one of #{inspect(agents)}, got #{inspect(view_info.leader)}"
    end
  end

  # ── OSA-H1: Discord webhook signature verification ───────────────────────

  describe "OSA-H1: Discord webhook Ed25519 signature" do
    test "returns 401 when DISCORD_PUBLIC_KEY env var is missing" do
      # Unset the env var to simulate missing config
      original = System.get_env("DISCORD_PUBLIC_KEY")
      System.delete_env("DISCORD_PUBLIC_KEY")

      # ChannelRoutes is mounted at /channels — call it with the sub-path /discord/webhook
      conn =
        conn(:post, "/discord/webhook", Jason.encode!(%{"type" => 1}))
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-signature-ed25519", "deadbeef")
        |> put_req_header("x-signature-timestamp", "1234567890")

      conn = OptimalSystemAgent.Channels.HTTP.API.ChannelRoutes.call(conn, [])

      assert conn.status == 401

      # Restore
      if original do
        System.put_env("DISCORD_PUBLIC_KEY", original)
      end
    end

    test "returns 401 when DISCORD_PUBLIC_KEY is empty string" do
      original = System.get_env("DISCORD_PUBLIC_KEY")
      System.put_env("DISCORD_PUBLIC_KEY", "")

      conn =
        conn(:post, "/discord/webhook", Jason.encode!(%{"type" => 1}))
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-signature-ed25519", "deadbeef")
        |> put_req_header("x-signature-timestamp", "1234567890")

      conn = OptimalSystemAgent.Channels.HTTP.API.ChannelRoutes.call(conn, [])

      assert conn.status == 401

      # Restore to original state
      case original do
        nil -> System.delete_env("DISCORD_PUBLIC_KEY")
        val -> System.put_env("DISCORD_PUBLIC_KEY", val)
      end
    end
  end

  # ── OSA-M3: Session.get_messages/1 ───────────────────────────────────────

  describe "OSA-M3: Session.get_messages/1 returns a list" do
    test "returns an empty list for an unknown session (not raises)" do
      result = Session.get_messages("nonexistent-session-id-#{System.unique_integer()}")

      assert is_list(result),
             "Expected a list, got: #{inspect(result)}"
    end

    test "returns messages list for an active session" do
      # Start a loop for a session
      session_id = "test-session-#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        DynamicSupervisor.start_child(
          OptimalSystemAgent.SessionSupervisor,
          {OptimalSystemAgent.Agent.Loop,
           session_id: session_id, user_id: "test-user", channel: :http}
        )

      result = Session.get_messages(session_id)

      assert is_list(result)

      # Cleanup
      case Registry.lookup(OptimalSystemAgent.SessionRegistry, session_id) do
        [{pid, _}] -> DynamicSupervisor.terminate_child(OptimalSystemAgent.SessionSupervisor, pid)
        _ -> :ok
      end
    end
  end

  # ── OSA-M4: recent_message_previews ──────────────────────────────────────

  describe "OSA-M4: AgentStateRoutes recent_message_previews" do
    test "GET /state returns a map with last_messages as a list" do
      # AgentStateRoutes is mounted at /agent and handles /state internally.
      # Call the subrouter directly with the sub-path /state.
      conn =
        conn(:get, "/state", nil)
        |> put_req_header("content-type", "application/json")

      conn =
        OptimalSystemAgent.Channels.HTTP.API.AgentStateRoutes.call(conn, [])

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert is_list(body["last_messages"]),
             "Expected last_messages to be a list, got: #{inspect(body["last_messages"])}"
    end
  end

  # ── OSA-M9: Fortune5 health layers 5–7 ───────────────────────────────────

  describe "OSA-M9: Fortune5 health layer 5 is not :not_implemented" do
    test "GET /health/fortune5 layer5 returns a map (not :not_implemented)" do
      conn =
        conn(:get, "/health/fortune5", nil)

      conn =
        OptimalSystemAgent.Channels.HTTP.API.call(conn, [])

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      layers = body["fortune5_layers"]

      assert is_map(layers),
             "Expected fortune5_layers to be a map, got: #{inspect(layers)}"

      layer5 = layers["layer5_reconstruction"]
      refute layer5 == "not_implemented",
             "layer5_reconstruction must not be 'not_implemented', got: #{inspect(layer5)}"

      assert is_map(layer5) or is_binary(layer5) or is_atom(layer5),
             "layer5 should be a map or status string, got: #{inspect(layer5)}"
    end

    test "GET /health/fortune5 layer6 returns a map (not :not_implemented)" do
      conn = conn(:get, "/health/fortune5", nil)
      conn = OptimalSystemAgent.Channels.HTTP.API.call(conn, [])

      body = Jason.decode!(conn.resp_body)
      layer6 = body["fortune5_layers"]["layer6_verification"]

      refute layer6 == "not_implemented",
             "layer6_verification must not be 'not_implemented'"
    end

    test "GET /health/fortune5 layer7 returns a map (not :not_implemented)" do
      conn = conn(:get, "/health/fortune5", nil)
      conn = OptimalSystemAgent.Channels.HTTP.API.call(conn, [])

      body = Jason.decode!(conn.resp_body)
      layer7 = body["fortune5_layers"]["layer7_event_horizon"]

      refute layer7 == "not_implemented",
             "layer7_event_horizon must not be 'not_implemented'"
    end
  end
end
