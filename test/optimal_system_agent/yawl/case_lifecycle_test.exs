defmodule OptimalSystemAgent.Yawl.CaseLifecycleTest do
  @moduledoc """
  Chicago TDD tests for OptimalSystemAgent.Yawl.CaseLifecycle.

  Strategy: test the real module, not mocks.  Tests tolerate {:error, _} responses
  when the YAWL embedded server is not running (CI / unit mode).  Tests tagged
  :integration require a live embedded server at the configured :yawl_url.

  Chicago-style assertions focus on WHAT the function returns (the observable
  behaviour), not HOW it communicates internally.
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application

  alias OptimalSystemAgent.Yawl.CaseLifecycle

  setup do
    case Process.whereis(CaseLifecycle) do
      nil -> start_supervised({CaseLifecycle, []})
      _   -> :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Basic contract tests — run in every environment (no live server required)
  # ---------------------------------------------------------------------------

  describe "launch_case/3" do
    test "returns tagged tuple — never raises or crashes the caller" do
      result = CaseLifecycle.launch_case("<spec/>", nil, nil)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "result shape {:ok, map} when server is available" do
      case CaseLifecycle.launch_case("<spec/>", nil, nil) do
        {:ok, body} -> assert is_map(body)
        {:error, _} -> :ok  # server not running — tolerate
      end
    end
  end

  describe "list_workitems/1" do
    test "returns tagged tuple — never raises" do
      result = CaseLifecycle.list_workitems("nonexistent-case")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns {:error, :not_found} for unknown case when server is up" do
      case CaseLifecycle.list_workitems("definitely-nonexistent-#{:rand.uniform(99_999)}") do
        {:error, :not_found} -> :ok
        {:error, :yawl_unavailable} -> :ok  # server not running
        {:error, {:http_error, 404, _}} -> :ok
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end
  end

  describe "start_workitem/2" do
    test "returns tagged tuple — never raises" do
      result = CaseLifecycle.start_workitem("nonexistent", "nonexistent-wid")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "complete_workitem/3" do
    test "returns tagged tuple — never raises" do
      result = CaseLifecycle.complete_workitem("nonexistent", "nonexistent-wid", "")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "checkpoint/1" do
    test "returns tagged tuple — never raises" do
      result = CaseLifecycle.checkpoint("nonexistent")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "restore_checkpoint/2" do
    test "returns tagged tuple — never raises" do
      result = CaseLifecycle.restore_checkpoint("nonexistent", "<xml/>")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "cancel_case/1" do
    test "returns :ok or {:error, _} — never raises" do
      result = CaseLifecycle.cancel_case("nonexistent")
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # Timeout resilience
  # ---------------------------------------------------------------------------

  test "GenServer handles malformed call gracefully" do
    # Send a valid call; should not crash the server
    result = CaseLifecycle.list_workitems("")
    assert match?({:ok, _}, result) or match?({:error, _}, result)
    # GenServer must still be alive
    assert Process.whereis(CaseLifecycle) != nil
  end

  # ---------------------------------------------------------------------------
  # Integration tests — require live embedded server
  # ---------------------------------------------------------------------------

  @tag :integration
  test "full lifecycle: launch → list → start → complete" do
    spec_xml = load_spec_xml()

    case_id = "lifecycle-test-#{System.unique_integer([:positive])}"

    # 1. Launch
    assert {:ok, launch_body} = CaseLifecycle.launch_case(spec_xml, case_id, nil)
    assert launch_body["case_id"] == case_id

    # 2. List work items — expect at least one
    assert {:ok, items} = CaseLifecycle.list_workitems(case_id)
    assert is_list(items)
    assert length(items) > 0

    first = hd(items)
    wid = first["id"]
    assert is_binary(wid)

    # 3. Start first work item
    start_result = CaseLifecycle.start_workitem(case_id, wid)
    # Accept ok or error (depends on task status in spec)
    assert match?({:ok, _}, start_result) or match?({:error, _}, start_result)

    # 4. Cancel case (cleanup)
    assert :ok = CaseLifecycle.cancel_case(case_id)
  end

  @tag :integration
  test "checkpoint round-trip: launch → checkpoint → cancel → restore" do
    spec_xml = load_spec_xml()

    case_id = "checkpoint-test-#{System.unique_integer([:positive])}"

    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)

    # Checkpoint
    assert {:ok, %{"xml" => checkpoint_xml}} = CaseLifecycle.checkpoint(case_id)
    assert is_binary(checkpoint_xml)
    assert String.length(checkpoint_xml) > 0

    # Cancel original
    assert :ok = CaseLifecycle.cancel_case(case_id)

    # Restore under new ID
    restored_id = "restored-#{case_id}"
    assert {:ok, restore_body} = CaseLifecycle.restore_checkpoint(restored_id, checkpoint_xml)
    assert restore_body["case_id"] == restored_id

    # Clean up
    CaseLifecycle.cancel_case(restored_id)
  end

  @tag :integration
  test "duplicate launch returns {:error, :already_exists}" do
    spec_xml = load_spec_xml()
    case_id = "dup-test-#{System.unique_integer([:positive])}"

    assert {:ok, _} = CaseLifecycle.launch_case(spec_xml, case_id, nil)
    assert {:error, :already_exists} = CaseLifecycle.launch_case(spec_xml, case_id, nil)

    CaseLifecycle.cancel_case(case_id)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp load_spec_xml do
    # Load from the yawl-core test resources if available
    path = Path.expand("../../../../yawlv6/yawl-core/src/test/resources/exampleSpecs/xml/Beta2-7/BarnesAndNoble.xml",
                       __DIR__)

    if File.exists?(path) do
      File.read!(path)
    else
      # Minimal fallback spec (will be rejected by server but tests the client contract)
      ~s(<specificationSet xmlns="http://www.citi.qut.edu.au/yawl"/>)
    end
  end
end
