defmodule OptimalSystemAgent.Tools.Builtins.YawlWorkflowTraceLinkingTest do
  @moduledoc """
  Tests for OTEL Steps 4&5: YAWL case → trace_id linking via EventStream.

  Verifies that:
  1. launch_case subscribes to EventStream
  2. EventStream creates case_id → trace_id mapping in ETS
  3. launch_case result includes trace_id when available
  4. lookup_trace_id retrieves the mapping correctly
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application

  alias OptimalSystemAgent.Tools.Builtins.YawlWorkflow
  alias OptimalSystemAgent.Yawl.EventStream


  # Mock YAWL server from the main yawl_workflow_test.exs
  defmodule MockYawlServer do
    use Plug.Router

    plug Plug.Parsers,
      parsers: [:urlencoded, :json],
      pass: ["*/*"],
      json_decoder: Jason

    plug :match
    plug :dispatch

    post "/ia" do
      action = conn.body_params["action"] || ""

      {status, body} =
        case action do
          "launchCase" -> {200, "<success>#{conn.body_params["specID"]}.#{System.unique_integer([:positive])}</success>"}
          "upload" -> {200, "<success>TestSpec:1.0</success>"}
          _ -> {200, "<success>ok</success>"}
        end

      conn
      |> put_resp_content_type("text/xml")
      |> send_resp(status, body)
    end

    get "/ia" do
      action = conn.query_params["action"] || ""

      {status, body} =
        case action do
          "getAllRunningCases" ->
            {200, "<success><cases><case id=\"1.1\" specID=\"TestSpec:1.0\"/></cases></success>"}

          _ ->
            {200, "<success>ok</success>"}
        end

      conn
      |> put_resp_content_type("text/xml")
      |> send_resp(status, body)
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  setup_all do
    # EventStream is started by the application, so no need to start it here
    :ok
  end

  setup do
    # Set YAWL engine URL to mock server
    engine_url = start_mock_yawl_server()
    System.put_env("YAWL_ENGINE_URL", engine_url)
    on_exit(fn -> System.delete_env("YAWL_ENGINE_URL") end)
    {:ok, engine_url: engine_url}
  end

  defp start_mock_yawl_server do
    {:ok, server} = Bandit.start_link(plug: MockYawlServer, port: 0, ip: :loopback)
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    "http://127.0.0.1:#{port}"
  end

  describe "launch_case trace linking" do
    test "launch_case returns case_id on success" do
      case_result = YawlWorkflow.execute(%{"operation" => "upload_spec", "spec_xml" => "<spec></spec>"})
      assert {:ok, %{"status" => "success"}} = case_result

      # Now launch a case from the uploaded spec
      launch_result = YawlWorkflow.execute(%{"operation" => "launch_case", "spec_id" => "TestSpec:1.0"})

      assert {:ok, %{"status" => "success", "value" => case_id}} = launch_result
      assert is_binary(case_id)
      assert String.length(case_id) > 0
    end

    test "launch_case subscribes EventStream for trace mapping", %{engine_url: _engine_url} do
      upload_result = YawlWorkflow.execute(%{"operation" => "upload_spec", "spec_xml" => "<spec></spec>"})
      assert {:ok, %{"status" => "success"}} = upload_result

      launch_result = YawlWorkflow.execute(%{"operation" => "launch_case", "spec_id" => "TestSpec:1.0"})
      assert {:ok, %{"status" => "success", "value" => case_id}} = launch_result

      # Give EventStream a moment to create the mapping (it's async via Task.Supervisor)
      Process.sleep(100)

      # Verify trace_id was created
      trace_id = EventStream.lookup_trace_id(case_id)
      assert trace_id != nil
      assert is_binary(trace_id)
      assert String.length(trace_id) == 32  # SHA-256 first 16 bytes → 32 hex chars
    end

    test "launch_case includes trace_id in result when available", %{engine_url: _engine_url} do
      upload_result = YawlWorkflow.execute(%{"operation" => "upload_spec", "spec_xml" => "<spec></spec>"})
      assert {:ok, %{"status" => "success"}} = upload_result

      launch_result = YawlWorkflow.execute(%{"operation" => "launch_case", "spec_id" => "TestSpec:1.0"})
      assert {:ok, %{"status" => "success", "value" => case_id} = result} = launch_result

      # Result may or may not have trace_id immediately (async EventStream)
      # But if it does, verify it's correct
      if Map.get(result, "trace_id") do
        trace_id = Map.get(result, "trace_id")
        assert is_binary(trace_id)
        assert String.length(trace_id) == 32

        # Verify it matches the ETS mapping
        ets_trace_id = EventStream.lookup_trace_id(case_id)
        assert trace_id == ets_trace_id
      end
    end
  end

  describe "EventStream trace_id derivation" do
    test "lookup_trace_id returns nil for unknown case" do
      unknown_case = "unknown_case_#{:erlang.system_time(:millisecond)}"
      trace_id = EventStream.lookup_trace_id(unknown_case)
      assert trace_id == nil
    end

    test "lookup_trace_id returns stable trace_id for same case_id" do
      case_id = "test_case_#{:erlang.system_time(:millisecond)}"

      # Manually subscribe to create mapping (as launch_case does)
      EventStream.subscribe(case_id)
      Process.sleep(50)

      trace_id_1 = EventStream.lookup_trace_id(case_id)
      trace_id_2 = EventStream.lookup_trace_id(case_id)

      assert trace_id_1 != nil
      assert trace_id_1 == trace_id_2
    end

    test "different case_ids produce different trace_ids" do
      case_id_1 = "case_1_#{:erlang.system_time(:millisecond)}"
      case_id_2 = "case_2_#{:erlang.system_time(:millisecond)}"

      EventStream.subscribe(case_id_1)
      EventStream.subscribe(case_id_2)
      Process.sleep(50)

      trace_id_1 = EventStream.lookup_trace_id(case_id_1)
      trace_id_2 = EventStream.lookup_trace_id(case_id_2)

      assert trace_id_1 != nil
      assert trace_id_2 != nil
      assert trace_id_1 != trace_id_2
    end

    test "trace_id is W3C 128-bit (32 hex chars)" do
      case_id = "w3c_test_#{:erlang.system_time(:millisecond)}"
      EventStream.subscribe(case_id)
      Process.sleep(50)

      trace_id = EventStream.lookup_trace_id(case_id)

      assert is_binary(trace_id)
      assert String.length(trace_id) == 32
      # Verify it's valid hex
      assert String.match?(trace_id, ~r/^[0-9a-f]{32}$/i)
    end
  end

  describe "Multiple YAWL cases correlation" do
    test "Multiple launched cases get distinct trace_ids", %{engine_url: _engine_url} do
      upload_result = YawlWorkflow.execute(%{"operation" => "upload_spec", "spec_xml" => "<spec></spec>"})
      assert {:ok, %{"status" => "success"}} = upload_result

      # Launch multiple cases
      {:ok, %{"value" => case_id_1}} = YawlWorkflow.execute(%{"operation" => "launch_case", "spec_id" => "TestSpec:1.0"})
      {:ok, %{"value" => case_id_2}} = YawlWorkflow.execute(%{"operation" => "launch_case", "spec_id" => "TestSpec:1.0"})

      Process.sleep(100)

      trace_id_1 = EventStream.lookup_trace_id(case_id_1)
      trace_id_2 = EventStream.lookup_trace_id(case_id_2)

      assert trace_id_1 != nil
      assert trace_id_2 != nil
      assert trace_id_1 != trace_id_2
      assert case_id_1 != case_id_2
    end
  end
end
