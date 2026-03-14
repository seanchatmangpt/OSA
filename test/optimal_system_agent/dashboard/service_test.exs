defmodule OptimalSystemAgent.Dashboard.ServiceTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Dashboard.Service

  describe "summary/0" do
    test "returns map with all required top-level keys" do
      result = Service.summary()

      assert is_map(result)
      assert Map.has_key?(result, :kpis)
      assert Map.has_key?(result, :active_agents)
      assert Map.has_key?(result, :recent_activity)
      assert Map.has_key?(result, :system_health)
    end

    test "kpis contains all expected numeric fields" do
      %{kpis: kpis} = Service.summary()

      assert is_integer(kpis.active_sessions)
      assert is_integer(kpis.agents_online)
      assert is_integer(kpis.agents_total)
      assert is_integer(kpis.signals_today)
      assert is_integer(kpis.tasks_completed)
      assert is_integer(kpis.tasks_pending)
      assert is_integer(kpis.tokens_used_today)
      assert is_integer(kpis.uptime_seconds)
    end

    test "kpis values are non-negative" do
      %{kpis: kpis} = Service.summary()

      assert kpis.active_sessions >= 0
      assert kpis.agents_online >= 0
      assert kpis.agents_total >= 0
      assert kpis.tasks_pending >= 0
      assert kpis.tokens_used_today >= 0
      assert kpis.uptime_seconds >= 0
    end

    test "active_agents is a list of maps with required fields" do
      %{active_agents: agents} = Service.summary()
      assert is_list(agents)

      for agent <- agents do
        assert is_binary(agent.name)
        assert agent.status in ["idle", "running", "paused", "queued", "done", "error", "leased"]
      end
    end

    test "recent_activity is a list of maps with required fields" do
      %{recent_activity: activity} = Service.summary()
      assert is_list(activity)

      for event <- activity do
        assert is_binary(event.type)
        assert is_binary(event.level)
        assert event.level in ["info", "warning", "error", "debug"]
      end
    end

    test "system_health has valid backend status and positive memory" do
      %{system_health: health} = Service.summary()

      assert health.backend in ["ok", "degraded", "error"]
      assert is_binary(health.provider)
      assert health.provider_status in ["connected", "disconnected"]
      assert is_integer(health.memory_mb)
      assert health.memory_mb > 0
    end

    test "summary is JSON-serializable" do
      result = Service.summary()
      assert {:ok, _json} = Jason.encode(result)
    end

    test "calling summary twice returns consistent structure" do
      s1 = Service.summary()
      s2 = Service.summary()

      assert Map.keys(s1.kpis) == Map.keys(s2.kpis)
      assert Map.keys(s1.system_health) == Map.keys(s2.system_health)
    end
  end
end
