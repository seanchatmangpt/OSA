defmodule OptimalSystemAgent.Semconv.SpanNamesTest do
  use ExUnit.Case, async: true
  alias OptimalSystemAgent.Semconv.SpanNames

  test "healing span names match schema" do
    assert SpanNames.healing_diagnosis() == "healing.diagnosis"
    assert SpanNames.healing_escalation() == "healing.escalation"
  end

  test "a2a span names match schema" do
    assert SpanNames.a2a_call() == "a2a.call"
    assert SpanNames.a2a_negotiate() == "a2a.negotiate"
    assert SpanNames.a2a_task_delegate() == "a2a.task.delegate"
  end

  test "mcp span names match schema" do
    assert SpanNames.mcp_call() == "mcp.call"
    assert SpanNames.mcp_tool_execute() == "mcp.tool_execute"
  end

  test "process mining span names match schema" do
    assert SpanNames.process_mining_discovery() == "process.mining.discovery"
    assert SpanNames.process_mining_dfg() == "process.mining.dfg"
    assert SpanNames.process_mining_conformance() == "process.mining.conformance"
  end

  test "signal span names match schema" do
    assert SpanNames.signal_classify() == "signal.classify"
    assert SpanNames.signal_encode() == "signal.encode"
  end

  test "workflow span names match schema" do
    assert SpanNames.workflow_execute() == "workflow.execute"
    assert SpanNames.workflow_milestone() == "workflow.milestone"
  end

  test "event span names match schema" do
    assert SpanNames.event_emit() == "event.emit"
  end

  test "consensus span names match schema" do
    assert SpanNames.consensus_round() == "consensus.round"
    assert SpanNames.consensus_vote() == "consensus.vote"
  end
end
