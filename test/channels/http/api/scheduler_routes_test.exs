defmodule OptimalSystemAgent.Channels.HTTP.API.SchedulerRoutesTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias OptimalSystemAgent.Channels.HTTP.API.SchedulerRoutes

  @opts SchedulerRoutes.init([])

  defp call_routes(conn) do
    SchedulerRoutes.call(conn, @opts)
  end

  defp json_get(path) do
    conn(:get, path)
    |> call_routes()
  end

  defp json_post(path, body) do
    conn(:post, path, Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], json_decoder: Jason))
    |> call_routes()
  end

  defp json_put(path, body) do
    conn(:put, path, Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], json_decoder: Jason))
    |> call_routes()
  end

  defp json_delete(path) do
    conn(:delete, path)
    |> call_routes()
  end

  defp decode_body(conn) do
    Jason.decode!(conn.resp_body)
  end

  describe "GET /presets" do
    test "returns 8 cron presets" do
      conn = json_get("/presets")
      assert conn.status == 200

      body = decode_body(conn)
      assert body["status"] == "ok"
      assert length(body["presets"]) == 8
    end

    test "each preset has required fields" do
      conn = json_get("/presets")
      body = decode_body(conn)

      for preset <- body["presets"] do
        assert is_binary(preset["id"])
        assert is_binary(preset["cron"])
        assert is_binary(preset["label"])
      end
    end

    test "presets include next_run timestamps" do
      conn = json_get("/presets")
      body = decode_body(conn)

      for preset <- body["presets"] do
        assert is_binary(preset["next_run"]) or is_nil(preset["next_run"])
      end
    end
  end

  describe "GET /" do
    test "returns task list (may be empty or populated)" do
      conn = json_get("/")

      case conn.status do
        200 ->
          body = decode_body(conn)
          assert body["status"] == "ok"
          assert is_list(body["tasks"])
          assert is_integer(body["count"])

        503 ->
          body = decode_body(conn)
          assert body["error"] == "scheduler_unavailable"
      end
    end
  end

  describe "POST /" do
    test "rejects missing name" do
      conn = json_post("/", %{})

      case conn.status do
        400 ->
          body = decode_body(conn)
          assert body["error"] == "invalid_request"

        503 ->
          :ok
      end
    end
  end

  describe "PUT /:id/toggle" do
    test "rejects missing enabled field" do
      conn = json_put("/some-id/toggle", %{})

      case conn.status do
        400 ->
          body = decode_body(conn)
          assert body["error"] == "invalid_request"

        503 ->
          :ok
      end
    end
  end

  describe "GET /:id/runs" do
    test "returns run history (may fail if executor not running)" do
      conn = json_get("/some-task-id/runs")

      case conn.status do
        200 ->
          body = decode_body(conn)
          assert body["status"] == "ok"
          assert is_list(body["runs"])

        503 ->
          :ok
      end
    end
  end

  describe "GET /:id/runs/:run_id" do
    test "returns 404 for unknown run" do
      conn = json_get("/task-1/runs/nonexistent-run")

      case conn.status do
        404 ->
          body = decode_body(conn)
          assert body["error"] == "not_found"

        503 ->
          :ok
      end
    end
  end

  describe "DELETE /:id" do
    test "returns 404 for unknown task" do
      conn = json_delete("/nonexistent-task-id")

      case conn.status do
        404 ->
          body = decode_body(conn)
          assert body["error"] == "not_found"

        503 ->
          :ok
      end
    end
  end

  describe "catch-all" do
    test "returns 404 for unknown endpoint" do
      conn = json_get("/nonexistent/deeply/nested/path")
      assert conn.status == 404

      body = decode_body(conn)
      assert body["error"] == "not_found"
    end
  end
end
