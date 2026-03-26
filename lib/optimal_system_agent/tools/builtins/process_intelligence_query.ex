defmodule OptimalSystemAgent.Tools.Builtins.ProcessIntelligenceQuery do
  @moduledoc """
  Process Intelligence Query Tool

  Queries pm4py-rust process intelligence endpoints for process context.
  Converts process models (Petri nets, DFGs, event logs) into plain-English narratives.

  Used for grounding LLM reasoning in process state.
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  @default_timeout 30_000
  @default_pm4py_url "http://localhost:8090"

  @impl true
  def safety, do: :sandboxed

  @impl true
  def name, do: "process_intelligence_query"

  @impl true
  def description do
    """
    Query process intelligence endpoints for natural language process insights.

    Supports:
    - abstracting Petri nets to English descriptions
    - abstracting DFGs to English descriptions
    - abstracting event logs to English descriptions
    - routing natural language queries to appropriate abstraction

    Examples:
    - "What is the bottleneck in the current process?"
    - "Describe the critical path"
    - "What are the most common activity variants?"
    """
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "query" => %{
          "type" => "string",
          "description" => "Natural language query about the process (e.g., 'What is the bottleneck?')"
        },
        "petri_net" => %{
          "type" => "object",
          "description" => "Optional Petri net in JSON format to use as context"
        },
        "event_log" => %{
          "type" => "object",
          "description" => "Optional event log in JSON format to use as context"
        },
        "pm4py_url" => %{
          "type" => "string",
          "description" => "pm4py-rust HTTP endpoint (default: http://localhost:8090)"
        }
      },
      "required" => ["query"]
    }
  end

  @impl true
  def execute(%{"query" => query} = params) when is_binary(query) do
    pm4py_url = Map.get(params, "pm4py_url", @default_pm4py_url)

    try do
      result = query_process_intelligence(query, params, pm4py_url)
      {:ok, result}
    rescue
      e ->
        Logger.error("Process intelligence query failed: #{inspect(e)}")
        {:error, "Query failed: #{Exception.message(e)}"}
    end
  end

  def execute(_params) do
    {:error, "Missing required parameter: query"}
  end

  # Query pm4py-rust /api/query endpoint
  defp query_process_intelligence(query, params, pm4py_url) do
    url = "#{pm4py_url}/api/query"

    request_body = %{
      "query" => query,
      "petri_net" => Map.get(params, "petri_net"),
      "event_log" => Map.get(params, "event_log")
    }

    case Req.post(url, json: request_body, receive_timeout: @default_timeout) do
      {:ok, response} ->
        case response.body do
          %{"response" => insight, "execution_time_ms" => elapsed_ms} ->
            %{
              "success" => true,
              "query" => query,
              "insight" => insight,
              "execution_time_ms" => elapsed_ms
            }

          other ->
            %{
              "success" => false,
              "error" => "Invalid response format",
              "details" => inspect(other)
            }
        end

      {:error, reason} ->
        %{
          "success" => false,
          "error" => "HTTP request failed",
          "details" => inspect(reason)
        }
    end
  end
end
