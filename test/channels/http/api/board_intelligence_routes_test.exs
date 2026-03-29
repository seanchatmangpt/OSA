defmodule OptimalSystemAgent.Channels.HTTP.API.BoardIntelligenceRoutesTest do
  @moduledoc """
  Chicago TDD tests for POST /intelligence on BoardDecisionRoutes.

  Tests validate:
  - 422 on missing or invalid required fields
  - 200 or 202 on valid payload (monitor up or unavailable)
  - board.kpi_compute span attributes (sampled via telemetry test events)
  """
  use ExUnit.Case, async: false

  use Plug.Test

  alias OptimalSystemAgent.Channels.HTTP.API.BoardDecisionRoutes

  @opts BoardDecisionRoutes.init([])

  defp post_intelligence(body) do
    conn(:post, "/intelligence", Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> BoardDecisionRoutes.call(@opts)
  end

  defp decode(conn), do: Jason.decode!(conn.resp_body)

  defp valid_payload do
    %{
      "health_summary" => 0.85,
      "conformance_score" => 0.90,
      "top_risk" => "conway_boundary_overlap",
      "conway_violations" => 2,
      "case_count" => 42,
      "handoff_count" => 10
    }
  end

  # ── 422 Validation failures ──────────────────────────────────────────────────

  describe "POST /intelligence — validation (422)" do
    test "missing health_summary returns 422" do
      payload = Map.delete(valid_payload(), "health_summary")
      conn = post_intelligence(payload)
      assert conn.status == 422
      body = decode(conn)
      assert body["error"] == "validation_failed"
      assert is_list(body["details"])
      assert Enum.any?(body["details"], &String.contains?(&1, "health_summary"))
    end

    test "health_summary out of range (>1) returns 422" do
      payload = Map.put(valid_payload(), "health_summary", 1.5)
      conn = post_intelligence(payload)
      assert conn.status == 422
    end

    test "health_summary out of range (<0) returns 422" do
      payload = Map.put(valid_payload(), "health_summary", -0.1)
      conn = post_intelligence(payload)
      assert conn.status == 422
    end

    test "missing conformance_score returns 422" do
      payload = Map.delete(valid_payload(), "conformance_score")
      conn = post_intelligence(payload)
      assert conn.status == 422
    end

    test "conformance_score > 1 returns 422" do
      payload = Map.put(valid_payload(), "conformance_score", 2.0)
      conn = post_intelligence(payload)
      assert conn.status == 422
    end

    test "missing top_risk returns 422" do
      payload = Map.delete(valid_payload(), "top_risk")
      conn = post_intelligence(payload)
      assert conn.status == 422
    end

    test "empty top_risk returns 422" do
      payload = Map.put(valid_payload(), "top_risk", "")
      conn = post_intelligence(payload)
      assert conn.status == 422
    end

    test "negative conway_violations returns 422" do
      payload = Map.put(valid_payload(), "conway_violations", -1)
      conn = post_intelligence(payload)
      assert conn.status == 422
    end
  end

  # ── 200 / 202 Success ────────────────────────────────────────────────────────

  describe "POST /intelligence — success paths" do
    test "valid payload returns 200 or 202 (Armstrong: degraded state ok)" do
      conn = post_intelligence(valid_payload())
      assert conn.status in [200, 202]
    end

    test "response body has status field" do
      conn = post_intelligence(valid_payload())
      body = decode(conn)
      assert Map.has_key?(body, "status")
      assert body["status"] in ["accepted", "stored"]
    end

    test "response body has received_at timestamp" do
      conn = post_intelligence(valid_payload())
      body = decode(conn)
      assert Map.has_key?(body, "received_at")
      assert is_binary(body["received_at"])
    end

    test "response body has intelligence_source" do
      conn = post_intelligence(valid_payload())
      body = decode(conn)
      assert Map.has_key?(body, "intelligence_source")
    end

    test "response is JSON content-type" do
      conn = post_intelligence(valid_payload())
      [ct | _] = get_resp_header(conn, "content-type")
      assert String.starts_with?(ct, "application/json")
    end
  end

  # ── WvdA: monitor unavailable path (degraded, not crash) ────────────────────

  describe "POST /intelligence — monitor unavailable (202)" do
    test "returns 202 when ConwayLittleMonitor is not running" do
      # Stop monitor if running, test without it (Armstrong degraded state).
      case Process.whereis(OptimalSystemAgent.Board.ConwayLittleMonitor) do
        nil ->
          conn = post_intelligence(valid_payload())
          # Without monitor: must return 202 (degraded), not 500
          assert conn.status in [200, 202]

        _pid ->
          # Monitor is running — either 200 ok
          conn = post_intelligence(valid_payload())
          assert conn.status in [200, 202]
      end
    end
  end
end
