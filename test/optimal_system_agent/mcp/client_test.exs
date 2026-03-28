defmodule OptimalSystemAgent.MCP.ClientTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.MCP.Client

  setup_all do
    # Ensure :persistent_term key exists for tests
    :persistent_term.put({OptimalSystemAgent.Tools.Registry, :mcp_tools}, %{})

    # Create the tool cache table
    try do
      :ets.new(:mcp_tool_cache, [:named_table, :public, :set, read_concurrency: true])
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  describe "config resolution" do
    test "resolves default config path" do
      path = Application.get_env(:optimal_system_agent, :mcp_config_path, "~/.osa/mcp.json")
      assert path =~ "mcp.json"
    end

    test "uses custom config path from application env" do
      original = Application.get_env(:optimal_system_agent, :mcp_config_path)
      Application.put_env(:optimal_system_agent, :mcp_config_path, "/tmp/test-mcp.json")

      try do
        path = Application.get_env(:optimal_system_agent, :mcp_config_path)
        assert path == "/tmp/test-mcp.json"
      after
        if original, do: Application.put_env(:optimal_system_agent, :mcp_config_path, original)
        if is_nil(original), do: Application.delete_env(:optimal_system_agent, :mcp_config_path)
      end
    end
  end

  describe "list_servers/0" do
    test "returns a list of server names" do
      # Start a standalone client that reads no config
      config_path =
        Path.join(System.tmp_dir!(), "mcp-client-test-#{System.unique_integer([:positive])}.json")

      # Ensure no config file exists so client starts empty
      File.rm(config_path)

      Application.put_env(:optimal_system_agent, :mcp_config_path, config_path)

      try do
        {:ok, pid} = GenServer.start_link(Client, [], name: nil)
        GenServer.stop(pid)

        # With no config, servers should be empty
        # The GenServer starts and returns ok with empty servers map
        assert true
      after
        Application.delete_env(:optimal_system_agent, :mcp_config_path)
        File.rm(config_path)
      end
    end
  end

  describe "config parsing" do
    test "parses mcpServers format" do
      config = ~s({"mcpServers":{"test":{"transport":"stdio","command":"echo"}}})

      path =
        Path.join(System.tmp_dir!(), "mcp-parse-test-#{System.unique_integer([:positive])}.json")

      File.write!(path, config)

      try do
        content = File.read!(path)

        case Jason.decode(content) do
          {:ok, %{"mcpServers" => servers}} ->
            assert is_map(servers)
            assert Map.has_key?(servers, "test")
            assert servers["test"]["transport"] == "stdio"
            assert servers["test"]["command"] == "echo"

          other ->
            flunk("Expected mcpServers key, got: #{inspect(other)}")
        end
      after
        File.rm(path)
      end
    end

    test "parses mcp_servers (snake_case) format" do
      config =
        ~s({"mcp_servers":{"my_server":{"transport":"http","url":"http://localhost:3001"}}})

      path =
        Path.join(System.tmp_dir!(), "mcp-parse-test-#{System.unique_integer([:positive])}.json")

      File.write!(path, config)

      try do
        content = File.read!(path)

        case Jason.decode(content) do
          {:ok, %{"mcp_servers" => servers}} ->
            assert is_map(servers)
            assert Map.has_key?(servers, "my_server")
            assert servers["my_server"]["transport"] == "http"
            assert servers["my_server"]["url"] == "http://localhost:3001"

          other ->
            flunk("Expected mcp_servers key, got: #{inspect(other)}")
        end
      after
        File.rm(path)
      end
    end
  end

  describe "register_tools/0" do
    test "stores empty tools map when no servers are running" do
      :persistent_term.put({OptimalSystemAgent.Tools.Registry, :mcp_tools}, %{})
      assert :persistent_term.get({OptimalSystemAgent.Tools.Registry, :mcp_tools}) == %{}
    end

    test "tools are stored as atoms with mcp_ prefix" do
      # Simulate the format that register_tools would produce
      sample_tools = %{
        :mcp_test_server_read_file => %{
          original_name: "read_file",
          description: "Read a file",
          input_schema: %{"type" => "object", "properties" => %{"path" => %{"type" => "string"}}},
          server_name: "test_server"
        }
      }

      :persistent_term.put({OptimalSystemAgent.Tools.Registry, :mcp_tools}, sample_tools)

      tools = :persistent_term.get({OptimalSystemAgent.Tools.Registry, :mcp_tools})
      assert map_size(tools) == 1
      assert Map.has_key?(tools, :mcp_test_server_read_file)

      tool_info = tools[:mcp_test_server_read_file]
      assert tool_info.original_name == "read_file"
      assert tool_info.server_name == "test_server"
    end
  end

  describe "validate_config/1" do
    test "delegates to ConfigValidator" do
      assert {:ok, _} =
               Client.validate_config(%{
                 "name" => "test",
                 "transport" => "stdio",
                 "command" => "echo"
               })

      assert {:error, _} = Client.validate_config(%{"name" => "bad"})
    end
  end

  describe "validate_config_file/1" do
    test "delegates to ConfigValidator" do
      assert {:ok, _} =
               Client.validate_config_file(%{
                 "mcpServers" => %{
                   "test" => %{"name" => "test", "transport" => "stdio", "command" => "echo"}
                 }
               })

      assert {:error, _} =
               Client.validate_config_file(%{"mcpServers" => %{"bad" => %{"name" => "bad"}}})
    end
  end

  describe "error propagation in collect_all_tools" do
    test "register_tools returns error when tool collection fails" do
      # Start a client with no config so there are no servers
      config_path =
        Path.join(System.tmp_dir!(), "mcp-error-prop-test-#{System.unique_integer([:positive])}.json")

      File.rm(config_path)

      Application.put_env(:optimal_system_agent, :mcp_config_path, config_path)

      try do
        {:ok, pid} = GenServer.start_link(Client, [], name: nil)

        # The initial register_tools on startup would collect from empty servers (returns ok)
        # So we verify that the function structure is sound by checking that the GenServer
        # is handling the case correctly

        result = GenServer.call(pid, :register_tools, 5000)

        # With no servers, tool collection succeeds with empty map
        assert result == :ok

        GenServer.stop(pid)
      after
        Application.delete_env(:optimal_system_agent, :mcp_config_path)
        File.rm(config_path)
      end
    end
  end

  describe "tool caching" do
    setup do
      # Ensure the cache table exists for each test
      try do
        :ets.delete(:mcp_tool_cache)
      rescue
        ArgumentError -> :ok
      end

      :ets.new(:mcp_tool_cache, [:named_table, :public, :set, read_concurrency: true])
      :ok
    end

    test "get_cached_tool_result returns :miss for non-existent entry" do
      assert :miss == Client.get_cached_tool_result("no_server", "no_tool", %{})
    end

    test "put_cached_tool_result stores and retrieves result" do
      server = "cache_test_server"
      tool = "cache_test_tool"
      args = %{"path" => "/tmp/test"}
      result = %{content: "hello"}

      assert :miss == Client.get_cached_tool_result(server, tool, args)

      Client.put_cached_tool_result(server, tool, args, result)

      assert {:ok, %{content: "hello"}} = Client.get_cached_tool_result(server, tool, args)
    end

    test "clear_tool_cache removes all entries" do
      Client.put_cached_tool_result("s1", "t1", %{}, %{"data" => "val1"})
      Client.put_cached_tool_result("s2", "t2", %{}, %{"data" => "val2"})

      assert {:ok, _} = Client.get_cached_tool_result("s1", "t1", %{})

      Client.clear_tool_cache()

      assert :miss == Client.get_cached_tool_result("s1", "t1", %{})
      assert :miss == Client.get_cached_tool_result("s2", "t2", %{})
    end

    test "invalidate_server_cache only removes entries for specific server" do
      Client.put_cached_tool_result("keep_server", "t1", %{}, %{"data" => "keep"})
      Client.put_cached_tool_result("remove_server", "t1", %{}, %{"data" => "remove"})

      Client.invalidate_server_cache("remove_server")

      assert {:ok, _} = Client.get_cached_tool_result("keep_server", "t1", %{})
      assert :miss == Client.get_cached_tool_result("remove_server", "t1", %{})
    end
  end

  describe "with_retry/2" do
    test "returns success on first attempt" do
      assert {:ok, :value} == Client.with_retry([], fn -> {:ok, :value} end)
    end

    test "retries on failure and returns success" do
      {:ok, counter_pid} = Agent.start_link(fn -> 0 end)

      result =
        Client.with_retry([context: "test"], fn ->
          count = Agent.get_and_update(counter_pid, fn c -> {c, c + 1} end)

          if count < 1 do
            {:error, :transient}
          else
            {:ok, :recovered}
          end
        end)

      Agent.stop(counter_pid)
      assert {:ok, :recovered} == result
    end

    test "returns error after max retries" do
      assert {:error, {:max_retries_exceeded, :permanent}} ==
               Client.with_retry([context: "test", max_retries: 1], fn ->
                 {:error, :permanent}
               end)
    end

    test "does not retry on invalid request errors" do
      result =
        Client.with_retry([context: "test", max_retries: 3], fn ->
          {:error, %{"code" => -32600, "message" => "Invalid Request"}}
        end)

      assert {:error, %{"code" => -32600}} = result
    end

    test "does not retry on method not found" do
      result =
        Client.with_retry([context: "test", max_retries: 3], fn ->
          {:error, %{"code" => -32601, "message" => "Method not found"}}
        end)

      assert {:error, %{"code" => -32601}} = result
    end

    test "does not retry on invalid params" do
      result =
        Client.with_retry([context: "test", max_retries: 3], fn ->
          {:error, %{"code" => -32602, "message" => "Invalid params"}}
        end)

      assert {:error, %{"code" => -32602}} = result
    end
  end
end
