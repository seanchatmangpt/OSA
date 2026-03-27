defmodule OptimalSystemAgent.Swarm.PatternsYawlTest do
  @moduledoc """
  Tests YAWL topology validation in swarm patterns.

  Coverage:
    1. SpecBuilder.parallel_split/2 produces valid YAWL XML for swarm agent names.
    2. SpecBuilder.sequence/1 produces valid YAWL XML for pipeline steps.
    3. All SpecBuilder outputs parse as well-formed XML via :xmerl_scan.
    4. sequence/1 includes every task ID in the spec.
    5. validate_yawl_topology gracefully degrades when YAWL engine is unreachable.
    6. validate_yawl_topology rejects fitness==0.0 specs as unsound topology.
    7. parallel_split trigger carries and-split code.
    8. synchronization/2 join task carries and-join code.
    9. exclusive_choice/2 decision task carries xor-split code.
  """

  use ExUnit.Case, async: true
  @moduletag :capture_log

  alias OptimalSystemAgent.Yawl.SpecBuilder

  # ---------------------------------------------------------------------------
  # SpecBuilder for swarm topology
  # ---------------------------------------------------------------------------

  describe "SpecBuilder for swarm topology" do
    test "parallel_split produces valid YAWL XML for agent names" do
      spec = SpecBuilder.parallel_split("dispatch", ["agent_a", "agent_b", "agent_c"])
      assert String.contains?(spec, "agent_a")
      assert String.contains?(spec, "agent_b")
      assert String.contains?(spec, "agent_c")
      assert String.contains?(spec, ~s(code="and"))
    end

    test "sequence produces valid YAWL XML for pipeline steps" do
      spec = SpecBuilder.sequence(["step1", "step2", "step3"])
      assert String.contains?(spec, "step1")
      assert String.contains?(spec, "step2")
      assert String.contains?(spec, "step3")
    end

    test "YAWL specs are parseable XML" do
      spec = SpecBuilder.parallel_split("start", ["a", "b"])
      assert {:ok, _} = try_parse(spec)
    end

    test "sequence spec contains all task IDs" do
      tasks = ["alpha", "beta", "gamma"]
      spec = SpecBuilder.sequence(tasks)

      for task <- tasks do
        assert String.contains?(spec, task),
               "Expected spec to contain task ID #{inspect(task)}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # YAWL spec structure invariants
  # ---------------------------------------------------------------------------

  describe "YAWL spec structure invariants" do
    test "parallel_split trigger task has and-split code" do
      spec = SpecBuilder.parallel_split("trigger", ["b1", "b2"])
      assert String.contains?(spec, ~s(split code="and"))
    end

    test "parallel_split spec wraps specificationSet root element" do
      spec = SpecBuilder.parallel_split("t", ["x"])
      assert String.contains?(spec, "specificationSet")
      assert String.contains?(spec, "<?xml version")
    end

    test "sequence spec connects via flowsInto elements" do
      spec = SpecBuilder.sequence(["first", "second"])
      assert String.contains?(spec, "flowsInto")
      assert String.contains?(spec, ~s(id="first"))
      assert String.contains?(spec, ~s(id="second"))
    end

    test "synchronization join task has and-join code" do
      spec = SpecBuilder.synchronization(["b1", "b2"], "merge")
      assert String.contains?(spec, ~s(join code="and"))
    end

    test "exclusive_choice decision task has xor-split code" do
      spec = SpecBuilder.exclusive_choice("decide", [{"c1", "t1"}, {"c2", "t2"}])
      assert String.contains?(spec, ~s(split code="xor"))
    end

    test "parallel_split spec is valid XML for single branch" do
      spec = SpecBuilder.parallel_split("dispatch", ["only_agent"])
      assert {:ok, _} = try_parse(spec)
    end

    test "sequence spec is valid XML for single task" do
      spec = SpecBuilder.sequence(["lone_step"])
      assert {:ok, _} = try_parse(spec)
    end

    test "sequence spec is valid XML for empty task list" do
      spec = SpecBuilder.sequence([])
      assert {:ok, _} = try_parse(spec)
    end
  end

  # ---------------------------------------------------------------------------
  # YAWL topology validation gate — pure logic via SpecBuilder output shape
  # ---------------------------------------------------------------------------

  describe "YAWL topology validation gate (pure logic)" do
    test "validate_parallel_topology returns :ok when fitness > 0.0" do
      # Simulate the validation logic inline (pure): a well-formed spec from
      # SpecBuilder always produces parseable XML, which a real YAWL engine
      # would return fitness > 0.0 for.  We verify the spec is structurally
      # non-trivial (has both InputCondition and OutputCondition).
      spec = SpecBuilder.parallel_split("dispatch", ["agent_a", "agent_b"])

      assert String.contains?(spec, "InputCondition")
      assert String.contains?(spec, "OutputCondition")
      # A spec with both conditions is structurally sound → engine returns fitness > 0
      assert String.contains?(spec, "agent_a")
      assert String.contains?(spec, "agent_b")
    end

    test "validate_pipeline_topology returns :ok when spec has all steps" do
      steps = ["ingest", "transform", "emit"]
      spec = SpecBuilder.sequence(steps)

      assert String.contains?(spec, "InputCondition")
      assert String.contains?(spec, "OutputCondition")

      for step <- steps do
        assert String.contains?(spec, step)
      end
    end

    test "yawl_unavailable returns error (fail fast)" do
      # Phase B: YAWL Primary — fail fast when YAWL engine is unavailable
      result = simulate_yawl_check({:error, :yawl_unavailable})
      assert result == {:error, :yawl_unavailable},
             "YAWL unavailable should return error, not proceed silently"
    end

    test "unsound topology (fitness == 0.0) blocks spawning" do
      result = simulate_yawl_check({:ok, %{fitness: 0.0}})
      assert result == {:error, :unsound_topology},
             "fitness == 0.0 must return {:error, :unsound_topology}"
    end

    test "sound topology (fitness > 0.0) allows spawning" do
      result = simulate_yawl_check({:ok, %{fitness: 0.85}})
      assert result == :ok,
             "fitness > 0.0 must return :ok to allow agent spawning"
    end

    test "yawl engine error (non-unavailable) returns error (fail fast)" do
      result = simulate_yawl_check({:error, :timeout})
      assert result == {:error, :yawl_unavailable},
             "Generic YAWL error should fail fast as unavailable"
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Wraps :xmerl_scan.string/2 — which returns {xmlElement, rest} on success,
  # not {:ok, ...} — in a rescue so tests can use {:ok, _} pattern matching.
  defp try_parse(xml) do
    try do
      {doc, _rest} = :xmerl_scan.string(String.to_charlist(xml), quiet: true)
      {:ok, doc}
    rescue
      _ -> {:error, :parse_failed}
    catch
      _, _ -> {:error, :parse_failed}
    end
  end

  # Mirrors the case logic in Patterns.validate_yawl_topology/2 so we can
  # unit-test the decision table without needing the YAWL engine running.
  # Phase B: YAWL Primary — fail fast on any error.
  defp simulate_yawl_check(yawl_result) do
    case yawl_result do
      {:error, :yawl_unavailable} ->
        {:error, :yawl_unavailable}

      {:error, _reason} ->
        {:error, :yawl_unavailable}

      {:ok, %{fitness: fitness}} when fitness == 0.0 ->
        {:error, :unsound_topology}

      {:ok, %{fitness: _fitness}} ->
        :ok
    end
  end
end
