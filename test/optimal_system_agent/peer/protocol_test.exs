defmodule OptimalSystemAgent.Peer.ProtocolTest do
  @moduledoc """
  Tests for Peer.Protocol.

  Tests handoff struct construction, create_handoff/3, receive_handoff/2,
  and format validation. Uses ETS for storage tests (setup/teardown per test).

  Does NOT start GenServers — tests pure struct manipulation and ETS CRUD.
  """
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Peer.Protocol

  @handoffs_table :osa_peer_handoffs

  setup do
    # Create ETS table if it doesn't exist
    try do
      :ets.new(@handoffs_table, [:named_table, :public, :set])
    rescue
      ArgumentError -> :ok
    end

    on_exit(fn ->
      # Clean up any handoffs we created
      try do
        :ets.delete_all_objects(@handoffs_table)
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Struct construction
  # ---------------------------------------------------------------------------

  describe "__struct__ defaults" do
    test "creates a struct with required fields" do
      handoff = %Protocol{
        id: "handoff_test1",
        from: "agent-a",
        to: "agent-b",
        created_at: DateTime.utc_now()
      }

      assert handoff.id == "handoff_test1"
      assert handoff.from == "agent-a"
      assert handoff.to == "agent-b"
      assert handoff.actions_taken == []
      assert handoff.discoveries == []
      assert handoff.files_changed == []
      assert handoff.decisions_made == []
      assert handoff.open_questions == []
      assert handoff.metadata == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # create_handoff/3
  # ---------------------------------------------------------------------------

  describe "create_handoff/3" do
    test "creates a handoff with generated ID" do
      handoff = Protocol.create_handoff("agent-a", "agent-b")

      assert %Protocol{} = handoff
      assert handoff.from == "agent-a"
      assert handoff.to == "agent-b"
      assert String.starts_with?(handoff.id, "handoff_")
      assert %DateTime{} = handoff.created_at
    end

    test "populates fields from state map" do
      state = %{
        actions_taken: ["Wrote tests", "Fixed bug"],
        discoveries: ["Found memory leak in cache"],
        files_changed: ["lib/cache.ex", "test/cache_test.exs"],
        decisions_made: ["Use ETS instead of Agent"],
        open_questions: ["Should we add TTL?"],
        metadata: %{priority: :high}
      }

      handoff = Protocol.create_handoff("agent-a", "agent-b", state)

      assert handoff.actions_taken == ["Wrote tests", "Fixed bug"]
      assert handoff.discoveries == ["Found memory leak in cache"]
      assert handoff.files_changed == ["lib/cache.ex", "test/cache_test.exs"]
      assert handoff.decisions_made == ["Use ETS instead of Agent"]
      assert handoff.open_questions == ["Should we add TTL?"]
      assert handoff.metadata == %{priority: :high}
    end

    test "ignores unrecognized state keys" do
      state = %{actions_taken: ["action1"], unknown_key: "ignored", extra: 42}

      handoff = Protocol.create_handoff("agent-a", "agent-b", state)

      assert handoff.actions_taken == ["action1"]
      refute Map.has_key?(handoff, :unknown_key)
      refute Map.has_key?(handoff, :extra)
    end

    test "defaults missing fields to empty values" do
      handoff = Protocol.create_handoff("agent-a", "agent-b", %{})

      assert handoff.actions_taken == []
      assert handoff.discoveries == []
      assert handoff.files_changed == []
      assert handoff.decisions_made == []
      assert handoff.open_questions == []
      assert handoff.metadata == %{}
    end

    test "stores handoff in ETS" do
      handoff = Protocol.create_handoff("agent-a", "agent-b")

      retrieved = Protocol.get_handoff(handoff.id)
      assert retrieved == handoff
    end
  end

  # ---------------------------------------------------------------------------
  # receive_handoff/2
  # ---------------------------------------------------------------------------

  describe "receive_handoff/2" do
    test "merges handoff into empty context" do
      handoff = Protocol.create_handoff("agent-a", "agent-b", %{
        actions_taken: ["Action 1"],
        discoveries: ["Discovery 1"],
        files_changed: ["file.ex"],
        decisions_made: ["Decision 1"],
        open_questions: ["Question 1"],
        metadata: %{key: "value"}
      })

      {:ok, merged} = Protocol.receive_handoff(handoff, %{})

      assert merged.prior_actions == ["Action 1"]
      assert merged.known_discoveries == ["Discovery 1"]
      assert merged.files_changed == ["file.ex"]
      assert merged.prior_decisions == ["Decision 1"]
      assert merged.open_questions == ["Question 1"]
      assert merged.last_handoff_id == handoff.id
      assert merged.last_handoff_from == "agent-a"
      assert merged.key == "value"
    end

    test "appends to existing context lists" do
      handoff1 = Protocol.create_handoff("agent-a", "agent-b", %{
        actions_taken: ["Action A1"]
      })

      handoff2 = Protocol.create_handoff("agent-b", "agent-c", %{
        actions_taken: ["Action B1"]
      })

      {:ok, ctx1} = Protocol.receive_handoff(handoff1, %{})
      {:ok, ctx2} = Protocol.receive_handoff(handoff2, ctx1)

      assert ctx2.prior_actions == ["Action A1", "Action B1"]
    end

    test "deduplicates files_changed" do
      handoff = Protocol.create_handoff("agent-a", "agent-b", %{
        files_changed: ["file.ex"]
      })

      context = %{files_changed: ["file.ex", "other.ex"]}
      {:ok, merged} = Protocol.receive_handoff(handoff, context)

      # file.ex should appear only once
      assert Enum.count(merged.files_changed, &(&1 == "file.ex")) == 1
      assert "other.ex" in merged.files_changed
    end

    test "existing context keys take precedence over metadata" do
      handoff = Protocol.create_handoff("agent-a", "agent-b", %{
        metadata: %{priority: :high}
      })

      context = %{priority: :low}
      {:ok, merged} = Protocol.receive_handoff(handoff, context)

      # Existing context preserved, not overwritten by metadata
      assert merged.priority == :low
    end

    test "updates last_handoff_id and last_handoff_from" do
      handoff = Protocol.create_handoff("agent-x", "agent-y")

      {:ok, merged} = Protocol.receive_handoff(handoff, %{
        last_handoff_id: "previous-id",
        last_handoff_from: "previous-agent"
      })

      assert merged.last_handoff_id == handoff.id
      assert merged.last_handoff_from == "agent-x"
    end

    test "works with default empty context" do
      handoff = Protocol.create_handoff("agent-a", "agent-b", %{})
      {:ok, merged} = Protocol.receive_handoff(handoff)

      assert merged.last_handoff_id == handoff.id
    end
  end

  # ---------------------------------------------------------------------------
  # get_handoff/1
  # ---------------------------------------------------------------------------

  describe "get_handoff/1" do
    test "returns nil for non-existent handoff" do
      assert Protocol.get_handoff("nonexistent") == nil
    end

    test "returns handoff by ID" do
      handoff = Protocol.create_handoff("agent-a", "agent-b")
      retrieved = Protocol.get_handoff(handoff.id)

      assert retrieved.id == handoff.id
      assert retrieved.from == handoff.from
      assert retrieved.to == handoff.to
    end
  end

  # ---------------------------------------------------------------------------
  # init_table/0
  # ---------------------------------------------------------------------------

  describe "init_table/0" do
    test "returns :ok and is idempotent" do
      assert :ok = Protocol.init_table()
      assert :ok = Protocol.init_table()
    end
  end

  # ---------------------------------------------------------------------------
  # deliver/2 (tests the rescue path since PubSub is not running)
  # ---------------------------------------------------------------------------

  describe "deliver/2" do
    test "returns :ok even when PubSub is not available" do
      handoff = Protocol.create_handoff("agent-a", "agent-b", %{
        actions_taken: ["Test action"]
      })

      # deliver/2 calls Phoenix.PubSub.broadcast and Team.send_message
      # which will fail in --no-start mode. The function rescues and returns :ok.
      result = Protocol.deliver(handoff, "test-team")
      assert result == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Validation / edge cases
  # ---------------------------------------------------------------------------

  describe "edge cases" do
    test "handoff with empty lists serializes correctly" do
      handoff = Protocol.create_handoff("a", "b")
      assert is_binary(handoff.id)
      assert handoff.actions_taken == []
      assert handoff.discoveries == []
      assert handoff.files_changed == []
      assert handoff.decisions_made == []
      assert handoff.open_questions == []
      assert handoff.metadata == %{}
    end

    test "handoff ID format is consistent" do
      ids = for _ <- 1..10, do: Protocol.create_handoff("a", "b").id

      for id <- ids do
        assert String.starts_with?(id, "handoff_")
        # "handoff_" prefix + hex-encoded random bytes
        assert String.length(id) >= 20
      end

      # All IDs should be unique
      assert length(Enum.uniq(ids)) == 10
    end

    test "receive_handoff preserves metadata from handoff" do
      handoff = Protocol.create_handoff("a", "b", %{
        metadata: %{version: 2, tags: ["urgent"]}
      })

      {:ok, merged} = Protocol.receive_handoff(handoff, %{})
      assert merged.version == 2
      assert merged.tags == ["urgent"]
    end
  end
end
