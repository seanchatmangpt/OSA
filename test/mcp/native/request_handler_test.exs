defmodule OptimalSystemAgent.MCP.Native.RequestHandlerTest do
  @moduledoc """
  Chicago TDD: request_handler handles all MCP JSON-RPC methods correctly.
  Tests are pure-functional — no GenServer, no HTTP, no mocks.
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.MCP.Native.RequestHandler

  # ── initialize ────────────────────────────────────────────────────────

  describe "initialize" do
    test "returns protocol version and server capabilities" do
      req = %{"jsonrpc" => "2.0", "method" => "initialize", "id" => 1, "params" => %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{},
        "clientInfo" => %{"name" => "test-client", "version" => "1.0"}
      }}

      response = RequestHandler.handle(req)

      assert response[:jsonrpc] == "2.0"
      assert response[:id] == 1
      assert get_in(response, [:result, :protocolVersion]) == "2024-11-05"
      assert get_in(response, [:result, :serverInfo, :name]) == "osa"
      assert get_in(response, [:result, :capabilities, :tools]) != nil
    end

    test "returns server info with non-empty version" do
      req = %{"jsonrpc" => "2.0", "method" => "initialize", "id" => 2, "params" => %{}}
      response = RequestHandler.handle(req)
      version = get_in(response, [:result, :serverInfo, :version])
      assert is_binary(version)
      assert String.length(version) > 0
    end
  end

  # ── notifications/initialized ─────────────────────────────────────────

  describe "notifications/initialized" do
    test "returns nil (notification — no reply)" do
      req = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}
      assert RequestHandler.handle(req) == nil
    end
  end

  # ── tools/list ────────────────────────────────────────────────────────

  describe "tools/list" do
    test "returns a list of tools" do
      req = %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => 3, "params" => %{}}
      response = RequestHandler.handle(req)

      assert response[:jsonrpc] == "2.0"
      assert response[:id] == 3
      tools = get_in(response, [:result, :tools])
      assert is_list(tools)
    end

    test "each tool has name, description, inputSchema" do
      req = %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => 4, "params" => %{}}
      response = RequestHandler.handle(req)
      tools = get_in(response, [:result, :tools])

      for tool <- tools do
        assert is_binary(Map.get(tool, :name)), "tool.name must be a string: #{inspect(tool)}"
        assert is_binary(Map.get(tool, :description)), "tool.description must be a string"
        assert is_map(Map.get(tool, :inputSchema)), "tool.inputSchema must be a map"
      end
    end
  end

  # ── tools/call ────────────────────────────────────────────────────────

  describe "tools/call" do
    test "returns error -32602 when name param is missing" do
      req = %{"jsonrpc" => "2.0", "method" => "tools/call", "id" => 5, "params" => %{}}
      response = RequestHandler.handle(req)

      assert get_in(response, [:error, :code]) == -32_602
    end

    test "returns error -32001 when tool does not exist" do
      req = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => 6,
        "params" => %{"name" => "no_such_tool_xyz_abc", "arguments" => %{}}
      }
      response = RequestHandler.handle(req)

      assert get_in(response, [:error, :code]) == -32_001
    end
  end

  # ── unknown method ────────────────────────────────────────────────────

  describe "unknown method" do
    test "returns -32601 Method Not Found" do
      req = %{"jsonrpc" => "2.0", "method" => "unknown/method", "id" => 7, "params" => %{}}
      response = RequestHandler.handle(req)

      assert get_in(response, [:error, :code]) == -32_601
      assert response[:id] == 7
    end
  end

  # ── invalid request ───────────────────────────────────────────────────

  describe "invalid request" do
    test "returns -32600 for non-jsonrpc-2.0 input" do
      response = RequestHandler.handle(%{"method" => "tools/list"})
      assert get_in(response, [:error, :code]) == -32_600
    end

    test "returns -32600 for empty map" do
      response = RequestHandler.handle(%{})
      assert get_in(response, [:error, :code]) == -32_600
    end
  end

  # ── response structure ────────────────────────────────────────────────

  describe "response structure" do
    test "all responses include jsonrpc: 2.0" do
      reqs = [
        %{"jsonrpc" => "2.0", "method" => "initialize", "id" => 10, "params" => %{}},
        %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => 11, "params" => %{}},
        %{"jsonrpc" => "2.0", "method" => "unknown", "id" => 12, "params" => %{}}
      ]

      for req <- reqs do
        response = RequestHandler.handle(req)
        assert response[:jsonrpc] == "2.0", "expected jsonrpc: 2.0 in #{inspect(response)}"
      end
    end

    test "success responses have result key, not error" do
      req = %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => 13, "params" => %{}}
      response = RequestHandler.handle(req)

      assert Map.has_key?(response, :result)
      refute Map.has_key?(response, :error)
    end

    test "error responses have error key with code and message" do
      req = %{"jsonrpc" => "2.0", "method" => "bad/method", "id" => 14, "params" => %{}}
      response = RequestHandler.handle(req)

      error = response[:error]
      assert is_map(error)
      assert is_integer(error[:code])
      assert is_binary(error[:message])
    end
  end
end
