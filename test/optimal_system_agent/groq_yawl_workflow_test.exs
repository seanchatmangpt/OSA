defmodule OptimalSystemAgent.GroqYawlWorkflowTest do
  @moduledoc """
  Chicago TDD: Real Groq API calls driving real YAWL embedded server workflows.

  Joe Armstrong rules — NO TOLERANCE for missing prerequisites:
    - If GROQ_API_KEY is absent:     flunk/1 (not skip)
    - If YAWL server unreachable:    flunk/1 (not skip)

  Every test hits the REAL Groq API and the REAL embedded YAWL server.

  Run:
    GROQ_API_KEY=<key> mix test test/optimal_system_agent/groq_yawl_workflow_test.exs \\
      --include integration

  Prerequisites:
    1. GROQ_API_KEY env var set (or in Application config)
    2. YAWL embedded server running at :yawl_url (default http://localhost:8080)
       Start: java -jar yawl-embedded-server.jar
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias OptimalSystemAgent.Providers.OpenAICompatProvider
  alias OptimalSystemAgent.Yawl.CaseLifecycle
  alias OptimalSystemAgent.Yawl.SpecBuilder

  @groq_model "openai/gpt-oss-20b"
  @groq_opts [model: @groq_model, temperature: 0.0, receive_timeout: 30_000]

  # ---------------------------------------------------------------------------
  # Setup — crash loudly on missing prerequisites (Armstrong: let it crash)
  # ---------------------------------------------------------------------------

  setup do
    # Two-layer key check (per groq_live_test.exs pattern)
    api_key =
      Application.get_env(:optimal_system_agent, :groq_api_key) ||
        System.get_env("GROQ_API_KEY")

    if is_nil(api_key) or api_key == "" do
      flunk("""
      GROQ_API_KEY is not configured.
      These tests make real Groq HTTP calls — no mocks.
      Set it before running:

        export GROQ_API_KEY=gsk_...
        mix test test/optimal_system_agent/groq_yawl_workflow_test.exs --include integration
      """)
    end

    Application.put_env(:optimal_system_agent, :groq_api_key, api_key)

    # Ensure CaseLifecycle GenServer is running
    case Process.whereis(CaseLifecycle) do
      nil -> start_supervised({CaseLifecycle, []})
      _pid -> :ok
    end

    # Verify YAWL embedded server is up — crash visibly if not
    yawl_url = Application.get_env(:optimal_system_agent, :yawl_url, "http://localhost:8080")
    health_url = yawl_url <> "/health.jsp"

    case Req.get(health_url, receive_timeout: 2_000) do
      {:ok, %{status: s}} when s in 200..299 ->
        :ok

      {:ok, %{status: s}} ->
        flunk("YAWL embedded server at #{health_url} returned HTTP #{s}. Is the server healthy?")

      {:error, reason} ->
        flunk("""
        YAWL embedded server unreachable at #{health_url}.
        Error: #{inspect(reason)}
        Start it with: java -jar yawl-embedded-server.jar
        """)
    end

    case_id = "groq-yawl-#{:erlang.unique_integer([:positive])}"

    on_exit(fn ->
      _result = CaseLifecycle.cancel_case(case_id)
    end)

    {:ok, case_id: case_id}
  end

  # ---------------------------------------------------------------------------
  # Test 1 — Groq recommends WCP1 for a sequential process
  # ---------------------------------------------------------------------------

  @tag timeout: 45_000
  test "Groq recommends WCP1 for a 3-step sequential order process" do
    messages = [
      %{
        role: "user",
        content:
          "What YAWL workflow control-flow pattern should I use for a " <>
            "3-step sequential order process (receive order, process payment, ship item)? " <>
            "Reply with ONLY one of: WCP1, WCP2, or WCP4. No other text."
      }
    ]

    assert {:ok, %{content: content}} = OpenAICompatProvider.chat(:groq, messages, @groq_opts)

    assert String.contains?(content, "WCP1"),
           "Expected Groq to recommend WCP1 for a sequential process, got: #{inspect(content)}"
  end

  # ---------------------------------------------------------------------------
  # Test 2 — Groq generates JSON steps, spec is built and case is launched
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "Groq generates 3-step approval workflow JSON, then launches WCP-1 case",
       %{case_id: case_id} do
    # Ask Groq to produce structured JSON describing workflow steps
    messages = [
      %{role: "system", content: "You are a workflow designer. Respond ONLY with valid JSON. No markdown, no prose."},
      %{
        role: "user",
        content:
          ~s(Describe a 3-step document approval workflow as JSON: ) <>
            ~s({"steps": ["step_name_1", "step_name_2", "step_name_3"]}. ) <>
            ~s(Use snake_case identifiers with no spaces.)
      }
    ]

    assert {:ok, %{content: json_content}} = OpenAICompatProvider.chat(:groq, messages, @groq_opts)

    # Parse the JSON Groq returned — Let-It-Crash: if non-JSON, decode fails visibly
    assert {:ok, %{"steps" => steps}} = Jason.decode(json_content),
           "Groq must return JSON with 'steps' key, got: #{inspect(json_content)}"

    assert is_list(steps) and length(steps) == 3,
           "Expected exactly 3 steps from Groq, got: #{inspect(steps)}"

    # Build YAWL WCP-1 spec from Groq-generated step names
    spec_xml = SpecBuilder.sequence(steps)
    assert String.contains?(spec_xml, "OSA_Sequence")

    # Launch the case — must succeed against the real embedded server
    assert {:ok, body} = CaseLifecycle.launch_case(spec_xml, case_id, nil),
           "CaseLifecycle.launch_case returned error — is the YAWL server running?"

    assert body["case_id"] == case_id
  end

  # ---------------------------------------------------------------------------
  # Test 3 — Groq says YES to starting task_A, workitem is started
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "Groq says YES to starting task_A, then workitem is started in WCP-1 case",
       %{case_id: case_id} do
    # Launch a fixed WCP-1 spec — no Groq involvement in spec creation
    spec_xml = SpecBuilder.sequence(["task_A", "task_B", "task_C"])

    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)

    # Ask Groq whether to start the first enabled task
    messages = [
      %{
        role: "user",
        content:
          "Should I start work item 'task_A' in a sequential approval workflow " <>
            "where it is the first task and has just become enabled? " <>
            "Reply with ONLY: YES or NO."
      }
    ]

    assert {:ok, %{content: groq_decision}} = OpenAICompatProvider.chat(:groq, messages, @groq_opts)

    assert String.contains?(String.upcase(groq_decision), "YES"),
           "Expected Groq to say YES to starting the first enabled task, got: #{inspect(groq_decision)}"

    # List work items — must have at least one enabled
    assert {:ok, workitems} = CaseLifecycle.list_workitems(case_id)

    assert is_list(workitems) and length(workitems) > 0,
           "Expected at least one work item after launch, got: #{inspect(workitems)}"

    first_item = hd(workitems)
    wid = first_item["id"]
    assert is_binary(wid), "Expected work item id to be a string, got: #{inspect(wid)}"

    # Start the work item — action driven by Groq's YES decision
    assert {:ok, started} = CaseLifecycle.start_workitem(case_id, wid),
           "Failed to start work item #{wid} in case #{case_id}"

    assert started["status"] == "Executing",
           "Expected work item status 'Executing' after start, got: #{inspect(started["status"])}"
  end

  # ---------------------------------------------------------------------------
  # Test 4 — Groq recommends checkpointing, checkpoint returns {:ok, _}
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "Groq recommends checkpointing a running case, checkpoint returns {:ok, _}",
       %{case_id: case_id} do
    # Launch a real case so there is something to checkpoint
    spec_xml = SpecBuilder.sequence(["review", "approve", "archive"])

    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)

    # Ask Groq whether to checkpoint a running workflow for crash recovery
    messages = [
      %{
        role: "user",
        content:
          "A YAWL workflow case has just been launched and is running. " <>
            "Should I checkpoint its state to durable storage for reliability and crash recovery? " <>
            "Reply with ONLY: YES or NO."
      }
    ]

    assert {:ok, %{content: groq_opinion}} = OpenAICompatProvider.chat(:groq, messages, @groq_opts)

    assert String.contains?(String.upcase(groq_opinion), "YES"),
           "Expected Groq to recommend checkpointing a running case, got: #{inspect(groq_opinion)}"

    # Groq agreed — call checkpoint against the real server
    assert {:ok, checkpoint_body} = CaseLifecycle.checkpoint(case_id),
           "checkpoint/1 returned error for case #{case_id}"

    assert is_map(checkpoint_body),
           "Expected checkpoint response to be a map, got: #{inspect(checkpoint_body)}"
  end

  # ---------------------------------------------------------------------------
  # Test 5 — Armstrong Let-It-Crash: corrupt XML → launch returns {:error, _}
  # ---------------------------------------------------------------------------

  @tag timeout: 60_000
  test "corrupt XML makes launch_case return {:error, _} — failure is visible not swallowed",
       %{case_id: case_id} do
    # Make a real Groq call to demonstrate the chain is real (not mocked)
    messages = [
      %{
        role: "user",
        content:
          "Briefly describe a 2-step inventory restock workflow: " <>
            ~s({"steps": ["check_stock", "reorder"]}. ) <>
            "Reply with valid JSON only."
      }
    ]

    # We call Groq (real) but don't use its output — the point is the chain is real
    {:ok, %{content: _description}} = OpenAICompatProvider.chat(:groq, messages, @groq_opts)

    # Deliberately truncated XML — guaranteed parse failure on the YAWL server
    # This demonstrates Let-It-Crash: failures are returned visibly, not swallowed
    truncated_xml =
      "<?xml version=\"1.0\"?><specificationSet xmlns=\"http://www.ci"

    # launch_case MUST return {:error, _} — not :ok, not a process crash
    assert {:error, _reason} = CaseLifecycle.launch_case(truncated_xml, case_id, nil),
           "Expected {:error, _} when launching with truncated XML, but got :ok — " <>
             "the YAWL server should reject malformed specs"
  end
end
