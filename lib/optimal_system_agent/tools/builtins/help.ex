defmodule OptimalSystemAgent.Tools.Builtins.Help do
  @behaviour OptimalSystemAgent.Tools.Behaviour

  @impl true
  def safety, do: :read_only

  @impl true
  def name, do: "help"

  @impl true
  def description, do: "List all available tools with their descriptions"

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "tool_name" => %{
          "type" => "string",
          "description" => "Optional: Get detailed help for a specific tool"
        }
      },
      "required" => []
    }
  end

  @impl true
  def execute(params) do
    tool_name = Map.get(params, "tool_name")

    tools = OptimalSystemAgent.Tools.Registry.list_tools_direct()

    case tool_name do
      nil ->
        # List all tools
        tool_list =
          tools
          |> Enum.map(fn tool ->
            "- #{tool.name}: #{tool.description}"
          end)
          |> Enum.join("\n")

        {:ok, %{content: "Available tools:\n\n" <> tool_list}}

      name ->
        # Get detailed info for specific tool
        case Enum.find(tools, fn t -> t.name == name end) do
          nil ->
            {:ok, %{content: "Tool '#{name}' not found. Available tools: " <> Enum.map_join(tools, ", ", fn t -> t.name end)}}

          tool ->
            schema = Jason.encode!(tool.parameters, pretty: true)

            help_text = """
            Tool: #{tool.name}
            Description: #{tool.description}
            Parameters:
            #{schema}
            """

            {:ok, %{content: help_text}}
        end
    end
  end
end
