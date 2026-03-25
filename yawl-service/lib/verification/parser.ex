defmodule YawlService.Verification.Parser do
  @moduledoc """
  Workflow parser for YAWL, BPMN, and Markdown formats.
  """

  @doc """
  Parse workflow from provided format.
  """
  def parse(%{"type" => type, "content" => content}) do
    case type do
      "yawl" -> parse_yawl(content)
      "bpmn" -> parse_bpmn(content)
      "markdown" -> parse_markdown(content)
      _ -> {:error, "Unknown workflow type: #{type}"}
    end
  end

  def parse(_), do: {:error, "Invalid workflow format"}

  # Parse YAWL XML format
  defp parse_yawl(xml_content) do
    try do
      # Extract workflow structure
      {name, places, transitions, arcs} = extract_yawl_structure(xml_content)

      yawl_net = %{
        name: name,
        type: :yawl,
        places: places,
        transitions: transitions,
        arcs: arcs,
        patterns: detect_patterns(places, transitions, arcs)
      }

      {:ok, yawl_net}
    rescue
      e -> {:error, "YAWL parse error: #{inspect(e)}"}
    end
  end

  # Parse BPMN format (convert to YAWL)
  defp parse_bpmn(bpmn_content) do
    try do
      # Convert BPMN to YAWL net
      yawl_net = %{
        name: "bpmn-converted",
        type: :bpmn,
        places: extract_bpmn_places(bpmn_content),
        transitions: extract_bpmn_transitions(bpmn_content),
        arcs: extract_bpmn_arcs(bpmn_content),
        patterns: []
      }

      {:ok, yawl_net}
    rescue
      e -> {:error, "BPMN parse error: #{inspect(e)}"}
    end
  end

  # Parse Markdown workflow description
  defp parse_markdown(md_content) do
    try do
      # Extract workflow from markdown
      steps = extract_markdown_steps(md_content)

      yawl_net = %{
        name: "markdown-workflow",
        type: :markdown,
        places: generate_places_from_steps(steps),
        transitions: generate_transitions_from_steps(steps),
        arcs: generate_arcs_from_steps(steps),
        patterns: [1]  # Sequence pattern
      }

      {:ok, yawl_net}
    rescue
      e -> {:error, "Markdown parse error: #{inspect(e)}"}
    end
  end

  # Extract YAWL net structure from XML
  defp extract_yawl_structure(xml) do
    # Simplified XML parsing (in production, use sweet_xml)
    name = extract_name(xml)
    places = extract_places(xml)
    transitions = extract_transitions(xml)
    arcs = extract_arcs(xml)

    {name, places, transitions, arcs}
  end

  defp extract_name(xml) do
    case Regex.run(~r/<name>(.*?)<\/name>/s, xml) do
      [_, name] -> String.trim(name)
      nil -> "unnamed-workflow"
    end
  end

  defp extract_places(xml) do
    Regex.scan(~r/<place[^>]*id="([^"]+)"/, xml)
    |> Enum.map(fn [_, id] -> %{id: id, type: :place} end)
  end

  defp extract_transitions(xml) do
    Regex.scan(~r/<task[^>]*id="([^"]+)"/, xml)
    |> Enum.map(fn [_, id] -> %{id: id, type: :transition} end)
  end

  defp extract_arcs(xml) do
    input_arcs = Regex.scan(~r/<inputCondition[^>]*id="([^"]+)"/, xml)
    output_arcs = Regex.scan(~r/<outputCondition[^>]*id="([^"]+)"/, xml)
    flows = Regex.scan(~r/<flow[^>]*source="([^"]+)"[^>]*target="([^"]+)"/, xml)

    (input_arcs ++ output_arcs ++ flows)
    |> Enum.map(fn
      [_, from, to] -> %{from: from, to: to}
      [_, id] -> %{id: id}
    end)
  end

  defp extract_bpmn_places(_bpmn), do: []
  defp extract_bpmn_transitions(_bpmn), do: []
  defp extract_bpmn_arcs(_bpmn), do: []

  defp extract_markdown_steps(md) do
    Regex.scan(~r/^[\-\*]\s+(.+)$/m, md)
    |> Enum.map(fn [_, step] -> String.trim(step) end)
  end

  defp generate_places_from_steps(steps) do
    steps
    |> Enum.with_index()
    |> Enum.map(fn {step, i} ->
      %{id: "p#{i}", type: :place, label: step}
    end)
  end

  defp generate_transitions_from_steps(steps) do
    steps
    |> Enum.with_index()
    |> Enum.map(fn {_step, i} ->
      %{id: "t#{i}", type: :transition}
    end)
  end

  defp generate_arcs_from_steps(steps) do
    count = length(steps)
    Enum.map(0..(count - 2), fn i ->
      %{from: "p#{i}", to: "t#{i}"}
    end) ++ Enum.map(0..(count - 2), fn i ->
      %{from: "t#{i}", to: "p#{i + 1}"}
    end)
  end

  # Detect YAWL workflow patterns used
  defp detect_patterns(places, transitions, arcs) do
    patterns = []

    # Pattern 1: Sequence
    if is_sequence?(arcs) do
      patterns = patterns ++ [1]
    end

    # Pattern 2: Parallel split
    if has_parallel_split?(arcs) do
      patterns = patterns ++ [2]
    end

    # Pattern 6: Multi-merge
    if has_multi_merge?(arcs) do
      patterns = patterns ++ [6]
    end

    patterns
  end

  defp is_sequence?(arcs) do
    # Check if each node has at most one outgoing arc
    arc_counts = Enum.reduce(arcs, %{}, fn arc, acc ->
      Map.update(acc, arc.from, 1, &(&1 + 1))
    end)

    Enum.all?(arc_counts, fn {_node, count} -> count <= 1 end)
  end

  defp has_parallel_split?(arcs) do
    # Check if any node has multiple outgoing arcs
    Enum.any?(arcs, fn arc ->
      Enum.count(arcs, fn a -> a.from == arc.from end) > 1
    end)
  end

  defp has_multi_merge?(arcs) do
    # Check if any node has multiple incoming arcs
    Enum.any?(arcs, fn arc ->
      Enum.count(arcs, fn a -> a.to == arc.to end) > 1
    end)
  end
end
