defmodule OptimalSystemAgent.Memory.ObservationRealTest do
  @moduledoc """
  Chicago TDD integration tests for Memory.Observation.

  NO MOCKS. Tests real observation construction and validation.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Memory.Observation

  describe "Observation.new/1 — valid types" do
    test "CRASH: :success type creates observation" do
      assert {:ok, %Observation{}} = Observation.new(%{type: :success, tool_name: "file_read"})
    end

    test "CRASH: :failure type creates observation" do
      assert {:ok, %Observation{}} = Observation.new(%{type: :failure, tool_name: "write", error_message: "boom"})
    end

    test "CRASH: :correction type creates observation" do
      assert {:ok, %Observation{}} = Observation.new(%{type: :correction, tool_name: "edit"})
    end
  end

  describe "Observation.new/1 — defaults" do
    test "CRASH: default tool_name is unknown" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.tool_name == "unknown"
    end

    test "CRASH: default context is empty map" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.context == %{}
    end

    test "CRASH: default error_message is nil" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.error_message == nil
    end

    test "CRASH: default duration_ms is nil" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert obs.duration_ms == nil
    end

    test "CRASH: id is a positive integer (gap fixed)" do
      # GAP FIXED: now uses System.unique_integer([:positive, :monotonic])
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert is_integer(obs.id)
      assert obs.id > 0
    end

    test "CRASH: recorded_at is a DateTime" do
      assert {:ok, obs} = Observation.new(%{type: :success})
      assert %DateTime{} = obs.recorded_at
    end
  end

  describe "Observation.new/1 — field handling" do
    test "CRASH: sets error_message for failures" do
      assert {:ok, obs} = Observation.new(%{type: :failure, error_message: "file not found"})
      assert obs.error_message == "file not found"
    end

    test "CRASH: error_message coerces non-string to string" do
      assert {:ok, obs} = Observation.new(%{type: :failure, error_message: :atom_err})
      assert obs.error_message == "atom_err"
    end

    test "CRASH: sets duration_ms" do
      assert {:ok, obs} = Observation.new(%{type: :success, duration_ms: 123})
      assert obs.duration_ms == 123
    end

    test "CRASH: sets context" do
      assert {:ok, obs} = Observation.new(%{type: :success, context: %{session: "s1"}})
      assert obs.context == %{session: "s1"}
    end

    test "CRASH: string type works" do
      assert {:ok, %Observation{type: :success}} = Observation.new(%{"type" => "success"})
    end
  end

  describe "Observation.new/1 — validation" do
    test "CRASH: invalid type returns error" do
      assert {:error, msg} = Observation.new(%{type: :invalid})
      assert is_binary(msg)
      assert String.contains?(msg, "invalid observation type")
    end

    test "CRASH: non-map input returns error" do
      assert {:error, msg} = Observation.new("not a map")
      assert msg == "observation attributes must be a map"
    end

    test "CRASH: nil input returns error" do
      assert {:error, msg} = Observation.new(nil)
      assert msg == "observation attributes must be a map"
    end

    test "CRASH: list input returns error" do
      assert {:error, _} = Observation.new([])
    end

    test "CRASH: unknown string type returns error" do
      assert {:error, msg} = Observation.new(%{type: "unknown_type"})
      assert is_binary(msg)
    end
  end
end
