defmodule OptimalSystemAgent.Memory.VigilRealTest do
  @moduledoc """
  Chicago TDD integration tests for Memory.VIGIL.

  NO MOCKS. Tests real regex-based error classification.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Memory.VIGIL

  describe "VIGIL.classify/1 — file-system errors" do
    test "CRASH: enoent returns io_error/file_not_found" do
      {cat, sub, _hint} = VIGIL.classify("** (FileNotFoundError) no such file or directory: /tmp/missing")
      assert cat == :io_error
      assert sub == "file_not_found"
    end

    test "CRASH: permission denied returns io_error/permission_denied" do
      {cat, sub, _hint} = VIGIL.classify("** (EACCES) permission denied: /etc/shadow")
      assert cat == :io_error
      assert sub == "permission_denied"
    end

    test "CRASH: already exists returns io_error/file_exists" do
      {cat, sub, _hint} = VIGIL.classify("** (EEXIST) file already exists: /tmp/test")
      assert cat == :io_error
      assert sub == "file_exists"
    end

    test "CRASH: enospc returns io_error/disk_full" do
      {cat, sub, _hint} = VIGIL.classify("** no space left on device")
      assert cat == :io_error
      assert sub == "disk_full"
    end

    test "CRASH: is a directory returns io_error/is_a_directory" do
      {cat, sub, _hint} = VIGIL.classify("** is a directory: /tmp")
      assert cat == :io_error
      assert sub == "is_a_directory"
    end
  end

  describe "VIGIL.classify/1 — network errors" do
    test "CRASH: timeout returns network_error/timeout" do
      {cat, sub, _hint} = VIGIL.classify("** connection timed out")
      assert cat == :network_error
      assert sub == "timeout"
    end

    test "CRASH: connection refused returns network_error/connection_refused" do
      {cat, sub, _hint} = VIGIL.classify("** connection refused (ECONNREFUSED)")
      assert cat == :network_error
      assert sub == "connection_refused"
    end

    test "CRASH: DNS failure returns network_error/dns_failure" do
      {cat, sub, _hint} = VIGIL.classify("** getaddrinfo: Name or service not known")
      assert cat == :network_error
      assert sub == "dns_failure"
    end

    test "CRASH: SSL error returns network_error/ssl_error" do
      {cat, sub, _hint} = VIGIL.classify("** SSL certificate verify failed")
      assert cat == :network_error
      assert sub == "ssl_error"
    end
  end

  describe "VIGIL.classify/1 — HTTP errors" do
    test "CRASH: 400 returns http_error/client_error" do
      {cat, sub, _hint} = VIGIL.classify("** HTTP 400 bad request")
      assert cat == :http_error
      assert sub == "client_error"
    end

    test "CRASH: 500 returns http_error/server_error" do
      {cat, sub, _hint} = VIGIL.classify("** HTTP 500 internal server error")
      assert cat == :http_error
      assert sub == "server_error"
    end
  end

  describe "VIGIL.classify/1 — argument errors" do
    test "CRASH: bad argument returns argument_error/bad_argument" do
      {cat, sub, _hint} = VIGIL.classify("** (ArgumentError) bad argument: :foo")
      assert cat == :argument_error
      assert sub == "bad_argument"
    end

    test "CRASH: FunctionClauseError returns argument_error/no_matching_clause" do
      {cat, sub, _hint} = VIGIL.classify("** (FunctionClauseError) no function clause matching")
      assert cat == :argument_error
      assert sub == "no_matching_clause"
    end

    test "CRASH: MatchError returns argument_error/match_error" do
      {cat, sub, _hint} = VIGIL.classify("** (MatchError) no match of right hand side")
      assert cat == :argument_error
      assert sub == "match_error"
    end
  end

  describe "VIGIL.classify/1 — resource/process errors" do
    test "CRASH: out of memory returns resource_error/out_of_memory" do
      {cat, sub, _hint} = VIGIL.classify("** out of memory")
      assert cat == :resource_error
      assert sub == "out_of_memory"
    end

    test "CRASH: process killed returns resource_error/heap_limit" do
      {cat, sub, _hint} = VIGIL.classify("** process killed")
      assert cat == :resource_error
      assert sub == "heap_limit"
    end

    test "CRASH: noproc returns process_error/no_process" do
      {cat, sub, _hint} = VIGIL.classify("** noproc")
      assert cat == :process_error
      assert sub == "no_process"
    end
  end

  describe "VIGIL.classify/1 — parse/tool errors" do
    test "CRASH: JSON parse error returns parse_error/json_parse" do
      {cat, sub, _hint} = VIGIL.classify("** (Jason.DecodeError) unexpected byte")
      assert cat == :parse_error
      assert sub == "json_parse"
    end

    test "CRASH: unknown tool returns tool_error/unknown_tool" do
      {cat, sub, _hint} = VIGIL.classify("** unknown tool: foo_bar_baz")
      assert cat == :tool_error
      assert sub == "unknown_tool"
    end

    test "CRASH: missing param returns tool_error/missing_params" do
      {cat, sub, _hint} = VIGIL.classify("** missing required param: path")
      assert cat == :tool_error
      assert sub == "missing_params"
    end
  end

  describe "VIGIL.classify/1 — fallback" do
    test "CRASH: unknown message returns unknown_error" do
      {cat, sub, hint} = VIGIL.classify("xyzzy nothing matches here")
      assert cat == :unknown_error
      assert sub == "unclassified"
      assert is_binary(hint)
    end

    test "CRASH: nil returns unknown_error" do
      {cat, _sub, _hint} = VIGIL.classify(nil)
      assert cat == :unknown_error
    end

    test "CRASH: empty string returns unknown_error" do
      {cat, _sub, _hint} = VIGIL.classify("")
      assert cat == :unknown_error
    end

    test "CRASH: suggestion includes truncated message" do
      {_cat, _sub, hint} = VIGIL.classify("some long error message that should be truncated")
      assert String.contains?(hint, "some long error")
    end

    test "CRASH: every classification has 3 elements" do
      results = [
        "** (FileNotFoundError) no such file",
        "** connection refused",
        "** HTTP 500",
        "** out of memory",
        "** noproc",
        "random text that matches nothing",
        nil,
        ""
      ]
      for msg <- results do
        {cat, sub, hint} = VIGIL.classify(msg)
        assert is_atom(cat), "Expected atom category for: #{inspect(msg)}"
        assert is_binary(sub), "Expected string subcategory for: #{inspect(msg)}"
        assert is_binary(hint), "Expected string suggestion for: #{inspect(msg)}"
      end
    end
  end
end
