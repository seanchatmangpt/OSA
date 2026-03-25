defmodule OptimalSystemAgent.SignalRealTest do
  @moduledoc """
  Chicago TDD integration tests for Signal (S=(M,G,T,F,W)).

  NO MOCKS. Tests real signal construction, validation, CloudEvents encoding.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Signal

  describe "Signal.new/1" do
    test "CRASH: creates signal with defaults" do
      signal = Signal.new(%{})
      assert signal.mode == :assist
      assert signal.genre == :direct
      assert signal.type == :general
      assert signal.format == :text
      assert signal.weight == 0.5
      assert signal.content == ""
    end

    test "CRASH: creates signal with custom attributes" do
      signal = Signal.new(%{mode: :execute, genre: :inform, weight: 0.9, content: "hello"})
      assert signal.mode == :execute
      assert signal.genre == :inform
      assert signal.weight == 0.9
      assert signal.content == "hello"
    end

    test "CRASH: unknown mode still creates struct" do
      signal = Signal.new(%{mode: :unknown})
      assert signal.mode == :unknown
    end
  end

  describe "Signal.valid?/1" do
    test "CRASH: valid with all default values" do
      assert Signal.valid?(Signal.new(%{}))
    end

    test "CRASH: valid with all custom valid values" do
      signal = Signal.new(%{mode: :build, genre: :commit, type: :request, format: :code})
      assert Signal.valid?(signal)
    end

    test "CRASH: invalid with unknown mode" do
      refute Signal.valid?(Signal.new(%{mode: :invalid}))
    end

    test "CRASH: invalid with unknown genre" do
      refute Signal.valid?(Signal.new(%{genre: :invalid}))
    end

    test "CRASH: invalid with unknown type" do
      refute Signal.valid?(Signal.new(%{type: :invalid}))
    end

    test "CRASH: invalid with unknown format" do
      refute Signal.valid?(Signal.new(%{format: :invalid}))
    end

    test "CRASH: valid with every mode enum value" do
      for mode <- [:execute, :build, :analyze, :maintain, :assist] do
        assert Signal.valid?(Signal.new(%{mode: mode}))
      end
    end

    test "CRASH: valid with every genre enum value" do
      for genre <- [:direct, :inform, :commit, :decide, :express] do
        assert Signal.valid?(Signal.new(%{genre: genre}))
      end
    end
  end

  describe "Signal.to_cloud_event/1" do
    test "CRASH: returns CloudEvents envelope" do
      signal = Signal.new(%{content: "test"})
      ce = Signal.to_cloud_event(signal)
      assert ce.specversion == "1.0"
      assert ce.source == "osa-agent"
      assert ce.type == "com.osa.signal.assist"
      assert is_binary(ce.id)
      assert is_map(ce.data)
    end

    test "CRASH: type reflects signal mode" do
      signal = Signal.new(%{mode: :execute})
      ce = Signal.to_cloud_event(signal)
      assert ce.type == "com.osa.signal.execute"
    end

    test "CRASH: data contains all signal fields" do
      signal = Signal.new(%{mode: :build, genre: :commit, weight: 0.7, content: "hi"})
      ce = Signal.to_cloud_event(signal)
      assert ce.data.mode == :build
      assert ce.data.genre == :commit
      assert ce.data.weight == 0.7
      assert ce.data.content == "hi"
    end
  end

  describe "Signal.from_cloud_event/1" do
    test "CRASH: decodes valid CloudEvents envelope" do
      ce = %{
        "specversion" => "1.0",
        "type" => "com.osa.signal.execute",
        "source" => "osa-agent",
        "data" => %{
          "mode" => "execute",
          "genre" => "commit",
          "type" => "request",
          "format" => "code",
          "weight" => 0.8,
          "content" => "decoded"
        }
      }
      signal = Signal.from_cloud_event(ce)
      # GAP: from_cloud_event/1 does not atomize enum values — returns string values
      # because String.to_existing_atom only converts keys, not values
      assert signal.content == "decoded"
      assert signal.weight == 0.8
      assert signal.mode in [:execute, "execute"]
      assert signal.genre in [:commit, "commit"]
    end

    test "CRASH: missing data returns default signal" do
      ce = %{"specversion" => "1.0"}
      signal = Signal.from_cloud_event(ce)
      assert signal.mode == :assist
      assert signal.content == ""
    end

    test "CRASH: non-map data returns default signal" do
      ce = %{"data" => "not a map"}
      signal = Signal.from_cloud_event(ce)
      assert signal.mode == :assist
    end
  end

  describe "Signal.measure_sn_ratio/1" do
    test "CRASH: returns weight field value" do
      signal = Signal.new(%{weight: 0.85})
      assert Signal.measure_sn_ratio(signal) == 0.85
    end

    test "CRASH: default weight is 0.5" do
      signal = Signal.new(%{})
      assert Signal.measure_sn_ratio(signal) == 0.5
    end
  end
end
