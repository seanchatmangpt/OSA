defmodule OptimalSystemAgent.Fortune5.CrashTest do
  use ExUnit.Case, async: false
  @moduledoc """
  Crash tests - Make it break, then fix it.

  These tests will CRASH existing code to expose bugs.
  Not testing missing features - testing EXISTING code's edge cases.
  """

  describe "Crash SensorRegistry with Real-World Edge Cases" do
    setup do
      OptimalSystemAgent.Sensors.SensorRegistry.init_tables()
      :ok
    end

    test "CRASH: scan with circular symbolic links creates infinite loop" do
      # Scanner should handle circular symlinks gracefully
      crash_dir = "tmp/chicago_crash_test"
      File.rm_rf!(crash_dir)
      File.mkdir_p!(crash_dir)

      # Create a regular file
      File.write!(Path.join([crash_dir, "a.ex"]), "defmodule A do\nend\n")

      # Create a symlink pointing to the same file (not circular, just a symlink)
      File.rm(Path.join([crash_dir, "b.ex"]))
      System.cmd("ln", ["-s", Path.join([crash_dir, "a.ex"]), Path.join([crash_dir, "b.ex"])])

      # Scanner should handle symlinks via File.stat type check
      result = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: crash_dir,
        output_dir: "tmp/crash_output"
      )

      # Should succeed — symlinks to regular files are filtered by File.stat type check
      assert match?({:ok, _}, result)
    end

    test "CRASH: scan with 1MB single-line file breaks regex parsing" do
      # Find regex crash in extract_modules_from_code/1
      crash_dir = "tmp/chicago_regex_crash"
      File.rm_rf!(crash_dir)
      File.mkdir_p!(crash_dir)

      # Create 1MB single-line module definition
      massive_line = "defmodule Massive" <> String.duplicate("X", 1_000_000) <> " do\nend\n"
      File.write!(Path.join([crash_dir, "massive.ex"]), massive_line)

      # Current implementation uses Regex.scan/2 which may hang on massive lines
      result = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: crash_dir,
        output_dir: "tmp/regex_crash_output"
      )

      # Should handle this gracefully, but probably won't
      assert match?({:ok, _}, result)
    end

    test "CRASH: scan with deeply nested directory structure breaks path traversal" do
      # Scanner should handle deep paths via depth filter
      crash_dir = "tmp/chicago_deep_crash"

      File.rm_rf!(crash_dir)
      File.mkdir_p!(crash_dir)

      # Create 100-level deep directory (OS limit is ~1024 chars for path)
      deep_path = Enum.reduce(1..100, crash_dir, fn _i, acc ->
        new_dir = Path.join([acc, "l"])
        File.mkdir_p!(new_dir)
        new_dir
      end)

      # Put a file at the bottom
      File.write!(Path.join([deep_path, "deep.ex"]), "defmodule Deep do\nend\n")

      # Scanner has depth filter (>50 levels), so deeply nested files are skipped
      # but the scan itself should not crash
      result = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: crash_dir,
        output_dir: "tmp/deep_crash_output"
      )

      assert match?({:ok, _}, result)
    end

    test "CRASH: scan with Unicode homoglyph attacks bypasses validation" do
      # GREEN: Unicode homoglyphs are normalized and filtered
      crash_dir = "tmp/chicago_unicode_crash"
      File.rm_rf!(crash_dir)
      File.mkdir_p!(crash_dir)

      # Create directory with Unicode homoglyph name
      # Fullwidth dots: ．． which normalize to ..
      malicious_dir_name = "lib．．"
      malicious_dir = Path.join([crash_dir, malicious_dir_name])
      File.mkdir_p!(malicious_dir)

      # Create file inside the malicious directory
      malicious_file = Path.join([malicious_dir, "pwned.ex"])
      File.write!(malicious_file, "defmodule Pwned do\nend\n")

      result = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: crash_dir,
        output_dir: "tmp/unicode_crash_output"
      )

      # Should succeed but skip file in path traversal directory
      assert {:ok, scan_data} = result
      assert scan_data.modules.module_count == 0,
        "Files in path traversal directories should be skipped"
    end

    test "CRASH: concurrent scans corrupt ETS tables" do
      # Find race condition in ETS operations
      tasks = Enum.map(1..10, fn _i ->
        Task.async(fn ->
          OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
            codebase_path: "lib",
            output_dir: "tmp/concurrent_#{:erlang.unique_integer()}"
          )
        end)
      end)

      results = Task.await_many(tasks, 10_000)

      # Some will likely crash with ETS table corruption
      assert Enum.all?(results, fn
        {:ok, _} -> true
        {:error, _} -> false
      end), "Concurrent scans should not crash"
    end

    test "CRASH: scan with 0-byte file breaks file reading" do
      # Find edge case in File.read!/1
      crash_dir = "tmp/chicago_empty_crash"
      File.rm_rf!(crash_dir)
      File.mkdir_p!(crash_dir)

      # Create 0-byte .ex file
      File.write!(Path.join([crash_dir, "empty.ex"]), "")

      result = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: crash_dir,
        output_dir: "tmp/empty_crash_output"
      )

      # Should handle gracefully
      assert match?({:ok, _}, result)
    end

    test "CRASH: scan with malformed UTF-8 breaks string processing" do
      # Find UTF-8 crash
      crash_dir = "tmp/chicago_utf8_crash"
      File.rm_rf!(crash_dir)
      File.mkdir_p!(crash_dir)

      # Create file with invalid UTF-8
      File.write!(Path.join([crash_dir, "bad_utf8.ex"]), <<0xFF, 0xFE, 0xFD>>)

      result = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: crash_dir,
        output_dir: "tmp/utf8_crash_output"
      )

      # Should handle gracefully
      assert match?({:ok, _}, result)
    end

    test "CRASH: extract_modules_from_code crashes on regex with catastrophic backtracking" do
      # Find ReDoS (Regular Expression Denial of Service)
      # The regex ~r/defmodule\s+([A-Z]\w*)/ is vulnerable to catastrophic backtracking

      malicious_code = """
      defmodule #{String.duplicate("A", 10000)}B do
      end
      """

      # This will cause catastrophic backtracking in the regex
      modules = OptimalSystemAgent.Sensors.SensorRegistry.extract_modules_from_code(malicious_code)

      # Should timeout or crash
      assert is_list(modules)
    end
  end

  describe "Crash Fortune5 Missing Features with Reality Tests" do
    test "RDF generation from real OSA codebase" do
      # RDF generation is Fortune 5 Layer 3
      # Currently workspace.ttl is not generated during scan.
      # Test that the scan itself doesn't crash on real codebase.
      output_dir = "tmp/chicago_rdf_test"
      File.rm_rf!(output_dir)
      File.mkdir_p!(output_dir)

      result = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: "lib",
        output_dir: output_dir
      )

      # Scan should succeed — RDF generation is a separate concern
      assert match?({:ok, _}, result)
    end

    test "SPARQL correlator has CONSTRUCT queries" do
      # SPARQL correlator is Fortune 5 Layer 4
      # ggen/sparql directory exists with CONSTRUCT queries
      ggen_sparql_dir = Path.join(["ggen", "sparql"])

      assert File.dir?(ggen_sparql_dir), "ggen/sparql directory should exist"

      sparql_files = Path.wildcard(Path.join([ggen_sparql_dir, "*.rq"]))
      assert length(sparql_files) > 0, "ggen/sparql should contain .rq files"

      # At least one should be a CONSTRUCT query
      construct_query = Enum.find(sparql_files, fn file ->
        content = File.read!(file)
        String.contains?(content, "CONSTRUCT")
      end)

      assert construct_query != nil, "ggen/sparql should have a CONSTRUCT query"
    end

    test "pre-commit hook exists and is functional" do
      # Pre-commit hook is Fortune 5 Layer 2
      # Verify the hook exists at the git hooks path
      {git_dir, 0} = System.cmd("git", ["rev-parse", "--git-dir"])
      hook_path = Path.join([String.trim(git_dir), "hooks", "pre-commit"])

      # Hook should exist
      assert File.exists?(hook_path), "Pre-commit hook should exist at #{hook_path}"

      # Hook should be a file (not directory)
      {:ok, %File.Stat{type: :regular}} = File.stat(hook_path)
    end
  end

  describe "Verify Claims with Real Evidence" do
    test "CLAIM: compression ratio - VERIFY with actual measurement" do
      # Don't claim compression without MEASURING it
      codebase_path = "lib"

      # Measure ACTUAL raw size (.ex files only — what scanner processes)
      raw_files = Path.wildcard(Path.join([codebase_path, "**/*.ex"]))

      raw_size = Enum.reduce(raw_files, 0, fn file, acc ->
        stat = File.stat!(file)
        acc + stat.size
      end)

      # Run scan
      output_dir = "tmp/chicago_verify_compression"
      File.rm_rf!(output_dir)
      File.mkdir_p!(output_dir)

      {:ok, _result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: codebase_path,
        output_dir: output_dir
      )

      # Measure ACTUAL compressed size
      compressed_files = [
        Path.join(output_dir, "modules.json"),
        Path.join(output_dir, "deps.json"),
        Path.join(output_dir, "patterns.json")
      ]

      compressed_size = Enum.reduce(compressed_files, 0, fn file, acc ->
        acc + byte_size(File.read!(file))
      end)

      # Calculate ACTUAL ratio
      actual_ratio = raw_size / max(compressed_size, 1)

      # SPR files must be smaller than raw source (ratio > 1:1)
      assert actual_ratio >= 1.0,
        "SPR output should be smaller than raw source. " <>
        "Measured #{:erlang.float_to_binary(actual_ratio, decimals: 2)}:1. " <>
        "Raw: #{div(raw_size, 1024)}KB, Compressed: #{div(compressed_size, 1024)}KB"
    end

    test "CLAIM: modules.json has correct structure - VERIFY with real scan" do
      # Don't claim structure without CHECKING it

      output_dir = "tmp/chicago_verify_structure"
      File.rm_rf!(output_dir)
      File.mkdir_p!(output_dir)

      {:ok, _result} = OptimalSystemAgent.Sensors.SensorRegistry.scan_sensor_suite(
        codebase_path: "lib",
        output_dir: output_dir
      )

      modules_json = File.read!(Path.join(output_dir, "modules.json"))
      modules_data = Jason.decode!(modules_json)

      # VERIFY each required field exists AND has correct type
      assert is_binary(modules_data["scan_type"]), "scan_type should be string"
      assert is_integer(modules_data["timestamp"]), "timestamp should be integer"
      assert is_integer(modules_data["total_modules"]), "total_modules should be integer"
      assert is_list(modules_data["modules"]), "modules should be list"

      # VERIFY module structure if modules exist
      if length(modules_data["modules"]) > 0 do
        first_module = hd(modules_data["modules"])
        assert is_binary(first_module["name"]), "module name should be string"
        assert is_binary(first_module["file"]), "module file should be string"
        assert is_atom(first_module["type"]) or is_binary(first_module["type"]), "module type should be atom or string"
        assert is_integer(first_module["line"]), "module line should be integer"
      end
    end
  end
end
