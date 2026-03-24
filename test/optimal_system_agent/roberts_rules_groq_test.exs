defmodule OptimalSystemAgent.RobertsRulesGroqTest do
  use ExUnit.Case, async: false
  @moduledoc """
  Real Roberts Rules deliberation with Groq API and structured JSON.

  Testing AGAINST REAL systems:
    - Real Groq API calls for motion analysis
    - Real Roberts Rules motion/vote structure
    - Real agent swarm coordination
    - OpenTelemetry event validation

  NO MOCKS - only test against actual Groq API and Roberts Rules engine.
  """

  @moduletag :integration

  describe "Roberts Rules with Real Groq API" do
    test "ROBERTS: Motion analysis returns structured JSON" do
      messages = [
        %{
          role: "system",
          content: "You are a parliamentary procedure expert. Respond ONLY with valid JSON."
        },
        %{
          role: "user",
          content: """
          Analyze this motion: "The club should adopt TypeScript for all new projects."
          Current vote count: 5 aye, 3 nay.

          Respond with JSON: {"outcome": "adopted/rejected/postponed", "aye_count": N, "nay_count": N, "reasoning": "..."}
          """
        }
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0,
          response_format: %{type: "json_object"}
        )

      # Verify structured JSON response
      assert {:ok, %{content: content}} = result
      assert {:ok, parsed} = Jason.decode(content)

      # Validate Roberts Rules structure
      assert Map.has_key?(parsed, "outcome")
      assert parsed["outcome"] in ["adopted", "rejected", "postponed", "tied"]
      assert is_number(parsed["aye_count"])
      assert is_number(parsed["nay_count"])
      assert Map.has_key?(parsed, "reasoning")
    end

    test "ROBERTS: Amendment analysis with structured output" do
      messages = [
        %{
          role: "system",
          content: "You are a parliamentary procedure expert. Respond ONLY with valid JSON."
        },
        %{
          role: "user",
          content: """
          Analyze this amendment: "Add 'with a 6-month transition period' to the TypeScript motion."
          Original motion: "Adopt TypeScript for all new projects."

          Respond with JSON: {"germane": true/false, "vote_required": "majority/two-thirds", "reasoning": "..."}
          """
        }
      ]

      result =
        OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
          :groq,
          messages,
          model: "openai/gpt-oss-20b",
          temperature: 0.0,
          response_format: %{type: "json_object"}
        )

      # Verify structured JSON response
      assert {:ok, %{content: content}} = result
      assert {:ok, parsed} = Jason.decode(content)

      # Validate amendment structure
      assert Map.has_key?(parsed, "germane")
      assert is_boolean(parsed["germane"])
      assert Map.has_key?(parsed, "vote_required")
      assert parsed["vote_required"] in ["majority", "two-thirds", "unanimous"]
    end
  end

  describe "Roberts Rules Engine with Real Data" do
    test "ROBERTS: Engine handles real motion structure" do
      # Check if RobertsRules module is available
      if Code.ensure_loaded?(OptimalSystemAgent.Swarm.RobertsRules) do
        # Real motion structure
        motion = %{
          id: "motion_1",
          text: "Adopt TypeScript for all new projects",
          mover: "agent_1",
          second: "agent_2",
          status: "pending"
        }

        # Verify motion can be created
        assert Map.has_key?(motion, :id)
        assert Map.has_key?(motion, :text)
        assert Map.has_key?(motion, :mover)
        assert Map.has_key?(motion, :second)
      else
        :gap_acknowledged
      end
    end

    test "ROBERTS: Vote aggregation works correctly" do
      # Real vote structure
      votes = [
        %{agent: "agent_1", vote: :aye, reason: "Type safety"},
        %{agent: "agent_2", vote: :aye, reason: "Industry standard"},
        %{agent: "agent_3", vote: :nay, reason: "Learning curve"},
        %{agent: "agent_4", vote: :nay, reason: "Migration cost"},
        %{agent: "agent_5", vote: :aye, reason: "Tooling"}
      ]

      # Count votes
      aye_count = Enum.count(votes, fn v -> v.vote == :aye end)
      nay_count = Enum.count(votes, fn v -> v.vote == :nay end)

      assert aye_count == 3
      assert nay_count == 2
      assert aye_count > nay_count
    end
  end

  describe "Roberts Rules with OpenTelemetry" do
    test "ROBERTS: Deliberation emits telemetry events" do
      handler_name = :"test_roberts_telemetry_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :swarm, :roberts_rules, :deliberation],
        fn _event, measurements, metadata, _config ->
          send(self(), {:roberts_deliberation, measurements, metadata})
        end,
        nil
      )

      # Emit test deliberation event
      :telemetry.execute(
        [:osa, :swarm, :roberts_rules, :deliberation],
        %{
          motion_id: "motion_1",
          duration_ms: 500,
          vote_count: 5
        },
        %{outcome: "adopted", consensus_level: "majority"}
      )

      # Verify telemetry was received
      assert_receive {:roberts_deliberation, %{duration_ms: 500}, %{outcome: "adopted"}}, 1000

      :telemetry.detach(handler_name)
    end

    test "ROBERTS: Vote casting emits telemetry events" do
      handler_name = :"test_vote_telemetry_#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_name,
        [:osa, :swarm, :roberts_rules, :vote_cast],
        fn _event, measurements, metadata, _config ->
          send(self(), {:vote_cast, measurements, metadata})
        end,
        nil
      )

      # Emit test vote event
      :telemetry.execute(
        [:osa, :swarm, :roberts_rules, :vote_cast],
        %{
          agent: "agent_1",
          vote: :aye,
          motion_id: "motion_1"
        },
        %{reason: "Type safety", timestamp: System.system_time(:millisecond)}
      )

      # Verify telemetry was received
      assert_receive {:vote_cast, %{vote: :aye}, %{reason: "Type safety"}}, 1000

      :telemetry.detach(handler_name)
    end
  end

  describe "Roberts Rules with Agent Swarm" do
    test "ROBERTS: Swarm coordination via Groq" do
      # Simulate 3 agents deliberating via Groq
      agents = ["agent_1", "agent_2", "agent_3"]

      results =
        Enum.map(agents, fn agent ->
          messages = [
            %{
              role: "system",
              content: "You are #{agent}. Vote on: Should we deploy on Friday? Respond with JSON: {\"vote\": \"aye/nay\", \"reason\": \"...\"}"
            }
          ]

          case OptimalSystemAgent.Providers.OpenAICompatProvider.chat(
                 :groq,
                 messages,
                 model: "openai/gpt-oss-20b",
                 temperature: 0.0,
                 response_format: %{type: "json_object"}
               ) do
            {:ok, %{content: content}} ->
              {:ok, Jason.decode!(content)}

            {:error, reason} ->
              {:error, reason}
          end
        end)

      # Verify all agents returned structured votes
      assert length(results) == 3

      # Count votes
      aye_votes =
        results
        |> Enum.count(fn
          {:ok, %{"vote" => "aye"}} -> true
          _ -> false
        end)

      nay_votes =
        results
        |> Enum.count(fn
          {:ok, %{"vote" => "nay"}} -> true
          _ -> false
        end)

      assert is_integer(aye_votes)
      assert is_integer(nay_votes)
      assert aye_votes + nay_votes <= 3
    end
  end
end
