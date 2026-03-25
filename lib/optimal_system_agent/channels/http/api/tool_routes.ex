defmodule OptimalSystemAgent.Channels.HTTP.API.ToolRoutes do
  @moduledoc """
  Tools, skills, and commands routes.

  This module is forwarded to from three prefixes in the parent router:
    forward "/tools"    → GET /, POST /:name/execute
    forward "/skills"   → GET /, POST /create
    forward "/commands" → GET /, POST /execute

  Effective endpoints:
    GET  /tools
    POST /tools/:name/execute
    GET  /skills
    POST /skills/create
    GET  /commands           — list all commands
    GET  /commands?q=term    — fuzzy-search commands + skills, ranked by relevance
    POST /commands/execute
  """
  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared

  alias OptimalSystemAgent.Tools.Registry, as: Tools

  plug :match
  plug :dispatch

  # ── GET / ─────────────────────────────────────────────────────────
  # Handles GET /tools, GET /skills, GET /commands after prefix strip.
  # Disambiguate by path_info on the conn.

  get "/" do
    case conn.path_info do
      _ ->
        # Determine which resource by looking at the script_name
        # (the stripped prefix is in conn.script_name after forward)
        case List.last(conn.script_name) do
          "skills" -> handle_list_skills(conn)
          "commands" -> handle_list_commands(conn)
          _ -> handle_list_tools(conn)
        end
    end
  end

  # ── POST /create (skills) ─────────────────────────────────────────

  post "/create" do
    with %{"name" => name, "description" => desc, "instructions" => instructions}
         when is_binary(name) and is_binary(desc) and is_binary(instructions) <- conn.body_params do
      _tools = conn.body_params["tools"] || []

      json_error(conn, 501, "not_implemented", "Skill creation not available in this build")
    else
      _ ->
        json_error(
          conn,
          400,
          "invalid_request",
          "Missing required fields: name, description, instructions"
        )
    end
  end

  # ── POST /execute (commands) ───────────────────────────────────────

  post "/execute" do
    with %{"command" => command} when is_binary(command) <- conn.body_params do
      arg = conn.body_params["arg"] || ""
      session_id = conn.body_params["session_id"] || "http-#{:erlang.unique_integer([:positive])}"

      _input = if arg == "", do: command, else: "#{command} #{arg}"
      _ = session_id

      json_error(conn, 501, "not_implemented", "Commands not available in this build")
    else
      _ -> json_error(conn, 400, "invalid_request", "Missing required field: command")
    end
  end

  # ── POST /:name/execute (tools) ────────────────────────────────────

  post "/:name/execute" do
    tool_name = conn.params["name"]
    arguments = conn.body_params["arguments"] || %{}

    case Tools.execute(tool_name, arguments) do
      {:ok, result} ->
        body =
          Jason.encode!(%{
            tool: tool_name,
            status: "completed",
            result: result
          })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, body)

      {:error, reason} ->
        json_error(conn, 422, "tool_error", to_string(reason))
    end
  end

  # ── POST /match — dry-run skill matching for a message ──────────────
  # Returns which skills would be triggered for a given message, without
  # actually running any agent. Useful for debugging and UI previews.

  post "/match" do
    message = conn.body_params["message"]

    cond do
      not (is_binary(message) && message != "") ->
        json_error(conn, 400, "missing_message", "'message' (non-empty string) is required")

      true ->
        matched = Tools.match_skill_triggers(message)

        skills =
          Enum.map(matched, fn {name, skill} ->
            %{
              name: name,
              description: Map.get(skill, :description, ""),
              triggers: Map.get(skill, :triggers, []),
              has_instructions: Map.get(skill, :instructions, "") != ""
            }
          end)

        body =
          Jason.encode!(%{
            message_preview: String.slice(message, 0, 120),
            matched_count: length(skills),
            skills: skills
          })

        conn |> put_resp_content_type("application/json") |> send_resp(200, body)
    end
  end

  match _ do
    json_error(conn, 404, "not_found", "Tool endpoint not found")
  end

  # ── Private handlers ────────────────────────────────────────────────

  defp handle_list_tools(conn) do
    tools = Tools.list_tools()

    body =
      Jason.encode!(%{
        tools: tools,
        count: length(tools)
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  defp handle_list_skills(conn) do
    skills = Tools.load_skill_definitions()

    summaries =
      Enum.map(skills, &Map.take(&1, [:name, :description, :category, :triggers, :priority]))

    body = Jason.encode!(%{skills: summaries, count: length(summaries)})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  @builtin_commands [
    %{name: "help", description: "Show available commands and usage", category: "system"},
    %{name: "status", description: "Show current agent status and active sessions", category: "system"},
    %{name: "reload", description: "Reload skills and configuration", category: "system"},
    %{name: "mem-search", description: "Search persistent memory", category: "memory"},
    %{name: "mem-save", description: "Save a note to persistent memory", category: "memory"},
    %{name: "mem-recall", description: "Recall recent memory entries", category: "memory"},
    %{name: "session-list", description: "List active sessions", category: "sessions"},
    %{name: "session-new", description: "Start a new session", category: "sessions"},
    %{name: "session-cancel", description: "Cancel the current session loop", category: "sessions"},
    %{name: "tools-list", description: "List all available tools", category: "tools"},
    %{name: "skills-list", description: "List all loaded skills", category: "skills"},
    %{name: "debug", description: "Enable debug logging for the current session", category: "dev"},
    %{name: "version", description: "Show OSA version information", category: "system"}
  ]

  defp handle_list_commands(conn) do
    conn = Plug.Conn.fetch_query_params(conn)
    q = conn.query_params["q"]

    if is_binary(q) and q != "" do
      handle_command_palette_search(conn, q)
    else
      body = Jason.encode!(%{commands: @builtin_commands, count: length(@builtin_commands)})

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)
    end
  end

  # Fuzzy command palette: merges commands and skills, ranked by relevance score.
  #
  # Scoring uses a simple substring match strategy:
  #   - name exact match:      1.0
  #   - name starts with q:   0.8
  #   - name contains q:      0.6
  #   - description contains q: 0.3
  #   - trigger exact match:   0.9
  #   - trigger contains q:    0.5
  #
  # Commands and skills with score > 0.0 are included. Results are sorted
  # descending by score. Type field distinguishes "command" from "skill".
  defp handle_command_palette_search(conn, q) do
    q_lower = String.downcase(q)

    command_results =
      @builtin_commands
      |> Enum.map(fn cmd ->
        score = fuzzy_score(cmd.name, cmd.description, q_lower)
        Map.put(cmd, :score, score) |> Map.put(:type, "command")
      end)
      |> Enum.filter(fn cmd -> cmd.score > 0.0 end)

    skill_results =
      :persistent_term.get({Tools, :skills}, %{})
      |> Enum.map(fn {name, skill} ->
        desc = Map.get(skill, :description, "")
        triggers = Map.get(skill, :triggers, [])
        category = Map.get(skill, :category, "skill")

        base_score = fuzzy_score(name, desc, q_lower)

        trigger_score =
          Enum.reduce(triggers, 0.0, fn t, acc ->
            t_lower = String.downcase(to_string(t))
            cond do
              t_lower == q_lower -> max(acc, 0.9)
              String.contains?(t_lower, q_lower) -> max(acc, 0.5)
              String.contains?(q_lower, t_lower) -> max(acc, 0.4)
              true -> acc
            end
          end)

        score = max(base_score, trigger_score)
        %{type: "skill", name: name, description: desc, category: category, score: score}
      end)
      |> Enum.filter(fn s -> s.score > 0.0 end)

    all =
      (command_results ++ skill_results)
      |> Enum.sort_by(fn item -> item.score end, :desc)

    body = Jason.encode!(%{results: all, count: length(all), query: q})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  # Score a name + description pair against a lowercase query token.
  defp fuzzy_score(name, description, q_lower) do
    name_lower = String.downcase(name)
    desc_lower = String.downcase(description)

    cond do
      name_lower == q_lower -> 1.0
      String.starts_with?(name_lower, q_lower) -> 0.8
      String.contains?(name_lower, q_lower) -> 0.6
      String.contains?(desc_lower, q_lower) -> 0.3
      true -> 0.0
    end
  end
end
