defmodule OptimalSystemAgent.Channels.HTTP.API.VerificationRoutes do
  @moduledoc """
  Formal Correctness as a Service (Innovation 8) -- HTTP API endpoints
  for workflow structural verification.

  Endpoints:
    POST /api/v1/verify/workflow        Verify a single workflow
    GET  /api/v1/verify/certificate/:id Look up a previously issued certificate
    POST /api/v1/verify/batch           Verify multiple workflows in one request

  Accepts YAWL XML, BPMN XML, or markdown workflow definitions.
  Returns verification results with SHA-256 signed certificates stored in ETS.

  Certificate format:
    {
      "verified": true,
      "certificate": {
        "id": "cert_<sha256>",
        "workflow_hash": "<sha256>",
        "proof_hash": "<sha256>",
        "issued_at": "ISO8601",
        "checks": { ... },
        "overall_score": 4.5,
        "issues": []
      }
    }
  """
  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Verification.StructuralAnalyzer

  plug :match
  plug :dispatch

  @certificate_table :osa_verify_certificates

  @valid_formats ~w(yawl bpmn markdown)

  # ===========================================================================
  # POST /api/v1/verify/workflow
  # ===========================================================================

  post "/workflow" do
    workflow_def = conn.body_params["workflow"]
    format = conn.body_params["format"] || "yawl"

    cond do
      is_nil(workflow_def) ->
        json_error(conn, 400, "invalid_request", "Missing required field: workflow")

      is_map(workflow_def) ->
        # Accept JSON workflow objects — serialize to markdown for parsing
        md_workflow = workflow_to_markdown(workflow_def)
        format = "markdown"

        case verify_single_workflow(md_workflow, format) do
          {:ok, result} -> json(conn, 200, result)
          {:error, reason} -> json_error(conn, 422, "verification_failed", reason)
        end

      is_binary(workflow_def) and workflow_def == "" ->
        json_error(conn, 400, "invalid_request", "Missing required field: workflow")

      format not in @valid_formats ->
        valid_list = Enum.join(@valid_formats, ", ")
        json_error(conn, 400, "invalid_format", "Invalid format '#{format}'. Valid formats: #{valid_list}")

      true ->
        case verify_single_workflow(workflow_def, format) do
          {:ok, result} -> json(conn, 200, result)
          {:error, reason} -> json_error(conn, 422, "verification_failed", reason)
        end
    end
  end

  # ===========================================================================
  # GET /api/v1/verify/certificate/:id
  # ===========================================================================

  get "/certificate/:id" do
    case :ets.lookup(@certificate_table, id) do
      [{^id, certificate}] ->
        json(conn, 200, certificate)

      [] ->
        json_error(conn, 404, "not_found", "Certificate '#{id}' not found")
    end
  end

  # ===========================================================================
  # POST /api/v1/verify/batch
  # ===========================================================================

  post "/batch" do
    workflows = conn.body_params["workflows"]

    cond do
      is_nil(workflows) or not is_list(workflows) ->
        json_error(conn, 400, "invalid_request", "Missing required field: workflows (must be an array)")

      workflows == [] ->
        json_error(conn, 400, "invalid_request", "Field 'workflows' must be a non-empty array")

      length(workflows) > 50 ->
        json_error(conn, 400, "invalid_request", "Batch size exceeds maximum of 50 workflows")

      true ->
        results =
          workflows
          |> Enum.with_index()
          |> Enum.map(fn {item, idx} ->
            workflow_def = item["workflow"]
            format = item["format"] || "yawl"

            case verify_single_workflow(workflow_def, format) do
              {:ok, result} ->
                Map.put(result, "index", idx)

              {:error, reason} ->
                %{
                  "index" => idx,
                  "verified" => false,
                  "error" => reason
                }
            end
          end)

        total = length(results)
        passed = Enum.count(results, fn r -> r["verified"] == true end)

        json(conn, 200, %{
          results: results,
          total: total,
          passed: passed,
          failed: total - passed
        })
    end
  end

  # ===========================================================================
  # Catch-all
  # ===========================================================================

  match _ do
    json_error(conn, 404, "not_found", "Verification endpoint not found")
  end

  # ===========================================================================
  # Private: Core verification logic
  # ===========================================================================

  @spec verify_single_workflow(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  defp verify_single_workflow(workflow_def, format) do
    format_atom = String.to_existing_atom(format)

    # Parse the workflow definition into a normalized structure
    case parse_workflow(workflow_def, format_atom) do
      {:ok, workflow} ->
        # Run structural analysis
        analysis = StructuralAnalyzer.analyze_workflow(workflow, format_atom)

        # Build certificate
        certificate = build_certificate(workflow_def, format, analysis)

        # Store in ETS
        :ets.insert(@certificate_table, {certificate["certificate"]["id"], certificate})

        {:ok, certificate}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    ArgumentError ->
      {:error, "Invalid format: #{format}"}
  end

  # ===========================================================================
  # Private: Workflow Parsers
  # ===========================================================================

  @spec parse_workflow(String.t(), atom()) :: {:ok, map()} | {:error, String.t()}
  defp parse_workflow(content, :yawl), do: parse_yawl_xml(content)
  defp parse_workflow(content, :bpmn), do: parse_bpmn_xml(content)
  defp parse_workflow(content, :markdown), do: parse_markdown(content)

  # ---------------------------------------------------------------------------
  # YAWL XML Parser
  # ---------------------------------------------------------------------------

  defp parse_yawl_xml(xml_content) do
    try do
      {doc, _} = :xmerl_scan.string(String.to_charlist(xml_content))

      # Extract tasks
      tasks =
        xpath_all(doc, ~c"//task")
        |> Enum.map(fn node ->
          id = xml_attr(node, "id") || generate_id()
          name = xml_text(xpath_all(node, ~c"name/text()"))

          %{
            id: id,
            name: name || id,
            type: :task,
            split_type: nil,
            join_type: nil
          }
        end)
        |> Map.new(fn t -> {t.id, t} end)

      # Extract conditions (gateways)
      conditions =
        xpath_all(doc, ~c"//condition")
        |> Enum.map(fn node ->
          id = xml_attr(node, "id") || generate_id()
          name = xml_text(xpath_all(node, ~c"name/text()"))

          split_type =
            case xml_attr(node, "split") do
              "And" -> :and
              "Xor" -> :xor
              "Or" -> :or
              _ -> nil
            end

          join_type =
            case xml_attr(node, "join") do
              "And" -> :and
              "Xor" -> :xor
              "Or" -> :or
              _ -> nil
            end

          %{
            id: id,
            name: name || id,
            type: :condition,
            split_type: split_type,
            join_type: join_type
          }
        end)
        |> Map.new(fn t -> {t.id, t} end)

      all_tasks = Map.merge(tasks, conditions)

      # Add start/end markers
      all_tasks =
        all_tasks
        |> maybe_add_start(xpath_all(doc, ~c"//inputCondition"))
        |> maybe_add_end(xpath_all(doc, ~c"//outputCondition"))

      # Extract flow (transitions)
      # YAWL uses <flowsInto> elements inside task/condition elements.
      # Each <flowsInto> contains <flowElementRef>targetId</flowElementRef>.
      # We build transitions by iterating over all elements that have an id
      # and checking if they contain <flowsInto> children.
      transitions =
        build_yawl_transitions(doc, all_tasks)

      start_node = find_start_node(all_tasks, transitions)
      end_node = find_end_node(all_tasks, transitions)

      {:ok, %{
        tasks: all_tasks,
        transitions: transitions,
        start_node: start_node,
        end_node: end_node,
        metadata: %{format: :yawl, task_count: map_size(all_tasks), transition_count: length(transitions)}
      }}
    rescue
      e ->
        Logger.warning("[VerificationRoutes] YAWL XML parse error: #{Exception.message(e)}")
        {:error, "Failed to parse YAWL XML: #{Exception.message(e)}"}
    end
  end

  # ---------------------------------------------------------------------------
  # BPMN XML Parser
  # ---------------------------------------------------------------------------

  defp parse_bpmn_xml(xml_content) do
    try do
      {doc, _} = :xmerl_scan.string(String.to_charlist(xml_content))

      bpmn_ns_task_xpath = ~c"//bpmn:userTask | //bpmn:serviceTask | //bpmn:scriptTask | //bpmn:task"
      plain_task_xpath = ~c"//userTask | //serviceTask | //scriptTask | //task"

      # Extract user tasks, service tasks, script tasks
      task_nodes =
        xpath_all(doc, bpmn_ns_task_xpath)
        |> Enum.concat(xpath_all(doc, plain_task_xpath))
        |> Enum.uniq_by(fn node -> xml_attr(node, "id") end)
        |> Enum.map(fn node ->
          id = xml_attr(node, "id") || generate_id()
          name = xml_attr(node, "name") || id

          %{
            id: id,
            name: name,
            type: :task,
            split_type: nil,
            join_type: nil
          }
        end)
        |> Map.new(fn t -> {t.id, t} end)

      # Extract gateways (exclusive, parallel, inclusive)
      gateway_xpath =
        ~c"//bpmn:exclusiveGateway | //bpmn:parallelGateway | //bpmn:inclusiveGateway | //exclusiveGateway | //parallelGateway | //inclusiveGateway"

      gateways =
        xpath_all(doc, gateway_xpath)
        |> Enum.uniq_by(fn node -> xml_attr(node, "id") end)
        |> Enum.map(fn node ->
          id = xml_attr(node, "id") || generate_id()
          name = xml_attr(node, "name") || id
          gateway_type = xml_attr(node, "type") || ""

          # Infer from element name
          element_name =
            xpath_all(node, ~c"name()")
            |> Enum.map(&to_string/1)
            |> Enum.join("")
            |> String.downcase()

          {split_type, join_type} =
            cond do
              String.contains?(gateway_type, "parallel") or String.contains?(element_name, "parallel") ->
                {:and, :and}

              String.contains?(gateway_type, "exclusive") or String.contains?(element_name, "exclusive") ->
                {:xor, :xor}

              String.contains?(gateway_type, "inclusive") or String.contains?(element_name, "inclusive") ->
                {:or, :or}

              true ->
                {nil, nil}
            end

          %{
            id: id,
            name: name,
            type: :gateway,
            split_type: split_type,
            join_type: join_type
          }
        end)
        |> Map.new(fn t -> {t.id, t} end)

      # Extract start events
      start_events =
        xpath_all(doc, ~c"//bpmn:startEvent | //startEvent")
        |> Enum.uniq_by(fn node -> xml_attr(node, "id") end)
        |> Enum.map(fn node ->
          id = xml_attr(node, "id") || generate_id()
          name = xml_attr(node, "name") || "Start"

          %{
            id: id,
            name: name,
            type: :start,
            split_type: nil,
            join_type: nil
          }
        end)
        |> Map.new(fn t -> {t.id, t} end)

      # Extract end events
      end_events =
        xpath_all(doc, ~c"//bpmn:endEvent | //endEvent")
        |> Enum.uniq_by(fn node -> xml_attr(node, "id") end)
        |> Enum.map(fn node ->
          id = xml_attr(node, "id") || generate_id()
          name = xml_attr(node, "name") || "End"

          %{
            id: id,
            name: name,
            type: :end,
            split_type: nil,
            join_type: nil
          }
        end)
        |> Map.new(fn t -> {t.id, t} end)

      all_tasks =
        task_nodes
        |> Map.merge(gateways)
        |> Map.merge(start_events)
        |> Map.merge(end_events)

      # Extract sequence flows (transitions)
      transitions =
        xpath_all(doc, ~c"//bpmn:sequenceFlow | //sequenceFlow")
        |> Enum.map(fn node ->
          source_ref = xml_attr(node, "sourceRef")
          target_ref = xml_attr(node, "targetRef")
          name = xml_attr(node, "name")

          %{
            from: source_ref || "",
            to: target_ref || "",
            condition: if(name && name != "", do: name, else: nil)
          }
        end)
        |> Enum.filter(fn t -> t.from != "" and t.to != "" end)

      start_node = start_events |> Map.keys() |> List.first()
      end_node = end_events |> Map.keys() |> List.first()

      {:ok, %{
        tasks: all_tasks,
        transitions: transitions,
        start_node: start_node,
        end_node: end_node,
        metadata: %{format: :bpmn, task_count: map_size(all_tasks), transition_count: length(transitions)}
      }}
    rescue
      e ->
        Logger.warning("[VerificationRoutes] BPMN XML parse error: #{Exception.message(e)}")
        {:error, "Failed to parse BPMN XML: #{Exception.message(e)}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Markdown Parser
  # ---------------------------------------------------------------------------

  defp parse_markdown(content) do
    lines = String.split(content, "\n")

    # Parse task definitions and dependencies from markdown
    # Supports:
    #   - "## Task Name" headings
    #   - "- [ ] Task Name" checkboxes
    #   - "- Task Name -> depends_on_task" dependency syntax
    #   - "->", "=>", "~>", ">>>" arrows for flow connections
    {tasks, transitions, start_node, end_node} = parse_markdown_tasks(lines)

    if map_size(tasks) == 0 do
      {:error, "No tasks found in markdown workflow. Use headings (## Task) or checkboxes (- [ ] Task)."}
    else
      {:ok, %{
        tasks: tasks,
        transitions: transitions,
        start_node: start_node,
        end_node: end_node,
        metadata: %{format: :markdown, task_count: map_size(tasks), transition_count: length(transitions)}
      }}
    end
  end

  defp parse_markdown_tasks(lines) do
    # Phase 1: Extract tasks
    {tasks, start_node, end_node} = extract_markdown_tasks(lines)

    # Phase 2: Extract explicit transitions from dependency syntax
    explicit_transitions = extract_markdown_transitions(lines, tasks)

    # Phase 3: If no explicit transitions, infer sequential order from document order
    transitions =
      if explicit_transitions == [] do
        infer_sequential_transitions(tasks)
      else
        explicit_transitions
      end

    {tasks, transitions, start_node, end_node}
  end

  defp extract_markdown_tasks(lines) do
    {tasks, _} =
      lines
      |> Enum.reduce({%{}, 0}, fn line, {acc, idx} ->
        trimmed = String.trim(line)

        cond do
          # ## Task Name or ### Task Name
          Regex.match?(~r/^##+?\s+(.+)/, trimmed) ->
            [_, name] = Regex.run(~r/^##+?\s+(.+)/, trimmed)
            id = "task_#{idx}"
            task = %{id: id, name: String.trim(name), type: :task, split_type: nil, join_type: nil}
            {Map.put(acc, id, task), idx + 1}

          # - [ ] Task Name or - [x] Task Name
          Regex.match?(~r/^- \[([ xX])\]\s+(.+)/, trimmed) ->
            [_, _status, name] = Regex.run(~r/^- \[([ xX])\]\s+(.+)/, trimmed)
            id = "task_#{idx}"
            task = %{id: id, name: String.trim(name), type: :task, split_type: nil, join_type: nil}
            {Map.put(acc, id, task), idx + 1}

          # - Task Name (simple list item)
          Regex.match?(~r/^-\s+(.+)/, trimmed) ->
            [_, name] = Regex.run(~r/^-\s+(.+)/, trimmed)

            if String.contains?(name, ["->", "->>", "~>", "=>"]) do
              {acc, idx}
            else
              id = "task_#{idx}"
              task = %{id: id, name: String.trim(name), type: :task, split_type: nil, join_type: nil}
              {Map.put(acc, id, task), idx + 1}
            end

          # * Task Name (bullet with asterisk)
          Regex.match?(~r/^\*\s+(.+)/, trimmed) ->
            [_, name] = Regex.run(~r/^\*\s+(.+)/, trimmed)

            if String.contains?(name, ["->", "->>", "~>", "=>"]) do
              {acc, idx}
            else
              id = "task_#{idx}"
              task = %{id: id, name: String.trim(name), type: :task, split_type: nil, join_type: nil}
              {Map.put(acc, id, task), idx + 1}
            end

          true ->
            {acc, idx}
        end
      end)

    # Detect start/end nodes by name convention
    task_list = Map.values(tasks)

    start_node =
      Enum.find(task_list, fn t ->
        name = String.downcase(t.name)
        String.contains?(name, "start") or String.contains?(name, "begin") or String.contains?(name, "input")
      end)
      |> then(fn
        nil -> nil
        t -> t.id
      end)

    end_node =
      Enum.find(task_list, fn t ->
        name = String.downcase(t.name)
        String.contains?(name, "end") or String.contains?(name, "finish") or String.contains?(name, "complete") or
          String.contains?(name, "output") or String.contains?(name, "done")
      end)
      |> then(fn
        nil -> nil
        t -> t.id
      end)

    # If no explicit start/end, use first and last
    ordered_ids = tasks |> Map.keys() |> Enum.sort()

    {start_node, end_node} =
      cond do
        start_node && end_node -> {start_node, end_node}
        map_size(tasks) == 0 -> {nil, nil}
        map_size(tasks) == 1 -> {hd(ordered_ids), hd(ordered_ids)}
        true ->
          {start_node || hd(ordered_ids), end_node || List.last(ordered_ids)}
      end

    {tasks, start_node, end_node}
  end

  defp extract_markdown_transitions(lines, tasks) do
    task_by_name =
      tasks
      |> Map.values()
      |> Enum.map(fn t -> {String.downcase(t.name), t.id} end)
      |> Map.new()

    lines
    |> Enum.flat_map(fn line ->
      trimmed = String.trim(line)

      # Match "Task A -> Task B" or "Task A => Task B" or "Task A ~> Task B"
      case Regex.run(~r/^(.+?)\s*(?:->|=>|~>|->>)\s*(.+)$/, trimmed) do
        [_, from_name, to_name] ->
          from_id = Map.get(task_by_name, String.downcase(String.trim(from_name)))
          to_id = Map.get(task_by_name, String.downcase(String.trim(to_name)))

          if from_id && to_id do
            [%{from: from_id, to: to_id, condition: nil}]
          else
            []
          end

        nil ->
          []
      end
    end)
  end

  defp infer_sequential_transitions(tasks) do
    ordered_ids = tasks |> Map.keys() |> Enum.sort()

    ordered_ids
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] ->
      %{from: from, to: to, condition: nil}
    end)
  end

  # ===========================================================================
  # Private: Certificate Building
  # ===========================================================================

  @spec build_certificate(String.t(), String.t(), map()) :: map()
  defp build_certificate(workflow_def, format, analysis) do
    workflow_hash = sha256(workflow_def)

    # Build proof payload: concatenate all check results deterministically
    proof_payload =
      [
        to_string(analysis.deadlock_free),
        to_string(analysis.livelock_free),
        to_string(analysis.sound),
        to_string(analysis.proper_completion),
        to_string(analysis.no_orphan_tasks),
        to_string(analysis.no_unreachable_tasks),
        Float.to_string(analysis.overall_score),
        format
      ]
      |> Enum.join(":")

    proof_hash = sha256(proof_payload)
    certificate_id = "cert_#{proof_hash}"
    issued_at = DateTime.utc_now() |> DateTime.to_iso8601()

    %{
      "verified" => analysis.overall_score >= 3.0,
      "certificate" => %{
        "id" => certificate_id,
        "workflow_hash" => workflow_hash,
        "proof_hash" => proof_hash,
        "issued_at" => issued_at,
        "checks" => %{
          "deadlock_free" => analysis.deadlock_free,
          "livelock_free" => analysis.livelock_free,
          "sound" => analysis.sound,
          "proper_completion" => analysis.proper_completion,
          "no_orphan_tasks" => analysis.no_orphan_tasks,
          "no_unreachable_tasks" => analysis.no_unreachable_tasks
        },
        "overall_score" => analysis.overall_score,
        "issues" =>
          analysis.issues
          |> Enum.map(fn issue ->
            %{
              "type" => to_string(issue.type),
              "severity" => to_string(issue.severity),
              "description" => issue.description
            }
          end)
      }
    }
  end

  # ===========================================================================
  # Private: XML Helpers
  # ===========================================================================

  # Wrapper around :xmerl_xpath.string/2 that returns a list of nodes.
  defp xpath_all(doc, path) when is_list(path) do
    :xmerl_xpath.string(path, doc)
  end

  # Extract an XML attribute value from a list of xmerl nodes.
  defp xml_attr([], _attr_name), do: nil

  defp xml_attr(nodes, attr_name) when is_list(nodes) do
    xml_attr(hd(nodes), attr_name)
  end

  defp xml_attr(node, attr_name) do
    path = '@' ++ String.to_charlist(attr_name)

    case :xmerl_xpath.string(path, node) do
      # xmlAttribute record (Erlang/OTP 27): {xmlAttribute, name, parents, pos, ns, nsinfo, list_pos, lang, value, expanded, specified}
      # 10 elements -- value at index 8
      [{:xmlAttribute, _, _, _, _, _, _, _, value, _}] ->
        List.to_string(value)

      _ ->
        nil
    end
  end

  # Extract text content from a list of xmerl text nodes.
  defp xml_text([]), do: nil

  defp xml_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(fn
      # xmlText record (Erlang/OTP 27): {xmlText, parents, pos, language, data, type}
      # 6 elements -- data at index 4
      {:xmlText, _, _, _, data, _} when is_list(data) ->
        List.to_string(data)

      {:xmlText, _, _, _, data, _} when is_binary(data) ->
        data

      _ ->
        ""
    end)
    |> Enum.join("")
    |> String.trim()
  rescue
    _ -> nil
  end

  # Build transitions from YAWL XML by examining each known task/condition element
  # and extracting its <flowsInto> children.
  defp build_yawl_transitions(doc, tasks) do
    # For each known task id, find its element in the doc and extract flowsInto targets
    tasks
    |> Map.keys()
    |> Enum.flat_map(fn task_id ->
      # XPath to find element with this id and its flowsInto children
      xpath = '//*[@id=\'' ++ String.to_charlist(task_id) ++ '\']/flowsInto/flowElementRef/text()'

      targets =
        xpath_all(doc, xpath)
        |> xml_text()
        |> then(fn
          nil -> []
          text -> String.split(text, ~r/\s+/) |> Enum.filter(&(&1 != ""))
        end)

      Enum.map(targets, fn target -> %{from: task_id, to: target, condition: nil} end)
    end)
    |> Enum.filter(fn t -> t.from != "" and t.to != "" end)
  end

  defp find_start_node(tasks, transitions) do
    # Prefer tasks explicitly typed as :start
    case Enum.find(tasks, fn {_id, t} -> t[:type] == :start end) do
      {id, _} -> id
      nil ->
        # Otherwise find a node with no incoming transitions
        targets = transitions |> Enum.map(& &1.to) |> MapSet.new()
        sources = transitions |> Enum.map(& &1.from) |> MapSet.new()
        candidates = MapSet.difference(sources, targets)

        case MapSet.to_list(candidates) |> Enum.find(fn id -> Map.has_key?(tasks, id) end) do
          nil -> nil
          id -> id
        end
    end
  end

  defp find_end_node(tasks, transitions) do
    # Prefer tasks explicitly typed as :end
    case Enum.find(tasks, fn {_id, t} -> t[:type] == :end end) do
      {id, _} -> id
      nil ->
        # Otherwise find a node with no outgoing transitions
        targets = transitions |> Enum.map(& &1.to) |> MapSet.new()
        sources = transitions |> Enum.map(& &1.from) |> MapSet.new()
        sinks = MapSet.difference(targets, sources)

        case MapSet.to_list(sinks) |> Enum.find(fn id -> Map.has_key?(tasks, id) end) do
          nil -> nil
          id -> id
        end
    end
  end

  defp maybe_add_start(tasks, []), do: tasks

  defp maybe_add_start(tasks, [node | _]) do
    id = xml_attr(node, "id") || "start"
    name = xml_text(xpath_all(node, ~c"name/text()")) || "Start"

    Map.put_new(tasks, id, %{
      id: id,
      name: name,
      type: :start,
      split_type: nil,
      join_type: nil
    })
  end

  defp maybe_add_end(tasks, []), do: tasks

  defp maybe_add_end(tasks, [node | _]) do
    id = xml_attr(node, "id") || "end"
    name = xml_text(xpath_all(node, ~c"name/text()")) || "End"

    Map.put_new(tasks, id, %{
      id: id,
      name: name,
      type: :end,
      split_type: nil,
      join_type: nil
    })
  end

  # ===========================================================================
  # Private: Utility
  # ===========================================================================

  # Convert a JSON workflow object to markdown format for parsing.
  # Accepts: %{"name" => ..., "tasks" => %{"task_id" => %{"type" => ..., "next" => [...]}}}
  defp workflow_to_markdown(workflow) when is_map(workflow) do
    name = Map.get(workflow, "name", "Workflow")
    tasks = Map.get(workflow, "tasks", %{})

    lines = ["# #{name}", ""]

    # Write each task as a heading with next-step transitions
    sorted_tasks = Enum.sort_by(tasks, fn {id, _config} -> id end)

    task_lines =
      Enum.flat_map(sorted_tasks, fn {id, config} ->
        task_type = Map.get(config, "type", "automated")
        next = Map.get(config, "next", [])

        next_str =
          case next do
            [] -> ""
            targets -> " -> #{Enum.join(targets, ", ")}"
          end

        ["## #{id} (#{task_type})#{next_str}"]
      end)

    Enum.join(lines ++ task_lines, "\n")
  end

  defp sha256(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end
end
