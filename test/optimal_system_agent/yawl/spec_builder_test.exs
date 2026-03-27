defmodule OptimalSystemAgent.Yawl.SpecBuilderTest do
  use ExUnit.Case, async: true
  alias OptimalSystemAgent.Yawl.SpecBuilder

  describe "sequence/1" do
    test "produces XML containing each task id" do
      xml = SpecBuilder.sequence(["step_a", "step_b", "step_c"])
      assert String.contains?(xml, ~s(id="step_a"))
      assert String.contains?(xml, ~s(id="step_b"))
      assert String.contains?(xml, ~s(id="step_c"))
    end

    test "produces valid XML parseable by :xmerl_scan" do
      xml = SpecBuilder.sequence(["a", "b"])
      assert {:ok, _} = try_parse(xml)
    end

    test "contains specificationSet root element" do
      xml = SpecBuilder.sequence(["a"])
      assert String.contains?(xml, "specificationSet")
    end
  end

  describe "parallel_split/2" do
    test "produces AND-split for trigger task" do
      xml = SpecBuilder.parallel_split("start", ["b1", "b2"])
      assert String.contains?(xml, ~s(split code="and"))
    end

    test "contains all branch task ids" do
      xml = SpecBuilder.parallel_split("start", ["branch_a", "branch_b"])
      assert String.contains?(xml, ~s(id="branch_a"))
      assert String.contains?(xml, ~s(id="branch_b"))
    end
  end

  describe "synchronization/2" do
    test "produces AND-join for sync task" do
      xml = SpecBuilder.synchronization(["b1", "b2"], "join")
      assert String.contains?(xml, ~s(join code="and"))
    end
  end

  describe "exclusive_choice/2" do
    test "produces XOR-split for decision task" do
      xml = SpecBuilder.exclusive_choice("decide", [{"cond_a", "task_a"}, {"cond_b", "task_b"}])
      assert String.contains?(xml, ~s(split code="xor"))
    end
  end

  defp try_parse(xml) do
    try do
      charlist = String.to_charlist(xml)
      {doc, _} = :xmerl_scan.string(charlist)
      {:ok, doc}
    rescue
      _ -> {:error, :parse_failed}
    catch
      _, _ -> {:error, :parse_failed}
    end
  end
end
