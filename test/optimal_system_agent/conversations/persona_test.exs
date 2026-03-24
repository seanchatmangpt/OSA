defmodule OptimalSystemAgent.Conversations.PersonaTest do
  @moduledoc """
  Chicago TDD unit tests for Persona module.

  Tests lightweight agent configuration for conversation participants.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Conversations.Persona

  @moduletag :capture_log

  describe "predefined_keys/0" do
    test "returns list of predefined persona atoms" do
      keys = Persona.predefined_keys()

      assert is_list(keys)
      assert :devils_advocate in keys
      assert :optimist in keys
      assert :pragmatist in keys
      assert :domain_expert in keys
    end
  end

  describe "predefined/1" do
    test "returns devils_advocate persona" do
      persona = Persona.predefined(:devils_advocate)

      assert persona.name == "devils_advocate"
      assert persona.role == "Devil's Advocate"
      assert persona.perspective =~ "challenger"
      assert persona.system_prompt_additions =~ "challenge every claim"
    end

    test "returns optimist persona" do
      persona = Persona.predefined(:optimist)

      assert persona.name == "optimist"
      assert persona.role == "Optimist"
      assert persona.perspective =~ "amplifier"
      assert persona.system_prompt_additions =~ "what is working"
    end

    test "returns pragmatist persona" do
      persona = Persona.predefined(:pragmatist)

      assert persona.name == "pragmatist"
      assert persona.role == "Pragmatist"
      assert persona.perspective =~ "Feasibility"
      assert persona.system_prompt_additions =~ "concrete, achievable"
    end

    test "returns domain_expert persona" do
      persona = Persona.predefined(:domain_expert)

      assert persona.name == "domain_expert"
      assert persona.role == "Domain Expert"
      assert persona.perspective =~ "authority"
      assert persona.system_prompt_additions =~ "deep, accurate domain knowledge"
    end

    test "raises for unknown persona key" do
      assert_raise ArgumentError, fn ->
        Persona.predefined(:unknown_persona)
      end
    end
  end

  describe "from_map/1" do
    test "builds persona from keyword list" do
      attrs = [
        name: "alice",
        role: "Architect",
        perspective: "System design expert",
        system_prompt_additions: "Focus on scalability"
      ]

      persona = Persona.from_map(attrs)

      assert persona.name == "alice"
      assert persona.role == "Architect"
      assert persona.perspective == "System design expert"
      assert persona.system_prompt_additions == "Focus on scalability"
    end

    test "builds persona from map with string keys" do
      attrs = %{
        "name" => "bob",
        "role" => "Reviewer",
        "perspective" => "Quality focused",
        "system_prompt_additions" => "Check for bugs"
      }

      persona = Persona.from_map(attrs)

      assert persona.name == "bob"
      assert persona.role == "Reviewer"
      assert persona.perspective == "Quality focused"
      assert persona.system_prompt_additions == "Check for bugs"
    end

    test "provides defaults for missing fields" do
      persona = Persona.from_map(%{})

      assert persona.name == "participant"
      assert persona.role == "Participant"
      assert persona.perspective == ""
      assert persona.system_prompt_additions == ""
      assert persona.model == nil
    end

    test "converts atom names to strings" do
      persona = Persona.from_map(name: :alice)

      assert persona.name == "alice"
      assert is_binary(persona.name)
    end

    test "accepts custom model" do
      persona = Persona.from_map(name: "test", model: "claude-opus-4-5")

      assert persona.model == "claude-opus-4-5"
    end
  end

  describe "resolve/1" do
    test "returns persona struct unchanged" do
      persona = %Persona{name: "test", role: "Test"}

      result = Persona.resolve(persona)

      assert result == persona
    end

    test "resolves atom key to predefined persona" do
      persona = Persona.resolve(:optimist)

      assert persona.name == "optimist"
      assert persona.role == "Optimist"
    end

    test "resolves map to custom persona" do
      persona = Persona.resolve(%{name: "custom", role: "Custom"})

      assert persona.name == "custom"
      assert persona.role == "Custom"
    end
  end

  describe "system_prompt/2" do
    test "builds system prompt with topic" do
      persona = %Persona{
        name: "alice",
        role: "Architect",
        perspective: "Design expert",
        system_prompt_additions: ""
      }

      prompt = Persona.system_prompt(persona, "microservices architecture")

      assert String.contains?(prompt, "alice")
      assert String.contains?(prompt, "Architect")
      assert String.contains?(prompt, "Design expert")
      assert String.contains?(prompt, "microservices architecture")
    end

    test "includes system_prompt_additions when present" do
      persona = %Persona{
        name: "test",
        role: "Tester",
        perspective: "QA",
        system_prompt_additions: "Always test edge cases."
      }

      prompt = Persona.system_prompt(persona, "testing strategy")

      assert String.contains?(prompt, "Always test edge cases.")
    end

    test "handles empty system_prompt_additions" do
      persona = %Persona{
        name: "test",
        role: "Test",
        perspective: "Testing",
        system_prompt_additions: ""
      }

      prompt = Persona.system_prompt(persona, "topic")

      # Should not have extra blank line when additions is empty
      refute String.contains?(prompt, "\n\n\n")
    end
  end

  describe "struct definition" do
    test "creates persona struct with all fields" do
      persona = %Persona{
        name: "test",
        role: "Test Role",
        perspective: "Test perspective",
        system_prompt_additions: "Test additions",
        model: "test-model"
      }

      assert persona.name == "test"
      assert persona.role == "Test Role"
      assert persona.perspective == "Test perspective"
      assert persona.system_prompt_additions == "Test additions"
      assert persona.model == "test-model"
    end

    test "model defaults to nil" do
      persona = %Persona{name: "test"}

      assert persona.model == nil
    end
  end

  describe "integration - full persona workflow" do
    test "create predefined persona and generate system prompt" do
      persona = Persona.predefined(:pragmatist)
      prompt = Persona.system_prompt(persona, "API design")

      assert String.contains?(prompt, "pragmatist")
      assert String.contains?(prompt, "Pragmatist")
      assert String.contains?(prompt, "API design")
      assert String.contains?(prompt, "concrete, achievable")
    end

    test "create custom persona and generate system prompt" do
      persona = Persona.from_map(%{
        name: "security_expert",
        role: "Security Analyst",
        perspective: "Threat modeling specialist",
        system_prompt_additions: "Always consider attack vectors."
      })

      prompt = Persona.system_prompt(persona, "authentication system")

      assert String.contains?(prompt, "security_expert")
      assert String.contains?(prompt, "Security Analyst")
      assert String.contains?(prompt, "authentication system")
      assert String.contains?(prompt, "Always consider attack vectors.")
    end
  end
end
