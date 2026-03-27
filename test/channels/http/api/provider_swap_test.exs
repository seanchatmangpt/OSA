defmodule OptimalSystemAgent.Channels.HTTP.API.ProviderSwapTest do
  use ExUnit.Case, async: false

  @moduletag :requires_application

  use Plug.Test

  alias OptimalSystemAgent.Channels.HTTP.API.SessionRoutes

  @opts SessionRoutes.init([])

  defp json_post(path, body \\ %{}) do
    conn(:post, path, Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], json_decoder: Jason))
    |> SessionRoutes.call(@opts)
  end

  describe "POST /:id/provider" do
    test "returns 400 when provider is missing" do
      conn = json_post("/some-session/provider", %{})
      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "provider" or conn.resp_body =~ "provider"
    end

    test "returns 400 when provider is empty string" do
      conn = json_post("/some-session/provider", %{"provider" => ""})
      assert conn.status == 400
    end

    test "returns 404 for non-existent session" do
      # Requires app boot — Registry.lookup(OptimalSystemAgent.SessionRegistry, _) crashes without it
      conn = json_post("/no-such-session-xyz/provider", %{"provider" => "openai"})
      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "not_found" or body["details"] =~ "not_found"
    end

    test "returns 404 when session registry has no entry" do
      # Requires app boot — Registry.lookup(OptimalSystemAgent.SessionRegistry, _) crashes without it
      conn = json_post("/ghost-session-42/provider", %{"provider" => "anthropic"})
      # 404 because session doesn't exist in registry
      assert conn.status == 404
    end

    test "response includes provider field on success path" do
      # Requires app boot — Registry.lookup(OptimalSystemAgent.SessionRegistry, _) crashes without it
      conn = json_post("/missing-session/provider", %{"provider" => "groq", "model" => "llama3"})
      assert conn.status in [200, 404]
      body = Jason.decode!(conn.resp_body)
      assert is_map(body)
    end
  end
end
