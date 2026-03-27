defmodule OptimalSystemAgent.Tools.Builtins.YawlProcessMiningTest do
  @moduledoc """
  Tests for the YawlProcessMining tool.

  Two categories of tests:

  1. Pure XES parsing — exercises the internal :xmerl_scan pipeline without any
     HTTP calls by calling execute/1 with mocked HTTP via Bandit servers.

  2. HTTP path tests — two Bandit servers (YAWL logGateway mock + pm4py-rust mock)
     are started per describe block. YAWL_ENGINE_URL and PM4PY_HTTP_URL are
     overridden for the duration of each test.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Tools.Builtins.YawlProcessMining

  # ──────────────────────────────────────────────────────────────────────────
  # Sample XES XML (minimal, valid for :xmerl_scan)
  # ──────────────────────────────────────────────────────────────────────────

  @sample_xes """
  <?xml version="1.0" encoding="UTF-8"?>
  <log xmlns="http://www.xes-standard.org/" xes.version="1.0">
    <trace>
      <string key="concept:name" value="case1"/>
      <event>
        <string key="concept:name" value="TaskA"/>
        <date key="time:timestamp" value="2024-01-01T10:00:00Z"/>
      </event>
      <event>
        <string key="concept:name" value="TaskB"/>
        <date key="time:timestamp" value="2024-01-01T11:00:00Z"/>
      </event>
    </trace>
    <trace>
      <string key="concept:name" value="case2"/>
      <event>
        <string key="concept:name" value="TaskA"/>
        <date key="time:timestamp" value="2024-01-02T10:00:00Z"/>
      </event>
    </trace>
  </log>
  """

  # ──────────────────────────────────────────────────────────────────────────
  # Bandit mock helpers
  # ──────────────────────────────────────────────────────────────────────────

  defmodule MockYawlLogGateway do
    @moduledoc "Returns a valid XES log for any spec."
    use Plug.Router
    plug :match
    plug :dispatch

    get "/logGateway" do
      xes = OptimalSystemAgent.Tools.Builtins.YawlProcessMiningTest.sample_xes()

      conn
      |> put_resp_content_type("text/xml")
      |> send_resp(200, xes)
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  defmodule MockYawlLogGateway404 do
    @moduledoc "Simulates a 404 from YAWL (spec not found)."
    use Plug.Router
    plug :match
    plug :dispatch

    get "/logGateway" do
      send_resp(conn, 404, "Spec not found")
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  defmodule MockPm4pyDiscover do
    @moduledoc "Returns a mock Petri net from pm4py /api/discovery/alpha."
    use Plug.Router
    plug Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason
    plug :match
    plug :dispatch

    post "/api/discovery/alpha" do
      response = Jason.encode!(%{
        "model" => %{
          "places" => ["start", "p1", "end"],
          "transitions" => ["TaskA", "TaskB"],
          "arcs" => [["start", "TaskA"], ["TaskA", "p1"], ["p1", "TaskB"], ["TaskB", "end"]]
        },
        "metadata" => %{"algorithm" => "alpha_miner"}
      })

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, response)
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  defmodule MockPm4pyStatistics do
    @moduledoc "Returns mock statistics from pm4py /api/statistics."
    use Plug.Router
    plug Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason
    plug :match
    plug :dispatch

    post "/api/statistics" do
      response = Jason.encode!(%{
        "case_count" => 2,
        "activity_count" => 2,
        "activities" => [%{"name" => "TaskA", "count" => 2}, %{"name" => "TaskB", "count" => 1}]
      })

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, response)
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  defmodule MockPm4pyUnavailable do
    @moduledoc "Simulates pm4py returning a 503."
    use Plug.Router
    plug :match
    plug :dispatch

    post "/api/discovery/alpha" do
      send_resp(conn, 503, "Service Unavailable")
    end

    match _ do
      send_resp(conn, 503, "Service Unavailable")
    end
  end

  # Expose sample XES so nested modules can call it.
  def sample_xes, do: @sample_xes

  defp start_mock(plug_module) do
    # Use port 0 to let the OS assign a free port, then read the actual port back.
    {:ok, server} = Bandit.start_link(plug: plug_module, port: 0, ip: :loopback)
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    "http://127.0.0.1:#{port}"
  end

  defp with_env(vars, fun) do
    old = Enum.map(vars, fn {k, _} -> {k, System.get_env(k)} end)

    Enum.each(vars, fn {k, v} -> System.put_env(k, v) end)

    try do
      fun.()
    after
      Enum.each(old, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Parameter validation — pure logic, no HTTP
  # ──────────────────────────────────────────────────────────────────────────

  describe "parameter validation (no HTTP)" do
    test "missing operation and spec_id returns error" do
      assert {:error, msg} = YawlProcessMining.execute(%{})
      assert is_binary(msg)
      assert msg =~ "Missing"
    end

    test "missing spec_id returns error" do
      assert {:error, msg} = YawlProcessMining.execute(%{"operation" => "discover"})
      assert is_binary(msg)
    end

    test "invalid operation returns error without hitting YAWL" do
      System.put_env("YAWL_ENGINE_URL", "http://127.0.0.1:1")

      try do
        assert {:error, msg} =
                 YawlProcessMining.execute(%{
                   "operation" => "explode",
                   "spec_id" => "SomeSpec:1.0"
                 })

        assert msg =~ "Invalid operation"
      after
        System.delete_env("YAWL_ENGINE_URL")
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # discover operation — full HTTP chain
  # ──────────────────────────────────────────────────────────────────────────

  describe "discover operation with mocked YAWL + pm4py" do
    setup do
      yawl_url = start_mock(MockYawlLogGateway)
      pm4py_url = start_mock(MockPm4pyDiscover)
      {:ok, yawl_url: yawl_url, pm4py_url: pm4py_url}
    end

    test "returns {:ok, result} with petri_net key", %{yawl_url: yawl_url, pm4py_url: pm4py_url} do
      with_env([{"YAWL_ENGINE_URL", yawl_url}, {"PM4PY_HTTP_URL", pm4py_url}], fn ->
        assert {:ok, result} =
                 YawlProcessMining.execute(%{
                   "operation" => "discover",
                   "spec_id" => "TestSpec:1.0"
                 })

        assert Map.has_key?(result, "petri_net"),
               "Expected petri_net in result, got: #{inspect(Map.keys(result))}"
      end)
    end

    test "result includes trace_count and algorithm", %{yawl_url: yawl_url, pm4py_url: pm4py_url} do
      with_env([{"YAWL_ENGINE_URL", yawl_url}, {"PM4PY_HTTP_URL", pm4py_url}], fn ->
        assert {:ok, result} =
                 YawlProcessMining.execute(%{
                   "operation" => "discover",
                   "spec_id" => "TestSpec:1.0"
                 })

        assert is_integer(result["trace_count"])
        assert result["trace_count"] >= 1
        assert is_binary(result["algorithm"])
      end)
    end

    test "custom algorithm is forwarded", %{yawl_url: yawl_url, pm4py_url: pm4py_url} do
      with_env([{"YAWL_ENGINE_URL", yawl_url}, {"PM4PY_HTTP_URL", pm4py_url}], fn ->
        assert {:ok, result} =
                 YawlProcessMining.execute(%{
                   "operation" => "discover",
                   "spec_id" => "TestSpec:1.0",
                   "algorithm" => "inductive_miner"
                 })

        # The algorithm field in the result should reflect what was requested
        assert result["algorithm"] == "inductive_miner"
      end)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # get_statistics operation — full HTTP chain
  # ──────────────────────────────────────────────────────────────────────────

  describe "get_statistics operation with mocked YAWL + pm4py" do
    setup do
      yawl_url = start_mock(MockYawlLogGateway)
      pm4py_url = start_mock(MockPm4pyStatistics)
      {:ok, yawl_url: yawl_url, pm4py_url: pm4py_url}
    end

    test "returns {:ok, result} with case_count", %{yawl_url: yawl_url, pm4py_url: pm4py_url} do
      with_env([{"YAWL_ENGINE_URL", yawl_url}, {"PM4PY_HTTP_URL", pm4py_url}], fn ->
        assert {:ok, result} =
                 YawlProcessMining.execute(%{
                   "operation" => "get_statistics",
                   "spec_id" => "TestSpec:1.0"
                 })

        assert Map.has_key?(result, "case_count") or Map.has_key?(result, "trace_count"),
               "Expected case_count or trace_count in #{inspect(Map.keys(result))}"
      end)
    end

    test "result always has trace_count and event_count (supplemented locally)",
         %{yawl_url: yawl_url, pm4py_url: pm4py_url} do
      with_env([{"YAWL_ENGINE_URL", yawl_url}, {"PM4PY_HTTP_URL", pm4py_url}], fn ->
        assert {:ok, result} =
                 YawlProcessMining.execute(%{
                   "operation" => "get_statistics",
                   "spec_id" => "TestSpec:1.0"
                 })

        # YawlProcessMining supplements trace_count / event_count locally
        assert Map.has_key?(result, "trace_count")
        assert Map.has_key?(result, "event_count")
      end)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # YAWL unavailable
  # ──────────────────────────────────────────────────────────────────────────

  describe "YAWL engine unavailable" do
    test "returns {:error, _} with clear message when YAWL is unreachable" do
      with_env(
        [{"YAWL_ENGINE_URL", "http://127.0.0.1:19998"}, {"PM4PY_HTTP_URL", "http://127.0.0.1:19997"}],
        fn ->
          assert {:error, msg} =
                   YawlProcessMining.execute(%{
                     "operation" => "discover",
                     "spec_id" => "TestSpec:1.0"
                   })

          assert is_binary(msg)
          # Should mention YAWL or connection in the error message
          assert msg =~ "YAWL" or msg =~ "Connection" or msg =~ "refused" or msg =~ "failed"
        end
      )
    end

    test "returns {:error, _} when YAWL returns 404 (spec not found)" do
      yawl_url = start_mock(MockYawlLogGateway404)

      with_env(
        [{"YAWL_ENGINE_URL", yawl_url}, {"PM4PY_HTTP_URL", "http://127.0.0.1:19997"}],
        fn ->
          assert {:error, msg} =
                   YawlProcessMining.execute(%{
                     "operation" => "discover",
                     "spec_id" => "MissingSpec:0.0"
                   })

          assert is_binary(msg)
        end
      )
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # pm4py-rust unavailable
  # ──────────────────────────────────────────────────────────────────────────

  describe "pm4py-rust unavailable" do
    setup do
      yawl_url = start_mock(MockYawlLogGateway)
      {:ok, yawl_url: yawl_url}
    end

    test "returns {:error, _} when pm4py-rust is not reachable", %{yawl_url: yawl_url} do
      with_env(
        [{"YAWL_ENGINE_URL", yawl_url}, {"PM4PY_HTTP_URL", "http://127.0.0.1:19996"}],
        fn ->
          assert {:error, msg} =
                   YawlProcessMining.execute(%{
                     "operation" => "discover",
                     "spec_id" => "TestSpec:1.0"
                   })

          assert is_binary(msg)
          assert msg =~ "pm4py" or msg =~ "Connection" or msg =~ "refused" or msg =~ "failed"
        end
      )
    end

    test "returns {:error, _} when pm4py-rust returns 503", %{yawl_url: yawl_url} do
      pm4py_url = start_mock(MockPm4pyUnavailable)

      with_env(
        [{"YAWL_ENGINE_URL", yawl_url}, {"PM4PY_HTTP_URL", pm4py_url}],
        fn ->
          assert {:error, msg} =
                   YawlProcessMining.execute(%{
                     "operation" => "discover",
                     "spec_id" => "TestSpec:1.0"
                   })

          assert is_binary(msg)
        end
      )
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Tool metadata
  # ──────────────────────────────────────────────────────────────────────────

  describe "tool metadata" do
    test "name is yawl_process_mining" do
      assert YawlProcessMining.name() == "yawl_process_mining"
    end

    test "safety is sandboxed" do
      assert YawlProcessMining.safety() == :sandboxed
    end

    test "parameters schema includes operation and spec_id as required" do
      params = YawlProcessMining.parameters()
      assert params["type"] == "object"
      assert Map.has_key?(params["properties"], "operation")
      assert Map.has_key?(params["properties"], "spec_id")
      assert "operation" in params["required"]
      assert "spec_id" in params["required"]
    end
  end
end
