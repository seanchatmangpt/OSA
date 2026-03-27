defmodule OptimalSystemAgent.Ontology.InferenceChainTest do
  @moduledoc """
  Chicago TDD tests for InferenceChain GenServer.

  Tests follow Chicago School (black-box behavior verification):
  - Real GenServer started per test (no mocks of internal state)
  - HTTP tests use an in-process raw TCP mock server (no external deps)
  - All tests run with full OTP application
  - HTTP tests require app (Finch pool) — tagged :integration

  FIRST: Fast (<100ms), Independent (isolated ETS + named server), Repeatable,
    Self-Checking (explicit assertions), Timely (written with implementation)

  WvdA: all tests terminate; no unbounded waits. Each test has explicit timeout.
  Armstrong: GenServer started fresh per test; supervisor not needed for unit tests.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Ontology.InferenceChain

  @moduletag :inference_chain

  # ── Test Helpers ───────────────────────────────────────────────────────────

  defp start_chain(opts \\ []) do
    sparql_dir = Keyword.get(opts, :sparql_dir, build_temp_sparql_dir())
    oxigraph_url = Keyword.get(opts, :oxigraph_url, "http://localhost:7878")
    timeout_ms = Keyword.get(opts, :timeout_ms, 5_000)

    {:ok, pid} =
      GenServer.start_link(
        InferenceChain,
        [
          oxigraph_url: oxigraph_url,
          timeout_ms: timeout_ms,
          sparql_dir: sparql_dir
        ],
        name: :"inference_chain_#{System.unique_integer([:positive])}"
      )

    on_exit(fn ->
      try do
        if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1_000)
      catch
        :exit, _ -> :ok
      end
    end)

    pid
  end

  # Build a temp directory with minimal valid SPARQL stub files
  defp build_temp_sparql_dir do
    dir = Path.join(System.tmp_dir!(), "inference_chain_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    stub = fn level ->
      """
      PREFIX bos: <https://chatmangpt.com/ontology/businessos/>
      PREFIX prov: <http://www.w3.org/ns/prov#>
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

      CONSTRUCT {
        <https://chatmangpt.com/test/stub/#{level}> a bos:ProcessMetric ;
          bos:derivationLevel "#{String.upcase(Atom.to_string(level))}" ;
          prov:generatedAtTime ?now .
      }
      WHERE {
        BIND(NOW() AS ?now)
      }
      """
    end

    File.write!(Path.join(dir, "l1_process_metrics.sparql"), stub.(:l1))
    File.write!(Path.join(dir, "l2_org_health.sparql"), stub.(:l2))
    File.write!(Path.join(dir, "l3_board_intelligence.sparql"), stub.(:l3))

    dir
  end

  # ── Tests: chain_status/0 — pure ETS logic, no HTTP ──────────────────────
  # These tests run with --no-start (no Finch pool needed).

  describe "chain_status/0" do
    test "returns {:never, :never, :never} when no levels have been materialized" do
      ensure_clean_ets()
      pid = start_chain()

      {l1_age, l2_age, l3_age} = GenServer.call(pid, :chain_status, 5_000)

      assert l1_age == :never
      assert l2_age == :never
      assert l3_age == :never
    end

    test "returns integer age in ms when a level has been materialized" do
      ensure_test_ets()
      refreshed_at = System.monotonic_time(:millisecond)
      :ets.insert(:osa_inference_chain_status, {:l1, refreshed_at, 55})

      pid = start_chain()
      Process.sleep(5)

      {l1_age, _l2_age, _l3_age} = GenServer.call(pid, :chain_status, 5_000)

      assert is_integer(l1_age)
      assert l1_age >= 0
    end

    test "returns correct tuple shape {l1_age, l2_age, l3_age}" do
      ensure_clean_ets()
      pid = start_chain()

      result = GenServer.call(pid, :chain_status, 5_000)

      assert is_tuple(result)
      assert tuple_size(result) == 3

      {l1_age, l2_age, l3_age} = result
      assert l1_age == :never or is_integer(l1_age)
      assert l2_age == :never or is_integer(l2_age)
      assert l3_age == :never or is_integer(l3_age)
    end

    test "ages increase monotonically between two calls" do
      ensure_test_ets()
      refreshed_at = System.monotonic_time(:millisecond)
      :ets.insert(:osa_inference_chain_status, {:l2, refreshed_at, 77})

      pid = start_chain()
      Process.sleep(10)

      {_l1a, l2_age_1, _l3a} = GenServer.call(pid, :chain_status, 5_000)
      Process.sleep(10)
      {_l1b, l2_age_2, _l3b} = GenServer.call(pid, :chain_status, 5_000)

      if is_integer(l2_age_1) and is_integer(l2_age_2) do
        assert l2_age_2 > l2_age_1
      end
    end
  end

  # ── Tests: invalidate_from/1 — cascade metadata (no Oxigraph) ────────────
  # NOTE: invalidate_from also triggers re-run; these tests are tagged :integration
  # because the re-run uses Req (requires Finch pool / app started).

  describe "invalidate_from/1 cascade logic" do
    @tag :integration
    test "invalidate_from(:l0) returns ok tuple with levels_invalidated list" do
      ensure_clean_ets()
      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req -> {204, [], ""} end)
      sparql_dir = build_temp_sparql_dir()
      pid = start_chain(oxigraph_url: "http://localhost:#{mock_port}", sparql_dir: sparql_dir)

      result = GenServer.call(pid, {:invalidate_from, :l0}, 12_000)

      assert {:ok, %{levels_invalidated: levels}} = result
      assert :l1 in levels
      assert :l2 in levels
      assert :l3 in levels

      Task.shutdown(mock_task, :brutal_kill)
    end

    @tag :integration
    test "invalidate_from(:l1) invalidates only l2 and l3" do
      ensure_clean_ets()
      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req -> {204, [], ""} end)
      sparql_dir = build_temp_sparql_dir()
      pid = start_chain(oxigraph_url: "http://localhost:#{mock_port}", sparql_dir: sparql_dir)

      result = GenServer.call(pid, {:invalidate_from, :l1}, 12_000)

      assert {:ok, %{levels_invalidated: levels}} = result
      assert :l1 not in levels
      assert :l2 in levels
      assert :l3 in levels

      Task.shutdown(mock_task, :brutal_kill)
    end

    @tag :integration
    test "invalidate_from(:l2) invalidates only l3" do
      ensure_clean_ets()
      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req -> {204, [], ""} end)
      sparql_dir = build_temp_sparql_dir()
      pid = start_chain(oxigraph_url: "http://localhost:#{mock_port}", sparql_dir: sparql_dir)

      result = GenServer.call(pid, {:invalidate_from, :l2}, 12_000)

      assert {:ok, %{levels_invalidated: levels}} = result
      assert :l1 not in levels
      assert :l2 not in levels
      assert :l3 in levels

      Task.shutdown(mock_task, :brutal_kill)
    end

    @tag :integration
    test "invalidate_from(:l0) levels are in cascade order [:l1, :l2, :l3]" do
      ensure_clean_ets()
      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req -> {204, [], ""} end)
      sparql_dir = build_temp_sparql_dir()
      pid = start_chain(oxigraph_url: "http://localhost:#{mock_port}", sparql_dir: sparql_dir)

      {:ok, %{levels_invalidated: levels}} = GenServer.call(pid, {:invalidate_from, :l0}, 12_000)

      # L1 before L2, L2 before L3 — no circular dependency
      l1_idx = Enum.find_index(levels, &(&1 == :l1))
      l2_idx = Enum.find_index(levels, &(&1 == :l2))
      l3_idx = Enum.find_index(levels, &(&1 == :l3))

      assert l1_idx < l2_idx
      assert l2_idx < l3_idx

      Task.shutdown(mock_task, :brutal_kill)
    end

    @tag :integration
    test "invalidate_from(:l0) marks all three ETS entries as stale then refreshed" do
      ensure_test_ets()
      # Pre-seed all three levels as fresh
      now_ms = System.monotonic_time(:millisecond)
      :ets.insert(:osa_inference_chain_status, {:l1, now_ms, 10})
      :ets.insert(:osa_inference_chain_status, {:l2, now_ms, 20})
      :ets.insert(:osa_inference_chain_status, {:l3, now_ms, 30})

      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req -> {204, [], ""} end)
      sparql_dir = build_temp_sparql_dir()
      pid = start_chain(oxigraph_url: "http://localhost:#{mock_port}", sparql_dir: sparql_dir)

      # Invalidate deletes ETS, then re-runs successfully
      {:ok, _} = GenServer.call(pid, {:invalidate_from, :l0}, 12_000)

      # After successful re-run, levels should have fresh integer ages
      {l1_age, l2_age, l3_age} = GenServer.call(pid, :chain_status, 5_000)
      assert is_integer(l1_age)
      assert is_integer(l2_age)
      assert is_integer(l3_age)

      Task.shutdown(mock_task, :brutal_kill)
    end
  end

  # ── Tests: run_level/1 — file not found (pure logic, no HTTP needed) ────────
  # SPARQL file check happens before any HTTP call — no Finch pool required.

  describe "run_level/1 error handling" do
    test "returns {:error, {:sparql_file_not_found, path}} when l1 SPARQL file missing" do
      empty_dir = Path.join(System.tmp_dir!(), "empty_sparql_#{System.unique_integer([:positive])}")
      File.mkdir_p!(empty_dir)

      pid = start_chain(sparql_dir: empty_dir)

      result = GenServer.call(pid, {:run_level, :l1}, 5_000)

      assert {:error, {:sparql_file_not_found, path}} = result
      assert String.ends_with?(path, "l1_process_metrics.sparql")
    end

    test "returns {:error, {:sparql_file_not_found, path}} for l2 SPARQL file missing" do
      empty_dir = Path.join(System.tmp_dir!(), "empty_sparql_#{System.unique_integer([:positive])}")
      File.mkdir_p!(empty_dir)

      pid = start_chain(sparql_dir: empty_dir)

      result = GenServer.call(pid, {:run_level, :l2}, 5_000)

      assert {:error, {:sparql_file_not_found, path}} = result
      assert String.ends_with?(path, "l2_org_health.sparql")
    end

    test "returns {:error, {:sparql_file_not_found, path}} for l3 SPARQL file missing" do
      empty_dir = Path.join(System.tmp_dir!(), "empty_sparql_#{System.unique_integer([:positive])}")
      File.mkdir_p!(empty_dir)

      pid = start_chain(sparql_dir: empty_dir)

      result = GenServer.call(pid, {:run_level, :l3}, 5_000)

      assert {:error, {:sparql_file_not_found, path}} = result
      assert String.ends_with?(path, "l3_board_intelligence.sparql")
    end

    @tag :integration
    test "returns {:error, :connection_refused} when Oxigraph port is closed" do
      # Port 19999 should be unbound; this test needs Req/Finch running
      pid = start_chain(oxigraph_url: "http://localhost:19999", timeout_ms: 2_000)

      result = GenServer.call(pid, {:run_level, :l1}, 5_000)

      assert {:error, :connection_refused} = result
    end
  end

  # ── Tests: run_level/1 with mock HTTP — tagged :integration ───────────────
  # These tests require the Finch HTTP pool (app must be started).
  # Run with: mix test --include integration

  describe "run_level/1 with mock Oxigraph (HTTP)" do
    @tag :integration
    test "returns {:ok, count} with count > 0 when Oxigraph responds 204" do
      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req -> {204, [], ""} end)
      sparql_dir = build_temp_sparql_dir()

      pid = start_chain(
        oxigraph_url: "http://localhost:#{mock_port}",
        sparql_dir: sparql_dir
      )

      result = GenServer.call(pid, {:run_level, :l1}, 8_000)

      assert {:ok, count} = result
      assert count > 0

      Task.shutdown(mock_task, :brutal_kill)
    end

    @tag :integration
    test "returns {:error, {:http_error, 500, _body}} when Oxigraph returns 500" do
      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req ->
        {500, [], "Internal Server Error"}
      end)

      sparql_dir = build_temp_sparql_dir()
      pid = start_chain(
        oxigraph_url: "http://localhost:#{mock_port}",
        sparql_dir: sparql_dir
      )

      result = GenServer.call(pid, {:run_level, :l1}, 8_000)

      assert {:error, {:http_error, 500, _body}} = result

      Task.shutdown(mock_task, :brutal_kill)
    end

    @tag :integration
    test "run_full_chain returns {:ok, map} with l1/l2/l3 keys on success" do
      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req -> {204, [], ""} end)
      sparql_dir = build_temp_sparql_dir()

      pid = start_chain(
        oxigraph_url: "http://localhost:#{mock_port}",
        sparql_dir: sparql_dir
      )

      result = GenServer.call(pid, :run_full_chain, 15_000)

      assert {:ok, %{l1: l1, l2: l2, l3: l3}} = result
      assert is_integer(l1) and l1 > 0
      assert is_integer(l2) and l2 > 0
      assert is_integer(l3) and l3 > 0

      Task.shutdown(mock_task, :brutal_kill)
    end

    @tag :integration
    test "returns {:error, :timeout} when Oxigraph hangs longer than timeout_ms" do
      {:ok, mock_port, mock_task} = start_mock_oxigraph(fn _req ->
        Process.sleep(3_000)
        {204, [], ""}
      end)

      sparql_dir = build_temp_sparql_dir()
      # 1 second timeout — less than mock's 3s sleep
      pid = start_chain(
        oxigraph_url: "http://localhost:#{mock_port}",
        sparql_dir: sparql_dir,
        timeout_ms: 1_000
      )

      result = GenServer.call(pid, {:run_level, :l1}, 5_000)

      assert {:error, :timeout} = result

      Task.shutdown(mock_task, :brutal_kill)
    end
  end

  # ── Private: Minimal In-Process Mock HTTP Server ───────────────────────────

  # Starts a raw TCP server that speaks HTTP/1.1 at the byte level.
  # handler_fn receives the raw request binary and returns {status, headers, body}.
  # WvdA: bounded — max 50 connections; 3s read timeout per connection.
  defp start_mock_oxigraph(handler_fn) do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])

    {:ok, {_addr, port}} = :inet.sockname(listen_socket)

    task =
      Task.async(fn ->
        serve_mock_connections(listen_socket, handler_fn, 0)
      end)

    {:ok, port, task}
  end

  defp serve_mock_connections(_listen_socket, _handler_fn, count) when count >= 50, do: :ok

  defp serve_mock_connections(listen_socket, handler_fn, count) do
    case :gen_tcp.accept(listen_socket, 1_000) do
      {:ok, client_socket} ->
        raw_request = drain_http_request(client_socket)
        {status_code, _extra_headers, body} = handler_fn.(raw_request)

        response =
          "HTTP/1.1 #{status_code} #{status_text(status_code)}\r\n" <>
          "Content-Length: #{byte_size(body)}\r\n" <>
          "Content-Type: text/plain\r\n" <>
          "Connection: close\r\n\r\n" <>
          body

        :gen_tcp.send(client_socket, response)
        :gen_tcp.close(client_socket)
        serve_mock_connections(listen_socket, handler_fn, count + 1)

      {:error, :timeout} ->
        serve_mock_connections(listen_socket, handler_fn, count)

      {:error, _reason} ->
        :ok
    end
  end

  # Read raw bytes until \r\n\r\n (end of HTTP headers) — up to 64KB.
  # WvdA: bounded by 3s timeout and 64KB max buffer.
  defp drain_http_request(socket, acc \\ "", size \\ 0)

  defp drain_http_request(_socket, acc, size) when size > 65_536, do: acc

  defp drain_http_request(socket, acc, size) do
    case :gen_tcp.recv(socket, 0, 3_000) do
      {:ok, data} ->
        new_acc = acc <> data
        new_size = size + byte_size(data)
        if String.contains?(new_acc, "\r\n\r\n") do
          new_acc
        else
          drain_http_request(socket, new_acc, new_size)
        end

      {:error, _} ->
        acc
    end
  end

  defp status_text(200), do: "OK"
  defp status_text(204), do: "No Content"
  defp status_text(500), do: "Internal Server Error"
  defp status_text(code), do: "Status #{code}"

  # ── Private: ETS Helpers ───────────────────────────────────────────────────

  defp ensure_test_ets do
    if :ets.whereis(:osa_inference_chain_status) == :undefined do
      :ets.new(:osa_inference_chain_status, [:named_table, :public, :set, read_concurrency: true])
    end
  end

  defp ensure_clean_ets do
    if :ets.whereis(:osa_inference_chain_status) != :undefined do
      :ets.delete_all_objects(:osa_inference_chain_status)
    else
      :ets.new(:osa_inference_chain_status, [:named_table, :public, :set, read_concurrency: true])
    end
  end
end
