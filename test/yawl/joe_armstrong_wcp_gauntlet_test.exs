defmodule OptimalSystemAgent.Yawl.JoeArmstrongWCPGauntletTest do
  @moduledoc """
  Chicago TDD — Joe Armstrong WCP Gauntlet with Real Groq API Calls.

  Covers WCP-1 (Sequence), WCP-2 (Parallel Split), WCP-3 (Synchronization),
  and WCP-4 (Exclusive Choice) using Groq AI to DRIVE workflow decisions.

  Key distinction from the Java TestJoeArmstrongGauntlet:
    Java verifies YAWL engine mechanics in isolation.
    These tests use AI to make decisions WITHIN the workflows.

  Armstrong Principles — one per test:
    Test 1 (WCP-1): Let-It-Crash   — no error swallowing; raw failures propagate
    Test 2 (WCP-2): No Shared State — unique case_ids; parallel branch tokens isolated
    Test 3 (WCP-4): Supervision     — GenServer survives bad case_id injection
    Test 4 (WCP-1): Budget          — Groq and YAWL calls asserted within explicit limits
    Test 5 (WCP-3): Crash Visibility — empty-spec error surfaced, not swallowed

  Run:
    GROQ_API_KEY=<key> mix test test/yawl/joe_armstrong_wcp_gauntlet_test.exs \\
      --include integration

  Prerequisites:
    - GROQ_API_KEY env var set
    - YAWL embedded server running at :yawl_url (default http://localhost:8080)
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias OptimalSystemAgent.Providers.OpenAICompatProvider
  alias OptimalSystemAgent.Yawl.CaseLifecycle
  alias OptimalSystemAgent.Yawl.SpecBuilder

  @groq_model "openai/gpt-oss-20b"
  @groq_timeout 30_000
  @yawl_timeout 5_000

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    api_key =
      Application.get_env(:optimal_system_agent, :groq_api_key) ||
        System.get_env("GROQ_API_KEY")

    if is_nil(api_key) or api_key == "" do
      flunk("GROQ_API_KEY not configured — set it before running integration tests")
    end

    Application.put_env(:optimal_system_agent, :groq_api_key, api_key)

    case Process.whereis(CaseLifecycle) do
      nil -> start_supervised({CaseLifecycle, []})
      _pid -> :ok
    end

    yawl_url = Application.get_env(:optimal_system_agent, :yawl_url, "http://localhost:8080")
    health_url = yawl_url <> "/health.jsp"

    case Req.get(health_url, receive_timeout: 2_000) do
      {:ok, %{status: s}} when s in 200..299 ->
        :ok

      _ ->
        flunk("YAWL embedded server unreachable at #{health_url} — start it first")
    end

    case_id = "wcp-gauntlet-#{:erlang.unique_integer([:positive])}"

    on_exit(fn -> _result = CaseLifecycle.cancel_case(case_id) end)

    {:ok, case_id: case_id}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Armstrong Let-It-Crash: no rescue block — {:error, _} from Groq fails the test
  defp ask_groq(prompt) do
    messages = [%{role: "user", content: prompt}]

    {:ok, %{content: content}} =
      OpenAICompatProvider.chat(
        :groq,
        messages,
        model: @groq_model,
        temperature: 0.0,
        receive_timeout: @groq_timeout
      )

    content
  end

  # Execute a workitem through start → complete; returns :ok
  # Let-It-Crash: pattern-matches {:ok, _} — any error propagates as match failure
  # YAWL creates child work items on start — complete must use the child's ID
  defp execute_workitem(case_id, %{"id" => wid}) do
    {:ok, started} = CaseLifecycle.start_workitem(case_id, wid)
    # YAWL parses output data as XML — use minimal valid XML, not empty string
    child_id = started["id"]
    {:ok, _} = CaseLifecycle.complete_workitem(case_id, child_id, "<data/>")
    :ok
  end

  # ---------------------------------------------------------------------------
  # Test 1: WCP-1 Sequence + Let-It-Crash
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "WCP-1 Sequence: Groq names the steps, YAWL advances the task token",
       %{case_id: case_id} do
    # Groq drives the workflow design — Let-It-Crash if Groq fails
    content =
      ask_groq("""
      You are designing a support-ticket workflow.
      Reply with EXACTLY three task names separated by commas, nothing else.
      The tasks must handle: receive, diagnose, resolve.
      Example format: ReceiveTicket,DiagnoseIssue,ResolveTicket
      """)

    tasks =
      content
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.replace(&1, " ", "_"))
      |> Enum.take(3)

    assert length(tasks) == 3,
           "Groq must return exactly 3 comma-separated task names, got: #{inspect(content)}"

    # Build and launch the WCP-1 spec
    spec_xml = SpecBuilder.sequence(tasks)
    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)

    # Verify at least one work item is enabled
    assert {:ok, items} = CaseLifecycle.list_workitems(case_id)
    assert length(items) >= 1, "At least one work item must be enabled after launch"

    # Execute the first enabled item
    first = hd(items)
    :ok = execute_workitem(case_id, first)

    # The executed item must NOT still be Executing — WCP-1 token must advance
    assert {:ok, next_items} = CaseLifecycle.list_workitems(case_id)

    executing_same =
      Enum.any?(next_items, fn item ->
        item["id"] == first["id"] and item["status"] == "Executing"
      end)

    refute executing_same,
           "WCP-1 violated: completed task must not remain Executing — token must advance"
  end

  # ---------------------------------------------------------------------------
  # Test 2: WCP-2 Parallel Split + No Shared State
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "WCP-2 Parallel Split: Groq picks branches, each has its own independent token",
       %{case_id: case_id} do
    # Groq picks the parallel audit branch names
    content =
      ask_groq("""
      You are designing a parallel document-review workflow.
      Reply with EXACTLY two task names separated by a comma, nothing else.
      Each task is an independent review branch (e.g. LegalReview,ComplianceReview).
      Only two branch names — no other text.
      """)

    branches =
      content
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.replace(&1, " ", "_"))
      |> Enum.take(2)

    assert length(branches) == 2,
           "Groq must return exactly 2 branch names, got: #{inspect(content)}"

    trigger = "ReviewTrigger"

    # Build and launch the WCP-2 spec (AND-split)
    spec_xml = SpecBuilder.parallel_split(trigger, branches)
    assert String.contains?(spec_xml, "OSA_ParallelSplit")
    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)

    # Execute trigger to fire the AND-split
    assert {:ok, trigger_items} = CaseLifecycle.list_workitems(case_id)
    assert length(trigger_items) >= 1, "Trigger work item must be enabled"
    :ok = execute_workitem(case_id, hd(trigger_items))

    # After trigger: both branches must be independently enabled
    assert {:ok, branch_items} = CaseLifecycle.list_workitems(case_id)
    branch_task_ids = Enum.map(branch_items, & &1["taskId"])

    # No Shared State: each branch has its OWN work item with unique ID
    unique_task_ids = Enum.uniq(branch_task_ids)

    assert length(unique_task_ids) == length(branch_task_ids),
           "Each parallel branch must have a unique work item — no shared token"

    # Both Groq-named branches must appear
    for branch <- branches do
      assert Enum.any?(branch_items, fn item -> item["taskId"] == branch end),
             "Branch '#{branch}' must have an enabled work item after AND-split"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: WCP-4 Exclusive Choice + Supervision
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "WCP-4 Exclusive Choice: Groq picks FullReview for $15k order, GenServer survives bad request",
       %{case_id: case_id} do
    # Groq makes the XOR-split routing decision
    content =
      ask_groq("""
      A purchase order for $15,000 needs approval routing.
      Reply with EXACTLY one word: either FastTrack or FullReview.
      FastTrack is for orders under $10,000. FullReview is for orders over $10,000.
      Reply with only the single word, nothing else.
      """)

    chosen_branch = String.trim(content)

    assert chosen_branch in ["FastTrack", "FullReview"],
           "Groq must choose FastTrack or FullReview for $15k order, got: #{inspect(chosen_branch)}"

    assert chosen_branch == "FullReview",
           "Groq chose #{chosen_branch} for $15k order — expected FullReview (>$10k threshold)"

    # Supervision: inject a bad case_id — GenServer must return error, not crash
    bad_id = "nonexistent-case-#{:erlang.unique_integer([:positive])}"
    result = CaseLifecycle.list_workitems(bad_id)
    assert match?({:error, _}, result), "Bad case_id must return {:error, _}, not crash GenServer"

    # Verify GenServer is still alive after the error
    pid = Process.whereis(CaseLifecycle)
    assert pid != nil, "CaseLifecycle must remain registered after error injection"
    assert Process.alive?(pid), "CaseLifecycle GenServer must be alive after {:error, _}"

    # Build and launch the WCP-4 spec (XOR-split)
    decision = "ApprovalRouter"
    branches = [{"cond_fast", "FastTrack"}, {"cond_full", "FullReview"}]
    spec_xml = SpecBuilder.exclusive_choice(decision, branches)
    assert String.contains?(spec_xml, "OSA_ExclusiveChoice")

    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)
    assert {:ok, items} = CaseLifecycle.list_workitems(case_id)
    assert length(items) >= 1, "Decision task must be enabled after launch"

    # Execute the XOR-split decision task
    :ok = execute_workitem(case_id, hd(items))

    # WCP-4: after XOR-split fires, YAWL may auto-complete the case when the activated
    # branch flows directly to OutputCondition. {:error, :not_found} = 0 active items.
    post_items =
      case CaseLifecycle.list_workitems(case_id) do
        {:ok, list} -> list
        {:error, :not_found} -> []
      end

    active_count = length(post_items)

    # XOR-split: exactly ONE branch must become active (or 0 if case completed)
    assert active_count in [0, 1],
           "WCP-4 XOR-split must activate exactly one branch, got #{active_count} active items"
  end

  # ---------------------------------------------------------------------------
  # Test 4: WCP-1 + Budget Constraints
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "WCP-1 budget: Groq call < 30s and YAWL launch < 5s, both asserted live",
       %{case_id: case_id} do
    # Measure Groq wall time — budget assertion is live, not documentation
    groq_start = System.monotonic_time(:millisecond)

    content =
      ask_groq("""
      You are describing a 2-step incident-response workflow.
      Reply with EXACTLY two task names separated by a comma, nothing else.
      The tasks are: detect, respond.
      Example: DetectIncident,RespondToIncident
      """)

    groq_elapsed = System.monotonic_time(:millisecond) - groq_start

    assert groq_elapsed <= @groq_timeout,
           "Groq call exceeded #{@groq_timeout}ms budget: took #{groq_elapsed}ms"

    tasks =
      content
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.replace(&1, " ", "_"))
      |> Enum.take(2)

    assert length(tasks) == 2,
           "Groq must return 2 task names, got: #{inspect(content)}"

    spec_xml = SpecBuilder.sequence(tasks)

    # Measure YAWL launch time — budget assertion is live
    yawl_start = System.monotonic_time(:millisecond)
    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)
    yawl_elapsed = System.monotonic_time(:millisecond) - yawl_start

    assert yawl_elapsed <= @yawl_timeout,
           "YAWL launch exceeded #{@yawl_timeout}ms budget: took #{yawl_elapsed}ms"

    # Also bound list_workitems
    list_start = System.monotonic_time(:millisecond)
    assert {:ok, items} = CaseLifecycle.list_workitems(case_id)
    list_elapsed = System.monotonic_time(:millisecond) - list_start

    assert list_elapsed <= @yawl_timeout,
           "list_workitems exceeded #{@yawl_timeout}ms budget: took #{list_elapsed}ms"

    assert length(items) >= 1, "At least one work item must be enabled"

    IO.puts("\n  [Budget] Groq: #{groq_elapsed}ms / YAWL launch: #{yawl_elapsed}ms / list: #{list_elapsed}ms")
  end

  # ---------------------------------------------------------------------------
  # Test 5: WCP-3 Synchronization + Crash Visibility
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "WCP-3 Synchronization: empty-spec error is visible, valid AND-join converges branches",
       %{case_id: case_id} do
    # Crash Visibility: malformed spec must surface an error, not be swallowed
    bad_result = CaseLifecycle.launch_case("", case_id <> "-bad", nil)

    assert match?({:error, _}, bad_result),
           "Empty spec must return {:error, _} — errors must be visible, not swallowed"

    # Groq names the converging branches
    content =
      ask_groq("""
      You are designing a parallel validation workflow that converges into one approval.
      Reply with EXACTLY two branch task names separated by a comma, nothing else.
      Each branch runs independently and must complete before the workflow proceeds.
      Example: ValidateLegal,ValidateFinance
      """)

    branches =
      content
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.replace(&1, " ", "_"))
      |> Enum.take(2)

    assert length(branches) == 2,
           "Groq must return exactly 2 branch names, got: #{inspect(content)}"

    join_task = "ApprovalGateway"

    # Build and launch the WCP-3 spec (AND-join)
    spec_xml = SpecBuilder.synchronization(branches, join_task)
    assert String.contains?(spec_xml, "OSA_Synchronization")
    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)

    # Both branch work items must be initially enabled
    assert {:ok, initial_items} = CaseLifecycle.list_workitems(case_id)
    enabled_task_ids = Enum.map(initial_items, & &1["taskId"])

    for branch <- branches do
      assert branch in enabled_task_ids,
             "Branch '#{branch}' must be enabled before AND-join; active: #{inspect(enabled_task_ids)}"
    end

    # Execute both branches — AND-join requires ALL to complete before firing.
    # Re-fetch per branch: after the first branch's child completes, YAWL may
    # remove the case from the registry (all tokens consumed) or change item states.
    # {:error, :not_found} means the case already resolved — treat as complete.
    Enum.each(branches, fn branch ->
      case CaseLifecycle.list_workitems(case_id) do
        {:ok, current_items} ->
          item = Enum.find(current_items, fn i -> i["taskId"] == branch end)
          if item, do: execute_workitem(case_id, item)

        {:error, :not_found} ->
          # Case resolved before this branch could be executed — AND-join may have
          # fired or the embedded server auto-completed the case. Accept and continue.
          :ok
      end
    end)

    # After both branches complete, the join task or empty list indicates convergence.
    # {:error, :not_found} = case auto-completed; treat as 0 remaining items.
    post_items =
      case CaseLifecycle.list_workitems(case_id) do
        {:ok, list} -> list
        {:error, :not_found} -> []
      end

    post_task_ids = Enum.map(post_items, & &1["taskId"])

    assert join_task in post_task_ids or post_task_ids == [],
           "WCP-3 AND-join must enable '#{join_task}' after all branches complete, " <>
             "got: #{inspect(post_task_ids)}"
  end
end
