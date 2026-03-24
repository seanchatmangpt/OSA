defmodule OptimalSystemAgent.A2A.ConfigValidatorTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.A2A.ConfigValidator

  describe "validate_agent_card/1" do
    test "validates a minimal valid agent card" do
      card = %{
        "name" => "test-agent",
        "version" => "1.0.0"
      }

      assert {:ok, validated} = ConfigValidator.validate_agent_card(card)
      assert validated["name"] == "test-agent"
      assert validated["version"] == "1.0.0"
    end

    test "validates a full agent card" do
      card = %{
        "name" => "osa-agent",
        "version" => "0.2.5",
        "display_name" => "OSA Agent",
        "description" => "An OSA agent",
        "url" => "http://localhost:9089/api/v1/a2a",
        "capabilities" => ["streaming", "tools", "stateless"],
        "input_schema" => %{
          "type" => "object",
          "properties" => %{
            "message" => %{"type" => "string"}
          },
          "required" => ["message"]
        }
      }

      assert {:ok, validated} = ConfigValidator.validate_agent_card(card)
      assert validated["name"] == "osa-agent"
      assert validated["version"] == "0.2.5"
      assert validated["capabilities"] == ["streaming", "tools", "stateless"]
    end

    test "returns error for missing name" do
      card = %{"version" => "1.0.0"}
      assert {:error, msg} = ConfigValidator.validate_agent_card(card)
      assert msg =~ "name"
    end

    test "returns error for empty name" do
      card = %{"name" => "", "version" => "1.0.0"}
      assert {:error, msg} = ConfigValidator.validate_agent_card(card)
      assert msg =~ "name"
    end

    test "returns error for missing version" do
      card = %{"name" => "test"}
      assert {:error, msg} = ConfigValidator.validate_agent_card(card)
      assert msg =~ "version"
    end

    test "returns error for empty version" do
      card = %{"name" => "test", "version" => ""}
      assert {:error, msg} = ConfigValidator.validate_agent_card(card)
      assert msg =~ "version"
    end

    test "returns error for invalid capabilities" do
      card = %{
        "name" => "test",
        "version" => "1.0.0",
        "capabilities" => ["streaming", "teleportation"]
      }

      assert {:error, msg} = ConfigValidator.validate_agent_card(card)
      assert msg =~ "teleportation"
    end

    test "accepts all valid capabilities" do
      card = %{
        "name" => "test",
        "version" => "1.0.0",
        "capabilities" => ["streaming", "tools", "stateless", "push_notifications"]
      }

      assert {:ok, validated} = ConfigValidator.validate_agent_card(card)

      assert validated["capabilities"] == [
               "streaming",
               "tools",
               "stateless",
               "push_notifications"
             ]
    end

    test "returns error for invalid input_schema type" do
      card = %{
        "name" => "test",
        "version" => "1.0.0",
        "input_schema" => %{"type" => "array"}
      }

      assert {:error, msg} = ConfigValidator.validate_agent_card(card)
      assert msg =~ "input_schema.type"
    end

    test "returns error for invalid input_schema properties" do
      card = %{
        "name" => "test",
        "version" => "1.0.0",
        "input_schema" => %{"type" => "object", "properties" => "not a map"}
      }

      assert {:error, msg} = ConfigValidator.validate_agent_card(card)
      assert msg =~ "properties"
    end

    test "returns error for non-map input" do
      assert {:error, msg} = ConfigValidator.validate_agent_card("not a map")
      assert msg =~ "map"
    end

    test "normalizes card with defaults" do
      card = %{"name" => "test", "version" => "1.0.0"}

      assert {:ok, validated} = ConfigValidator.validate_agent_card(card)
      assert validated["display_name"] == "test"
      assert validated["description"] == ""
      assert validated["capabilities"] == []
      assert validated["input_schema"]["type"] == "object"
    end
  end

  describe "validate_agent_cards/1" do
    test "validates a list of valid cards" do
      cards = [
        %{"name" => "agent1", "version" => "1.0.0"},
        %{"name" => "agent2", "version" => "2.0.0"}
      ]

      assert {:ok, validated} = ConfigValidator.validate_agent_cards(cards)
      assert length(validated) == 2
    end

    test "returns errors for mixed valid and invalid cards" do
      cards = [
        %{"name" => "valid", "version" => "1.0.0"},
        %{"name" => "no-version"},
        %{"version" => "1.0.0"}
      ]

      assert {:error, msg} = ConfigValidator.validate_agent_cards(cards)
      assert msg =~ "no-version"
    end

    test "returns error for non-list input" do
      assert {:error, _} = ConfigValidator.validate_agent_cards("not a list")
    end

    test "returns ok for empty list" do
      assert {:ok, []} = ConfigValidator.validate_agent_cards([])
    end
  end
end
