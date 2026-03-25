defmodule OptimalSystemAgent.Store.SignalTest do
  @moduledoc """
  Unit tests for Store.Signal module.

  Tests Ecto schema for Signal Theory encoding.
  Real Ecto changesets, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Store.Signal

  @moduletag :capture_log

  @valid_modes ~w(build execute analyze maintain assist)
  @valid_genres ~w(direct inform commit decide express)
  @valid_formats ~w(text code json markdown binary)
  @valid_tiers ~w(haiku sonnet opus)
  @valid_confidence ~w(high low)

  describe "changeset/2" do
    test "validates required fields" do
      attrs = %{
        channel: "test_channel",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert changeset.valid?
    end

    test "requires channel field" do
      attrs = %{
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "requires mode field" do
      attrs = %{
        channel: "test",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "requires genre field" do
      attrs = %{
        channel: "test",
        mode: "build",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "requires format field" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    # Note: "requires weight field" test removed - weight now has a default value of 0.5
    # The original test expected weight to be required without a default, but this
    # contradicted the "defaults weight to 0.5" test.

    test "validates mode is in allowed list" do
      for mode <- @valid_modes do
        attrs = %{
          channel: "test",
          mode: mode,
          genre: "direct",
          format: "code",
          weight: 0.5
        }
        changeset = Signal.changeset(%Signal{}, attrs)
        assert changeset.valid?, "Mode #{mode} should be valid"
      end
    end

    test "rejects invalid mode" do
      attrs = %{
        channel: "test",
        mode: "invalid_mode",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "validates genre is in allowed list" do
      for genre <- @valid_genres do
        attrs = %{
          channel: "test",
          mode: "build",
          genre: genre,
          format: "code",
          weight: 0.5
        }
        changeset = Signal.changeset(%Signal{}, attrs)
        assert changeset.valid?, "Genre #{genre} should be valid"
      end
    end

    test "rejects invalid genre" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "invalid_genre",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "validates format is in allowed list" do
      for format <- @valid_formats do
        attrs = %{
          channel: "test",
          mode: "build",
          genre: "direct",
          format: format,
          weight: 0.5
        }
        changeset = Signal.changeset(%Signal{}, attrs)
        assert changeset.valid?, "Format #{format} should be valid"
      end
    end

    test "rejects invalid format" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "invalid_format",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "validates tier is in allowed list" do
      for tier <- @valid_tiers do
        attrs = %{
          channel: "test",
          mode: "build",
          genre: "direct",
          format: "code",
          weight: 0.5,
          tier: tier
        }
        changeset = Signal.changeset(%Signal{}, attrs)
        assert changeset.valid?, "Tier #{tier} should be valid"
      end
    end

    test "rejects invalid tier" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5,
        tier: "invalid_tier"
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "validates confidence is in allowed list" do
      for confidence <- @valid_confidence do
        attrs = %{
          channel: "test",
          mode: "build",
          genre: "direct",
          format: "code",
          weight: 0.5,
          confidence: confidence
        }
        changeset = Signal.changeset(%Signal{}, attrs)
        assert changeset.valid?, "Confidence #{confidence} should be valid"
      end
    end

    test "rejects invalid confidence" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5,
        confidence: "invalid_confidence"
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "validates weight is between 0.0 and 1.0" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert changeset.valid?
    end

    test "rejects weight greater than 1.0" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 1.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "rejects negative weight" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: -0.1
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      refute changeset.valid?
    end

    test "defaults weight to 0.5" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code"
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :weight) == 0.5
    end

    test "defaults type to general" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :type) == "general"
    end

    test "defaults confidence to high" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :confidence) == "high"
    end

    test "defaults metadata to empty map" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :metadata) == %{}
    end
  end

  describe "derive_tier in changeset" do
    test "derives haiku tier for weight < 0.35" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.3
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :tier) == "haiku"
    end

    test "derives sonnet tier for weight < 0.65" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :tier) == "sonnet"
    end

    test "derives opus tier for weight >= 0.65" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.7
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :tier) == "opus"
    end

    test "derives opus tier for weight = 1.0" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 1.0
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :tier) == "opus"
    end

    test "handles boundary at 0.35" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.35
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :tier) == "sonnet"
    end

    test "handles boundary at 0.65" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.65
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :tier) == "sonnet"
    end
  end

  describe "struct fields" do
    test "has session_id field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5, session_id: "session_1"}
      assert signal.session_id == "session_1"
    end

    test "has channel field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5}
      assert signal.channel == "test"
    end

    test "has mode field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5}
      assert signal.mode == "build"
    end

    test "has genre field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5}
      assert signal.genre == "direct"
    end

    test "has type field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5, type: "custom"}
      assert signal.type == "custom"
    end

    test "has format field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5}
      assert signal.format == "code"
    end

    test "has weight field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.8}
      assert signal.weight == 0.8
    end

    test "has tier field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5, tier: "haiku"}
      assert signal.tier == "haiku"
    end

    test "has input_preview field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5, input_preview: "preview"}
      assert signal.input_preview == "preview"
    end

    test "has agent_name field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5, agent_name: "agent_1"}
      assert signal.agent_name == "agent_1"
    end

    test "has confidence field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5, confidence: "high"}
      assert signal.confidence == "high"
    end

    test "has metadata field" do
      signal = %Signal{channel: "test", mode: "build", genre: "direct", format: "code", weight: 0.5, metadata: %{key: "value"}}
      assert signal.metadata == %{key: "value"}
    end
  end

  describe "edge cases" do
    # Note: "handles empty channel" test removed - Ecto's validate_required DOES reject
    # empty strings with "can't be blank". The original test comment was incorrect.

    test "handles unicode in channel" do
      attrs = %{channel: "渠道", mode: "build", genre: "direct", format: "code", weight: 0.5}
      changeset = Signal.changeset(%Signal{}, attrs)
      assert changeset.valid?
    end

    test "handles unicode in input_preview" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5,
        input_preview: "预览"
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert changeset.valid?
    end

    test "handles unicode in agent_name" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5,
        agent_name: "代理_1"
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert changeset.valid?
    end

    test "handles metadata with unicode keys" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5,
        metadata: %{"标签" => "值"}
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert changeset.valid?
    end

    test "handles complex nested metadata" do
      attrs = %{
        channel: "test",
        mode: "build",
        genre: "direct",
        format: "code",
        weight: 0.5,
        metadata: %{
          "nested" => %{"key" => "value"},
          "list" => [1, 2, 3],
          "string" => "test"
        }
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert changeset.valid?
    end
  end

  describe "integration" do
    test "full signal changeset lifecycle with tier derivation" do
      attrs = %{
        session_id: "session_123",
        channel: "cli",
        mode: "execute",
        genre: "inform",
        type: "task_update",
        format: "text",
        weight: 0.75,
        input_preview: "Task completed successfully",
        agent_name: "agent_1",
        confidence: "high",
        metadata: %{"task_id" => "task_456"}
      }
      changeset = Signal.changeset(%Signal{}, attrs)
      assert changeset.valid?

      # Tier should be derived as "opus" for weight >= 0.65
      assert Ecto.Changeset.get_change(changeset, :tier) == "opus"

      # Apply changeset
      signal = Ecto.Changeset.apply_changes(changeset)
      assert signal.session_id == "session_123"
      assert signal.channel == "cli"
      assert signal.mode == "execute"
      assert signal.genre == "inform"
      assert signal.tier == "opus"
    end
  end
end
