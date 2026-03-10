defmodule OptimalSystemAgent.Bridge.PubSubTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Bridge.PubSub

  # Start a minimal PubSub instance for each test module run.
  setup_all do
    Application.ensure_all_started(:phoenix_pubsub)
    start_supervised!({Phoenix.PubSub, name: OptimalSystemAgent.PubSub})
    :ok
  end

  # -----------------------------------------------------------------------
  # subscribe helpers
  # -----------------------------------------------------------------------

  describe "subscribe helpers" do
    test "subscribe_firehose/0 subscribes to osa:events" do
      assert :ok = PubSub.subscribe_firehose()
    end

    test "subscribe_session/1 subscribes to session-scoped topic" do
      assert :ok = PubSub.subscribe_session("sess-abc")
    end

    test "subscribe_type/1 subscribes to type-scoped topic" do
      assert :ok = PubSub.subscribe_type(:llm_response)
    end

    test "subscribe_tui_output/0 subscribes to osa:tui:output" do
      assert :ok = PubSub.subscribe_tui_output()
    end
  end

  # -----------------------------------------------------------------------
  # Tier 1: Firehose
  # -----------------------------------------------------------------------

  describe "broadcast_event/1 -- tier 1 firehose" do
    test "any event is delivered to osa:events subscribers" do
      PubSub.subscribe_firehose()
      event = %{type: :some_event, payload: "hello"}
      PubSub.broadcast_event(event)
      assert_receive {:osa_event, ^event}, 500
    end
  end

  # -----------------------------------------------------------------------
  # Tier 2: Session fan-out
  # -----------------------------------------------------------------------

  describe "broadcast_event/1 -- tier 2 session fan-out" do
    test "event with session_id is delivered to session subscribers" do
      PubSub.subscribe_session("sess-1")
      event = %{type: :agent_response, session_id: "sess-1"}
      PubSub.broadcast_event(event)
      assert_receive {:osa_event, ^event}, 500
    end

    test "event without session_id is NOT delivered to session subscribers" do
      PubSub.subscribe_session("sess-2")
      event = %{type: :agent_response}
      PubSub.broadcast_event(event)
      refute_receive {:osa_event, _}, 100
    end
  end

  # -----------------------------------------------------------------------
  # Tier 3: Type fan-out
  # -----------------------------------------------------------------------

  describe "broadcast_event/1 -- tier 3 type fan-out" do
    test "event with type is delivered to type subscribers" do
      PubSub.subscribe_type(:llm_response)
      event = %{type: :llm_response, text: "hi"}
      PubSub.broadcast_event(event)
      assert_receive {:osa_event, ^event}, 500
    end

    test "event with different type is NOT delivered to type subscribers" do
      PubSub.subscribe_type(:tool_result)
      event = %{type: :agent_started}
      PubSub.broadcast_event(event)
      refute_receive {:osa_event, _}, 100
    end
  end

  # -----------------------------------------------------------------------
  # Tier 4: TUI output fan-out
  # -----------------------------------------------------------------------

  describe "broadcast_event/1 -- tier 4 TUI fan-out" do
    @tui_types [:llm_response, :agent_response, :tool_result, :tool_error,
                :thinking_chunk, :agent_message, :signal_classified, :llm_chunk]

    test "TUI-visible event types are delivered to osa:tui:output subscribers" do
      PubSub.subscribe_tui_output()
      Enum.each(@tui_types, fn t ->
        event = %{type: t, text: "payload"}
        PubSub.broadcast_event(event)
        assert_receive {:osa_event, ^event}, 500,
          "Expected TUI event for type #{t}"
      end)
    end

    test "non-TUI event type is NOT delivered to osa:tui:output subscribers" do
      PubSub.subscribe_tui_output()
      event = %{type: :agent_started, session_id: "x"}
      PubSub.broadcast_event(event)
      refute_receive {:osa_event, _}, 100
    end
  end
end
