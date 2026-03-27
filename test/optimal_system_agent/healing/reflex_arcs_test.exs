defmodule OptimalSystemAgent.Healing.ReflexArcsTest do
  @moduledoc """
  Unit tests for Autonomic Nervous System (Innovation 5).

  Tests the GenServer API: log, status, reap_sessions.
  The 5 reflex arcs are event-driven; we test their state management
  and cooldown behavior.
  """
  use ExUnit.Case, async: false

  @moduletag :requires_application

  alias OptimalSystemAgent.Healing.ReflexArcs

  describe "status/0" do
    test "returns status map with required keys" do
      status = ReflexArcs.status()
      assert Map.has_key?(status, :reflex_log)
      assert Map.has_key?(status, :cooldowns)
      assert Map.has_key?(status, :provider_failures)
      assert is_list(status.reflex_log)
      assert is_map(status.cooldowns)
      assert is_map(status.provider_failures)
    end
  end

  describe "log/0" do
    test "returns list of reflex log entries" do
      log = ReflexArcs.log()
      assert is_list(log)
    end
  end

  describe "reap_sessions/0" do
    test "completes without error" do
      # reap_sessions is a cast (async) -- just verify it doesn't crash
      assert :ok = ReflexArcs.reap_sessions()
      # Give it a moment to process
      Process.sleep(100)
    end
  end

  describe "cooldown behavior" do
    test "status shows cooldown state is a map" do
      status = ReflexArcs.status()
      assert is_map(status.cooldowns)
    end
  end
end
