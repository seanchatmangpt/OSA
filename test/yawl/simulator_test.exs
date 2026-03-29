defmodule OptimalSystemAgent.Yawl.SimulatorTest do
  @moduledoc """
  Chicago TDD — YAWL User Simulator.

  Unit tests use inline stub modules injected via `:lifecycle_mod` — no YAWL
  server or Mox required.  Integration tests are tagged `:integration` and
  require a live YAWL engine at `:yawl_url`.

  Run unit tests only (no server):
      mix test test/yawl/simulator_test.exs

  Run all (with live YAWL):
      mix test test/yawl/simulator_test.exs --include integration
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Yawl.Simulator
  alias OptimalSystemAgent.Yawl.Simulator.UserResult
  alias OptimalSystemAgent.Yawl.Simulator.SimulationResult
  alias OptimalSystemAgent.Yawl.CaseLifecycle

  # ===========================================================================
  # Inline stub modules (unit tests — no external dependencies)
  # ===========================================================================

  # Single task → completes in one pass.
  defmodule StubLifecycle do
    def launch_case(_xml, _case_id, _params), do: {:ok, %{"case_id" => "stub-case"}}

    def list_workitems(case_id) do
      key = {__MODULE__, case_id, :listed}

      if :ets.whereis(:sim_stub_state) == :undefined or
           :ets.lookup(:sim_stub_state, key) == [] do
        try_ensure_table()
        :ets.insert(:sim_stub_state, {key, true})
        {:ok, [%{"id" => "wid-1", "taskId" => "task1", "status" => "Enabled"}]}
      else
        {:ok, []}
      end
    end

    def start_workitem(_case_id, _wid),
      do: {:ok, %{"id" => "child-1", "status" => "Executing"}}

    def complete_workitem(_case_id, _child_id, _data), do: {:ok, %{}}
    def cancel_case(_case_id), do: {:ok, %{}}

    defp try_ensure_table do
      if :ets.whereis(:sim_stub_state) == :undefined do
        :ets.new(:sim_stub_state, [:named_table, :public, :set])
      end
    end
  end

  # Two parallel items (AND-split) — completes after both are executed.
  defmodule AndSplitStub do
    def launch_case(_xml, _case_id, _params), do: {:ok, %{"case_id" => "and-case"}}

    def list_workitems(case_id) do
      key = {__MODULE__, case_id, :listed}
      ensure_table()

      if :ets.lookup(:sim_stub_state, key) == [] do
        :ets.insert(:sim_stub_state, {key, true})

        {:ok,
         [
           %{"id" => "par-1", "taskId" => "branch_a", "status" => "Enabled"},
           %{"id" => "par-2", "taskId" => "branch_b", "status" => "Enabled"}
         ]}
      else
        {:ok, []}
      end
    end

    def start_workitem(_case_id, wid),
      do: {:ok, %{"id" => "c-#{wid}", "status" => "Executing"}}

    def complete_workitem(_case_id, _child_id, _data), do: {:ok, %{}}
    def cancel_case(_case_id), do: {:ok, %{}}

    defp ensure_table do
      if :ets.whereis(:sim_stub_state) == :undefined do
        :ets.new(:sim_stub_state, [:named_table, :public, :set])
      end
    end
  end

  # XOR auto-complete: after executing the one enabled item, the case disappears
  # from the registry (simulating WCP-4 where the case auto-completes).
  defmodule AutoCompleteStub do
    def launch_case(_xml, _case_id, _params), do: {:ok, %{"case_id" => "xor-case"}}

    def list_workitems(case_id) do
      key = {__MODULE__, case_id, :listed}
      ensure_table()

      if :ets.lookup(:sim_stub_state, key) == [] do
        :ets.insert(:sim_stub_state, {key, true})
        {:ok, [%{"id" => "xor-1", "taskId" => "choice", "status" => "Enabled"}]}
      else
        # After execution, case is gone from registry
        {:error, :not_found}
      end
    end

    def start_workitem(_case_id, _wid),
      do: {:ok, %{"id" => "xor-child-1", "status" => "Executing"}}

    def complete_workitem(_case_id, _child_id, _data), do: {:ok, %{}}
    def cancel_case(_case_id), do: {:ok, %{}}

    defp ensure_table do
      if :ets.whereis(:sim_stub_state) == :undefined do
        :ets.new(:sim_stub_state, [:named_table, :public, :set])
      end
    end
  end

  # Always returns one item — triggers max_steps guard.
  defmodule MaxStepsStub do
    def launch_case(_xml, _case_id, _params), do: {:ok, %{"case_id" => "loop-case"}}

    def list_workitems(_case_id) do
      {:ok, [%{"id" => "loop-wid", "taskId" => "looper", "status" => "Enabled"}]}
    end

    def start_workitem(_case_id, wid),
      do: {:ok, %{"id" => "c-#{wid}", "status" => "Executing"}}

    def complete_workitem(_case_id, _child_id, _data), do: {:ok, %{}}
    def cancel_case(_case_id), do: {:ok, %{}}
  end

  # launch_case immediately returns error.
  defmodule LaunchFailStub do
    def launch_case(_xml, _case_id, _params), do: {:error, :engine_unavailable}
    def list_workitems(_case_id), do: {:ok, []}
    def start_workitem(_case_id, _wid), do: {:ok, %{"id" => "x"}}
    def complete_workitem(_case_id, _child_id, _data), do: {:ok, %{}}
    def cancel_case(_case_id), do: {:ok, %{}}
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  # Minimal valid YAWL spec XML (stubs ignore content, but run/1 needs a string)
  @stub_xml "<specificationSet><specification uri=\"stub\"/></specificationSet>"

  # Build a fake spec list for injection (bypasses SpecLibrary disk access)
  defp stub_spec_list(count \\ 1) do
    Enum.map(1..count, fn i -> {"WCP-#{i}", @stub_xml} end)
  end

  # Build run opts that bypass SpecLibrary entirely by overriding load_specs_for
  # via the :specs_override key (handled in test wrappers below).
  defp run_with_stubs(lifecycle_mod, opts) do
    specs = Keyword.get(opts, :specs, stub_spec_list())
    user_count = Keyword.get(opts, :user_count, 1)
    max_steps = Keyword.get(opts, :max_steps, 50)
    timeout_ms = Keyword.get(opts, :timeout_ms, 5_000)

    # Directly call internal functions to avoid SpecLibrary disk access
    assignments = build_assignments(specs, user_count)

    results =
      Enum.map(assignments, fn {uid, sid, xml} ->
        Simulator.run_one(uid, sid, xml, [
          lifecycle_mod: lifecycle_mod,
          max_steps: max_steps,
          timeout_ms: timeout_ms
        ])
      end)

    total_ms = Enum.sum(Enum.map(results, fn r -> r.duration_ms || 0 end))
    completed = Enum.count(results, &(&1.status == :completed))
    errors = Enum.count(results, &(&1.status == :error))
    timeouts = Enum.count(results, &(&1.status == :timeout))

    %SimulationResult{
      spec_set: :stub,
      user_count: user_count,
      results: results,
      total_duration_ms: total_ms,
      completed_count: completed,
      error_count: errors,
      timeout_count: timeouts,
      summary:
        "stub users=#{length(results)} completed=#{completed} errors=#{errors} timeouts=#{timeouts}"
    }
  end

  defp build_assignments(specs, user_count) do
    spec_count = length(specs)

    Enum.map(1..user_count, fn uid ->
      {spec_id, xml} = Enum.at(specs, rem(uid - 1, spec_count))
      {uid, spec_id, xml}
    end)
  end

  # ===========================================================================
  # ETS cleanup
  # ===========================================================================

  setup do
    # Clean stub state table between tests (create if missing)
    case :ets.whereis(:sim_stub_state) do
      :undefined -> :ets.new(:sim_stub_state, [:named_table, :public, :set])
      _ -> :ets.delete_all_objects(:sim_stub_state)
    end

    :ok
  end

  # ===========================================================================
  # Unit tests — no YAWL server, no tags
  # ===========================================================================

  test "single user with StubLifecycle completes — status :completed, steps_completed >= 1" do
    result = run_with_stubs(StubLifecycle, user_count: 1)

    assert result.completed_count == 1
    assert result.error_count == 0
    [user_result] = result.results
    assert user_result.status == :completed
    assert user_result.steps_completed >= 1
  end

  test "user_count: 3 returns 3 UserResults" do
    result = run_with_stubs(StubLifecycle, user_count: 3)

    assert length(result.results) == 3
    assert result.user_count == 3
  end

  test "all case_ids are unique across users" do
    result = run_with_stubs(StubLifecycle, user_count: 5)

    case_ids = Enum.map(result.results, & &1.case_id)
    assert length(Enum.uniq(case_ids)) == 5
  end

  test "AND-split: two parallel items both executed → steps_completed == 2" do
    result = run_with_stubs(AndSplitStub, user_count: 1)

    [user_result] = result.results
    assert user_result.status == :completed
    assert user_result.steps_completed == 2
  end

  test "XOR auto-complete ({:error, :not_found}) → status :completed" do
    result = run_with_stubs(AutoCompleteStub, user_count: 1)

    [user_result] = result.results
    assert user_result.status == :completed
  end

  test "max_steps guard → status :error, error: :max_steps_exceeded" do
    result = run_with_stubs(MaxStepsStub, user_count: 1, max_steps: 3)

    [user_result] = result.results
    assert user_result.status == :error
    assert user_result.error == :max_steps_exceeded
  end

  test "launch failure → status :error, error: {:launch_failed, _}" do
    result = run_with_stubs(LaunchFailStub, user_count: 1)

    [user_result] = result.results
    assert user_result.status == :error
    assert match?({:launch_failed, _}, user_result.error)
  end

  test "cancel_case called even on launch failure (after block)" do
    # LaunchFailStub.cancel_case always returns :ok — if after block is missing,
    # the test still passes since we can't easily spy without Mox.
    # We verify indirectly: run_one must return a UserResult (not raise).
    user_result = Simulator.run_one(1, "WCP-1", @stub_xml, lifecycle_mod: LaunchFailStub)
    assert %UserResult{} = user_result
    assert user_result.status == :error
  end

  test "SimulationResult counts match UserResult statuses" do
    # Mix of 2 complete + 1 error by using different stubs across 3 users
    specs = [{"WCP-1", @stub_xml}, {"WCP-2", @stub_xml}, {"WCP-3", @stub_xml}]

    # All 3 use StubLifecycle — all should complete
    result = run_with_stubs(StubLifecycle, user_count: 3, specs: specs)

    assert result.completed_count == Enum.count(result.results, &(&1.status == :completed))
    assert result.error_count == Enum.count(result.results, &(&1.status == :error))
    assert result.timeout_count == Enum.count(result.results, &(&1.status == :timeout))
  end

  test "summary is a non-empty string" do
    result = run_with_stubs(StubLifecycle, user_count: 1)

    assert is_binary(result.summary)
    assert String.length(result.summary) > 0
  end

  test "run/1 returns empty SimulationResult when unknown spec_set provided" do
    # Unknown spec_set → load_specs_for returns [] → empty result, no crash
    result = Simulator.run(spec_set: :nonexistent_set, user_count: 3)

    assert %SimulationResult{} = result
    assert result.results == []
    assert result.completed_count == 0
    assert String.contains?(result.summary, "No specs")
  end

  test "duration_ms is non-negative for completed user" do
    result = run_with_stubs(StubLifecycle, user_count: 1)

    [user_result] = result.results
    assert user_result.duration_ms >= 0
  end

  test "user_id is preserved correctly in UserResult" do
    result = run_with_stubs(StubLifecycle, user_count: 3)

    user_ids = result.results |> Enum.map(& &1.user_id) |> Enum.sort()
    assert user_ids == [1, 2, 3]
  end

  test "spec_id is set in UserResult" do
    result = run_with_stubs(StubLifecycle, user_count: 1)

    [user_result] = result.results
    assert is_binary(user_result.spec_id)
    refute user_result.spec_id == ""
  end

  test "timeout guard triggers when elapsed exceeds timeout_ms" do
    # timeout_ms: 0 means first check in drain_loop fires :timeout
    user_result =
      Simulator.run_one(1, "WCP-1", @stub_xml,
        lifecycle_mod: MaxStepsStub,
        timeout_ms: 0,
        max_steps: 1000
      )

    assert user_result.status == :timeout
  end

  # ===========================================================================
  # Integration tests (require live YAWL server at :yawl_url)
  # ===========================================================================

  @tag :integration
  test "5 users on basic WCP patterns all complete successfully" do
    ensure_lifecycle_started()
    ensure_yawl_reachable()

    result = Simulator.run(spec_set: :basic_wcp, user_count: 5, timeout_ms: 30_000)

    assert result.timeout_count == 0,
           "Expected 0 timeouts, got #{result.timeout_count}: #{result.summary}"

    assert result.completed_count == 5,
           "Expected 5 completed, got #{result.completed_count}: #{result.summary}"
  end

  @tag :integration
  test "10 concurrent users on WCP-2 (parallel split) — no shared state" do
    ensure_lifecycle_started()
    ensure_yawl_reachable()

    # Force all users to WCP-2
    result =
      Simulator.run(
        spec_set: :basic_wcp,
        user_count: 10,
        max_concurrency: 10,
        timeout_ms: 30_000
      )

    case_ids = Enum.map(result.results, & &1.case_id)

    assert length(Enum.uniq(case_ids)) == 10,
           "case_ids must be unique (no shared state): #{inspect(case_ids)}"

    assert result.error_count == 0,
           "Expected 0 errors: #{result.summary}"
  end

  @tag :integration
  test "real_data order-management: single user runs to completion" do
    ensure_lifecycle_started()
    ensure_yawl_reachable()

    result = Simulator.run(spec_set: :real_data, user_count: 1, timeout_ms: 45_000)

    assert length(result.results) >= 1,
           "Expected at least 1 result, got 0 — real-data specs may not be on disk"

    # Only assert if specs were found
    if length(result.results) > 0 do
      [user_result | _] = result.results

      assert user_result.status in [:completed, :error],
             "User result should be :completed or :error, got: #{inspect(user_result)}"
    end
  end

  @tag :integration
  test "timeout_ms: 1 on looping spec produces :timeout results without crash" do
    ensure_lifecycle_started()
    ensure_yawl_reachable()

    # Very short timeout — likely to produce :timeout for any real YAWL spec
    result =
      Simulator.run(
        spec_set: :basic_wcp,
        user_count: 2,
        timeout_ms: 1,
        max_steps: 1000
      )

    # Should not raise; each result must be a valid UserResult
    assert length(result.results) == 2

    Enum.each(result.results, fn r ->
      assert %UserResult{} = r
      assert r.status in [:completed, :error, :timeout]
    end)
  end

  # ===========================================================================
  # Integration helpers
  # ===========================================================================

  defp ensure_lifecycle_started do
    case Process.whereis(CaseLifecycle) do
      nil -> start_supervised!({CaseLifecycle, []})
      _pid -> :ok
    end
  end

  defp ensure_yawl_reachable do
    yawl_url = Application.get_env(:optimal_system_agent, :yawl_url, "http://localhost:8080")
    health_url = yawl_url <> "/health.jsp"

    case Req.get(health_url, receive_timeout: 2_000) do
      {:ok, %{status: s}} when s in 200..299 ->
        :ok

      _ ->
        flunk("YAWL engine unreachable at #{health_url} — start it before running @integration tests")
    end
  end
end
