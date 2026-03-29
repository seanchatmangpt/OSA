defmodule OptimalSystemAgent.Channels.HTTP.API.OcelRoutesTest do
  @moduledoc """
  Chicago TDD tests for OcelRoutes Plug router.

  Uses Plug.Test to call routes directly without a running HTTP server.
  OcelCollector ETS tables are initialised via OcelCollector.init_tables/0
  so routes that query :ocel_events / :ocel_objects are safe to call.
  """
  use ExUnit.Case, async: false

  import Plug.Test

  alias OptimalSystemAgent.Channels.HTTP.API.OcelRoutes
  alias OptimalSystemAgent.ProcessMining.OcelCollector

  setup do
    # Ensure ETS tables exist (may already be set up by Application if running full suite)
    OcelCollector.init_tables()
    :ok
  end

  # ---------------------------------------------------------------------------
  # GET /export
  # ---------------------------------------------------------------------------

  describe "GET /export" do
    test "returns 200 with events and objects keys" do
      conn =
        conn(:get, "/export")
        |> OcelRoutes.call([])

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "events")
      assert Map.has_key?(body, "objects")
    end

    test "response body is valid JSON with objectTypes list" do
      conn =
        conn(:get, "/export")
        |> OcelRoutes.call([])

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert is_list(body["events"])
      assert is_list(body["objects"])
      assert is_list(body["objectTypes"])
    end
  end

  # ---------------------------------------------------------------------------
  # GET /export/:session_id
  # ---------------------------------------------------------------------------

  describe "GET /export/:session_id" do
    test "returns 200 filtered JSON for a given session_id" do
      conn =
        conn(:get, "/export/test-session-abc")
        |> OcelRoutes.call([])

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert is_list(body["events"])
      assert is_list(body["objects"])
    end

    test "returns 200 with empty events list for unknown session_id" do
      conn =
        conn(:get, "/export/nonexistent-session-xyz")
        |> OcelRoutes.call([])

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["events"] == []
    end
  end

  # ---------------------------------------------------------------------------
  # GET /status
  # ---------------------------------------------------------------------------

  describe "GET /status" do
    test "returns 200 with event_count and object_count" do
      conn =
        conn(:get, "/status")
        |> OcelRoutes.call([])

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "event_count")
      assert Map.has_key?(body, "object_count")
      assert is_integer(body["event_count"])
      assert is_integer(body["object_count"])
    end

    test "event_count and object_count are non-negative" do
      conn =
        conn(:get, "/status")
        |> OcelRoutes.call([])

      body = Jason.decode!(conn.resp_body)
      assert body["event_count"] >= 0
      assert body["object_count"] >= 0
    end
  end

  # ---------------------------------------------------------------------------
  # Catch-all
  # ---------------------------------------------------------------------------

  describe "catch-all route" do
    test "returns 404 for unknown path" do
      conn =
        conn(:get, "/does-not-exist")
        |> OcelRoutes.call([])

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "not_found"
    end
  end
end
