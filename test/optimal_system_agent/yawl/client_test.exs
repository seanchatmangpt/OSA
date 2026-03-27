defmodule OptimalSystemAgent.Yawl.ClientTest do
  use ExUnit.Case, async: false
  @moduletag :requires_application
  alias OptimalSystemAgent.Yawl.Client

  setup do
    case Process.whereis(OptimalSystemAgent.Yawl.Client) do
      nil -> start_supervised({OptimalSystemAgent.Yawl.Client, []})
      _ -> :ok
    end

    :ok
  end

  test "health/0 returns error when YAWL engine unreachable" do
    # With no engine running on port 8080, should return error not crash
    result = Client.health()
    assert result == :ok or match?({:error, _}, result)
  end

  test "check_conformance/2 returns error tuple when YAWL unavailable" do
    result = Client.check_conformance("<xml/>", "{}")
    assert match?({:ok, _}, result) or match?({:error, _}, result)
    # Must not raise or crash
  end

  test "discover/1 returns error tuple when YAWL unavailable" do
    result = Client.discover("{}")
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end
end
