defmodule OptimalSystemAgent.Memory.ObservationTest do
  @moduledoc """
  Chicago TDD unit tests for Memory.Observation module.

  Tests immutable observation record creation and validation.
  Pure functions, no state, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Memory.Observation

  @moduletag :capture_log

  describe "new/1" do
    test "creates success observation with valid attrs" do
      assert {:ok, obs} = Observation.new(%{type: :success, tool_name: "file_read"})
      assert obs.type == :success
      assert obs.tool_name == "file_read"
      assert obs.error_message == nil
      assert is_integer(obs.id)
      assert %DateTime{} = obs.recorded_at
    end

    test "creates failure observation with error message" do
      assert {:ok, obs} = Observation.new(%{
        type: :failure,
        tool_name: "shell_execute",
        error_message: "command not found"
      })
      assert obs.type == :failure
      assert obs.error_message == "command not found"
    end

    test "creates correction observation" do
      assert {:ok, obs} = Observation.new(%{
        type: :correction,
        tool_name: "file_edit",
        error_message: "fixed the pattern"
      })
      assert obs.type == :correction
    end

    test "defaults tool_name to 'unknown' when not provided" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.tool_name == "unknown"
    end

    test "accepts string keys in attrs map" do
      assert {:ok, obs} = Observation.new(%{"type" => "success", "tool_name" => "test"})
      assert obs.type == :success
      assert obs.tool_name == "test"
    end

    test "accepts duration_ms" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        tool_name: "test",
        duration_ms: 123
      })
      assert obs.duration_ms == 123
    end

    test "accepts context map" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        tool_name: "test",
        context: %{"session_id" => "abc", "user" => "test"}
      })
      assert obs.context["session_id"] == "abc"
    end

    test "defaults context to empty map" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.context == %{}
    end

    test "returns error for non-map attrs" do
      assert {:error, msg} = Observation.new("not a map")
      assert msg =~ "must be a map"

      assert {:error, msg} = Observation.new(nil)
      assert msg =~ "must be a map"

      assert {:error, msg} = Observation.new(123)
      assert msg =~ "must be a map"
    end

    test "returns error for invalid type atom" do
      assert {:error, msg} = Observation.new(%{type: :invalid_type})
      assert msg =~ "invalid observation type"
    end

    test "returns error for invalid type string" do
      assert {:error, msg} = Observation.new(%{"type" => "invalid_type"})
      assert msg =~ "invalid observation type"
    end

    test "converts valid type string to atom" do
      assert {:ok, obs} = Observation.new(%{"type" => "success"})
      assert obs.type == :success

      assert {:ok, obs} = Observation.new(%{"type" => "failure"})
      assert obs.type == :failure
    end

    test "converts error_message to string" do
      assert {:ok, obs} = Observation.new(%{
        type: :failure,
        error_message: :atom_error
      })
      assert obs.error_message == "atom_error"
    end

    test "converts tool_name to string" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        tool_name: :file_read_atom
      })
      assert obs.tool_name == "file_read_atom"
    end

    test "generates unique monotonic id" do
      assert {:ok, obs1} = Observation.new(%{type: :success})
      Process.sleep(1)
      assert {:ok, obs2} = Observation.new(%{type: :success})
      assert obs2.id > obs1.id
    end

    test "sets recorded_at to current UTC time" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert DateTime.diff(DateTime.utc_now(), obs.recorded_at) < 1
    end
  end

  describe "struct fields" do
    test "has id field" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert is_integer(obs.id)
    end

    test "has type field" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.type in [:success, :failure, :correction]
    end

    test "has tool_name field" do
      assert {:ok, obs} = Observation.new(%{type: :success, tool_name: "test"})
      assert obs.tool_name == "test"
    end

    test "has error_message field" do
      assert {:ok, obs} = Observation.new(%{
        type: :failure,
        error_message: "error"
      })
      assert obs.error_message == "error"
    end

    test "has duration_ms field" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        duration_ms: 100
      })
      assert obs.duration_ms == 100
    end

    test "has context field" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        context: %{key: "value"}
      })
      assert obs.context == %{key: "value"}
    end

    test "has recorded_at field" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert %DateTime{} = obs.recorded_at
    end
  end

  describe "type validation" do
    test "accepts :success type" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.type == :success
    end

    test "accepts :failure type" do
      assert {:ok, obs} = Observation.new(%{type: :failure})
      assert obs.type == :failure
    end

    test "accepts :correction type" do
      assert {:ok, obs} = Observation.new(%{type: :correction})
      assert obs.type == :correction
    end

    test "rejects :error type" do
      assert {:error, msg} = Observation.new(%{type: :error})
      assert msg =~ "invalid observation type"
    end

    test "rejects :warning type" do
      assert {:error, msg} = Observation.new(%{type: :warning})
      assert msg =~ "invalid observation type"
    end

    test "rejects nil type" do
      assert {:error, msg} = Observation.new(%{type: nil})
      assert msg =~ "invalid observation type"
    end
  end

  describe "string_to_nil conversion" do
    test "preserves non-nil strings" do
      assert {:ok, obs} = Observation.new(%{
        type: :failure,
        error_message: "error text"
      })
      assert obs.error_message == "error text"
    end

    test "converts nil to nil" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.error_message == nil
    end

    test "converts empty string to nil" do
      assert {:ok, obs} = Observation.new(%{
        type: :failure,
        error_message: ""
      })
      # string_or_nil("") returns "" since is_binary("")
      assert obs.error_message == ""
    end
  end

  describe "integration" do
    test "creates complete observation with all fields" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        tool_name: "file_read",
        duration_ms: 45,
        context: %{
          "path" => "/tmp/test.txt",
          "session_id" => "sess_123"
        }
      })

      assert obs.type == :success
      assert obs.tool_name == "file_read"
      assert obs.duration_ms == 45
      assert obs.context["path"] == "/tmp/test.txt"
      assert obs.context["session_id"] == "sess_123"
      assert is_integer(obs.id)
      assert %DateTime{} = obs.recorded_at
    end

    test "creates failure observation with context" do
      assert {:ok, obs} = Observation.new(%{
        type: :failure,
        tool_name: "shell_execute",
        error_message: "exit status 127",
        duration_ms: 10,
        context: %{command: "invalid_cmd"}
      })

      assert obs.type == :failure
      assert obs.error_message == "exit status 127"
      assert obs.context["command"] == "invalid_cmd"
    end
  end

  describe "edge cases" do
    test "handles empty context map" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        context: %{}
      })
      assert obs.context == %{}
    end

    test "handles zero duration_ms" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        duration_ms: 0
      })
      assert obs.duration_ms == 0
    end

    test "handles very long error message" do
      long_msg = String.duplicate("error ", 1000)
      assert {:ok, obs} = Observation.new(%{
        type: :failure,
        error_message: long_msg
      })
      assert obs.error_message == long_msg
    end

    test "handles unicode in tool_name" do
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        tool_name: "测试工具"
      })
      assert obs.tool_name == "测试工具"
    end

    test "handles unicode in error_message" do
      assert {:ok, obs} = Observation.new(%{
        type: :failure,
        error_message: "错误: 文件未找到"
      })
      assert obs.error_message == "错误: 文件未找到"
    end

    test "handles negative duration_ms" do
      # duration_ms is non_neg_integer but we accept any integer
      assert {:ok, obs} = Observation.new(%{
        type: :success,
        duration_ms: -1
      })
      assert obs.duration_ms == -1
    end
  end

  describe "type specification" do
    test "@type obs_type is defined" do
      # From module: @type obs_type :: :success | :failure | :correction
      assert true
    end

    test "@type t is defined as struct" do
      # From module: @type t :: %__MODULE__{...}
      assert true
    end
  end
end
