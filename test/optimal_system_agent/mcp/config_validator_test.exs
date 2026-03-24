defmodule OptimalSystemAgent.MCP.ConfigValidatorTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.MCP.ConfigValidator

  describe "validate_config/1" do
    test "validates a valid stdio config" do
      config = %{
        "name" => "test-server",
        "transport" => "stdio",
        "command" => "npx",
        "args" => ["-y", "some-mcp-server"]
      }

      assert {:ok, validated} = ConfigValidator.validate_config(config)
      assert validated["name"] == "test-server"
      assert validated["transport"] == "stdio"
      assert validated["command"] == "npx"
      assert validated["args"] == ["-y", "some-mcp-server"]
    end

    test "validates a valid http config" do
      config = %{
        "name" => "remote-server",
        "transport" => "http",
        "url" => "http://localhost:3001/mcp"
      }

      assert {:ok, validated} = ConfigValidator.validate_config(config)
      assert validated["name"] == "remote-server"
      assert validated["transport"] == "http"
      assert validated["url"] == "http://localhost:3001/mcp"
    end

    test "returns error for missing name" do
      config = %{
        "transport" => "stdio",
        "command" => "echo"
      }

      assert {:error, msg} = ConfigValidator.validate_config(config)
      assert msg =~ "name"
    end

    test "returns error for empty name" do
      config = %{
        "name" => "",
        "transport" => "stdio",
        "command" => "echo"
      }

      assert {:error, msg} = ConfigValidator.validate_config(config)
      assert msg =~ "name"
    end

    test "returns error for missing transport" do
      config = %{
        "name" => "test",
        "command" => "echo"
      }

      assert {:error, msg} = ConfigValidator.validate_config(config)
      assert msg =~ "transport"
    end

    test "returns error for invalid transport" do
      config = %{
        "name" => "test",
        "transport" => "grpc"
      }

      assert {:error, msg} = ConfigValidator.validate_config(config)
      assert msg =~ "grpc"
      assert msg =~ "stdio"
      assert msg =~ "http"
    end

    test "returns error when stdio transport is missing command" do
      config = %{
        "name" => "test",
        "transport" => "stdio"
      }

      assert {:error, msg} = ConfigValidator.validate_config(config)
      assert msg =~ "command"
    end

    test "returns error when stdio transport has empty command" do
      config = %{
        "name" => "test",
        "transport" => "stdio",
        "command" => ""
      }

      assert {:error, msg} = ConfigValidator.validate_config(config)
      assert msg =~ "command"
    end

    test "returns error when http transport is missing url" do
      config = %{
        "name" => "test",
        "transport" => "http"
      }

      assert {:error, msg} = ConfigValidator.validate_config(config)
      assert msg =~ "url"
    end

    test "returns error when http transport has empty url" do
      config = %{
        "name" => "test",
        "transport" => "http",
        "url" => ""
      }

      assert {:error, msg} = ConfigValidator.validate_config(config)
      assert msg =~ "url"
    end

    test "returns error for non-map input" do
      assert {:error, msg} = ConfigValidator.validate_config("not a map")
      assert msg =~ "map"

      assert {:error, msg} = ConfigValidator.validate_config(nil)
      assert msg =~ "map"
    end

    test "normalizes config with defaults" do
      config = %{
        "name" => "test",
        "transport" => "stdio",
        "command" => "echo"
      }

      assert {:ok, validated} = ConfigValidator.validate_config(config)
      assert validated["args"] == []
      assert validated["env"] == %{}
    end

    test "preserves existing args and env" do
      config = %{
        "name" => "test",
        "transport" => "stdio",
        "command" => "node",
        "args" => ["server.js"],
        "env" => %{"API_KEY" => "test"}
      }

      assert {:ok, validated} = ConfigValidator.validate_config(config)
      assert validated["args"] == ["server.js"]
      assert validated["env"] == %{"API_KEY" => "test"}
    end
  end

  describe "validate_config_file/1" do
    test "validates mcpServers format" do
      config = %{
        "mcpServers" => %{
          "test" => %{"name" => "test", "transport" => "stdio", "command" => "echo"}
        }
      }

      assert {:ok, servers} = ConfigValidator.validate_config_file(config)
      assert Map.has_key?(servers, "test")
    end

    test "validates mcp_servers (snake_case) format" do
      config = %{
        "mcp_servers" => %{
          "remote" => %{
            "name" => "remote",
            "transport" => "http",
            "url" => "http://localhost:3001"
          }
        }
      }

      assert {:ok, servers} = ConfigValidator.validate_config_file(config)
      assert Map.has_key?(servers, "remote")
    end

    test "validates backward compat top-level format" do
      config = %{
        "test" => %{"name" => "test", "transport" => "stdio", "command" => "echo"}
      }

      assert {:ok, servers} = ConfigValidator.validate_config_file(config)
      assert Map.has_key?(servers, "test")
    end

    test "returns errors for invalid servers" do
      config = %{
        "mcpServers" => %{
          "bad1" => %{"name" => "bad1", "transport" => "stdio"},
          "bad2" => %{"name" => "bad2", "transport" => "grpc"}
        }
      }

      assert {:error, msg} = ConfigValidator.validate_config_file(config)
      assert msg =~ "bad1"
      assert msg =~ "bad2"
    end

    test "returns error for non-map input" do
      assert {:error, _} = ConfigValidator.validate_config_file("invalid")
    end

    test "returns ok for empty servers map" do
      assert {:ok, servers} = ConfigValidator.validate_config_file(%{"mcpServers" => %{}})
      assert servers == %{}
    end
  end
end
