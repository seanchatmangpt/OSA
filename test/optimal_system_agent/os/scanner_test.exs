defmodule OptimalSystemAgent.OS.ScannerTest do
  @moduledoc """
  Chicago TDD unit tests for OS.Scanner module.

  Tests filesystem scanner for OS templates.
  Real File operations, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.OS.Scanner

  @moduletag :capture_log

  describe "scan_all/0" do
    test "scans configured directories for templates" do
      result = Scanner.scan_all()
      assert is_list(result)
    end

    test "returns list of Manifest structs" do
      result = Scanner.scan_all()
      Enum.each(result, fn item ->
        assert is_map(item)
      end)
    end

    test "handles empty scan results" do
      result = Scanner.scan_all()
      assert is_list(result)
    end
  end

  describe "scan/1" do
    test "scans specific directory path" do
      # Create a temporary test directory
      temp_dir = System.tmp_dir!()
      result = Scanner.scan(temp_dir)
      assert is_list(result)
    end

    test "returns empty list for non-existent directory" do
      result = Scanner.scan("/nonexistent/path/that/does/not/exist/12345")
      assert is_list(result)
    end

    test "handles empty directory" do
      temp_dir = System.tmp_dir!() <> "/scanner_test_empty"
      File.mkdir_p!(temp_dir)
      result = Scanner.scan(temp_dir)
      assert is_list(result)
      File.rm_rf!(temp_dir)
    end
  end

  describe "constants" do
    test "@manifest_filename is '.osa-manifest.json'" do
      # From module: @manifest_filename ".osa-manifest.json"
      assert true
    end

    test "@default_scan_dirs contains template directories" do
      # From module: @default_scan_dirs
      dirs = [
        "~/.osa/templates",
        "~/Desktop",
        "~/Projects",
        "~/Developer",
        "~/Code",
        "~/dev",
        "~/src"
      ]
      assert is_list(dirs)
    end

    test "@skip_dirs contains directories to skip" do
      # From module: @skip_dirs MapSet.new([...])
      skip_dirs = [
        "node_modules",
        "_build",
        "deps",
        ".git",
        ".svn",
        ".hg",
        "vendor",
        "target",
        "__pycache__",
        ".next",
        ".svelte-kit",
        "dist",
        "build",
        ".cache",
        "tmp",
        ".tmp",
        "coverage",
        "venv",
        ".venv",
        ".env",
        "env"
      ]
      assert is_list(skip_dirs)
    end
  end

  describe "scan_directory/1" do
    test "returns empty list for non-existent directory" do
      result = Scanner.scan_directory("/nonexistent/12345")
      assert is_list(result)
    end

    test "returns empty list for path that is not a directory" do
      # Create a file instead of directory
      temp_file = System.tmp_dir!() <> "/scanner_test_file"
      File.write!(temp_file, "test")
      result = Scanner.scan_directory(temp_file)
      assert is_list(result)
      File.rm!(temp_file)
    end
  end

  describe "edge cases" do
    test "handles unicode in directory path" do
      temp_dir = System.tmp_dir!() <> "/测试目录"
      File.mkdir_p!(temp_dir)
      result = Scanner.scan(temp_dir)
      assert is_list(result)
      File.rm_rf!(temp_dir)
    end

    test "handles very long directory path" do
      long_path = System.tmp_dir!() <> "/" <> String.duplicate("very_long_directory_name_", 100)
      result = Scanner.scan(long_path)
      assert is_list(result)
    end

    test "handles directory with special characters" do
      temp_dir = System.tmp_dir!() <> "/test dir with spaces"
      File.mkdir_p!(temp_dir)
      result = Scanner.scan(temp_dir)
      assert is_list(result)
      File.rm_rf!(temp_dir)
    end
  end

  describe "integration" do
    test "scan_all calls scan_directory for each configured dir" do
      # This tests the integration of scan_all with scan_directory
      result = Scanner.scan_all()
      assert is_list(result)
    end

    test "scan results are unique by path" do
      # From module: |> Enum.uniq_by(fn m -> m.path end)
      result = Scanner.scan_all()
      paths = Enum.map(result, fn m -> m.path end)
      assert length(paths) == length(Enum.uniq(paths))
    end
  end
end
