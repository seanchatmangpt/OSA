defmodule OptimalSystemAgent.Agent.Loop.GenreRouterTest do
  @moduledoc """
  Chicago TDD unit tests for GenreRouter module.

  Tests signal genre routing for agent loop message handling.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Agent.Loop.GenreRouter

  @moduletag :capture_log

  describe "route_by_genre/3" do
    test ":inform genre returns memory save suggestion" do
      message = "I'm using Neovim for editing"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:inform, message, state)

      assert {:respond, response} = result
      assert String.contains?(response, "memory_save")
    end

    test ":express genre with frustration returns empathetic response" do
      message = "I'm getting frustrated with this bug"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:express, message, state)

      assert {:respond, response} = result
      assert String.contains?(response, "frustrating") or String.contains?(response, "hear")
    end

    test ":express genre with anxiety returns supportive response" do
      message = "I'm worried about breaking things"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:express, message, state)

      assert {:respond, response} = result
      assert String.contains?(response, "stressful") or String.contains?(response, "step")
    end

    test ":express genre with happiness returns positive response" do
      message = "I'm so happy it works now!"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:express, message, state)

      assert {:respond, response} = result
      assert String.contains?(response, "great")
    end

    test ":express genre with neutral emotion returns default supportive response" do
      message = "I feel okay about this"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:express, message, state)

      assert {:respond, response} = result
      assert String.contains?(response, "support")
    end

    test ":decide genre returns clarifying question prompt" do
      message = "Should I use Postgres or MySQL?"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:decide, message, state)

      assert {:respond, response} = result
      assert String.contains?(response, "outcome matters most")
    end

    test ":commit genre returns confirmation prompt with intent summary" do
      message = "I want to create a new user authentication module with JWT tokens"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:commit, message, state)

      assert {:respond, response} = result
      assert String.contains?(response, "confirm")
      assert String.contains?(response, "plan would be to")
    end

    test ":direct genre returns execute_tools for normal execution" do
      message = "Create a new file"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:direct, message, state)

      assert result == :execute_tools
    end

    test "unknown genre returns execute_tools as fallback" do
      message = "Some message"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:unknown_genre, message, state)

      assert result == :execute_tools
    end
  end

  describe "summarize_intent/1" do
    test "summarizes short message without truncation" do
      message = "Create a new file"

      result = GenreRouter.summarize_intent(message)

      assert result == "Create a new file"
    end

    test "truncates long message to first 12 words" do
      message = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen"

      result = GenreRouter.summarize_intent(message)

      # Should be first 12 words with ellipsis attached to last word
      assert String.contains?(result, "twelve…")
      refute String.contains?(result, "thirteen")
    end

    test "adds ellipsis to truncated message" do
      message = "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12 word13"

      result = GenreRouter.summarize_intent(message)

      assert String.ends_with?(result, "…")
    end

    test "does not add ellipsis if message fits within 12 words" do
      message = "one two three four five"

      result = GenreRouter.summarize_intent(message)

      refute String.ends_with?(result, "…")
    end

    test "handles message with extra whitespace" do
      message = "  Create   a   new   file  "

      result = GenreRouter.summarize_intent(message)

      # Should trim and normalize whitespace
      refute String.contains?(result, "  ")
    end

    test "handles empty string" do
      message = ""

      result = GenreRouter.summarize_intent(message)

      assert result == ""
    end
  end

  describe "integration - genre routing" do
    test "all genres return either {:respond, _} or :execute_tools" do
      state = %{session_id: "test"}
      message = "test message"

      genres = [:direct, :inform, :express, :decide, :commit, :unknown]

      for genre <- genres do
        result = GenreRouter.route_by_genre(genre, message, state)

        case result do
          {:respond, _} -> :ok
          :execute_tools -> :ok
          _ -> flunk("Invalid return type for genre #{inspect(genre)}: #{inspect(result)}")
        end
      end
    end
  end

  describe "edge cases" do
    test "handles very long message for :express genre" do
      long_message = String.duplicate("I'm excited ", 1000)
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:express, long_message, state)

      assert {:respond, _response} = result
    end

    test "handles message with special characters" do
      message = "Create file: test.txt! @#$%"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:direct, message, state)

      assert result == :execute_tools
    end

    test "handles unicode characters in message" do
      message = "日本語のメッセージ"
      state = %{session_id: "test"}

      result = GenreRouter.route_by_genre(:inform, message, state)

      assert {:respond, _response} = result
    end
  end
end
