defmodule OptimalSystemAgent.Tools.Builtins.YawlWorkflowTest do
  @moduledoc """
  Tests for the YawlWorkflow tool.

  HTTP is mocked via a Bandit + Plug.Router server started on a random port for
  each test group. The YAWL_ENGINE_URL env var is pointed at the mock server so
  Req calls land locally.

  Pure-logic tests (parameter validation, XML parsing) run without any server.
  """

  use ExUnit.Case, async: false

  @moduletag :requires_application

  alias OptimalSystemAgent.Tools.Builtins.YawlWorkflow

  # ──────────────────────────────────────────────────────────────────────────
  # Helpers — minimal Bandit mock server
  # ──────────────────────────────────────────────────────────────────────────

  defmodule MockYawlServer do
    @moduledoc "Plug.Router that returns canned YAWL XML responses."
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
          "upload" ->
            {200, "<success>MySpec:1.0</success>"}

          "launchCase" ->
            {200, "<success>1.1</success>"}

          "cancelCase" ->
            {200, "<success></success>"}

          "failure_test" ->
            {200, "<failure>Spec not found</failure>"}

          _ ->
            {200, "<success>ok</success>"}
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

          "getCaseState" ->
            {200, "<success><state>running</state></success>"}

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

  defmodule FailureMockYawlServer do
    @moduledoc "Mock that always returns YAWL <failure> responses."
    use Plug.Router
    plug :match
    plug :dispatch

    post "/ia" do
      conn
      |> put_resp_content_type("text/xml")
      |> send_resp(200, "<failure>Spec not found in engine</failure>")
    end

    match _ do
      send_resp(conn, 500, "server error")
    end
  end

  # Start a Bandit server on a free OS-assigned port and return its URL.
  defp start_mock_server(plug_module) do
    {:ok, server} = Bandit.start_link(plug: plug_module, port: 0, ip: :loopback)
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    "http://127.0.0.1:#{port}"
  end

  # Override YAWL_ENGINE_URL for the duration of a test.
  defp with_engine_url(url, fun) do
    old = System.get_env("YAWL_ENGINE_URL")
    System.put_env("YAWL_ENGINE_URL", url)

    try do
      fun.()
    after
      if old, do: System.put_env("YAWL_ENGINE_URL", old), else: System.delete_env("YAWL_ENGINE_URL")
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Parameter validation — pure logic, no HTTP
  # ──────────────────────────────────────────────────────────────────────────

  describe "parameter validation (no HTTP)" do
    test "missing operation returns error" do
      assert {:error, msg} = YawlWorkflow.execute(%{})
      assert is_binary(msg)
    end

    test "invalid operation returns error" do
      assert {:error, msg} = YawlWorkflow.execute(%{"operation" => "explode"})
      assert msg =~ "Invalid operation"
    end

    test "upload_spec without spec_xml returns error immediately" do
      # We set an unreachable engine URL to confirm no HTTP call is attempted
      System.put_env("YAWL_ENGINE_URL", "http://127.0.0.1:1")

      try do
        assert {:error, msg} = YawlWorkflow.execute(%{"operation" => "upload_spec"})
        assert msg =~ "spec_xml"
      after
        System.delete_env("YAWL_ENGINE_URL")
      end
    end

    test "launch_case without spec_id returns error immediately" do
      System.put_env("YAWL_ENGINE_URL", "http://127.0.0.1:1")

      try do
        assert {:error, msg} = YawlWorkflow.execute(%{"operation" => "launch_case"})
        assert msg =~ "spec_id"
      after
        System.delete_env("YAWL_ENGINE_URL")
      end
    end

    test "cancel_case without case_id returns error immediately" do
      System.put_env("YAWL_ENGINE_URL", "http://127.0.0.1:1")

      try do
        assert {:error, msg} = YawlWorkflow.execute(%{"operation" => "cancel_case"})
        assert msg =~ "case_id"
      after
        System.delete_env("YAWL_ENGINE_URL")
      end
    end

    test "get_case_state without case_id returns error immediately" do
      System.put_env("YAWL_ENGINE_URL", "http://127.0.0.1:1")

      try do
        assert {:error, msg} = YawlWorkflow.execute(%{"operation" => "get_case_state"})
        assert msg =~ "case_id"
      after
        System.delete_env("YAWL_ENGINE_URL")
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Successful HTTP paths (mocked via Bandit)
  # ──────────────────────────────────────────────────────────────────────────

  describe "upload_spec with mock YAWL engine" do
    setup do
      url = start_mock_server(MockYawlServer)
      {:ok, engine_url: url}
    end

    test "returns {:ok, map} with status success and spec_id in value", %{engine_url: url} do
      with_engine_url(url, fn ->
        assert {:ok, result} =
                 YawlWorkflow.execute(%{
                   "operation" => "upload_spec",
                   "spec_xml" => "<specificationSet/>"
                 })

        assert result["status"] == "success"
        # MockYawlServer returns "MySpec:1.0" inside <success>
        assert result["value"] =~ "MySpec"
        assert is_binary(result["raw_xml"])
      end)
    end
  end

  describe "launch_case with mock YAWL engine" do
    setup do
      url = start_mock_server(MockYawlServer)
      {:ok, engine_url: url}
    end

    test "returns {:ok, map} with case_id value", %{engine_url: url} do
      with_engine_url(url, fn ->
        assert {:ok, result} =
                 YawlWorkflow.execute(%{
                   "operation" => "launch_case",
                   "spec_id" => "MySpec:1.0"
                 })

        assert result["status"] == "success"
        assert result["value"] == "1.1"
      end)
    end
  end

  describe "cancel_case with mock YAWL engine" do
    setup do
      url = start_mock_server(MockYawlServer)
      {:ok, engine_url: url}
    end

    test "returns {:ok, _} for cancel_case", %{engine_url: url} do
      with_engine_url(url, fn ->
        assert {:ok, result} =
                 YawlWorkflow.execute(%{
                   "operation" => "cancel_case",
                   "case_id" => "1.1"
                 })

        assert result["status"] == "success"
      end)
    end
  end

  describe "list_cases with mock YAWL engine" do
    setup do
      url = start_mock_server(MockYawlServer)
      {:ok, engine_url: url}
    end

    test "returns {:ok, _} for list_cases", %{engine_url: url} do
      with_engine_url(url, fn ->
        assert {:ok, result} = YawlWorkflow.execute(%{"operation" => "list_cases"})
        assert result["status"] == "success"
        assert is_binary(result["raw_xml"])
      end)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # YAWL <failure> response → {:error, ...}
  # ──────────────────────────────────────────────────────────────────────────

  describe "YAWL failure XML response" do
    setup do
      url = start_mock_server(FailureMockYawlServer)
      {:ok, engine_url: url}
    end

    test "upload_spec with failure response returns {:error, _}", %{engine_url: url} do
      with_engine_url(url, fn ->
        assert {:error, msg} =
                 YawlWorkflow.execute(%{
                   "operation" => "upload_spec",
                   "spec_xml" => "<specificationSet/>"
                 })

        assert msg =~ "YAWL failure"
        assert msg =~ "Spec not found"
      end)
    end

    test "launch_case with failure response returns {:error, _}", %{engine_url: url} do
      with_engine_url(url, fn ->
        assert {:error, msg} =
                 YawlWorkflow.execute(%{
                   "operation" => "launch_case",
                   "spec_id" => "BadSpec:0.0"
                 })

        assert msg =~ "YAWL failure"
      end)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # YAWL unreachable → {:error, _}
  # ──────────────────────────────────────────────────────────────────────────

  describe "YAWL engine unreachable" do
    test "returns {:error, _} when engine is not running" do
      with_engine_url("http://127.0.0.1:19999", fn ->
        assert {:error, msg} =
                 YawlWorkflow.execute(%{
                   "operation" => "upload_spec",
                   "spec_xml" => "<specificationSet/>"
                 })

        assert is_binary(msg)
        assert msg =~ "Connection" or msg =~ "refused" or msg =~ "failed"
      end)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Tool metadata
  # ──────────────────────────────────────────────────────────────────────────

  describe "tool metadata" do
    test "name is yawl_workflow" do
      assert YawlWorkflow.name() == "yawl_workflow"
    end

    test "safety is write_safe" do
      assert YawlWorkflow.safety() == :write_safe
    end

    test "parameters returns a valid JSON-schema object" do
      params = YawlWorkflow.parameters()
      assert params["type"] == "object"
      assert Map.has_key?(params["properties"], "operation")
      assert Map.has_key?(params["properties"], "spec_xml")
      assert Map.has_key?(params["properties"], "spec_id")
      assert Map.has_key?(params["properties"], "case_id")
      assert params["required"] == ["operation"]
    end
  end
end
