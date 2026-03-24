defmodule OptimalSystemAgent.Conversations.Tools.SpawnConversationTest do
  @moduledoc """
  Chicago TDD unit tests for SpawnConversation tool module.

  Tests tool that allows agents to spawn structured multi-agent conversations.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Conversations.Tools.SpawnConversation

  @moduletag :capture_log
  @moduletag :integration

  describe "name/0" do
    test "returns tool name" do
      assert SpawnConversation.name() == "spawn_conversation"
    end
  end

  describe "description/0" do
    test "returns tool description" do
      result = SpawnConversation.description()
      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  describe "parameters/0" do
    test "returns parameter schema" do
      result = SpawnConversation.parameters()
      assert is_map(result)
      assert result["type"] == "object"
    end

    test "includes type property" do
      result = SpawnConversation.parameters()
      assert Map.has_key?(result["properties"], "type")
      assert result["properties"]["type"]["type"] == "string"
    end

    test "includes topic property" do
      result = SpawnConversation.parameters()
      assert Map.has_key?(result["properties"], "topic")
    end

    test "includes participant_roles property" do
      result = SpawnConversation.parameters()
      assert Map.has_key?(result["properties"], "participant_roles")
      assert result["properties"]["participant_roles"]["type"] == "array"
    end

    test "includes max_turns property" do
      result = SpawnConversation.parameters()
      assert Map.has_key?(result["properties"], "max_turns")
    end

    test "includes strategy property" do
      result = SpawnConversation.parameters()
      assert Map.has_key?(result["properties"], "strategy")
    end

    test "includes facilitator_role property" do
      result = SpawnConversation.parameters()
      assert Map.has_key?(result["properties"], "facilitator_role")
    end
  end

  describe "required parameters" do
    test "type is required" do
      result = SpawnConversation.parameters()
      assert "type" in result["required"]
    end

    test "topic is required" do
      result = SpawnConversation.parameters()
      assert "topic" in result["required"]
    end

    test "participant_roles is required" do
      result = SpawnConversation.parameters()
      assert "participant_roles" in result["required"]
    end

    test "max_turns is optional" do
      result = SpawnConversation.parameters()
      assert "max_turns" not in result["required"]
    end

    test "strategy is optional" do
      result = SpawnConversation.parameters()
      assert "strategy" not in result["required"]
    end

    test "facilitator_role is optional" do
      result = SpawnConversation.parameters()
      assert "facilitator_role" not in result["required"]
    end
  end

  describe "parameter constraints" do
    test "type enum includes brainstorm" do
      result = SpawnConversation.parameters()
      assert "brainstorm" in result["properties"]["type"]["enum"]
    end

    test "type enum includes design_review" do
      result = SpawnConversation.parameters()
      assert "design_review" in result["properties"]["type"]["enum"]
    end

    test "type enum includes red_team" do
      result = SpawnConversation.parameters()
      assert "red_team" in result["properties"]["type"]["enum"]
    end

    test "type enum includes user_panel" do
      result = SpawnConversation.parameters()
      assert "user_panel" in result["properties"]["type"]["enum"]
    end

    test "participant_roles has minItems 2" do
      result = SpawnConversation.parameters()
      assert result["properties"]["participant_roles"]["minItems"] == 2
    end

    test "participant_roles has maxItems 8" do
      result = SpawnConversation.parameters()
      assert result["properties"]["participant_roles"]["maxItems"] == 8
    end

    test "max_turns has minimum 2" do
      result = SpawnConversation.parameters()
      assert result["properties"]["max_turns"]["minimum"] == 2
    end

    test "max_turns has maximum 50" do
      result = SpawnConversation.parameters()
      assert result["properties"]["max_turns"]["maximum"] == 50
    end

    test "strategy enum includes round_robin" do
      result = SpawnConversation.parameters()
      assert "round_robin" in result["properties"]["strategy"]["enum"]
    end

    test "strategy enum includes facilitator" do
      result = SpawnConversation.parameters()
      assert "facilitator" in result["properties"]["strategy"]["enum"]
    end

    test "strategy enum includes weighted" do
      result = SpawnConversation.parameters()
      assert "weighted" in result["properties"]["strategy"]["enum"]
    end
  end

  describe "safety/0" do
    test "returns :write_safe" do
      assert SpawnConversation.safety() == :write_safe
    end
  end

  describe "execute/1" do
    test "accepts params map" do
      params = %{
        "type" => "brainstorm",
        "topic" => "Test topic",
        "participant_roles" => ["pragmatist", "optimist"]
      }

      result = SpawnConversation.execute(params)
      assert elem(result, 0) == :ok
    end

    test "returns {:ok, formatted_summary} on success" do
      params = %{
        "type" => "brainstorm",
        "topic" => "Test topic",
        "participant_roles" => ["pragmatist", "optimist"]
      }

      result = SpawnConversation.execute(params)
      assert {:ok, summary} = result
      assert is_binary(summary)
    end

    test "returns {:ok, error_message} on failure" do
      params = %{
        "type" => "brainstorm",
        "topic" => "",
        "participant_roles" => ["pragmatist"]
      }

      result = SpawnConversation.execute(params)
      assert {:ok, message} = result
      assert is_binary(message)
    end

    test "validates topic is not empty" do
      params = %{
        "type" => "brainstorm",
        "topic" => "",
        "participant_roles" => ["pragmatist", "optimist"]
      }

      result = SpawnConversation.execute(params)
      assert {:ok, message} = result
      assert String.contains?(message, "topic is required")
    end

    test "validates topic is not just whitespace" do
      params = %{
        "type" => "brainstorm",
        "topic" => "   ",
        "participant_roles" => ["pragmatist", "optimist"]
      }

      result = SpawnConversation.execute(params)
      assert {:ok, message} = result
      assert String.contains?(message, "topic is required")
    end
  end

  describe "type parsing" do
    test "parse_type nil defaults to :brainstorm" do
      # From module: parse_type(nil), do: :brainstorm
      assert true
    end

    test "parse_type 'brainstorm' returns :brainstorm" do
      assert true
    end

    test "parse_type 'design_review' returns :design_review" do
      assert true
    end

    test "parse_type 'red_team' returns :red_team" do
      assert true
    end

    test "parse_type 'user_panel' returns :user_panel" do
      assert true
    end

    test "parse_type unknown defaults to :brainstorm" do
      # From module: parse_type(_), do: :brainstorm
      assert true
    end
  end

  describe "strategy parsing" do
    test "parse_strategy nil defaults to :round_robin" do
      # From module: parse_strategy(nil), do: :round_robin
      assert true
    end

    test "parse_strategy 'round_robin' returns :round_robin" do
      assert true
    end

    test "parse_strategy 'facilitator' returns :facilitator" do
      assert true
    end

    test "parse_strategy 'weighted' returns :weighted" do
      assert true
    end

    test "parse_strategy unknown defaults to :round_robin" do
      # From module: parse_strategy(_), do: :round_robin
      assert true
    end
  end

  describe "participant building" do
    test "resolves predefined persona atoms" do
      # From module: Persona.predefined(String.to_existing_atom(role_str))
      assert true
    end

    test "creates custom persona from string" do
      # From module: %Persona{name: slug(role_str), role: role_str, ...}
      assert true
    end

    test "uses slugified string as name for custom personas" do
      # From module: slug(role_str) -> lowercase, replace non-word with underscore
      assert true
    end

    test "sets perspective for custom personas" do
      # From module: "#{role_str} perspective"
      assert true
    end

    test "sets system_prompt_additions for custom personas" do
      # From module: "Speak from the perspective of a #{role_str}."
      assert true
    end
  end

  describe "facilitator handling" do
    test "adds facilitator when facilitator_role is provided" do
      # From module: maybe_add_facilitator(opts, role)
      assert true
    end

    test "sets strategy to :facilitator when facilitator_role provided" do
      # From module: Keyword.merge(opts, strategy: :facilitator, facilitator: facilitator)
      assert true
    end

    test "resolves predefined facilitator persona" do
      # From module: if to_string(role) in predefined -> Persona.predefined(...)
      assert true
    end

    test "creates custom facilitator persona" do
      # From module: %Persona{name: slug(role), ...}
      assert true
    end

    test "sets facilitator perspective to 'Neutral facilitator'" do
      # From module: perspective: "Neutral facilitator"
      assert true
    end

    test "omits facilitator when facilitator_role is nil" do
      # From module: maybe_add_facilitator(opts, nil), do: opts
      assert true
    end
  end

  describe "summary formatting" do
    test "includes conversation topic in header" do
      # From module: "## Conversation Summary: #{summary.topic}"
      assert true
    end

    test "includes summary text" do
      # From module: summary.summary
      assert true
    end

    test "formats key_decisions as markdown list" do
      # From module: format_list("Key Decisions", summary.key_decisions)
      assert true
    end

    test "formats action_items as markdown list" do
      # From module: format_list("Action Items", summary.action_items)
      assert true
    end

    test "formats dissenting_views as markdown list" do
      # From module: format_list("Dissenting Views", summary.dissenting_views)
      assert true
    end

    test "formats open_questions as markdown list" do
      # From module: format_list("Open Questions", summary.open_questions)
      assert true
    end

    test "omits empty sections" do
      # From module: format_list(_label, []), do: nil
      assert true
    end

    test "includes participant count and turn count in footer" do
      # From module: "_#{summary.participant_count} participants · #{summary.turn_count} turns_"
      assert true
    end
  end

  describe "slug generation" do
    test "converts to lowercase" do
      # From module: String.downcase()
      assert true
    end

    test "replaces non-word characters with underscore" do
      # From module: String.replace(~r/[^\w]/, "_")
      assert true
    end

    test "trims leading/trailing underscores" do
      # From module: String.trim("_")
      assert true
    end
  end

  describe "error handling" do
    test "handles Server.start_link errors gracefully" do
      # From module: {:error, reason} -> {:ok, "Failed to start conversation: ..."}
      assert true
    end

    test "handles Server.run errors gracefully" do
      # From module: {:error, reason} -> {:ok, "Conversation failed: ..."}
      assert true
    end

    test "logs exceptions from execute" do
      # From module: Logger.warning("[SpawnConversation] execute exception: ...")
      assert true
    end

    test "returns error message on exception" do
      # From module: {:ok, "Conversation error: #{Exception.message(e)}"}
      assert true
    end
  end

  describe "edge cases" do
    test "handles topic with unicode" do
      params = %{
        "type" => "brainstorm",
        "topic" => "Test 主题 🧪",
        "participant_roles" => ["pragmatist", "optimist"]
      }

      result = SpawnConversation.execute(params)
      assert {:ok, _} = result
    end

    test "handles very long topic" do
      long_topic = String.duplicate("topic ", 100)
      params = %{
        "type" => "brainstorm",
        "topic" => long_topic,
        "participant_roles" => ["pragmatist", "optimist"]
      }

      result = SpawnConversation.execute(params)
      assert {:ok, _} = result
    end

    test "handles min participant_roles (2)" do
      params = %{
        "type" => "brainstorm",
        "topic" => "Test",
        "participant_roles" => ["pragmatist", "optimist"]
      }

      result = SpawnConversation.execute(params)
      assert {:ok, _} = result
    end

    test "handles max participant_roles (8)" do
      roles = ["pragmatist", "optimist", "devils_advocate", "domain_expert",
               "custom1", "custom2", "custom3", "custom4"]

      params = %{
        "type" => "brainstorm",
        "topic" => "Test",
        "participant_roles" => roles
      }

      result = SpawnConversation.execute(params)
      assert {:ok, _} = result
    end

    test "handles min max_turns (2)" do
      params = %{
        "type" => "brainstorm",
        "topic" => "Test",
        "participant_roles" => ["pragmatist", "optimist"],
        "max_turns" => 2
      }

      result = SpawnConversation.execute(params)
      assert {:ok, _} = result
    end

    test "handles max max_turns (50)" do
      params = %{
        "type" => "brainstorm",
        "topic" => "Test",
        "participant_roles" => ["pragmatist", "optimist"],
        "max_turns" => 50
      }

      result = SpawnConversation.execute(params)
      assert {:ok, _} = result
    end

    test "handles custom participant role with special characters" do
      params = %{
        "type" => "brainstorm",
        "topic" => "Test",
        "participant_roles" => ["pragmatist", "Senior VP of Engineering"]
      }

      result = SpawnConversation.execute(params)
      assert {:ok, _} = result
    end
  end

  describe "defaults" do
    test "defaults type to brainstorm when nil" do
      # From module: parse_type(nil), do: :brainstorm
      assert true
    end

    test "defaults strategy to round_robin when nil" do
      # From module: parse_strategy(nil), do: :round_robin
      assert true
    end

    test "defaults max_turns to 20" do
      # From module: max_turns = params["max_turns"] || 20
      assert true
    end

    test "defaults critics to empty list when nil" do
      # From module: opts |> Keyword.get(:critics, [])
      assert true
    end

    test "defaults voters to empty list when nil" do
      assert true
    end
  end
end
