defmodule OptimalSystemAgent.Tools.Builtins.SessionSearch do
  @behaviour OptimalSystemAgent.Tools.Behaviour

  @impl true
  def safety, do: :read_safe

  @impl true
  def name, do: "session_search"

  @impl true
  def description,
    do: "Search past conversation sessions for messages matching a query."

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "query" => %{
          "type" => "string",
          "description" => "Search query"
        },
        "limit" => %{
          "type" => "integer",
          "description" => "Max results (default 5)"
        }
      },
      "required" => ["query"]
    }
  end

  @impl true
  def execute(%{"query" => query} = args) do
    limit = args["limit"] || 5

    case OptimalSystemAgent.Memory.search_sessions(query, limit: limit) do
      {:ok, []} ->
        {:ok, "No past sessions found matching: #{query}"}

      {:ok, results} ->
        formatted =
          results
          |> Enum.take(limit)
          |> Enum.with_index(1)
          |> Enum.map(fn {result, idx} ->
            content_preview = String.slice(Map.get(result, :content, ""), 0, 200)
            session = Map.get(result, :session_id, "unknown")
            ts = Map.get(result, :inserted_at, "")
            "#{idx}. [#{session}] #{ts} — #{content_preview}"
          end)
          |> Enum.join("\n")

        {:ok, "Found #{length(results)} matches\n---\n#{formatted}"}

      {:error, reason} ->
        {:error, "Session search failed: #{inspect(reason)}"}
    end
  end
end
