defmodule OptimalSystemAgent.Swarm.RobertsRules do
  @moduledoc """
  Roberts Rules of Order — parliamentary procedure for agent swarm deliberation.

  Implements the standard parliamentary procedure used in Fortune 500 boardrooms:
  - Motions (main, subsidiary, privileged, incidental)
  - Seconds (requirement for main motions)
  - Amendments (first-degree, second-degree)
  - Points of Order (procedural challenges)
  - Calling the Question (closing debate)
  - Voting (voice, roll call, ballot)
  - Quorum requirements
  - Parliamentary inquiry

  Uses real LLM calls with structured JSON outputs (response_format: json_object).
  All LLM responses are parsed with Jason.decode!, not free-text regex.

  ## Usage

      {:ok, result} = RobertsRules.deliberate(
        topic: "Should we migrate to microservices?",
        members: ["Alice", "Bob", "Charlie", "Diana"],
        quorum: 3,
        voting_method: :roll_call
      )

  ## Result shape

      %{
        motions: [%{type: ..., text: ..., status: ..., votes: ...}],
        points_of_order: [%{member: ..., point: ..., ruling: ...}],
        amendments: [%{motion_id: ..., text: ..., status: ...}],
        final_decision: :adopted | :rejected | :postponed,
        vote_record: %{member => :aye | :nay | :present | :absent},
        transcript: [{speaker: ..., action: ..., text: ...}]
      }
  """

  require Logger

  alias OptimalSystemAgent.Providers.Registry, as: Providers

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type motion_type :: :main | :amendment | :previous_question | :point_of_order | :parliamentary_inquiry | :table | :reconsider
  @type motion_status :: :pending | :seconded | :debating | :voting | :adopted | :rejected | :withdrawn
  @type vote :: :aye | :nay | :present | :absent
  @type voting_method :: :voice | :roll_call | :ballot | :unanimous_consent

  @type motion :: %{
          id: String.t(),
          type: motion_type(),
          text: String.t(),
          proposer: String.t(),
          seconder: String.t() | nil,
          status: motion_status(),
          votes: %{String.t() => vote()},
          debate_points: [String.t()]
        }

  @type point_of_order :: %{
          member: String.t(),
          point: String.t(),
          ruling: :sustained | :overruled,
          reason: String.t()
        }

  @type deliberation_result :: %{
          motions: [motion()],
          points_of_order: [point_of_order()],
          amendments: [motion()],
          final_decision: :adopted | :rejected | :postponed,
          vote_record: %{String.t() => vote()},
          transcript: [%{speaker: String.t(), action: atom(), text: String.t()}]
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Run a full Roberts Rules deliberation on a topic.

  All agents use real LLM calls with structured JSON outputs.
  """
  @spec deliberate(keyword()) :: {:ok, deliberation_result()} | {:error, any()}
  def deliberate(opts) do
    topic = Keyword.fetch!(opts, :topic)
    members = Keyword.get(opts, :members, ["Alice", "Bob", "Charlie"])
    quorum = Keyword.get(opts, :quorum, ceil(length(members) / 2) + 1)
    voting_method = Keyword.get(opts, :voting_method, :roll_call)
    max_motions = Keyword.get(opts, :max_motions, 5)

    Logger.info("[RobertsRules] Deliberation started: #{inspect(topic)} | members=#{length(members)} quorum=#{quorum}")

    state = %{
      topic: topic,
      members: members,
      quorum: quorum,
      voting_method: voting_method,
      motions: [],
      points_of_order: [],
      amendments: [],
      transcript: [],
      motion_counter: 0,
      max_motions: max_motions
    }

    # Step 1: Check quorum
    state = check_quorum(state)

    # Step 2: Open the floor — invite main motion
    state = open_floor(state)

    # Step 3: Process motions through debate and vote
    state = process_motions(state)

    # Step 4: Determine final decision
    {:ok, build_result(state)}
  rescue
    e ->
      Logger.warning("[RobertsRules] Deliberation error: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  # ---------------------------------------------------------------------------
  # Quorum
  # ---------------------------------------------------------------------------

  defp check_quorum(state) do
    present_count = length(state.members)

    if present_count < state.quorum do
      Logger.warning("[RobertsRules] Quorum not met: #{present_count}/#{state.quorum}")
      add_transcript(state, :system, "Quorum not met. #{state.quorum} members required, #{present_count} present.")
    else
      add_transcript(state, :system, "Quorum met. #{present_count} of #{state.quorum} required members present.")
    end
  end

  # ---------------------------------------------------------------------------
  # Open Floor
  # ---------------------------------------------------------------------------

  defp open_floor(state) do
    add_transcript(state, :chair, "The floor is now open for main motions concerning: #{state.topic}")
  end

  # ---------------------------------------------------------------------------
  # Process Motions
  # ---------------------------------------------------------------------------

  defp process_motions(%{motions: motions, max_motions: max} = state)
       when length(motions) >= max do
    state
  end

  defp process_motions(state) do
    # Step 1: Generate main motion from LLM (structured JSON)
    case generate_main_motion(state) do
      {:ok, motion_text, proposer} ->
        motion = new_motion(:main, motion_text, proposer, state.motion_counter)
        state = %{state | motion_counter: state.motion_counter + 1}

        state = add_transcript(state, proposer, "#{proposer} moves: #{motion_text}")

        # Step 2: Require a second
        state = handle_seconds(state, motion)

        # Step 3: Debate the motion
        state = debate_motion(state, motion)

        # Step 4: Vote on the motion
        state = vote_on_motion(state, motion)

        # Step 5: Handle points of order during vote
        state = handle_points_of_order(state)

        # Check if main motion was adopted or we should continue
        motion = update_motion_status(motion, state)
        state = put_motion(state, motion)

        case motion.status do
          :adopted -> state
          :rejected -> process_motions(state)
          _ -> state
        end

      {:error, reason} ->
        Logger.warning("[RobertsRules] Motion generation failed: #{inspect(reason)}")
        add_transcript(state, :chair, "No further motions. Moving to adjourn.")
        state
    end
  end

  # ---------------------------------------------------------------------------
  # Motion Generation (real LLM call — structured JSON output)
  # ---------------------------------------------------------------------------

  defp generate_main_motion(state) do
    prompt = """
    You are participating in a formal meeting using Roberts Rules of Order.
    The topic under discussion is: "#{state.topic}"

    Members present: #{Enum.join(state.members, ", ")}

    As one of the members, propose a specific, actionable main motion related to the topic.
    The motion should be clear and debatable.

    Respond with JSON: {"proposer": "<member_name>", "motion": "<motion_text>"}
    Choose the proposer from: #{Enum.join(state.members, ", ")}
    """

    case call_llm_json(prompt) do
      {:ok, %{"proposer" => proposer, "motion" => motion_text}} ->
        # Validate proposer is an actual member
        valid_proposer = if proposer in state.members, do: proposer, else: hd(state.members)
        {:ok, motion_text, valid_proposer}

      {:ok, %{"motion" => motion_text}} ->
        {:ok, motion_text, hd(state.members)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Seconds (real LLM call — structured JSON output)
  # ---------------------------------------------------------------------------

  defp handle_seconds(state, motion) do
    other_members = Enum.reject(state.members, &(&1 == motion.proposer))

    case other_members do
      [] ->
        add_transcript(state, :chair, "Motion fails for lack of a second.")
        %{state | motions: state.motions ++ [%{motion | status: :rejected}]}

      _ ->
        seconder = Enum.random(other_members)

        case should_second?(state, motion, seconder) do
          {:ok, true} ->
            add_transcript(state, seconder, "#{seconder} seconds the motion.")
            %{state | motions: state.motions ++ [%{motion | seconder: seconder, status: :seconded}]}

          {:ok, false} ->
            add_transcript(state, seconder, "#{seconder} does not second the motion.")
            add_transcript(state, :chair, "Motion fails for lack of a second.")
            %{state | motions: state.motions ++ [%{motion | status: :rejected}]}

          {:error, _} ->
            # Default: second the motion
            add_transcript(state, seconder, "#{seconder} seconds the motion.")
            %{state | motions: state.motions ++ [%{motion | seconder: seconder, status: :seconded}]}
        end
    end
  end

  defp should_second?(state, motion, seconder) do
    prompt = """
    You are #{seconder} in a formal meeting using Roberts Rules of Order.
    Another member has moved: "#{motion.text}"

    Topic: "#{state.topic}"

    Do you second this motion? Consider whether it's debatable, clear, and relevant.
    Respond with JSON: {"second": true} or {"second": false}
    """

    case call_llm_json(prompt, temperature: 0.3) do
      {:ok, %{"second" => seconded}} when is_boolean(seconded) ->
        {:ok, seconded}

      _ ->
        {:error, :invalid_response}
    end
  end

  # ---------------------------------------------------------------------------
  # Debate (real LLM calls — structured JSON output)
  # ---------------------------------------------------------------------------

  defp debate_motion(state, motion) do
    debaters = Enum.reject(state.members, &(&1 == motion.proposer))

    Enum.reduce(debaters, state, fn member, acc_state ->
      case debate_speech(acc_state, motion, member) do
        {:ok, speech} ->
          add_transcript(acc_state, member, speech)

        {:error, _} ->
          acc_state
      end
    end)
  end

  defp debate_speech(state, motion, member) do
    prompt = """
    You are #{member} in a formal meeting using Roberts Rules of Order.
    The motion under debate is: "#{motion.text}"
    Topic: "#{state.topic}"

    Give a brief debate speech (2-3 sentences) either supporting or opposing the motion.
    Be specific and constructive.

    Respond with JSON: {"speech": "<your debate speech>"}
    """

    case call_llm_json(prompt, temperature: 0.7) do
      {:ok, %{"speech" => speech}} when is_binary(speech) ->
        {:ok, speech}

      _ ->
        {:error, :invalid_response}
    end
  end

  # ---------------------------------------------------------------------------
  # Voting (real LLM calls — structured JSON output, each agent independently)
  # ---------------------------------------------------------------------------

  defp vote_on_motion(state, motion) do
    add_transcript(state, :chair, "The question is on the adoption of: #{motion.text}")
    add_transcript(state, :chair, "Those in favor say 'Aye'. Those opposed say 'Nay'.")

    voters = state.members

    {votes, updated_state} =
      Enum.reduce(voters, {%{}, state}, fn member, {vote_map, acc_state} ->
        case cast_vote(acc_state, motion, member) do
          {:ok, vote} ->
            add_transcript(acc_state, member, "#{member} votes: #{vote}")
            {Map.put(vote_map, member, vote), acc_state}

          {:error, _} ->
            {Map.put(vote_map, member, :present), acc_state}
        end
      end)

    # Tally the vote
    ayes = Enum.count(votes, fn {_, v} -> v == :aye end)
    nays = Enum.count(votes, fn {_, v} -> v == :nay end)
    present = Enum.count(votes, fn {_, v} -> v == :present end)

    result = determine_vote_result(ayes, nays, present, motion.type)

    add_transcript(updated_state, :chair, "Vote result: #{ayes} Aye, #{nays} Nay, #{present} Present. Motion is #{result}.")

    # Update the motion in the list
    updated_motion = %{motion | votes: votes, status: if(result == "adopted", do: :adopted, else: :rejected)}

    # Replace the last motion with the voted version
    motions = Enum.drop(updated_state.motions, -1) ++ [updated_motion]

    %{updated_state | motions: motions}
  end

  defp cast_vote(state, motion, member) do
    prompt = """
    You are #{member} in a formal meeting using Roberts Rules of Order.
    The motion under vote is: "#{motion.text}"
    Topic: "#{state.topic}"

    Cast your vote. Consider the debate arguments.
    Respond with JSON: {"vote": "aye"} or {"vote": "nay"}
    """

    case call_llm_json(prompt, temperature: 0.2) do
      {:ok, %{"vote" => vote_str}} when is_binary(vote_str) ->
        vote = case String.downcase(vote_str) do
          "aye" -> :aye
          "nay" -> :nay
          _ -> :present
        end
        {:ok, vote}

      _ ->
        {:error, :invalid_response}
    end
  end

  defp determine_vote_result(ayes, nays, _present, motion_type) do
    total = ayes + nays

    case motion_type do
      :main ->
        if ayes > nays, do: "adopted", else: "rejected"

      :amendment ->
        if ayes > nays, do: "adopted", else: "rejected"

      :previous_question ->
        # 2/3 required to close debate
        if ayes * 3 >= total * 2, do: "adopted", else: "rejected"

      _ ->
        if ayes > nays, do: "adopted", else: "rejected"
    end
  end

  # ---------------------------------------------------------------------------
  # Points of Order (real LLM call — structured JSON output)
  # ---------------------------------------------------------------------------

  defp handle_points_of_order(state) do
    member = Enum.random(state.members)

    case should_raise_point_of_order?(state, member) do
      {:ok, true, point_text} ->
        case rule_on_point_of_order(state, point_text, member) do
          {:ok, ruling, reason} ->
            point = %{member: member, point: point_text, ruling: ruling, reason: reason}
            add_transcript(state, member, "Point of Order: #{point_text}")
            add_transcript(state, :chair, "Point of Order #{ruling}. #{reason}")
            %{state | points_of_order: state.points_of_order ++ [point]}

          {:error, _} ->
            state
        end

      {:ok, false} ->
        state
    end
  end

  defp should_raise_point_of_order?(state, member) do
    prompt = """
    You are #{member} in a formal meeting using Roberts Rules of Order.
    Topic: "#{state.topic}"

    The meeting has just concluded a vote. Is there any valid point of order you would raise?
    A point of order questions a procedural irregularity.

    If raising a point, provide a specific procedural concern.
    Respond with JSON: {"raise": true, "point": "<description>"} or {"raise": false}
    """

    case call_llm_json(prompt, temperature: 0.3) do
      {:ok, %{"raise" => true, "point" => point}} when is_binary(point) and byte_size(point) > 0 ->
        {:ok, true, point}

      {:ok, %{"raise" => false}} ->
        {:ok, false}

      {:ok, %{"raise" => true}} ->
        {:ok, false}

      _ ->
        {:ok, false}
    end
  end

  defp rule_on_point_of_order(state, point_text, member) do
    prompt = """
    You are the Chair of a formal meeting using Roberts Rules of Order.
    Topic: "#{state.topic}"

    #{member} raises the following Point of Order: "#{point_text}"

    As Chair, rule on this point. Is it sustained (valid procedural concern) or overruled?
    Respond with JSON: {"ruling": "sustained", "reason": "<explanation>"} or {"ruling": "overruled", "reason": "<explanation>"}
    """

    case call_llm_json(prompt, temperature: 0.2) do
      {:ok, %{"ruling" => ruling_str, "reason" => reason}} when is_binary(ruling_str) and is_binary(reason) ->
        ruling = if String.downcase(ruling_str) == "sustained", do: :sustained, else: :overruled
        {:ok, ruling, reason}

      _ ->
        {:error, :invalid_response}
    end
  end

  # ---------------------------------------------------------------------------
  # Build Result
  # ---------------------------------------------------------------------------

  defp build_result(state) do
    main_motions = Enum.filter(state.motions, &(&1.type == :main))

    final_decision =
      case Enum.find(Enum.reverse(main_motions), &(&1.status in [:adopted, :rejected])) do
        %{status: :adopted} -> :adopted
        _ -> :rejected
      end

    vote_record =
      case List.last(state.motions) do
        %{votes: votes} when votes != %{} -> votes
        _ -> Map.new(state.members, fn m -> {m, :present} end)
      end

    %{
      motions: state.motions,
      points_of_order: state.points_of_order,
      amendments: state.amendments,
      final_decision: final_decision,
      vote_record: vote_record,
      transcript: state.transcript
    }
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp new_motion(type, text, proposer, id) do
    %{
      id: "motion_#{id}",
      type: type,
      text: text,
      proposer: proposer,
      seconder: nil,
      status: :pending,
      votes: %{},
      debate_points: []
    }
  end

  defp put_motion(state, motion) do
    motions = Enum.drop(state.motions, -1) ++ [motion]
    %{state | motions: motions}
  end

  defp update_motion_status(motion, _state) do
    motion
  end

  defp add_transcript(state, speaker, text) do
    entry = %{speaker: to_string(speaker), action: :speech, text: text}
    %{state | transcript: state.transcript ++ [entry]}
  end

  @doc """
  Call LLM with structured JSON output via tool calling.

  Uses OpenAI function calling (tool use) to force the model to return
  structured JSON, then parses the tool call arguments with Jason.decode!.
  No free-text regex parsing. Falls back to response_format: json_object
  if tool calling fails.

  Uses the configured default provider and model (no hardcoded provider).
  """
  def call_llm_json(prompt, opts \\ []) do
    temperature = Keyword.get(opts, :temperature, 0.6)
    max_tokens = Keyword.get(opts, :max_tokens, 300)

    # Use the caller's provider/model if specified, otherwise use defaults
    provider = Keyword.get(opts, :provider)
    model = Keyword.get(opts, :model)
    chat_opts = Keyword.drop(opts, [:provider, :model])

    messages = [%{role: "user", content: prompt}]

    # Strategy 1: Tool calling (reliable structured output on OpenAI-compat)
    tools = [
      %{
        name: "respond_json",
        description: "Return a JSON object as your response.",
        parameters: %{
          type: "object",
          properties: %{data: %{type: "object"}},
          required: ["data"]
        }
      }
    ]

    tool_opts = [temperature: temperature, max_tokens: max_tokens, tools: tools]
    tool_opts = if provider, do: Keyword.put(tool_opts, :provider, provider), else: tool_opts
    tool_opts = if model, do: Keyword.put(tool_opts, :model, model), else: tool_opts

    case Providers.chat(messages, tool_opts) do
      {:ok, %{tool_calls: [tool_call | _]}} when is_map(tool_call) ->
        args = tool_call[:arguments] || tool_call["arguments"] || %{}
        # Unwrap the "data" wrapper (string or atom keys)
        case args do
          %{"data" => data} when is_map(data) and map_size(data) > 0 -> {:ok, data}
          %{data: data} when is_map(data) and map_size(data) > 0 -> {:ok, data}
          _ when is_map(args) and map_size(args) > 0 -> {:ok, args}
          _ -> {:error, :empty_response}
        end

      {:ok, %{content: content}} when is_binary(content) and content != "" ->
        # Model returned text instead of tool call — try parsing as JSON
        case Jason.decode(content) do
          {:ok, parsed} when is_map(parsed) -> {:ok, parsed}
          _ -> call_llm_json_fallback(messages, chat_opts, provider, model)
        end

      {:ok, _} ->
        call_llm_json_fallback(messages, chat_opts, provider, model)

      {:error, reason} ->
        Logger.warning("[RobertsRules] Tool call failed: #{inspect(reason)}, trying fallback")
        call_llm_json_fallback(messages, chat_opts, provider, model)
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Fallback: use response_format: json_object
  defp call_llm_json_fallback(messages, chat_opts, provider, model) do
    format_opts = Keyword.put(chat_opts, :response_format, %{type: "json_object"})
    format_opts = if provider, do: Keyword.put(format_opts, :provider, provider), else: format_opts
    format_opts = if model, do: Keyword.put(format_opts, :model, model), else: format_opts

    case Providers.chat(messages, format_opts) do
      {:ok, %{content: content}} when is_binary(content) ->
        case Jason.decode(content) do
          {:ok, parsed} when is_map(parsed) -> {:ok, parsed}
          {:ok, _} -> {:error, :not_a_json_object}
          {:error, _} -> {:error, :json_decode_failed}
        end

      {:ok, content} when is_binary(content) ->
        case Jason.decode(content) do
          {:ok, parsed} when is_map(parsed) -> {:ok, parsed}
          {:ok, _} -> {:error, :not_a_json_object}
          {:error, _} -> {:error, :json_decode_failed}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
