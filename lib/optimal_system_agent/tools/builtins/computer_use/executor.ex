defmodule OptimalSystemAgent.Tools.Builtins.ComputerUse.Executor do
  @moduledoc """
  PPEV Executor — runs multi-step computer_use tasks using the
  Perceive → Plan → Execute → Verify loop.

  Uses a lightweight LLM call with ONLY the computer_use tool (~3-5s per step)
  instead of the full agent loop with 26 tools (20+ min).
  """

  require Logger

  alias OptimalSystemAgent.Tools.Builtins.ComputerUse
  alias OptimalSystemAgent.Tools.Builtins.ComputerUse.{Planner, Keyframe}

  @max_steps 15
  @cu_tool %{
    type: "function",
    function: %{
      name: "computer_use",
      description: """
      Control desktop. Actions: screenshot, click, double_click, type, key, scroll, move_mouse, drag, get_tree.
      - type/key: set "window" to focus a specific window before typing.
      - click: use x,y coordinates or "target" element ref (e.g. "e3") from get_tree.
      - key: combos like ctrl+z, enter, alt+tab in the "text" field.
      """,
      parameters: %{
        type: "object",
        properties: %{
          action: %{type: "string", enum: ["screenshot", "click", "double_click", "type", "key", "scroll", "move_mouse", "drag", "get_tree"]},
          x: %{type: "integer", description: "X coordinate"},
          y: %{type: "integer", description: "Y coordinate"},
          text: %{type: "string", description: "Text to type or key combo"},
          direction: %{type: "string", enum: ["up", "down", "left", "right"]},
          target: %{type: "string", description: "Element ref like e3"},
          window: %{type: "string", description: "Window name to focus before action"}
        },
        required: ["action"]
      }
    }
  }

  @launch_tool %{
    type: "function",
    function: %{
      name: "launch_app",
      description: "Launch an application by name (e.g. firefox, nautilus, gnome-terminal, gnome-text-editor). Use this to open apps.",
      parameters: %{
        type: "object",
        properties: %{
          app: %{type: "string", description: "Application binary name (e.g. firefox, nautilus)"},
          args: %{type: "string", description: "Optional arguments (e.g. a URL for firefox)"}
        },
        required: ["app"]
      }
    }
  }

  @doc """
  Run a multi-step PPEV loop for a complex computer_use task.

  Returns {:ok, summary} or {:error, reason}.
  """
  def run(goal, opts \\ []) do
    session_id = Keyword.get(opts, :session_id, "cu_#{System.system_time(:millisecond)}")
    on_step = Keyword.get(opts, :on_step, fn _step, _action, _result -> :ok end)

    planner = Planner.new(goal)
    {:ok, journal_dir} = Keyframe.init_journal(session_id)

    run_loop(planner, journal_dir, 0, on_step)
  end

  # ── PPEV Loop ─────────────────────────────────────────────────────

  defp run_loop(planner, _journal_dir, step, _on_step) when step >= @max_steps do
    {:ok, "Reached max steps (#{@max_steps}). #{Planner.summary(planner)}"}
  end

  defp run_loop(planner, journal_dir, step, on_step) do
    if Planner.stuck?(planner) do
      {:ok, "Stuck after 3 replans. #{Planner.summary(planner)}"}
    else
      case planner.phase do
        :perceive -> do_perceive(planner)
        :plan -> do_plan(planner)
        :execute -> do_execute(planner, step, on_step)
        :verify -> do_verify(planner)
        :done -> {:ok, format_done(planner)}
      end
      |> case do
        {:continue, new_planner, new_step} ->
          run_loop(new_planner, journal_dir, new_step, on_step)

        {:ok, _} = result -> result
        {:error, _} = err -> err
      end
    end
  end

  # ── Perceive: get the accessibility tree ─────────────────────────

  defp do_perceive(planner) do
    case ComputerUse.execute(%{"action" => "get_tree"}) do
      {:ok, tree_text} ->
        planner = Planner.set_perception(planner, tree_text)
        {:continue, planner, 0}

      {:error, reason} ->
        # Fallback: try screenshot instead
        case ComputerUse.execute(%{"action" => "screenshot"}) do
          {:ok, _} ->
            planner = Planner.set_perception(planner, "[screenshot taken, no tree available]")
            {:continue, planner, 0}

          {:error, _} ->
            {:error, "Cannot perceive screen: #{reason}"}
        end
    end
  end

  # ── Plan: ask LLM to create action steps ─────────────────────────

  defp do_plan(planner) do
    # Trim tree to keep prompt small — only interactive elements (lines with [eN])
    compact_tree = planner.current_tree
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "[e"))
      |> Enum.take(30)
      |> Enum.join("\n")

    messages = [
      %{role: "system", content: """
      You are a desktop automation agent. Execute ONE action at a time toward the goal.
      You have computer_use (desktop actions) and launch_app (open applications).

      Interactive elements on screen:
      #{compact_tree}

      #{if planner.history != [], do: "Steps done:\n#{format_history(planner.history)}", else: ""}
      """},
      %{role: "user", content: "Goal: #{planner.goal}\n\nCall ONE tool for the next step."}
    ]

    case llm_call(messages) do
      {:ok, tool_calls} when tool_calls != [] ->
        # Extract actions from tool calls, tagging with tool name
        actions = Enum.map(tool_calls, fn tc ->
          args = tc["function"]["arguments"] |> Jason.decode!()
          tool_name = tc["function"]["name"]
          if tool_name != "computer_use", do: Map.put(args, "_tool", tool_name), else: args
        end)
        planner = Planner.set_plan(planner, actions)
        {:continue, planner, 0}

      {:ok, []} ->
        # LLM didn't call tool — it's done or confused
        {:ok, "LLM completed without actions. #{Planner.summary(planner)}"}

      {:error, reason} ->
        {:error, "Planning failed: #{reason}"}
    end
  end

  # ── Execute: run the next action ─────────────────────────────────

  defp do_execute(planner, step, on_step) do
    case Planner.next_action(planner) do
      {nil, planner} ->
        planner = Planner.verify_success(planner)
        {:continue, planner, step}

      {action, planner} ->
        result_str = execute_action(action)
        on_step.(step + 1, action, result_str)

        planner = Planner.mark_executed(planner, action, result_str)
        planner = Planner.verify_success(planner)
        {:continue, planner, step + 1}
    end
  end

  defp execute_action(%{"_tool" => "launch_app", "app" => app} = params) do
    args = params["args"] || ""
    cmd_args = if args != "", do: String.split(args), else: []

    # Launch in background, wait for window to appear
    spawn(fn ->
      System.cmd("nohup", [app | cmd_args], stderr_to_stdout: true, env: [{"DISPLAY", System.get_env("DISPLAY") || ":0"}])
    end)
    Process.sleep(2000)
    "Launched #{app} #{args}"
  rescue
    e -> "Error launching #{app}: #{Exception.message(e)}"
  end

  defp execute_action(action) do
    case ComputerUse.execute(action) do
      {:ok, {:image, %{path: p}}} -> "Screenshot: #{p}"
      {:ok, msg} when is_binary(msg) -> msg
      {:ok, other} -> inspect(other)
      {:error, reason} -> "Error: #{reason}"
    end
  end

  # ── Verify: check if we should continue or replan ────────────────

  defp do_verify(planner) do
    # Already handled in do_execute via verify_success
    {:continue, planner, 0}
  end

  # ── LLM Call (lightweight, single tool) ──────────────────────────

  defp llm_call(messages) do
    url = cu_api_url()
    key = cu_api_key()
    model = cu_model()

    body = Jason.encode!(%{
      model: model,
      messages: messages,
      tools: [@cu_tool, @launch_tool],
      tool_choice: "auto",
      max_tokens: 150
    })

    headers = [
      {"authorization", "Bearer #{key}"},
      {"content-type", "application/json"}
    ]

    case Req.post(url, body: body, headers: headers, receive_timeout: 60_000) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => msg} | _]}}} ->
        tool_calls = msg["tool_calls"] || []
        {:ok, tool_calls}

      {:ok, %{status: status}} ->
        {:error, "LLM returned status #{status}"}

      {:error, reason} ->
        {:error, "LLM call failed: #{inspect(reason)}"}
    end
  rescue
    e -> {:error, "LLM error: #{Exception.message(e)}"}
  end

  # ── Helpers ──────────────────────────────────────────────────────

  defp format_history([]), do: "(none)"
  defp format_history(history) do
    history
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, i} ->
      action = entry.action || entry[:action] || "?"
      result = entry.result || entry[:result] || "?"
      "#{i}. #{inspect(action)} → #{result}"
    end)
    |> Enum.join("\n")
  end

  defp format_done(planner) do
    steps = length(planner.history)
    last_result = case List.last(planner.history) do
      %{result: r} -> r
      _ -> "done"
    end
    "Completed in #{steps} step(s). Last: #{last_result}"
  end

  defp cu_api_url do
    url = Application.get_env(:optimal_system_agent, :ollama_url) || "https://ollama.com"
    "#{url}/v1/chat/completions"
  end

  defp cu_api_key do
    Application.get_env(:optimal_system_agent, :ollama_api_key) || ""
  end

  defp cu_model do
    Application.get_env(:optimal_system_agent, :ollama_model) || "nemotron-3-super:cloud"
  end
end
