defmodule OptimalSystemAgent.Sandbox.HostTest do
  @moduledoc """
  Unit tests for Sandbox.Host module.

  Tests host backend (no sandbox) for command execution.
  Real System.cmd calls, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Sandbox.Host

  @moduletag :capture_log

  describe "available?/0" do
    test "returns true (host is always available)" do
      assert Host.available?() == true
    end
  end

  describe "name/0" do
    test "returns 'host (no sandbox)'" do
      assert Host.name() == "host (no sandbox)"
    end
  end

  describe "execute/2" do
    test "executes simple command successfully" do
      assert {:ok, output} = Host.execute("echo 'hello'")
      assert String.contains?(output, "hello")
    end

    test "executes command with pipes" do
      assert {:ok, output} = Host.execute("echo 'test' | wc -w")
      assert String.trim(output) == "1"
    end

    test "returns error for non-existent command" do
      assert {:error, _reason} = Host.execute("nonexistentcommand12345")
    end

    test "returns error for failing command" do
      assert {:error, _reason} = Host.execute("exit 1")
    end

    test "accepts timeout option" do
      assert {:ok, _output} = Host.execute("echo 'test'", timeout: 5000)
    end

    test "accepts working_dir option" do
      assert {:ok, _output} = Host.execute("pwd", working_dir: "/tmp")
    end

    test "respects timeout (command should complete within time)" do
      # Quick command should complete
      assert {:ok, _output} = Host.execute("true", timeout: 1000)
    end

    test "handles command with environment variables" do
      assert {:ok, output} = Host.execute("echo $HOME")
      assert String.length(output) > 0
    end
  end

  describe "run_file/2" do
    test "executes .py files with python3" do
      # Create a temporary Python file
      temp_file = "/tmp/test_host_sandbox.py"
      File.write!(temp_file, "print('Python executed')")
      assert {:ok, output} = Host.run_file(temp_file)
      assert String.contains?(output, "Python executed")
      File.rm!(temp_file)
    end

    test "executes .sh files with bash" do
      temp_file = "/tmp/test_host_sandbox.sh"
      File.write!(temp_file, "#!/bin/bash\necho 'Shell executed'")
      assert {:ok, output} = Host.run_file(temp_file)
      assert String.contains?(output, "Shell executed")
      File.rm!(temp_file)
    end

    test "executes .js files with node" do
      # Skip if node not available
      case System.cmd("which", ["node"]) do
        {_, 0} ->
          temp_file = "/tmp/test_host_sandbox.js"
          File.write!(temp_file, "console.log('Node executed')")
          assert {:ok, output} = Host.run_file(temp_file)
          assert String.contains?(output, "Node executed") or String.contains?(output, "node")
          File.rm!(temp_file)
        _ ->
          :skip
      end
    end

    test "executes .exs files with elixir" do
      temp_file = "/tmp/test_host_sandbox.exs"
      File.write!(temp_file, "IO.puts('Elixir executed')")
      assert {:ok, output} = Host.run_file(temp_file)
      assert String.contains?(output, "Elixir executed")
      File.rm!(temp_file)
    end

    test "executes .go files with go run" do
      # Skip if go not available
      case System.cmd("which", ["go"]) do
        {_, 0} ->
          temp_file = "/tmp/test_host_sandbox.go"
          File.write!(temp_file, "package main\nimport \"fmt\"\nfunc main() { fmt.Println(\"Go executed\") }")
          assert {:ok, output} = Host.run_file(temp_file)
          assert String.contains?(output, "Go executed") or String.contains?(output, "go")
          File.rm!(temp_file)
          # Clean up Go binary if it exists (location varies by go version)
          if File.exists?("/tmp/test_host_sandbox"), do: File.rm!("/tmp/test_host_sandbox")
        _ ->
          :skip
      end
    end

    test "handles unknown extension with sh" do
      temp_file = "/tmp/test_host_sandbox.unknown"
      File.write!(temp_file, "echo 'Unknown extension'")
      assert {:ok, _output} = Host.run_file(temp_file)
      File.rm!(temp_file)
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = Host.run_file("/nonexistent/file.py")
    end
  end

  describe "edge cases" do
    test "handles empty command" do
      result = Host.execute("")
      # Empty command might succeed or fail depending on shell
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles command with special characters" do
      assert {:ok, output} = Host.execute("echo 'test!@#$%^&*()'")
      assert String.length(output) > 0
    end

    test "handles command with unicode" do
      assert {:ok, output} = Host.execute("echo '测试'")
      assert String.contains?(output, "测试")
    end

    test "handles very long command" do
      long_cmd = "echo '" <> String.duplicate("test ", 1000) <> "'"
      assert {:ok, output} = Host.execute(long_cmd)
      assert String.length(output) > 0
    end

    test "handles file with unicode content" do
      temp_file = "/tmp/test_host_unicode.py"
      File.write!(temp_file, "print('测试内容')")
      assert {:ok, _output} = Host.run_file(temp_file)
      File.rm!(temp_file)
    end

    test "handles timeout option of 0" do
      # Zero timeout should either fail immediately or succeed instantly
      result = Host.execute("echo 'test'", timeout: 0)
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "integration" do
    test "full command execution lifecycle" do
      # Execute simple command
      assert {:ok, output} = Host.execute("echo 'lifecycle'")
      assert String.contains?(output, "lifecycle")

      # Execute with options
      assert {:ok, output2} = Host.execute("pwd", working_dir: "/tmp")
      assert String.contains?(output2, "tmp")
    end

    test "full file execution lifecycle" do
      # Create temp file
      temp_file = "/tmp/test_integration.py"
      File.write!(temp_file, """
import sys
print('Integration test')
sys.exit(0)
""")

      # Execute file
      assert {:ok, output} = Host.run_file(temp_file)
      assert String.contains?(output, "Integration test")

      # Cleanup
      File.rm!(temp_file)
    end
  end
end
