defmodule OptimalSystemAgent.Tools.Builtins.Delegate do
  @moduledoc """
  Delegate tool — spawns a subagent to handle a subtask.

  The parent agent calls this tool to delegate work to a specialized subagent.
  Each subagent gets its own context window, model selection (via the Tier system),
  and restricted tool access (:subagent permission tier).

  The tool blocks until the subagent completes, then returns the result as a
  string for the parent to synthesize.
  """
  @behaviour OptimalSystemAgent.Tools.Behaviour

  alias OptimalSystemAgent.Agents.Registry, as: AgentRegistry
  alias OptimalSystemAgent.Orchestrator
  alias OptimalSystemAgent.Agent.Tier

  @impl true
  def name, do: "delegate"

  @impl true
  def description do
    "Delegate a subtask to a specialized subagent. " <>
      "Each subagent gets its own context window and tool access. " <>
      "Use when a task has multiple independent parts or when a " <>
      "specialized role would handle the work better. " <>
      "The subagent runs to completion and returns its result."
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "required" => ["task"],
      "properties" => %{
        "task" => %{
          "type" => "string",
          "description" => "Clear, specific description of the subtask to delegate. " <>
            "Include all context the subagent needs — file paths, requirements, constraints. " <>
            "The subagent has NO access to your conversation history."
        },
        "role" => %{
          "type" => "string",
          "description" => "Agent role name (e.g., 'architect', 'backend', 'frontend', 'tester'). " <>
            "Must match a loaded agent definition. Omit for a generic subagent."
        },
        "tier" => %{
          "type" => "string",
          "enum" => ["elite", "specialist", "utility"],
          "description" => "Model tier — elite (strongest, slowest), specialist (balanced), " <>
            "utility (fastest, cheapest). Defaults to the role's configured tier, or 'specialist'."
        }
      }
    }
  end

  @impl true
  def execute(args) do
    task = Map.get(args, "task", "")
    role = Map.get(args, "role")
    tier_str = Map.get(args, "tier")
    parent_id = Map.get(args, "__session_id__", "unknown")

    if String.trim(task) == "" do
      {:ok, "Error: task description is required for delegation."}
    else
      # Resolve agent definition if role is specified
      agent_def = if role, do: AgentRegistry.get(role), else: nil

      # Resolve tier: explicit arg > agent definition > default
      # FLOOR: Never use :utility for subagents — small models (3B) can't do
      # tool calling. Minimum subagent tier is :specialist.
      raw_tier =
        cond do
          tier_str -> parse_tier(tier_str)
          agent_def -> agent_def[:tier] || :specialist
          true -> :specialist
        end

      tier = if raw_tier == :utility, do: :specialist, else: raw_tier

      # Build orchestrator config
      config = %{
        task: task,
        parent_session_id: parent_id,
        role: role || "agent",
        tier: tier,
        system_prompt: agent_def && agent_def[:system_prompt],
        tools_allowed: agent_def && agent_def[:tools_allowed],
        tools_blocked: (agent_def && agent_def[:tools_blocked]) || [],
        max_iterations: (agent_def && agent_def[:max_iterations]) || Tier.max_iterations(tier)
      }

      case Orchestrator.run_subagent(config) do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          {:ok, "Delegation failed: #{inspect(reason)}"}
      end
    end
  end

  defp parse_tier("elite"), do: :elite
  defp parse_tier("specialist"), do: :specialist
  defp parse_tier("utility"), do: :utility
  defp parse_tier(_), do: :specialist
end
