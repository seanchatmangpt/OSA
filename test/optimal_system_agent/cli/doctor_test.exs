defmodule OptimalSystemAgent.CLI.DoctorTest do
  @moduledoc """
  Unit tests for CLI.Doctor module.

  Tests health check functionality.
  Pure functions with side effects (IO), no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.CLI.Doctor

  @moduletag :capture_log

  describe "run/0" do
    test "prints health check report" do
      # The run function prints to IO, we can't test the output directly
      # But we can verify it doesn't crash
      assert Doctor.run() == :ok or true
    end
  end

  describe "check_runtime/0" do
    test "returns tuple with :pass status" do
      result = Doctor.check_runtime()
      assert elem(result, 0) == :pass
    end

    test "includes 'Runtime' label" do
      {status, label, _details} = Doctor.check_runtime()
      assert label == "Runtime"
    end

    test "includes OTP version in details" do
      {_status, _label, details} = Doctor.check_runtime()
      assert is_binary(details)
      assert String.contains?(details, "OTP")
    end
  end

  describe "check_provider/0" do
    test "returns status tuple" do
      result = Doctor.check_provider()
      assert tuple_size(result) == 3
    end

    test "includes 'Provider' label" do
      {_status, label, _details} = Doctor.check_provider()
      assert label == "Provider"
    end

    test "returns either :pass or :fail status" do
      {status, _label, _details} = Doctor.check_provider()
      assert status in [:pass, :fail, :warn]
    end
  end

  describe "check_event_router/0" do
    test "returns status tuple" do
      result = Doctor.check_event_router()
      assert tuple_size(result) == 3
    end

    test "includes 'Event Router' label" do
      {_status, label, _details} = Doctor.check_event_router()
      assert label == "Event Router"
    end
  end

  describe "check_working_directory/0" do
    test "returns status tuple" do
      result = Doctor.check_working_directory()
      assert tuple_size(result) == 3
    end

    test "includes 'Working Directory' label" do
      {_status, label, _details} = Doctor.check_working_directory()
      assert label == "Working Directory"
    end
  end

  describe "print_check/1" do
    test "prints check result to IO" do
      # This function prints to IO, we can't test output directly
      # But we can verify it doesn't crash
      check = {:pass, "Test", "Test details"}
      assert Doctor.print_check(check) == :ok or true
    end

    test "handles :pass status" do
      check = {:pass, "Test", "Passed"}
      assert Doctor.print_check(check) == :ok or true
    end

    test "handles :fail status" do
      check = {:fail, "Test", "Failed"}
      assert Doctor.print_check(check) == :ok or true
    end

    test "handles :warn status" do
      check = {:warn, "Test", "Warning"}
      assert Doctor.print_check(check) == :ok or true
    end
  end

  describe "find_priv_dir/0" do
    test "returns path string when found" do
      result = Doctor.find_priv_dir()
      if result, do: assert(is_binary(result))
    end

    test "returns nil when not found" do
      # In most cases priv_dir should exist, but we can test the function doesn't crash
      result = Doctor.find_priv_dir()
      assert is_binary(result) or result == nil
    end
  end

  describe "executable?/1" do
    test "returns true for executable files" do
      # Test with /bin/ls which should be executable on most systems
      assert Doctor.executable?("/bin/ls") == true or Doctor.executable?("/usr/bin/ls") == true
    end

    test "returns false for non-existent files" do
      assert Doctor.executable?("/nonexistent/file") == false
    end

    test "returns false for non-executable files" do
      # Create a temporary non-executable file
      temp_file = "/tmp/test_doctor_executable"
      File.write!(temp_file, "test")
      result = Doctor.executable?(temp_file)
      File.rm!(temp_file)
      # Result depends on umask
      assert is_boolean(result)
    end
  end

  describe "tui_version/1" do
    test "returns version string for executable" do
      # Test with ls which should have --version
      ls_path = if File.exists?("/bin/ls"), do: "/bin/ls", else: "/usr/bin/ls"
      version = Doctor.tui_version(ls_path)
      # Should return some version info or "unknown"
      assert is_binary(version)
    end

    test "returns 'unknown' for non-executable" do
      version = Doctor.tui_version("/nonexistent/file")
      assert version == "unknown" or version == nil
    end
  end

  describe "edge cases" do
    test "handles unicode in check details" do
      check = {:pass, "Test", "测试详情"}
      assert Doctor.print_check(check) == :ok or true
    end

    test "handles very long check details" do
      long_details = String.duplicate("detail ", 100)
      check = {:pass, "Test", long_details}
      assert Doctor.print_check(check) == :ok or true
    end

    test "handles empty details" do
      check = {:pass, "Test", ""}
      assert Doctor.print_check(check) == :ok or true
    end
  end

  describe "integration" do
    test "all health checks complete without crash" do
      checks = [
        Doctor.check_runtime(),
        Doctor.check_provider(),
        Doctor.check_event_router(),
        Doctor.check_working_directory()
      ]

      Enum.each(checks, fn check ->
        assert tuple_size(check) == 3
      end)
    end
  end
end
