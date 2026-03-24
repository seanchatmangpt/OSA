defmodule OptimalSystemAgent.Memory.VIGILTest do
  @moduledoc """
  Chicago TDD unit tests for Memory.VIGIL module.

  Tests error classification via regex pattern matching.
  Pure functions, no state, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Memory.VIGIL

  @moduletag :capture_log

  describe "classify/1" do
    # File-system errors
    test "classifies 'no such file' as io_error/file_not_found" do
      {cat, sub, hint} = VIGIL.classify("no such file or directory")
      assert cat == :io_error
      assert sub == "file_not_found"
      assert is_binary(hint)
    end

    test "classifies 'enoent' as io_error/file_not_found" do
      {cat, sub, _hint} = VIGIL.classify("enoent error occurred")
      assert cat == :io_error
      assert sub == "file_not_found"
    end

    test "classifies 'not found' as io_error/file_not_found" do
      {cat, sub, _hint} = VIGIL.classify("file not found")
      assert cat == :io_error
      assert sub == "file_not_found"
    end

    test "classifies 'permission denied' as io_error/permission_denied" do
      {cat, sub, _hint} = VIGIL.classify("permission denied")
      assert cat == :io_error
      assert sub == "permission_denied"
    end

    test "classifies 'eacces' as io_error/permission_denied" do
      {cat, sub, _hint} = VIGIL.classify("eacces: permission denied")
      assert cat == :io_error
      assert sub == "permission_denied"
    end

    test "classifies 'already exists' as io_error/file_exists" do
      {cat, sub, _hint} = VIGIL.classify("file already exists")
      assert cat == :io_error
      assert sub == "file_exists"
    end

    test "classifies 'eexist' as io_error/file_exists" do
      {cat, sub, _hint} = VIGIL.classify("eexist error")
      assert cat == :io_error
      assert sub == "file_exists"
    end

    test "classifies 'is a directory' as io_error/is_a_directory" do
      {cat, sub, _hint} = VIGIL.classify("error: is a directory")
      assert cat == :io_error
      assert sub == "is_a_directory"
    end

    test "classifies 'eisdir' as io_error/is_a_directory" do
      {cat, sub, _hint} = VIGIL.classify("eisdir")
      assert cat == :io_error
      assert sub == "is_a_directory"
    end

    test "classifies 'no space left' as io_error/disk_full" do
      {cat, sub, _hint} = VIGIL.classify("no space left on device")
      assert cat == :io_error
      assert sub == "disk_full"
    end

    test "classifies 'enospc' as io_error/disk_full" do
      {cat, sub, _hint} = VIGIL.classify("enospc")
      assert cat == :io_error
      assert sub == "disk_full"
    end

    # Network / HTTP errors
    test "classifies 'timeout' as network_error/timeout" do
      {cat, sub, _hint} = VIGIL.classify("connection timeout")
      assert cat == :network_error
      assert sub == "timeout"
    end

    test "classifies 'connection timed out' as network_error/timeout" do
      {cat, sub, _hint} = VIGIL.classify("connection timed out")
      assert cat == :network_error
      assert sub == "timeout"
    end

    test "classifies 'connection refused' as network_error/connection_refused" do
      {cat, sub, _hint} = VIGIL.classify("connection refused")
      assert cat == :network_error
      assert sub == "connection_refused"
    end

    test "classifies 'econnrefused' as network_error/connection_refused" do
      {cat, sub, _hint} = VIGIL.classify("econnrefused")
      assert cat == :network_error
      assert sub == "connection_refused"
    end

    test "classifies 'dns' as network_error/dns_failure" do
      {cat, sub, _hint} = VIGIL.classify("dns lookup failed")
      assert cat == :network_error
      assert sub == "dns_failure"
    end

    test "classifies 'nxdomain' as network_error/dns_failure" do
      {cat, sub, _hint} = VIGIL.classify("nxdomain error")
      assert cat == :network_error
      assert sub == "dns_failure"
    end

    test "classifies 'name or service not known' as network_error/dns_failure" do
      {cat, sub, _hint} = VIGIL.classify("name or service not known")
      assert cat == :network_error
      assert sub == "dns_failure"
    end

    test "classifies 'ssl' as network_error/ssl_error" do
      {cat, sub, _hint} = VIGIL.classify("ssl certificate error")
      assert cat == :network_error
      assert sub == "ssl_error"
    end

    test "classifies 'tls' as network_error/ssl_error" do
      {cat, sub, _hint} = VIGIL.classify("tls handshake failed")
      assert cat == :network_error
      assert sub == "ssl_error"
    end

    test "classifies 'certificate' as network_error/ssl_error" do
      {cat, sub, _hint} = VIGIL.classify("invalid certificate")
      assert cat == :network_error
      assert sub == "ssl_error"
    end

    test "classifies 4xx codes as http_error/client_error" do
      {cat, sub, _hint} = VIGIL.classify("http 404 not found")
      assert cat == :http_error
      assert sub == "client_error"
    end

    test "classifies 'bad request' as http_error/client_error" do
      {cat, sub, _hint} = VIGIL.classify("bad request")
      assert cat == :http_error
      assert sub == "client_error"
    end

    test "classifies 'unauthorized' as http_error/client_error" do
      {cat, sub, _hint} = VIGIL.classify("unauthorized access")
      assert cat == :http_error
      assert sub == "client_error"
    end

    test "classifies 5xx codes as http_error/server_error" do
      {cat, sub, _hint} = VIGIL.classify("http 500 internal server error")
      assert cat == :http_error
      assert sub == "server_error"
    end

    test "classifies 'bad gateway' as http_error/server_error" do
      {cat, sub, _hint} = VIGIL.classify("bad gateway")
      assert cat == :http_error
      assert sub == "server_error"
    end

    # Argument / Type errors
    test "classifies 'bad argument' as argument_error/bad_argument" do
      {cat, sub, _hint} = VIGIL.classify("bad argument error")
      assert cat == :argument_error
      assert sub == "bad_argument"
    end

    test "classifies 'argumenterror' as argument_error/bad_argument" do
      {cat, sub, _hint} = VIGIL.classify("argumenterror: invalid")
      assert cat == :argument_error
      assert sub == "bad_argument"
    end

    test "classifies 'functionclauseerror' as argument_error/no_matching_clause" do
      {cat, sub, _hint} = VIGIL.classify("functionclauseerror")
      assert cat == :argument_error
      assert sub == "no_matching_clause"
    end

    test "classifies 'no function clause' as argument_error/no_matching_clause" do
      {cat, sub, _hint} = VIGIL.classify("no function clause matching")
      assert cat == :argument_error
      assert sub == "no_matching_clause"
    end

    test "classifies 'matcherror' as argument_error/match_error" do
      {cat, sub, _hint} = VIGIL.classify("matcherror")
      assert cat == :argument_error
      assert sub == "match_error"
    end

    test "classifies 'match error' as argument_error/match_error" do
      {cat, sub, _hint} = VIGIL.classify("no match of right hand side value")
      assert cat == :argument_error
      assert sub == "match_error"
    end

    # Memory / Resource errors
    test "classifies 'out of memory' as resource_error/out_of_memory" do
      {cat, sub, _hint} = VIGIL.classify("out of memory")
      assert cat == :resource_error
      assert sub == "out_of_memory"
    end

    test "classifies 'enomem' as resource_error/out_of_memory" do
      {cat, sub, _hint} = VIGIL.classify("enomem")
      assert cat == :resource_error
      assert sub == "out_of_memory"
    end

    test "classifies 'max_heap_size' as resource_error/heap_limit" do
      {cat, sub, _hint} = VIGIL.classify("max_heap_size exceeded")
      assert cat == :resource_error
      assert sub == "heap_limit"
    end

    test "classifies 'process killed' as resource_error/heap_limit" do
      {cat, sub, _hint} = VIGIL.classify("process killed")
      assert cat == :resource_error
      assert sub == "heap_limit"
    end

    # Process / Concurrency errors
    test "classifies 'noproc' as process_error/no_process" do
      {cat, sub, _hint} = VIGIL.classify("noproc")
      assert cat == :process_error
      assert sub == "no_process"
    end

    test "classifies 'no process' as process_error/no_process" do
      {cat, sub, _hint} = VIGIL.classify("no process")
      assert cat == :process_error
      assert sub == "no_process"
    end

    test "classifies 'process not alive' as process_error/no_process" do
      {cat, sub, _hint} = VIGIL.classify("process not alive")
      assert cat == :process_error
      assert sub == "no_process"
    end

    test "classifies 'call_timeout' as process_error/genserver_timeout" do
      {cat, sub, _hint} = VIGIL.classify("call_timeout")
      assert cat == :process_error
      assert sub == "genserver_timeout"
    end

    test "classifies genserver timeout as process_error/genserver_timeout" do
      {cat, sub, _hint} = VIGIL.classify("genserver call timeout")
      assert cat == :process_error
      assert sub == "genserver_timeout"
    end

    # Encoding / Parsing errors
    test "classifies 'jason' as parse_error/json_parse" do
      {cat, sub, _hint} = VIGIL.classify("jason encoding error")
      assert cat == :parse_error
      assert sub == "json_parse"
    end

    test "classifies 'json' as parse_error/json_parse" do
      {cat, sub, _hint} = VIGIL.classify("invalid json")
      assert cat == :parse_error
      assert sub == "json_parse"
    end

    test "classifies 'yaml' as parse_error/yaml_parse" do
      {cat, sub, _hint} = VIGIL.classify("invalid yaml syntax")
      assert cat == :parse_error
      assert sub == "yaml_parse"
    end

    # Tool-specific errors
    test "classifies 'blocked:' as security_error/blocked_command" do
      {cat, sub, _hint} = VIGIL.classify("blocked: rm -rf /")
      assert cat == :security_error
      assert sub == "blocked_command"
    end

    test "classifies 'blocked pattern' as security_error/blocked_command" do
      {cat, sub, _hint} = VIGIL.classify("blocked pattern detected")
      assert cat == :security_error
      assert sub == "blocked_command"
    end

    test "classifies 'unknown tool' as tool_error/unknown_tool" do
      {cat, sub, _hint} = VIGIL.classify("unknown tool: foo")
      assert cat == :tool_error
      assert sub == "unknown_tool"
    end

    test "classifies 'tool not found' as tool_error/unknown_tool" do
      {cat, sub, _hint} = VIGIL.classify("tool not found")
      assert cat == :tool_error
      assert sub == "unknown_tool"
    end

    test "classifies 'missing required param' as tool_error/missing_params" do
      {cat, sub, _hint} = VIGIL.classify("missing required param")
      assert cat == :tool_error
      assert sub == "missing_params"
    end

    test "classifies 'missing param' as tool_error/missing_params" do
      {cat, sub, _hint} = VIGIL.classify("missing param: url")
      assert cat == :tool_error
      assert sub == "missing_params"
    end

    # Default / Unknown errors
    test "classifies unknown error as unknown_error/unclassified" do
      {cat, sub, hint} = VIGIL.classify("something completely unknown happened")
      assert cat == :unknown_error
      assert sub == "unclassified"
      assert is_binary(hint)
      assert String.length(hint) > 0
    end

    test "classifies empty string as unknown_error/unclassified" do
      {cat, sub, hint} = VIGIL.classify("")
      assert cat == :unknown_error
      assert sub == "unclassified"
      assert hint =~ ~r/unknown error/i
    end

    test "handles non-binary input" do
      {cat, sub, hint} = VIGIL.classify(nil)
      assert cat == :unknown_error
      assert sub == "unclassified"
      assert is_binary(hint)

      {cat, sub, hint} = VIGIL.classify(123)
      assert cat == :unknown_error
      assert sub == "unclassified"
    end

    test "first match wins when multiple patterns match" do
      # "file not found timeout" - should match file_not_found first
      {cat, sub, _hint} = VIGIL.classify("file not found timeout")
      assert cat == :io_error
      assert sub == "file_not_found"
    end
  end

  describe "suggestion hints" do
    test "provides actionable suggestion for file_not_found" do
      {_cat, _sub, hint} = VIGIL.classify("file not found")
      assert String.contains?(hint, "Verify")
      assert String.contains?(hint, "file path")
    end

    test "provides actionable suggestion for permission_denied" do
      {_cat, _sub, hint} = VIGIL.classify("permission denied")
      assert String.contains?(hint, "permission")
    end

    test "provides actionable suggestion for timeout" do
      {_cat, _sub, hint} = VIGIL.classify("connection timeout")
      assert String.contains?(hint, "timeout") or String.contains?(hint, "retry")
    end

    test "provides actionable suggestion for match_error" do
      {_cat, _sub, hint} = VIGIL.classify("match error")
      assert String.contains?(hint, "pattern")
    end
  end

  describe "case insensitivity" do
    test "patterns are case insensitive" do
      {cat1, _sub1, _hint1} = VIGIL.classify("ENOENT")
      {cat2, _sub2, _hint2} = VIGIL.classify("enoent")
      {cat3, _sub3, _hint3} = VIGIL.classify("EnOeNt")

      assert cat1 == cat2
      assert cat2 == cat3
    end

    test "HTTP status codes are case insensitive" do
      {cat1, _sub1, _} = VIGIL.classify("HTTP 404")
      {cat2, _sub2, _} = VIGIL.classify("http 404")

      assert cat1 == cat2
    end
  end

  describe "classification tuple format" do
    test "returns {category, subcategory, suggestion} tuple" do
      result = VIGIL.classify("file not found")
      assert is_tuple(result)
      assert tuple_size(result) == 3
    end

    test "category is an atom" do
      {cat, _sub, _hint} = VIGIL.classify("timeout")
      assert is_atom(cat)
    end

    test "subcategory is a string" do
      {_cat, sub, _hint} = VIGIL.classify("timeout")
      assert is_binary(sub)
    end

    test "suggestion is a string" do
      {_cat, _sub, hint} = VIGIL.classify("timeout")
      assert is_binary(hint)
    end
  end

  describe "real-world error messages" do
    test "classifies typical Elixir file error" do
      error = "** (File.Error) could not open file: no such file or directory"
      {cat, _sub, _hint} = VIGIL.classify(error)
      assert cat == :io_error
    end

    test "classifies typical HTTP client error" do
      error = "HTTPoison.Error: {:http_error, 404, 'Not Found'}"
      {cat, _sub, _hint} = VIGIL.classify(error)
      assert cat == :http_error
    end

    test "classifies typical GenServer timeout" do
      error = "** (exit) exited in: GenServer.call(:my_server, :ping, 5000)"
      {cat, _sub, _hint} = VIGIL.classify(error)
      assert cat == :process_error
    end

    test "classifies JSON decode error" do
      error = "** (Jason.DecodeError) unexpected byte at position 0"
      {cat, _sub, _hint} = VIGIL.classify(error)
      assert cat == :parse_error
    end
  end

  describe "edge cases" do
    test "handles very long error message" do
      long_msg = String.duplicate("error ", 1000) <> "timeout"
      {cat, _sub, _hint} = VIGIL.classify(long_msg)
      assert cat == :network_error
    end

    test "handles unicode error messages" do
      {_cat, _sub, hint} = VIGIL.classify("错误: file not found")
      assert is_binary(hint)
    end

    test "truncates very long messages in default hint" do
      long_msg = String.duplicate("x", 200)
      {_cat, _sub, hint} = VIGIL.classify(long_msg)
      # Should truncate at ~120 characters
      assert String.length(hint) < 200
    end
  end

  describe "integration" do
    test "classification can be used for error routing" do
      error = "file not found"
      {cat, sub, _hint} = VIGIL.classify(error)

      case cat do
        :io_error -> :handle_io
        :network_error -> :handle_network
        :process_error -> :handle_process
        _ -> :handle_generic
      end
    end

    test "all categories are valid atoms" do
      categories = [
        :io_error, :network_error, :http_error, :argument_error,
        :resource_error, :process_error, :parse_error, :security_error,
        :tool_error, :unknown_error
      ]

      Enum.each(categories, fn cat ->
        assert is_atom(cat)
      end)
    end
  end
end
