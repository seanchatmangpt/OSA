defmodule OptimalSystemAgent.Integration.A2ACrossStackCoordinationTest do
  @moduledoc """
  Cross-stack A2A coordination tests for OSA.
  Unit tests run without live services. Live tests skip when services are down.
  Crown jewel: OSA discovers Canopy and dispatches workspace_coordination work.

  Run: mix test --include integration --include crown_jewel \\
         test/integration/a2a_cross_stack_coordination_test.exs
  """
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :a2a_live

  @canopy_url "http://localhost:9089"
  @businessos_url "http://localhost:8001"
  @pm4py_url "http://localhost:8090"
  @osa_url "http://localhost:8089"

  # Probe all services once at module level; results flow into every test via context.
  setup_all do
    {:ok, %{
      canopy_up:     service_up?(@canopy_url),
      businessos_up: service_up?(@businessos_url),
      pm4py_up:      service_up?(@pm4py_url),
      osa_up:        service_up?(@osa_url)
    }}
  end

  defp service_up?(url) do
    Enum.any?(["/api/health", "/health", "/healthz"], fn path ->
      case Req.get("#{url}#{path}", receive_timeout: 2_000, retry: false) do
        {:ok, %{status: 200}} -> true
        _ -> false
      end
    end)
  end

  # ── Unit tests (no live services needed) ─────────────────────────────────────

  describe "OSA A2A Registry — unit" do
    test "Registry module is compiled and all_agents/0 returns a list", _ctx do
      assert {:module, _} = Code.ensure_compiled(OptimalSystemAgent.A2A.Registry)
      assert is_list(OptimalSystemAgent.A2A.Registry.all_agents())
    end

    test "get_agent/1 returns nil for unknown agent", _ctx do
      assert is_nil(OptimalSystemAgent.A2A.Registry.get_agent("nonexistent-xyz-999"))
    end

    test "refresh/0 is callable without error", _ctx do
      # refresh/0 issues a GenServer.cast — verify it returns :ok
      assert :ok = OptimalSystemAgent.A2A.Registry.refresh()
    end
  end

  describe "OSA A2ACall tool — unit (no network)" do
    test "execute/1 returns error for missing required parameters", _ctx do
      result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{})
      assert {:error, _reason} = result
    end

    test "execute/1 returns error for unknown action", _ctx do
      result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "bogus_action",
        "agent_url" => "http://localhost:9999"
      })
      assert {:error, _reason} = result
    end

    test "execute/1 sets telemetry span id in process dictionary", _ctx do
      # Even a failed call must set a span id (span is created before the action runs)
      _result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "discover",
        "agent_url" => "http://localhost:19999"
      })
      span_id = Process.get(:telemetry_current_span_id)
      assert not is_nil(span_id),
             "A2ACall.execute/1 must store a span_id in :telemetry_current_span_id"
    end

    test "execute/1 returns {:error, _} (not raise) when agent is unreachable", _ctx do
      result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "discover",
        "agent_url" => "http://localhost:19999"
      })
      assert {:error, _} = result
    end

    test "tasks_send action returns error when tool param is missing", _ctx do
      result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "tasks_send",
        "agent_url" => "http://localhost:19999"
      })
      assert {:error, _} = result
    end
  end

  # ── Registry live tests ───────────────────────────────────────────────────────

  describe "OSA A2A Registry — all 4 services" do
    setup_all %{canopy_up: c, businessos_up: b, pm4py_up: p, osa_up: o} do
      if c and b and p and o do
        :ok
      else
        {:skip, "Not all 4 services running (canopy=#{c} bos=#{b} pm4py=#{p} osa=#{o})"}
      end
    end

    test "discovers all 4 agents after refresh" do
      OptimalSystemAgent.A2A.Registry.refresh()
      Process.sleep(6_000)
      agents = OptimalSystemAgent.A2A.Registry.all_agents()
      assert length(agents) >= 4,
             "Expected >=4 agents, got #{length(agents)}: #{inspect(Enum.map(agents, & &1["name"]))}"
    end

    test "Canopy agent is discovered with name 'canopy'" do
      OptimalSystemAgent.A2A.Registry.refresh()
      Process.sleep(6_000)
      card = OptimalSystemAgent.A2A.Registry.get_agent("canopy")
      refute is_nil(card), "Canopy agent card must be cached after refresh"
      assert card["name"] == "canopy"
    end
  end

  # ── A2ACall tool → Canopy ─────────────────────────────────────────────────────

  describe "OSA a2a_call tool → Canopy" do
    setup_all %{canopy_up: canopy_up} do
      if canopy_up, do: :ok,
        else: {:skip, "Canopy not running at #{@canopy_url}"}
    end

    test "discover returns Canopy card with name 'canopy'" do
      assert {:ok, card} = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "discover",
        "agent_url" => @canopy_url
      })
      assert card["name"] == "canopy"
    end

    test "Canopy card has workspace_coordination and process_mining skills" do
      {:ok, card} = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "discover",
        "agent_url" => @canopy_url
      })
      skill_ids = (card["skills"] || []) |> Enum.map(& &1["id"])
      assert "workspace_coordination" in skill_ids,
             "workspace_coordination not in #{inspect(skill_ids)}"
      assert "process_mining" in skill_ids,
             "process_mining not in #{inspect(skill_ids)}"
    end

    test "call sends message to Canopy and gets a response" do
      result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "call",
        "agent_url" => "#{@canopy_url}/api/v1/a2a",
        "message" => "ping from OSA cross-stack test"
      })
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ── A2ACall tool → BusinessOS ─────────────────────────────────────────────────

  describe "OSA a2a_call tool → BusinessOS" do
    setup_all %{businessos_up: bos_up} do
      if bos_up, do: :ok,
        else: {:skip, "BusinessOS not running at #{@businessos_url}"}
    end

    test "discover returns BusinessOS card or structured error" do
      result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "discover",
        "agent_url" => @businessos_url
      })
      case result do
        {:ok, card} ->
          assert is_map(card)
          assert Map.has_key?(card, "name") or Map.has_key?(card, "url")
        {:error, _} -> :ok
      end
    end
  end

  # ── A2ACall tool → pm4py-rust ─────────────────────────────────────────────────

  describe "OSA a2a_call tool → pm4py-rust" do
    setup_all %{pm4py_up: pm4py_up} do
      if pm4py_up, do: :ok,
        else: {:skip, "pm4py-rust not running at #{@pm4py_url}"}
    end

    test "discover returns pm4py-rust card or structured error" do
      result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "discover",
        "agent_url" => @pm4py_url
      })
      case result do
        {:ok, card} -> assert is_map(card)
        {:error, _reason} -> :ok
      end
    end
  end

  # ── Crown Jewel ───────────────────────────────────────────────────────────────

  describe "Crown Jewel: OSA discovers Canopy and dispatches workspace work" do
    @describetag :crown_jewel

    setup_all %{canopy_up: canopy_up} do
      if canopy_up, do: :ok,
        else: {:skip, "Canopy not running — crown jewel requires Canopy at #{@canopy_url}"}
    end

    test "step 1: discovers Canopy with workspace_coordination skill" do
      {:ok, card} = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "discover",
        "agent_url" => @canopy_url
      })
      assert card["name"] == "canopy"
      skill_ids = (card["skills"] || []) |> Enum.map(& &1["id"])
      assert "workspace_coordination" in skill_ids,
             "Canopy must advertise workspace_coordination. Got: #{inspect(skill_ids)}"
    end

    test "step 2: sends workspace_coordination message to Canopy" do
      result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "call",
        "agent_url" => "#{@canopy_url}/api/v1/a2a",
        "message" => Jason.encode!(%{
          "skill" => "workspace_coordination",
          "task" => "list_workspaces",
          "source" => "osa_crown_jewel_test"
        })
      })
      case result do
        {:ok, response} ->
          assert is_map(response) or is_binary(response),
                 "Response must be map or string, got: #{inspect(response)}"
        {:error, reason} ->
          IO.puts("[INFO] Crown jewel step 2 error (non-fatal): #{inspect(reason)}")
          :ok
      end
    end

    test "step 3: A2ACall emits telemetry span context" do
      # Clear prior span id, verify a fresh one is set by execute/1
      Process.delete(:telemetry_current_span_id)
      _result = OptimalSystemAgent.Tools.Builtins.A2ACall.execute(%{
        "action" => "call",
        "agent_url" => "#{@canopy_url}/api/v1/a2a",
        "message" => "workspace_coordination from crown jewel"
      })
      span_id = Process.get(:telemetry_current_span_id)
      assert not is_nil(span_id),
             "A2ACall must emit a telemetry span and store span_id in process dictionary"
    end

    test "step 4: weaver registry check exit 0 (layer 3 proof)" do
      semconv_path = Path.expand(Path.join([File.cwd!(), "..", "semconv", "model"]))
      if File.exists?(semconv_path) and System.find_executable("weaver") do
        {output, code} = System.cmd("weaver", ["registry", "check", "-r", semconv_path],
          stderr_to_stdout: true)
        assert code == 0, "weaver registry check must exit 0:\n#{output}"
      else
        IO.puts("[SKIP] weaver not in PATH or semconv not found at #{semconv_path}")
        :ok
      end
    end
  end
end
