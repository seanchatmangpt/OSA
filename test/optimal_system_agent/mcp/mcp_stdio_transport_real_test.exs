defmodule OptimalSystemAgent.MCP.StdioTransportRealTest do
  @moduledoc """
  Real stdio MCP Transport Tests.

  NO MOCKS. Tests validate stdio MCP protocol with real subprocess.
  Uses an Elixir-based mock MCP server escript for testing.
  """

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :mcp_stdio

  # Tests will be added in subsequent tasks
end
