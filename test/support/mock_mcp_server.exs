#!/usr/bin/env elixir
# Mock MCP server for stdio transport testing
# Reads JSON-RPC from stdin, writes response to stdout
#
# Usage:
#   echo '{"jsonrpc":"2.0","method":"initialize","id":1}' | test/support/mock_mcp_server.exs
#
# Requires compiled deps (run `mix compile` first).

# Add compiled BEAM paths for Jason and its dependency Decimal
Code.append_path("_build/dev/lib/jason/ebin")
Code.append_path("_build/dev/lib/decimal/ebin")

defmodule MockMCPServer do
  def main(_args) do
    :io.setopts([:binary, true])
    loop()
  end

  defp loop do
    case IO.gets("") do
      :eof ->
        :ok

      "\n" ->
        loop()

      line ->
        handle_line(line)
        loop()
    end
  end

  defp handle_line(line) do
    trimmed = String.trim(line)

    case Jason.decode(trimmed) do
      {:ok, %{"method" => method, "id" => id}} ->
        response = build_response(method, id)
        IO.puts(Jason.encode!(response))

      {:ok, _} ->
        # Valid JSON but missing method or id, ignore
        :ok

      {:error, _} ->
        # Invalid JSON, ignore
        :ok
    end
  rescue
    _ -> :ok
  end

  defp build_response("initialize", id) do
    %{
      "jsonrpc" => "2.0",
      "result" => %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{},
        "serverInfo" => %{
          "name" => "Mock MCP Server",
          "version" => "0.1.0"
        }
      },
      "id" => id
    }
  end

  defp build_response("tools/list", id) do
    %{
      "jsonrpc" => "2.0",
      "result" => %{"tools" => []},
      "id" => id
    }
  end

  defp build_response(_method, id) do
    %{
      "jsonrpc" => "2.0",
      "error" => %{
        "code" => -32_601,
        "message" => "Method not found"
      },
      "id" => id
    }
  end
end

MockMCPServer.main(System.argv())
