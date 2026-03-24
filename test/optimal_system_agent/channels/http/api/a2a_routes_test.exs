defmodule OptimalSystemAgent.Channels.HTTP.API.A2ARoutesTest do
  @moduledoc """
  Tests for A2ARoutes Plug router.

  Uses Plug.Test for HTTP-level testing. Tests route matching,
  response codes, JSON structure, and error handling.

  NOTE: A2ARoutes is normally mounted under the parent API router which
  provides Plug.Parsers. For tests we parse the body manually and
  focus on GET routes and the catch-all route.
  """
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias OptimalSystemAgent.Channels.HTTP.API.A2ARoutes

  # ---------------------------------------------------------------------------
  # GET /agent-card
  # ---------------------------------------------------------------------------

  describe "GET /agent-card" do
    test "returns 200 with agent card JSON" do
      conn =
        conn(:get, "/agent-card")
        |> A2ARoutes.call([])

      assert conn.status == 200
      # Plug.Router stores content-type as "content-type" header
      ct = conn.resp_headers |> List.keyfind("content-type", 0) |> elem(1)
      assert ct =~ "application/json"

      body = Jason.decode!(conn.resp_body)
      assert body["name"] == "osa-agent"
      assert body["display_name"] == "OSA Agent"
      assert body["description"] =~ "Optimal System Architecture"
      assert is_list(body["capabilities"])
      assert "streaming" in body["capabilities"]
      assert "tools" in body["capabilities"]
      assert "stateless" in body["capabilities"]
    end

    test "agent card includes input_schema" do
      conn =
        conn(:get, "/agent-card")
        |> A2ARoutes.call([])

      body = Jason.decode!(conn.resp_body)
      assert body["input_schema"]["type"] == "object"
      assert "message" in body["input_schema"]["required"]
    end

    test "agent card includes url" do
      conn =
        conn(:get, "/agent-card")
        |> A2ARoutes.call([])

      body = Jason.decode!(conn.resp_body)
      assert String.contains?(body["url"], "/a2a")
    end

    test "agent card includes version" do
      conn =
        conn(:get, "/agent-card")
        |> A2ARoutes.call([])

      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["version"])
    end
  end

  # ---------------------------------------------------------------------------
  # GET /agents
  # ---------------------------------------------------------------------------

  describe "GET /agents" do
    test "returns 200 with agents list" do
      conn =
        conn(:get, "/agents")
        |> A2ARoutes.call([])

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert is_list(body["agents"])
      assert length(body["agents"]) >= 1

      [agent | _] = body["agents"]
      assert agent["name"] == "osa-main"
      assert agent["display_name"] == "OSA Main Agent"
      assert is_list(agent["capabilities"])
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tools
  # ---------------------------------------------------------------------------

  describe "GET /tools" do
    test "returns 200 with tools list structure" do
      conn =
        conn(:get, "/tools")
        |> A2ARoutes.call([])

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "tools")
      assert is_list(body["tools"])
    end
  end

  # ---------------------------------------------------------------------------
  # GET /servers
  # ---------------------------------------------------------------------------

  describe "GET /servers" do
    test "returns 200 with servers list structure" do
      conn =
        conn(:get, "/servers")
        |> A2ARoutes.call([])

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "servers")
      assert is_list(body["servers"])
    end
  end

  # ---------------------------------------------------------------------------
  # Catch-all route
  # ---------------------------------------------------------------------------

  describe "catch-all route" do
    test "returns 404 for unknown GET paths" do
      conn =
        conn(:get, "/nonexistent")
        |> A2ARoutes.call([])

      assert conn.status == 404

      resp = Jason.decode!(conn.resp_body)
      assert resp["error"] == "not_found"
      assert String.contains?(resp["details"], "A2A endpoint not found")
    end

    test "returns 404 for unknown POST paths" do
      conn =
        conn(:post, "/nonexistent/endpoint")
        |> A2ARoutes.call([])

      assert conn.status == 404
    end

    test "returns 404 for DELETE to unknown paths" do
      conn =
        conn(:delete, "/something")
        |> A2ARoutes.call([])

      assert conn.status == 404
    end
  end

  # ---------------------------------------------------------------------------
  # POST / -- requires Plug.Parsers from parent router
  # ---------------------------------------------------------------------------

  describe "POST / (body_params not available without Parsers)" do
    test "POST / with no parsers returns 400 for unrecognized body" do
      # Without Plug.Parsers, body_params defaults to %{}
      # which falls through to the 400 invalid_request handler
      conn =
        conn(:post, "/", "")
        |> A2ARoutes.call([])

      assert conn.status == 400

      resp = Jason.decode!(conn.resp_body)
      assert resp["error"] == "invalid_request"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tools/:name -- requires Plug.Parsers
  # ---------------------------------------------------------------------------

  describe "POST /tools/:name" do
    test "POST to tools endpoint without parsers returns 422" do
      # body_params is empty without Plug.Parsers, so tool execution fails
      conn =
        conn(:post, "/tools/nonexistent_tool", "")
        |> A2ARoutes.call([])

      # Will get 422 because the tool is not found
      assert conn.status == 422

      resp = Jason.decode!(conn.resp_body)
      assert resp["error"] == "tool_error"
    end
  end
end
