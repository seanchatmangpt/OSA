defmodule OptimalSystemAgent.Tools.Builtins.QueryOcel do
  @moduledoc """
  Tool: query_ocel — Query the current session's OCEL process context using natural language.

  Grounds answers in real event data captured by OcelCollector.
  Uses pm4py-rust /api/ocpm/llm/query for RAG-grounded response.

  Connection 4 of "No AI Without PI" (van der Aalst et al.):
  GenAI/RAG interface grounded in real OCEL context.
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  alias OptimalSystemAgent.ProcessMining.OcelCollector

  @impl true
  def name, do: "query_ocel"

  @impl true
  def safety, do: :sandboxed

  @impl true
  def description do
    "Query the session's OCEL process log with a natural language question. Returns an answer grounded in real event data."
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "question" => %{
          "type" => "string",
          "description" => "Natural language question about the process"
        },
        "session_id" => %{
          "type" => "string",
          "description" => "Session ID to filter OCEL context (optional)"
        }
      },
      "required" => ["question"]
    }
  end

  @impl true
  def execute(%{"question" => question} = params) do
    session_id = Map.get(params, "session_id")
    ocel = safe_export_ocel(session_id)
    pm4py_url = Application.get_env(:optimal_system_agent, :pm4py_url, "http://localhost:8090")

    body = Jason.encode!(%{"question" => question, "ocel" => ocel})

    case Req.post("#{pm4py_url}/api/ocpm/llm/query",
           body: body,
           headers: [{"content-type", "application/json"}],
           receive_timeout: 60_000
         ) do
      {:ok, %{status: 200, body: resp_body}} ->
        result = if is_map(resp_body), do: resp_body, else: Jason.decode!(resp_body)

        {:ok,
         %{
           "answer" => Map.get(result, "answer", "No answer returned"),
           "grounded" => Map.get(result, "grounded", false),
           "context_used" => true
         }}

      {:ok, %{status: status}} ->
        {:ok,
         %{
           "answer" => "OCEL query service returned status #{status}",
           "grounded" => false,
           "context_used" => false
         }}

      {:error, reason} ->
        Logger.warning("query_ocel: pm4py-rust unavailable: #{inspect(reason)}")
        event_count = ocel |> Map.get("events", []) |> length()

        {:ok,
         %{
           "answer" =>
             "Process context has #{event_count} events recorded (LLM service unavailable).",
           "grounded" => false,
           "context_used" => false
         }}
    end
  end

  def execute(_), do: {:error, "Missing required parameter: question"}

  # ── Private ──────────────────────────────────────────────────────────────────

  # Safely call OcelCollector — returns empty OCEL map if ETS tables are missing
  # (e.g. during tests where OcelCollector is not started).
  defp safe_export_ocel(session_id) do
    if :ets.whereis(:ocel_events) != :undefined do
      OcelCollector.export_ocel_json(session_id)
    else
      %{"objectTypes" => [], "objects" => [], "events" => []}
    end
  rescue
    _ -> %{"objectTypes" => [], "objects" => [], "events" => []}
  catch
    :exit, _ -> %{"objectTypes" => [], "objects" => [], "events" => []}
  end
end
