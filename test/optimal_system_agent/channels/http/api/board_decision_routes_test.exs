defmodule OptimalSystemAgent.Channels.HTTP.API.BoardDecisionRoutesTest do
  @moduledoc """
  Chicago TDD tests for BoardDecisionRoutes Plug router.

  Covers:
  - POST /intelligence — board intelligence ingest (calls ConwayLittleMonitor.inject_board_intelligence/1)
  - POST /decision    — board chair decision recording
  - GET  /briefing    — briefing retrieval (smoke test)
  - GET  /decisions   — decisions listing (smoke test)
  - Catch-all 404

  Uses Plug.Test directly. BoardDecisionRoutes includes its own Plug.Parsers,
  so we pass raw JSON bodies with content-type header.

  The :requires_application test (ConwayLittleMonitor state persistence) is
  tagged accordingly and excluded from the default `mix test` run per
  test_helper.exs.

  WvdA: Independent tests, no shared state, bounded.
  Armstrong: Each test sets up its own preconditions.
  Chicago TDD: Every assertion directly captures the claim being tested.
  """

  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias OptimalSystemAgent.Channels.HTTP.API.BoardDecisionRoutes

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp json_post(path, body_map) do
    encoded = Jason.encode!(body_map)

    conn(:post, path, encoded)
    |> put_req_header("content-type", "application/json")
    |> BoardDecisionRoutes.call([])
  end

  defp json_get(path) do
    conn(:get, path)
    |> BoardDecisionRoutes.call([])
  end

  # ---------------------------------------------------------------------------
  # POST /intelligence — valid payload
  # ---------------------------------------------------------------------------

  describe "POST /intelligence with valid payload" do
    test "returns 200 or 202 when all required fields are present" do
      # 202 is returned when ConwayLittleMonitor is not running (degraded mode).
      # 200 is returned when the monitor is running and accepts the payload.
      # Both are success responses — intelligence was received.
      conn = json_post("/intelligence", %{
        "health_summary" => 0.85,
        "conformance_score" => 0.9,
        "top_risk" => "supply chain delay",
        "conway_violations" => 2,
        "case_count" => 50,
        "handoff_count" => 10
      })

      assert conn.status in [200, 202]

      ct = conn.resp_headers |> List.keyfind("content-type", 0) |> elem(1)
      assert ct =~ "application/json"
    end

    test "response body contains status field on success" do
      conn = json_post("/intelligence", %{
        "health_summary" => 0.75,
        "conformance_score" => 0.8,
        "top_risk" => "process bottleneck",
        "conway_violations" => 0
      })

      assert conn.status in [200, 202]
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "status")
      assert body["status"] in ["accepted", "stored"]
    end

    test "response body contains received_at timestamp on success" do
      conn = json_post("/intelligence", %{
        "health_summary" => 0.6,
        "conformance_score" => 0.7,
        "top_risk" => "team misalignment",
        "conway_violations" => 1
      })

      assert conn.status in [200, 202]
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "received_at")
      assert is_binary(body["received_at"])
    end

    test "intelligence_source defaults to business_os when not provided" do
      conn = json_post("/intelligence", %{
        "health_summary" => 1.0,
        "conformance_score" => 1.0,
        "top_risk" => "minor latency spike",
        "conway_violations" => 0
      })

      assert conn.status in [200, 202]
      body = Jason.decode!(conn.resp_body)
      assert body["intelligence_source"] == "business_os"
    end

    test "custom intelligence_source is echoed in response" do
      conn = json_post("/intelligence", %{
        "health_summary" => 0.9,
        "conformance_score" => 0.95,
        "top_risk" => "none",
        "conway_violations" => 0,
        "intelligence_source" => "canopy_pipeline"
      })

      assert conn.status in [200, 202]
      body = Jason.decode!(conn.resp_body)
      assert body["intelligence_source"] == "canopy_pipeline"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /intelligence — missing required fields (422)
  # ---------------------------------------------------------------------------

  describe "POST /intelligence with missing required fields" do
    test "returns 422 when body is empty JSON object" do
      conn = json_post("/intelligence", %{})

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "validation_failed"
      assert is_list(body["details"])
      assert length(body["details"]) > 0
    end

    test "returns 422 when health_summary is missing" do
      conn = json_post("/intelligence", %{
        "conformance_score" => 0.8,
        "top_risk" => "overload",
        "conway_violations" => 0
      })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "validation_failed"
      assert Enum.any?(body["details"], &String.contains?(&1, "health_summary"))
    end

    test "returns 422 when conformance_score is missing" do
      conn = json_post("/intelligence", %{
        "health_summary" => 0.8,
        "top_risk" => "overload",
        "conway_violations" => 0
      })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "validation_failed"
      assert Enum.any?(body["details"], &String.contains?(&1, "conformance_score"))
    end

    test "returns 422 when top_risk is missing" do
      conn = json_post("/intelligence", %{
        "health_summary" => 0.8,
        "conformance_score" => 0.9,
        "conway_violations" => 0
      })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "validation_failed"
      assert Enum.any?(body["details"], &String.contains?(&1, "top_risk"))
    end

    test "returns 422 when conway_violations is missing" do
      conn = json_post("/intelligence", %{
        "health_summary" => 0.8,
        "conformance_score" => 0.9,
        "top_risk" => "queue growth"
      })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "validation_failed"
      assert Enum.any?(body["details"], &String.contains?(&1, "conway_violations"))
    end

    test "returns 422 when health_summary is out of [0, 1] range" do
      conn = json_post("/intelligence", %{
        "health_summary" => 1.5,
        "conformance_score" => 0.9,
        "top_risk" => "overload",
        "conway_violations" => 0
      })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "validation_failed"
    end

    test "returns 422 when conway_violations is negative" do
      conn = json_post("/intelligence", %{
        "health_summary" => 0.8,
        "conformance_score" => 0.9,
        "top_risk" => "drift",
        "conway_violations" => -1
      })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "validation_failed"
    end

    test "returns 422 when top_risk is an empty string" do
      conn = json_post("/intelligence", %{
        "health_summary" => 0.8,
        "conformance_score" => 0.9,
        "top_risk" => "",
        "conway_violations" => 0
      })

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "validation_failed"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /intelligence — ConwayLittleMonitor state (requires running app)
  # ---------------------------------------------------------------------------

  describe "POST /intelligence persists intelligence via ConwayLittleMonitor" do
    @describetag :requires_application

    test "returns 200 when ConwayLittleMonitor is running and accepts the payload" do
      # Full application must be started for ConwayLittleMonitor to be registered.
      assert Process.whereis(OptimalSystemAgent.Board.ConwayLittleMonitor),
             "ConwayLittleMonitor must be running (requires full app boot)"

      conn = json_post("/intelligence", %{
        "health_summary" => 0.7,
        "conformance_score" => 0.85,
        "top_risk" => "org boundary bottleneck",
        "conway_violations" => 3,
        "case_count" => 100
      })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "accepted"
    end

    test "inject_board_intelligence returns :ok when monitor is running" do
      alias OptimalSystemAgent.Board.ConwayLittleMonitor

      assert Process.whereis(ConwayLittleMonitor),
             "ConwayLittleMonitor must be running"

      intel = %{
        health_summary: 0.8,
        conformance_score: 0.9,
        top_risk: "minor risk",
        conway_violations: 0,
        case_count: 20,
        handoff_count: 5,
        received_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      result = ConwayLittleMonitor.inject_board_intelligence(intel)
      assert result == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # POST /decision — valid payload
  # ---------------------------------------------------------------------------

  describe "POST /decision with valid payload" do
    @describetag :requires_application

    test "returns 200 with status recorded for reorganize decision" do
      conn = json_post("/decision", %{
        "department" => "Engineering",
        "decision_type" => "reorganize",
        "notes" => "reduce cross-team coupling"
      })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "recorded"
      assert body["department"] == "Engineering"
      assert body["decision_type"] == "reorganize"
    end

    test "returns 200 for add_liaison decision type" do
      conn = json_post("/decision", %{
        "department" => "Operations",
        "decision_type" => "add_liaison"
      })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "recorded"
    end

    test "returns 200 for accept_constraint decision type" do
      conn = json_post("/decision", %{
        "department" => "Finance",
        "decision_type" => "accept_constraint",
        "notes" => "boundary accepted for Q2"
      })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "recorded"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /decision — invalid/missing fields (400)
  # ---------------------------------------------------------------------------

  describe "POST /decision with missing required fields" do
    test "returns 400 when body is empty JSON" do
      conn = json_post("/decision", %{})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "required"
    end

    test "returns 400 when department is missing" do
      conn = json_post("/decision", %{"decision_type" => "reorganize"})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "error")
    end

    test "returns 400 when decision_type is missing" do
      conn = json_post("/decision", %{"department" => "Engineering"})

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "error")
    end

    test "returns 400 for invalid decision_type" do
      conn = json_post("/decision", %{
        "department" => "Engineering",
        "decision_type" => "dissolve"
      })

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "invalid decision_type"
      assert is_list(body["valid_types"])
      assert "reorganize" in body["valid_types"]
    end

    test "response includes valid_types list on invalid type" do
      conn = json_post("/decision", %{
        "department" => "HR",
        "decision_type" => "fire_everyone"
      })

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert is_list(body["valid_types"])
      assert length(body["valid_types"]) == 3
    end

    test "returns 400 when department is empty string" do
      conn = json_post("/decision", %{
        "department" => "",
        "decision_type" => "reorganize"
      })

      assert conn.status == 400
    end
  end

  # ---------------------------------------------------------------------------
  # GET /briefing — smoke test
  # ---------------------------------------------------------------------------

  describe "GET /briefing" do
    test "returns 200 or 404 with JSON body" do
      conn = json_get("/briefing")

      assert conn.status in [200, 404]
      ct = conn.resp_headers |> List.keyfind("content-type", 0) |> elem(1)
      assert ct =~ "application/json"
      body = Jason.decode!(conn.resp_body)
      assert is_map(body)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /decisions — smoke test
  # ---------------------------------------------------------------------------

  describe "GET /decisions" do
    @describetag :requires_application

    test "returns 200 with a list" do
      conn = json_get("/decisions")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert is_list(body)
    end
  end

  # ---------------------------------------------------------------------------
  # Catch-all
  # ---------------------------------------------------------------------------

  describe "catch-all route" do
    test "returns 404 for unknown path" do
      conn = json_get("/nonexistent-path")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "not_found"
    end

    test "returns 404 for unknown POST path" do
      conn = json_post("/unknown-endpoint", %{})

      assert conn.status == 404
    end
  end
end
