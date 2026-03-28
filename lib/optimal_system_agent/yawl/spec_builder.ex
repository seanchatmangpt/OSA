defmodule OptimalSystemAgent.Yawl.SpecBuilder do
  @moduledoc """
  Pure-function builder for YAWL XML specification strings.

  Implements four canonical Workflow Control-flow Patterns (WCP):

    * `sequence/1`          — WCP-1: sequential chain of tasks
    * `parallel_split/2`    — WCP-2: AND-split fan-out
    * `synchronization/2`   — WCP-3: AND-join fan-in
    * `exclusive_choice/2`  — WCP-4: XOR-split decision

  All functions return a well-formed XML string parseable by `:xmerl_scan`
  and suitable for submission to the YAWL engine.
  """

  @xmlns "http://www.citi.qut.edu.au/yawl"
  @xsi "http://www.w3.org/2001/XMLSchema-instance"
  @schema_location "http://www.citi.qut.edu.au/yawl YAWL_Schema.xsd"

  # ---------------------------------------------------------------------------
  # WCP-1: Sequence
  # ---------------------------------------------------------------------------

  @doc """
  Build a YAWL XML spec that chains `tasks` sequentially (WCP-1).

  InputCondition -> task[0] -> task[1] -> ... -> OutputCondition
  Each task carries `<join code="xor"/><split code="and"/>`.
  """
  @spec sequence([String.t()]) :: String.t()
  def sequence(tasks) when is_list(tasks) do
    task_elements =
      tasks
      |> Enum.with_index()
      |> Enum.map(fn {task_id, idx} ->
        next =
          case Enum.at(tasks, idx + 1) do
            nil -> "OutputCondition"
            next_id -> next_id
          end

        task_xml(task_id, next, "xor", "and")
      end)
      |> Enum.join("\n")

    first = List.first(tasks) || "OutputCondition"

    body = input_condition(first) <> "\n" <> task_elements <> "\n" <> output_condition()
    wrap("OSA_Sequence", body, tasks)
  end

  # ---------------------------------------------------------------------------
  # WCP-2: Parallel Split
  # ---------------------------------------------------------------------------

  @doc """
  Build a YAWL XML spec that fans out from `trigger` into all `branches` (WCP-2).

  The trigger task carries `<split code="and"/>`.  Each branch task flows into
  `OutputCondition`.
  """
  @spec parallel_split(String.t(), [String.t()]) :: String.t()
  def parallel_split(trigger, branches) when is_binary(trigger) and is_list(branches) do
    branch_flows =
      Enum.map_join(branches, "\n", fn b ->
        "      " <> flow_into(b)
      end)

    trigger_element =
      "<task id=\"#{trigger}\">\n" <>
        branch_flows <>
        "\n      <join code=\"xor\"/>\n      <split code=\"and\"/>\n" <>
        "      <decomposesTo id=\"#{trigger}\"/>\n    </task>"

    branch_elements =
      Enum.map_join(branches, "\n", fn b ->
        task_xml(b, "OutputCondition", "xor", "and")
      end)

    body =
      input_condition(trigger) <>
        "\n    " <>
        trigger_element <>
        "\n" <>
        branch_elements <>
        "\n" <>
        output_condition()

    wrap("OSA_ParallelSplit", body, [trigger | branches])
  end

  # ---------------------------------------------------------------------------
  # WCP-3: Synchronization
  # ---------------------------------------------------------------------------

  @doc """
  Build a YAWL XML spec where all `branches` converge into `join_task` (WCP-3).

  Each branch task flows into `join_task`.  `join_task` carries
  `<join code="and"/>` and flows into `OutputCondition`.
  """
  @spec synchronization([String.t()], String.t()) :: String.t()
  def synchronization(branches, join_task)
      when is_list(branches) and is_binary(join_task) do
    # InputCondition flows to ALL branches simultaneously (parallel start)
    branch_flows =
      Enum.map_join(branches, "\n      ", fn b ->
        "<flowsInto><nextElementRef id=\"#{b}\"/></flowsInto>"
      end)

    input_cond =
      "<inputCondition id=\"InputCondition\">\n" <>
        "      " <> branch_flows <> "\n" <>
        "    </inputCondition>"

    branch_elements =
      Enum.map_join(branches, "\n", fn b ->
        task_xml(b, join_task, "xor", "and")
      end)

    join_element = task_xml(join_task, "OutputCondition", "and", "and")

    body =
      input_cond <>
        "\n" <>
        branch_elements <>
        "\n" <>
        join_element <>
        "\n" <>
        output_condition()

    wrap("OSA_Synchronization", body, branches ++ [join_task])
  end

  # ---------------------------------------------------------------------------
  # WCP-4: Exclusive Choice
  # ---------------------------------------------------------------------------

  @doc """
  Build a YAWL XML spec with an XOR-split `decision` task (WCP-4).

  `branches` is a list of `{condition, task_name}` pairs.  Each branch task
  flows into `OutputCondition`.  The decision task carries `<split code="xor"/>`.
  """
  @spec exclusive_choice(String.t(), [{String.t(), String.t()}]) :: String.t()
  def exclusive_choice(decision, branches)
      when is_binary(decision) and is_list(branches) do
    decision_flows =
      Enum.map_join(branches, "\n", fn {_cond, task_name} ->
        "      " <> flow_into(task_name)
      end)

    decision_element =
      "<task id=\"#{decision}\">\n" <>
        decision_flows <>
        "\n      <join code=\"xor\"/>\n      <split code=\"xor\"/>\n" <>
        "      <decomposesTo id=\"#{decision}\"/>\n    </task>"

    branch_elements =
      Enum.map_join(branches, "\n", fn {_cond, task_name} ->
        task_xml(task_name, "OutputCondition", "xor", "and")
      end)

    body =
      input_condition(decision) <>
        "\n    " <>
        decision_element <>
        "\n" <>
        branch_elements <>
        "\n" <>
        output_condition()

    branch_task_ids = Enum.map(branches, fn {_cond, task_name} -> task_name end)
    wrap("OSA_ExclusiveChoice", body, [decision | branch_task_ids])
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Build the opening specificationSet tag using sigil concatenation to
  # avoid Elixir parsing `xmlns:xsi` as a keyword argument inside
  # a string interpolation context.
  defp open_tag do
    ~s(<specificationSet xmlns="#{@xmlns}") <>
      ~s( xmlns:xsi="#{@xsi}") <>
      ~s( xsi:schemaLocation="#{@schema_location}">)
  end

  defp wrap(uri, body, task_ids) do
    decompositions =
      task_ids
      |> Enum.uniq()
      |> Enum.map(fn t ->
        ~s(  <decomposition id="#{t}" xsi:type="WebServiceGatewayFactsType"/>)
      end)
      |> Enum.join("\n")

    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" <>
      open_tag() <>
      "\n  <specification uri=\"#{uri}\">\n" <>
      "    <metaData/>\n" <>
      "    <rootNet id=\"Net\">\n" <>
      "      <processControlElements>\n" <>
      "        " <>
      String.trim(body) <>
      "\n      </processControlElements>\n" <>
      "    </rootNet>\n" <>
      decompositions <>
      "\n  </specification>\n" <>
      "</specificationSet>\n"
  end

  defp input_condition(next_id) do
    "<inputCondition id=\"InputCondition\">\n" <>
      "      <flowsInto><nextElementRef id=\"#{next_id}\"/></flowsInto>\n" <>
      "    </inputCondition>"
  end

  defp output_condition do
    "<outputCondition id=\"OutputCondition\"/>"
  end

  defp flow_into(next_id) do
    "<flowsInto><nextElementRef id=\"#{next_id}\"/></flowsInto>"
  end

  defp task_xml(task_id, next_id, join_code, split_code) do
    "    <task id=\"#{task_id}\">\n" <>
      "      <flowsInto><nextElementRef id=\"#{next_id}\"/></flowsInto>\n" <>
      "      <join code=\"#{join_code}\"/>\n" <>
      "      <split code=\"#{split_code}\"/>\n" <>
      "      <decomposesTo id=\"#{task_id}\"/>\n" <>
      "    </task>"
  end
end
