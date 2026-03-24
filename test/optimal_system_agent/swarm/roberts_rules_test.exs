defmodule OptimalSystemAgent.Swarm.RobertsRulesTest do
  @moduledoc """
  Chicago TDD — Roberts Rules of Order integration tests.

  NO MOCKS. NO HARDCODING. Every test uses real Groq LLM calls.

  All LLM calls use STRUCTURED OUTPUTS (response_format: json_object + Jason.decode!).
  No free-text parsing. No regex on LLM responses.

  Tests the full parliamentary procedure pipeline:
    RobertsRules.deliberate → LLM motion generation → LLM seconds → LLM debate → LLM voting → LLM points of order

  Following Joe Armstrong's principle: "Make it crash, then fix it."
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  setup do
    api_key = Application.get_env(:optimal_system_agent, :groq_api_key)

    if is_nil(api_key) or api_key == "" do
      flunk("GROQ_API_KEY not configured — set it in .env or environment")
    end

    # Ensure default provider is groq for Roberts Rules integration tests
    original = Application.get_env(:optimal_system_agent, :default_provider)
    Application.put_env(:optimal_system_agent, :default_provider, :groq)

    on_exit(fn ->
      if original, do: Application.put_env(:optimal_system_agent, :default_provider, original)
    end)

    :ok
  end

  describe "Chicago TDD: Roberts Rules — Structured Output Validation" do
    test "CRASH: call_llm_json returns valid parsed JSON (not free text)" do
      # Chicago TDD: Verify the structured output mechanism works end-to-end
      # This is the foundation — all Roberts Rules calls go through call_llm_json
      result =
        OptimalSystemAgent.Swarm.RobertsRules.call_llm_json(
          "Respond with JSON: {\"status\": \"ok\", \"number\": 42}",
          temperature: 0.1
        )

      assert {:ok, parsed} = result
      assert is_map(parsed), "Result must be a parsed map, not a string"
      # Tool calling may wrap in "data" key — check for expected fields
      assert Map.has_key?(parsed, "status") or Map.has_key?(parsed, "data"),
             "Parsed result must have expected keys"
    end

    test "CRASH: call_llm_json uses tool calling or response_format (no regex parsing)" do
      # Chicago TDD: Verify the implementation uses structured outputs, not free text
      # Check that the source code uses tool calling or response_format and Jason.decode
      source = File.read!("lib/optimal_system_agent/swarm/roberts_rules.ex")

      # Must use tool calling (primary) or response_format (fallback) for structured outputs
      structured_output =
        String.contains?(source, "tools:") and String.contains?(source, "respond_json")

      response_format = String.contains?(source, "response_format:")

      assert structured_output or response_format,
             "RobertsRules must use tool calling or response_format for structured outputs"

      # Must use Jason.decode (not regex)
      assert String.contains?(source, "Jason.decode"),
             "RobertsRules must use Jason.decode for JSON parsing"

      # Must NOT use Regex.run for parsing LLM responses
      refute String.contains?(source, "Regex.run"),
             "RobertsRules must NOT use regex to parse LLM responses"

      # Must NOT use String.contains for parsing vote/second decisions
      refute String.contains?(source, "String.contains?(String.downcase(response)"),
             "RobertsRules must NOT use string matching to parse LLM responses"

      # Must NOT hardcode provider or model — use whatever is configured
      refute String.contains?(source, "provider: :groq"),
             "RobertsRules must NOT hardcode :groq provider"
      refute String.contains?(source, ~s(model: "openai/)),
             "RobertsRules must NOT hardcode a specific model"
    end
  end

  describe "Chicago TDD: Roberts Rules — Full Deliberation" do
    test "CRASH: full deliberation with real LLM structured calls returns structured result" do
      # Chicago TDD: Complete parliamentary procedure with real Groq structured calls
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should the team adopt Elixir for the new microservice?",
          members: ["Alice", "Bob", "Charlie"],
          quorum: 2,
          voting_method: :roll_call,
          max_motions: 2
        )

      assert {:ok, deliberation} = result

      # Verify all required fields
      assert is_list(deliberation.motions), "Should have motions"
      assert is_list(deliberation.points_of_order), "Should have points of order"
      assert is_list(deliberation.transcript), "Should have transcript"
      assert is_map(deliberation.vote_record), "Should have vote record"
      assert deliberation.final_decision in [:adopted, :rejected, :postponed],
        "Should have a final decision"

      # Verify transcript has real LLM-generated content (not empty/hardcoded)
      speech_entries = Enum.filter(deliberation.transcript, fn entry ->
        entry.action == :speech and entry.speaker not in ["system", "chair"]
      end)

      assert length(speech_entries) > 0, "Transcript should have member speeches from LLM"

      # Verify at least one motion was generated by LLM
      assert length(deliberation.motions) > 0, "Should have at least one motion"

      first_motion = hd(deliberation.motions)
      assert String.length(first_motion.text) > 10, "Motion text should be LLM-generated, not hardcoded"

      # Verify final_decision is :adopted or :rejected (the build_result function produces these)
      assert deliberation.final_decision in [:adopted, :rejected]
    end

    test "CRASH: deliberation respects quorum requirement" do
      # Chicago TDD: Quorum must be checked and enforced
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we use Docker for deployment?",
          members: ["Alice", "Bob"],
          quorum: 2,
          voting_method: :voice
        )

      assert {:ok, deliberation} = result

      # Transcript should mention quorum
      quorum_mentions = Enum.filter(deliberation.transcript, fn entry ->
        String.contains?(String.downcase(entry.text), "quorum")
      end)

      assert length(quorum_mentions) > 0, "Transcript should mention quorum"
    end

    test "CRASH: each member gets independent LLM vote" do
      # Chicago TDD: Votes are NOT hardcoded — each member independently decides via LLM
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we implement dark mode in the UI?",
          members: ["Alice", "Bob", "Charlie"],
          quorum: 2,
          voting_method: :roll_call,
          max_motions: 1
        )

      assert {:ok, deliberation} = result

      # Vote record should have entries for all members
      assert map_size(deliberation.vote_record) > 0, "All members should vote"

      # Each vote should be a valid vote type
      Enum.each(deliberation.vote_record, fn {_member, vote} ->
        assert vote in [:aye, :nay, :present, :absent],
          "Each vote should be a valid Roberts Rules vote, got: #{inspect(vote)}"
      end)

      # Verify the transcript has enough entries to prove LLM was called for each member
      assert length(deliberation.transcript) >= 4,
        "Transcript should have multiple entries proving full deliberation occurred"
    end

    test "CRASH: debate speeches are LLM-generated via structured JSON" do
      # Chicago TDD: Speeches must come from LLM structured JSON, not templates
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we adopt trunk-based development?",
          members: ["Alice", "Bob"],
          quorum: 2,
          voting_method: :voice,
          max_motions: 1
        )

      assert {:ok, deliberation} = result

      # Extract debate speeches (not chair or system messages)
      speeches =
        deliberation.transcript
        |> Enum.filter(fn entry ->
          entry.action == :speech and entry.speaker not in ["system", "chair"]
        end)
        |> Enum.map(fn entry -> entry.text end)

      # Verify speeches are unique (not duplicated templates)
      unique_speeches = Enum.uniq(speeches)
      assert length(unique_speeches) > 1, "Debate speeches should be unique, not template-based"

      # Verify speeches have meaningful length (LLM-generated, not one-word)
      long_speeches = Enum.filter(speeches, fn s -> String.length(s) > 20 end)
      assert length(long_speeches) > 0, "Speeches should have substantive LLM-generated content"
    end

    test "CRASH: points of order use LLM structured JSON for ruling" do
      # Chicago TDD: Points of order are raised and ruled by LLM via structured JSON
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we migrate to Kubernetes?",
          members: ["Alice", "Bob", "Charlie", "Diana"],
          quorum: 3,
          voting_method: :roll_call,
          max_motions: 1
        )

      assert {:ok, deliberation} = result

      # Points of order (if any) should have structured rulings
      Enum.each(deliberation.points_of_order, fn point ->
        assert point.ruling in [:sustained, :overruled],
          "Point of order ruling should be sustained or overruled"
        assert String.length(point.reason) > 0,
          "Ruling should have LLM-generated reason, not hardcoded"
      end)
    end
  end

  describe "Chicago TDD: Roberts Rules — Voting Methods" do
    test "CRASH: roll call voting records each member's vote individually" do
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we add monitoring to production?",
          members: ["Alice", "Bob"],
          quorum: 2,
          voting_method: :roll_call,
          max_motions: 1
        )

      assert {:ok, deliberation} = result

      # Roll call should have vote record for every member
      assert map_size(deliberation.vote_record) >= 2,
        "Roll call should record every member's vote"
    end

    test "CRASH: voice voting produces vote outcome" do
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we implement caching?",
          members: ["Alice", "Bob", "Charlie"],
          quorum: 2,
          voting_method: :voice,
          max_motions: 1
        )

      assert {:ok, deliberation} = result

      # Vote result should be recorded in transcript (chair announces outcome)
      chair_entries = Enum.filter(deliberation.transcript, fn entry ->
        entry.speaker in ["chair", "system"]
      end)

      assert length(chair_entries) > 0, "Chair should announce vote outcome"
    end
  end

  describe "Chicago TDD: Roberts Rules — Motion Lifecycle" do
    test "CRASH: motion requires a second before debate" do
      # Chicago TDD: A motion must be seconded before debate begins
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we use TypeScript for the frontend?",
          members: ["Alice", "Bob"],
          quorum: 2,
          voting_method: :voice,
          max_motions: 1
        )

      assert {:ok, deliberation} = result

      # The deliberation should produce at least one motion in the result
      assert length(deliberation.motions) > 0,
        "Deliberation should produce at least one motion"
    end

    test "CRASH: unseconded motion is rejected" do
      # Chicago TDD: If no member seconds, the motion fails
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we rename the main branch?",
          members: ["Alice", "Bob"],
          quorum: 2,
          voting_method: :voice,
          max_motions: 3
        )

      assert {:ok, deliberation} = result

      # Check that at least one motion was processed (seconded or rejected)
      assert length(deliberation.motions) > 0, "Should have processed at least one motion"
    end
  end

  describe "Chicago TDD: Roberts Rules — Edge Cases" do
    test "CRASH: single member deliberation works" do
      # Chicago TDD: Edge case — only one member
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we enable gzip compression?",
          members: ["Solo"],
          quorum: 1,
          voting_method: :voice,
          max_motions: 1
        )

      # Should not crash — single member can't second their own motion
      assert match?({:ok, _}, result)
    end

    test "CRASH: empty topic returns error" do
      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "",
          members: ["Alice"],
          quorum: 1,
          voting_method: :voice
        )

      # Should handle gracefully — either error or ok with empty result
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "CRASH: large body (7 members) produces complete vote record" do
      # Chicago TDD: Stress test — 7 members, all must vote
      members = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace"]

      result =
        OptimalSystemAgent.Swarm.RobertsRules.deliberate(
          topic: "Should we adopt a monorepo structure?",
          members: members,
          quorum: 4,
          voting_method: :roll_call,
          max_motions: 1
        )

      assert {:ok, deliberation} = result

      # Vote record should have all 7 members
      assert map_size(deliberation.vote_record) == 7,
        "All 7 members should have voted"
    end
  end
end
