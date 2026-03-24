defmodule OptimalSystemAgent.Tools.Builtins.BusinessOSAPITest do
  @moduledoc """
  Unit tests for BusinessOS API tool (Innovation 10 - Agent Marketplace component).

  Tests the tool behaviour callbacks, parameter validation, and error handling.
  Network calls are not tested (integration scope).
  """
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.BusinessOSAPI

  describe "behaviour callbacks" do
    test "name/0 returns expected name" do
      assert BusinessOSAPI.name() == "businessos_api"
    end

    test "safety/0 returns sandboxed" do
      assert BusinessOSAPI.safety() == :sandboxed
    end

    test "description/0 returns non-empty string" do
      desc = BusinessOSAPI.description()
      assert is_binary(desc)
      assert String.length(desc) > 0
      assert String.contains?(desc, "BusinessOS")
    end
  end

  describe "parameters/0" do
    test "returns valid JSON schema" do
      params = BusinessOSAPI.parameters()

      assert Map.has_key?(params, "type")
      assert params["type"] == "object"
      assert Map.has_key?(params, "properties")
      assert Map.has_key?(params, "required")
    end

    test "requires endpoint and method" do
      params = BusinessOSAPI.parameters()

      assert "endpoint" in params["required"]
      assert "method" in params["required"]
      assert "body" not in params["required"]
    end

    test "endpoint property has correct type" do
      props = BusinessOSAPI.parameters()["properties"]
      assert props["endpoint"]["type"] == "string"
    end

    test "method property has correct enum values" do
      props = BusinessOSAPI.parameters()["properties"]
      assert props["method"]["type"] == "string"
      assert "GET" in props["method"]["enum"]
      assert "POST" in props["method"]["enum"]
      assert "PUT" in props["method"]["enum"]
      assert "DELETE" in props["method"]["enum"]
    end
  end

  describe "execute/1" do
    test "returns error for missing required parameters" do
      assert {:error, msg} = BusinessOSAPI.execute(%{})
      assert is_binary(msg)
      assert String.contains?(msg, "Missing required")
    end

    test "returns error for non-map input" do
      assert {:error, _msg} = BusinessOSAPI.execute("not a map")
    end

    test "returns error for nil input" do
      assert {:error, _msg} = BusinessOSAPI.execute(nil)
    end

    test "returns error for missing endpoint" do
      assert {:error, msg} = BusinessOSAPI.execute(%{"method" => "GET"})
      assert is_binary(msg)
    end

    test "returns error for missing method" do
      assert {:error, msg} = BusinessOSAPI.execute(%{"endpoint" => "/api/test"})
      assert is_binary(msg)
    end

    test "returns error for non-string endpoint" do
      assert {:error, msg} = BusinessOSAPI.execute(%{"endpoint" => 123, "method" => "GET"})
      assert is_binary(msg)
      assert String.contains?(msg, "strings")
    end

    test "returns error for non-string method" do
      assert {:error, msg} = BusinessOSAPI.execute(%{"endpoint" => "/api/test", "method" => 42})
      assert is_binary(msg)
      assert String.contains?(msg, "strings")
    end

    # Note: Network-dependent tests are in integration tests.
    # The actual HTTP call requires a running BusinessOS instance.
  end
end
