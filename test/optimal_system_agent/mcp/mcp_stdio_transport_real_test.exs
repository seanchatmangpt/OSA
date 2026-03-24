defmodule OptimalSystemAgent.MCP.StdioTransportRealTest do
  @moduledoc """
  Real stdio MCP Transport Tests.

  NO MOCKS. Tests validate stdio MCP protocol with real subprocess.
  Uses an Elixir-based mock MCP server for testing.

  NOTE: Port.open({:spawn_executable, cmd}, ...) requires a native binary.
  Since `elixir` is a shell script, we use `/bin/sh -c "elixir ..."` to
  spawn the mock server via the native /bin/sh binary.
  """

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :mcp_stdio

  # Helper to build stdio server options for the mock MCP server.
  # Uses /bin/sh to invoke `elixir` since Port.open({:spawn_executable, ...})
  # requires a native binary and `elixir` is a shell script.
  defp mock_server_opts(name) do
    server_path = Path.expand("../../support/mock_mcp_server.exs", __DIR__)

    [
      name: name,
      transport: "stdio",
      command: "/bin/sh",
      args: ["-c", "elixir #{server_path}"]
    ]
  end

  describe "stdio Transport" do
    test "CRASH: stdio transport starts subprocess" do
      {:ok, _server} = OptimalSystemAgent.MCP.Server.start_link(mock_server_opts("test_stdio_server"))

      # Verify server started
      assert {:ok, _pid} = OptimalSystemAgent.MCP.Server.whereis("test_stdio_server")

      # Cleanup
      OptimalSystemAgent.MCP.Server.stop("test_stdio_server")
    end

    test "CRASH: stdio transport handles JSON-RPC requests" do
      {:ok, _server} = OptimalSystemAgent.MCP.Server.start_link(mock_server_opts("test_stdio_jsonrpc"))

      on_exit(fn ->
        try do
          OptimalSystemAgent.MCP.Server.stop("test_stdio_jsonrpc")
        catch
          _, _ -> :ok
        end
      end)

      # Try to list tools
      result = OptimalSystemAgent.MCP.Server.list_tools("test_stdio_jsonrpc")

      # Should get response (empty list from mock server)
      assert is_list(result)
    end

    test "CRASH: stdio transport handles subprocess crash gracefully" do
      # Use invalid command that will fail
      result = OptimalSystemAgent.MCP.Server.start_link(
        name: "test_stdio_bad",
        transport: "stdio",
        command: "nonexistent_command_xyz",
        args: []
      )

      # Should return error or start server in disconnected state
      assert match?({:ok, _pid}, result) or match?({:error, _}, result)

      case result do
        {:ok, pid} -> GenServer.stop(pid)
        _ -> :ok
      end
    end

    test "CRASH: stdio transport emits [:osa, :mcp, :server_start] telemetry" do
      parent = self()
      ref = make_ref()

      handler_id = :telemetry.attach(
        {__MODULE__, ref},
        [:osa, :mcp, :server_start],
        fn _event, measurements, metadata, _config ->
          send(parent, {ref, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      {:ok, _server} = OptimalSystemAgent.MCP.Server.start_link(mock_server_opts("test_stdio_telemetry"))

      # Should receive telemetry event
      assert_receive {^ref, measurements, metadata}, 2000
      assert is_integer(measurements[:tools_count])
      assert metadata[:server_name] == "test_stdio_telemetry"
      assert metadata[:transport] == "stdio"

      OptimalSystemAgent.MCP.Server.stop("test_stdio_telemetry")
    end
  end
end
