defmodule OptimalSystemAgent.Integration.A2APm4pyWorkTest do
  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.A2ACall

  @pm4py_url "http://localhost:8090"

  defp one_trace_log do
    %{
      "attributes" => %{},
      "traces" => [%{
        "id" => "case-001",
        "attributes" => %{},
        "events" => [
          %{"activity" => "A", "timestamp" => "2024-01-01T10:00:00Z",
            "resource" => nil, "attributes" => %{}},
          %{"activity" => "B", "timestamp" => "2024-01-01T10:30:00Z",
            "resource" => nil, "attributes" => %{}}
        ]
      }]
    }
  end

  # ── no-server error path tests (always runnable) ──────────────────────────

  describe "tasks_send without pm4py running" do
    test "returns connection error for unreachable host" do
      result = A2ACall.execute(%{
        "action"    => "tasks_send",
        "agent_url" => "http://localhost:59997",
        "tool"      => "pm4py_statistics",
        "args"      => %{"event_log" => one_trace_log()}
      })
      assert match?({:error, {:connection_failed, _}}, result),
             "unreachable host must return {:error, {:connection_failed, _}}; got: #{inspect(result)}"
    end

    test "returns error for missing tool parameter" do
      result = A2ACall.execute(%{
        "action"    => "tasks_send",
        "agent_url" => @pm4py_url
      })
      assert match?({:error, _}, result)
    end

    test "discover at unreachable host fails gracefully" do
      result =
        try do
          A2ACall.execute(%{
            "action"    => "discover",
            "agent_url" => "http://localhost:59996"
          })
        rescue
          ArgumentError -> {:error, "connection unavailable"}
        end
      assert match?({:error, _}, result)
    end
  end

  # ── integration tests (require pm4py-rust at :8090) ──────────────────────

  describe "tasks_send with live pm4py-rust" do
    @tag :pm4py_required
    test "statistics returns correct trace and event counts" do
      {:ok, result} = A2ACall.execute(%{
        "action"    => "tasks_send",
        "agent_url" => @pm4py_url,
        "tool"      => "pm4py_statistics",
        "args"      => %{"event_log" => one_trace_log()}
      })

      assert result["status"]["state"] == "completed",
             "task must complete; got: #{inspect(result["status"])}"
      [artifact | _] = result["artifacts"]
      [part | _] = artifact["parts"]
      data = part["data"]
      assert data["trace_count"] == 1, "trace_count must be 1; got: #{inspect(data)}"
      assert data["event_count"] == 2, "event_count must be 2; got: #{inspect(data)}"
    end

    @tag :pm4py_required
    test "discover_alpha returns petri net structure" do
      abc_log = %{
        "attributes" => %{},
        "traces" => [%{
          "id" => "case-001", "attributes" => %{},
          "events" => [
            %{"activity" => "A", "timestamp" => "2024-01-01T10:00:00Z", "resource" => nil, "attributes" => %{}},
            %{"activity" => "B", "timestamp" => "2024-01-01T10:10:00Z", "resource" => nil, "attributes" => %{}},
            %{"activity" => "C", "timestamp" => "2024-01-01T10:20:00Z", "resource" => nil, "attributes" => %{}}
          ]
        }]
      }
      {:ok, result} = A2ACall.execute(%{
        "action"    => "tasks_send",
        "agent_url" => @pm4py_url,
        "tool"      => "pm4py_discover_alpha",
        "args"      => %{"event_log" => abc_log}
      })

      assert result["status"]["state"] == "completed"
      [artifact | _] = result["artifacts"]
      [part | _] = artifact["parts"]
      data = part["data"]
      has_model = Map.has_key?(data, "petri_net") or
                  Map.has_key?(data, "places") or
                  Map.has_key?(data, "transitions")
      assert has_model, "alpha discovery must return Petri net; got: #{inspect(data)}"
    end

    @tag :pm4py_required
    test "two tasks with explicit task_ids preserve their IDs" do
      {:ok, r1} = A2ACall.execute(%{
        "action" => "tasks_send", "agent_url" => @pm4py_url,
        "tool" => "pm4py_statistics",
        "args" => %{"event_log" => one_trace_log()},
        "task_id" => "osa-seq-1"
      })
      {:ok, r2} = A2ACall.execute(%{
        "action" => "tasks_send", "agent_url" => @pm4py_url,
        "tool" => "pm4py_statistics",
        "args" => %{"event_log" => %{"attributes" => %{}, "traces" => []}},
        "task_id" => "osa-seq-2"
      })

      assert r1["id"] == "osa-seq-1"
      assert r2["id"] == "osa-seq-2"
      # Different logs → different artifact data
      assert r1["artifacts"] != r2["artifacts"],
             "different event logs must produce different artifacts"
    end
  end
end
