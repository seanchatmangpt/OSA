defmodule OptimalSystemAgent.JTBD.Dashboard do
  @moduledoc """
  Live Terminal Dashboard for Wave 12 Self-Play Loop

  Subscribes to Canopy PubSub topic `jtbd:wave12` and displays real-time metrics:
  - Current iteration and loop status
  - Per-scenario status (pass/fail/running)
  - Step counts and latency
  - Overall pass rate and timestamp
  - Jaeger link for trace exploration

  Dashboard Updates:
  - ETS table `:jtbd_wave12_metrics` tracks all iteration results
  - Terminal updated on each scenario completion
  - Dashboard format uses box-drawing characters for professional appearance

  GenServer Behavior:
  - start_link/1 — initialize subscriber and ETS table
  - stop/0 — stop dashboard
  """

  use GenServer
  require Logger

  @ets_table :jtbd_wave12_metrics
  @pubsub_topic "jtbd:wave12"

  @yawl_default_url "http://localhost:8080"
  @yawl_poll_interval_ms 15_000

  @dmaic_phases %{
    define: [:compliance_check, :a2a_deal_lifecycle, :icp_qualification],
    measure: [:process_discovery, :workspace_sync, :conformance_drift, :yawl_v6_checkpoint],
    analyze: [:agent_decision_loop, :healing_recovery, :retrofit_complexity_scoring, :process_intelligence_query],
    improve: [:cross_system_handoff, :mcp_tool_execution, :outreach_sequence_execution],
    control: [:consensus_round, :deal_progression, :contract_closure]
  }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Start the dashboard"
  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    case GenServer.call(__MODULE__, {:start, opts}) do
      :ok -> {:ok, self()}
      error -> error
    end
  rescue
    _e -> {:error, :not_started}
  end

  @doc "Stop the dashboard"
  @spec stop() :: :ok
  def stop do
    GenServer.call(__MODULE__, :stop)
  rescue
    _e -> :ok
  end

  # Server Callbacks

  @impl GenServer
  def init(opts) do
    # Create ETS table for metrics storage
    Logger.debug("Wave 12 dashboard initializing ETS table | table=#{@ets_table}")

    table_exists = :ets.whereis(@ets_table) != :undefined

    if not table_exists do
      :ets.new(@ets_table, [:named_table, :set, :public])
      Logger.info("Wave 12 dashboard ETS table created | table=#{@ets_table}")

      :telemetry.execute([:jtbd, :dashboard, :ets_created], %{
        table: Atom.to_string(@ets_table)
      })
    else
      Logger.debug("Wave 12 dashboard ETS table already exists | table=#{@ets_table}")
    end

    state = %{
      current_iteration: 0,
      current_results: %{},
      pass_count: 0,
      fail_count: 0,
      last_update: DateTime.utc_now(),
      running: false,
      show_ascii: Keyword.get(opts, :ascii_only, false),
      yawlv6: nil,
      spc_history: [],
      spc_stats: %{},
      revops_funnel: %{
        contacts: 21_000,
        qualified: 0,
        enrolled: 0,
        deals: 0,
        contracts: 0
      },
      yawlv6_sim: nil,
      scenario_results: []
    }

    Logger.info("Wave 12 dashboard initialized | ascii_only=#{Keyword.get(opts, :ascii_only, false)}")

    # Schedule first YAWL engine health poll immediately
    Process.send_after(self(), :tick, 0)

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:start, _opts}, _from, state) do
    # Subscribe to PubSub topic
    Logger.info("Wave 12 dashboard subscribing to PubSub | topic=#{@pubsub_topic}")

    Phoenix.PubSub.subscribe(Canopy.PubSub, @pubsub_topic)

    Logger.info("Wave 12 dashboard subscribed successfully | topic=#{@pubsub_topic}")

    :telemetry.execute([:jtbd, :dashboard, :subscribed], %{
      topic: @pubsub_topic
    })

    new_state = %{state | running: true}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:stop, _from, state) do
    Logger.info(
      "Wave 12 dashboard stopping | iterations=#{state.current_iteration} | total_pass=#{state.pass_count} | total_fail=#{state.fail_count}"
    )

    Phoenix.PubSub.unsubscribe(Canopy.PubSub, @pubsub_topic)

    :telemetry.execute([:jtbd, :dashboard, :stopped], %{
      iterations: state.current_iteration,
      total_pass: state.pass_count,
      total_fail: state.fail_count
    })

    {:reply, :ok, %{state | running: false}}
  end

  @impl GenServer
  def handle_info({:wave12_update, metadata, payload}, state) do
    # New message format with metadata for DMAIC dashboard processing
    case validate_and_process_payload(payload, state) do
      {:ok, state_after_payload} ->
        # Process metadata for SPC and RevOps tracking
        new_state = process_dmaic_metadata(metadata, state_after_payload)
        Logger.debug("Wave 12 dashboard rendering UI")
        render_dashboard(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.warning(
          "Wave 12 dashboard received malformed wave12_update. Reason: #{reason}. Payload: #{inspect(payload)}"
        )

        :telemetry.execute([:jtbd, :dashboard, :message_error], %{
          reason: Atom.to_string(reason)
        })

        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:scenario_result, payload}, state) do
    # Legacy message format for backward compatibility
    case validate_and_process_payload(payload, state) do
      {:ok, new_state} ->
        Logger.debug("Wave 12 dashboard rendering UI (legacy format)")
        render_dashboard(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.warning(
          "Wave 12 dashboard received malformed scenario_result. Reason: #{reason}. Payload: #{inspect(payload)}"
        )

        :telemetry.execute([:jtbd, :dashboard, :message_error], %{
          reason: Atom.to_string(reason)
        })

        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:tick, state) do
    new_yawlv6 = poll_yawl_engine()
    Process.send_after(self(), :tick, @yawl_poll_interval_ms)
    {:noreply, %{state | yawlv6: new_yawlv6}}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Dashboard Rendering

  defp render_dashboard(state) do
    iteration = state.current_iteration
    timestamp = state.last_update |> DateTime.to_iso8601()
    pass_rate = calculate_pass_rate(state.pass_count, state.fail_count)

    # Clear terminal and render header
    IO.write("\e[2J\e[H")  # ANSI clear screen and home cursor

    render_header(iteration, timestamp, pass_rate)
    render_dmaic_phases(state.scenario_results)
    render_spc_chart(state.spc_history, state.spc_stats)
    render_revops_panel(state.revops_funnel)
    render_footer(pass_rate, state.pass_count, state.fail_count)
    render_yawlv6_full_panel(state.yawlv6)
  end

  defp render_header(iteration, timestamp, pass_rate) do
    max_iters = System.get_env("WAVE12_MAX_ITERATIONS", "∞")

    header = """
    ╔════════════════════════════════════════════════════════════════════╗
    ║  WAVE 12 DMAIC DASHBOARD │ Iter #{String.pad_leading(to_string(iteration), 3)}/#{max_iters} │ Pass: #{String.pad_leading(Float.to_string(pass_rate), 5)}% │ #{String.slice(timestamp, 0, 19)}  ║
    ╚════════════════════════════════════════════════════════════════════╝
    """

    IO.write(header)
  end

  # DMAIC phase rendering
  defp render_dmaic_phases(scenario_results) do
    phases = [:define, :measure, :analyze, :improve, :control]

    IO.write("\n")

    phases
    |> Enum.each(fn phase ->
      render_phase_section(phase, scenario_results)
    end)
  end

  defp render_phase_section(phase, scenario_results) do
    scenarios_in_phase = Map.get(@dmaic_phases, phase, [])
    _phase_name = phase |> to_string() |> String.upcase()

    header = case phase do
      :define -> "╔═ DEFINE ═══════════════════════════════════════════════════╗"
      :measure -> "╠═ MEASURE ══════════════════════════════════════════════════╣"
      :analyze -> "╠═ ANALYZE ══════════════════════════════════════════════════╣"
      :improve -> "╠═ IMPROVE ══════════════════════════════════════════════════╣"
      :control -> "╠═ CONTROL ══════════════════════════════════════════════════╣"
    end

    IO.write(header <> "\n")

    scenarios_in_phase
    |> Enum.each(fn scenario_id ->
      result = Enum.find(scenario_results, &match?(%{scenario: ^scenario_id}, &1))
      render_dmaic_scenario_row(scenario_id, result)
    end)
  end

  defp render_dmaic_scenario_row(scenario_id, result) when is_map(result) do
    pass_rate = Float.round(result.pass_count / (result.pass_count + result.fail_count) * 100, 0) |> to_string()
    scenario_name = scenario_id |> to_string()

    status_icon = case result.pass_count do
      n when n == result.pass_count + result.fail_count -> "✅"
      0 -> "❌"
      _ -> "🔄"
    end

    row = "║ #{status_icon} #{String.pad_trailing(scenario_name, 32)} pass: #{String.pad_leading("#{result.pass_count}/#{result.pass_count + result.fail_count}", 3)} (#{String.pad_leading(pass_rate, 3)}%)  ║\n"
    IO.write(row)
  end

  defp render_dmaic_scenario_row(scenario_id, nil) do
    scenario_name = scenario_id |> to_string()
    row = "║ ⏳ #{String.pad_trailing(scenario_name, 32)} pending            ║\n"
    IO.write(row)
  end

  # SPC Control Chart rendering
  defp render_spc_chart(spc_history, spc_stats) do
    IO.write("\n")
    IO.write("╔═ SPC CONTROL CHART ═ PASS RATE (LAST 20) ═════════════════════════╗\n")

    # Render UCL
    ucl = Map.get(spc_stats, :ucl, 1.0)
    IO.write("║ UCL ═════════════════════════════════════════ #{String.pad_leading(Float.to_string(Float.round(ucl * 100, 1)), 5)}%  ║\n")

    # Render sparkline
    sparkline = render_sparkline(spc_history)
    IO.write("║     " <> sparkline <> " ║\n")

    # Render LCL
    lcl = Map.get(spc_stats, :lcl, 0.0)
    IO.write("║ LCL ═════════════════════════════════════════ #{String.pad_leading(Float.to_string(Float.round(lcl * 100, 1)), 5)}%  ║\n")

    # Render stats
    mean = Map.get(spc_stats, :mean, 0.0)
    sigma = Map.get(spc_stats, :sigma, 0.0)
    count = length(spc_history)
    stats_line = "║ Mean: #{String.pad_leading(Float.to_string(Float.round(mean * 100, 1)), 5)}% | σ: #{String.pad_leading(Float.to_string(Float.round(sigma * 100, 2)), 5)}% | n=#{count}#{String.duplicate(" ", 38)}║\n"
    IO.write(stats_line)
    IO.write("╚═════════════════════════════════════════════════════════════════════╝\n")
  end

  # RevOps Funnel rendering
  defp render_revops_panel(funnel) do
    IO.write("\n")
    IO.write("╔═ REVOPS PIPELINE ═══════════════════════════════════════════════════╗\n")
    IO.write("║ LinkedIn to Contracts                                              ║\n")

    contacts = funnel.contacts
    IO.write("║ #{String.pad_leading(Integer.to_string(contacts), 6)} connections                                            ║\n")
    IO.write("║      ↓ ICP scoring (20%)                                            ║\n")

    qualified = Float.ceil(contacts * 0.20) |> trunc()
    funnel_updated = Map.put(funnel, :qualified, qualified)
    IO.write("║ #{String.pad_leading(Integer.to_string(qualified), 6)} ICP qualified                                          ║\n")
    IO.write("║      ↓ sequence enrollment (20%)                                    ║\n")

    enrolled = Float.ceil(qualified * 0.20) |> trunc()
    funnel_updated = Map.put(funnel_updated, :enrolled, enrolled)
    IO.write("║ #{String.pad_leading(Integer.to_string(enrolled), 6)} in sequences                                            ║\n")
    IO.write("║      ↓ deal creation (20%)                                          ║\n")

    deals = Float.ceil(enrolled * 0.20) |> trunc()
    funnel_updated = Map.put(funnel_updated, :deals, deals)
    deal_value = deals * 25_000
    IO.write("║ #{String.pad_leading(Integer.to_string(deals), 6)} active deals ($#{String.pad_leading(Integer.to_string(div(deal_value, 1_000_000)), 1)}.2M pipeline)                           ║\n")
    IO.write("║      ↓ contract closure (20%)                                       ║\n")

    contracts = Float.ceil(deals * 0.20) |> trunc()
    _funnel_updated = Map.put(funnel_updated, :contracts, contracts)
    arr = contracts * 50_000
    IO.write("║ #{String.pad_leading(Integer.to_string(contracts), 6)} contracts signed ($#{String.pad_leading(Integer.to_string(div(arr, 1_000_000)), 1)}.7M ARR)                     ║\n")
    IO.write("╚═════════════════════════════════════════════════════════════════════╝\n")
  end

  # YAWLv6 Full Panel rendering — uses real engine state from periodic health poll
  defp render_yawlv6_full_panel(yawlv6) do
    IO.write("\n")
    IO.write("╔═ YAWLV6 ENGINE STATUS ══════════════════════════════════════════════╗\n")

    case yawlv6 do
      %{status: "running"} = engine ->
        version = Map.get(engine, :version, "unknown")
        active_cases = Map.get(engine, :active_cases, 0)
        ts = Map.get(engine, :timestamp, "")
        ts_short = if is_binary(ts), do: String.slice(ts, 0, 19), else: ""

        IO.write("║ Status:  RUNNING                                                    ║\n")
        IO.write("║ Version: #{String.pad_trailing(to_string(version), 59)}║\n")
        IO.write("║ Active cases: #{String.pad_leading(to_string(active_cases), 4)}                                                  ║\n")
        IO.write("║ Last poll: #{String.pad_trailing(ts_short, 57)}║\n")

      _ ->
        # nil, %{status: "offline"}, or any other value
        IO.write("║ Status:  OFFLINE                                                    ║\n")
        IO.write("║ Start with: make run  (in ~/yawlv6)                                 ║\n")
        IO.write("║ Engine URL: #{String.pad_trailing(yawl_engine_url(), 56)}║\n")
    end

    IO.write("╚═════════════════════════════════════════════════════════════════════╝\n")
  end

  # Sparkline helper: convert pass rates to Unicode bar chart
  defp render_sparkline(spc_history) do
    chars = ["░", "▒", "▓", "█"]

    sparkline_str =
      spc_history
      |> Enum.take(-20)
      |> Enum.map(fn rate ->
        index = Float.round(rate * 3) |> trunc() |> min(3)
        Enum.at(chars, index, "░")
      end)
      |> Enum.join("")

    String.pad_trailing(sparkline_str, 40)
  end

  defp render_footer(pass_rate, pass_count, fail_count) do
    total = pass_count + fail_count

    footer =
      if total > 0 do
        """
        ╔═════════════════════════════════════════════════════════════════════╗
        ║  Cumulative: #{String.pad_leading("#{pass_count}/#{total}", 4)} passed (#{String.pad_leading(Float.to_string(pass_rate), 5)}%) │ Jaeger: localhost:16686                ║
        ╚═════════════════════════════════════════════════════════════════════╝
        """
      else
        """
        ╔═════════════════════════════════════════════════════════════════════╗
        ║  Cumulative: 0/0 passed (0.0%) │ Jaeger: localhost:16686                ║
        ╚═════════════════════════════════════════════════════════════════════╝
        """
      end

    IO.write(footer)
  end

  # YAWL Engine Polling

  defp yawl_engine_url do
    System.get_env("YAWL_ENGINE_URL") || @yawl_default_url
  end

  defp poll_yawl_engine do
    base_url = yawl_engine_url()
    health_url = base_url <> "/health"

    case Req.request(url: health_url, method: :get, receive_timeout: 5_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        version = extract_version(body)
        timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
        active_cases = fetch_active_case_count(base_url)

        %{
          status: "running",
          version: version,
          timestamp: timestamp,
          active_cases: active_cases
        }

      {:ok, %{status: status}} ->
        Logger.debug("[Dashboard] YAWL health returned HTTP #{status}")
        %{status: "offline"}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        Logger.debug("[Dashboard] YAWL engine not reachable at #{base_url}")
        %{status: "offline"}

      {:error, reason} ->
        Logger.debug("[Dashboard] YAWL health poll failed: #{inspect(reason)}")
        %{status: "offline"}
    end
  end

  # Extract version string from health JSON response (or body string)
  defp extract_version(body) when is_map(body) do
    Map.get(body, "version") || Map.get(body, "engineVersion") || "unknown"
  end

  defp extract_version(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} -> extract_version(map)
      _ -> "unknown"
    end
  end

  defp extract_version(_), do: "unknown"

  # Fetch running case count from Interface A (best-effort; returns 0 on error)
  defp fetch_active_case_count(base_url) do
    ia_url = base_url <> "/ia"

    case Req.request(url: ia_url, method: :get, params: %{"action" => "getAllRunningCases"}, receive_timeout: 5_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        count_cases_in_xml(body)

      _ ->
        0
    end
  end

  # Count <caseID> elements in YAWL getAllRunningCases XML response
  defp count_cases_in_xml(body) when is_binary(body) do
    body
    |> String.split("<caseID>")
    |> length()
    |> Kernel.-(1)
    |> max(0)
  end

  defp count_cases_in_xml(_), do: 0

  # Helpers

  defp validate_and_process_payload(payload, state) when is_map(payload) do
    with {:ok, iteration} <- validate_field(payload, :iteration, &is_integer/1),
         {:ok, scenarios} <- validate_field(payload, :scenarios, &is_list/1),
         {:ok, pass_count} <- validate_field(payload, :pass_count, &is_integer/1),
         {:ok, fail_count} <- validate_field(payload, :fail_count, &is_integer/1) do
      Logger.debug(
        "Wave 12 dashboard received iteration result | iteration=#{iteration} | pass_count=#{pass_count} | fail_count=#{fail_count}"
      )

      # Extract YAWLv6 scenario if present
      yawlv6_result =
        Enum.find(scenarios, &match?(%{"id" => "yawl_v6_checkpoint"}, &1)) || nil

      # Store in ETS
      case :ets.insert(@ets_table, {{iteration, :payload}, payload}) do
        true ->
          Logger.debug("Wave 12 dashboard ETS insert payload succeeded | iteration=#{iteration}")

          :telemetry.execute([:jtbd, :dashboard, :ets_insert], %{
            iteration: iteration,
            record_type: "payload"
          })

        false ->
          Logger.error("Wave 12 dashboard ETS insert payload failed | iteration=#{iteration}")
      end

      case :ets.insert(@ets_table, {{iteration, :timestamp}, DateTime.utc_now()}) do
        true ->
          Logger.debug("Wave 12 dashboard ETS insert timestamp succeeded | iteration=#{iteration}")

        false ->
          Logger.error("Wave 12 dashboard ETS insert timestamp failed | iteration=#{iteration}")
      end

      # Store YAWLv6 snapshot if present
      if yawlv6_result do
        case :ets.insert(@ets_table, {:yawlv6_latest, yawlv6_result}) do
          true ->
            Logger.debug("Wave 12 dashboard YAWLv6 snapshot stored | iteration=#{iteration}")

          false ->
            Logger.error("Wave 12 dashboard YAWLv6 snapshot failed | iteration=#{iteration}")
        end
      end

      # Update state
      new_state = %{
        state
        | current_iteration: iteration,
          current_results: build_result_map(scenarios),
          pass_count: state.pass_count + pass_count,
          fail_count: state.fail_count + fail_count,
          last_update: DateTime.utc_now(),
          yawlv6: yawlv6_result
      }

      Logger.info(
        "Wave 12 dashboard state updated | iteration=#{iteration} | cumulative_pass=#{new_state.pass_count} | cumulative_fail=#{new_state.fail_count}"
      )

      :telemetry.execute([:jtbd, :dashboard, :iteration_received], %{
        iteration: iteration,
        pass_count: pass_count,
        fail_count: fail_count,
        cumulative_pass: new_state.pass_count,
        cumulative_fail: new_state.fail_count
      })

      {:ok, new_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_and_process_payload(_payload, _state) do
    {:error, :invalid_payload_format}
  end

  defp validate_field(payload, field, validator) when is_map(payload) do
    case Map.fetch(payload, field) do
      {:ok, value} ->
        if validator.(value) do
          {:ok, value}
        else
          {:error, {:invalid_type, field}}
        end

      :error ->
        {:error, {:missing_field, field}}
    end
  end

  defp build_result_map(scenarios) when is_list(scenarios) do
    scenarios
    |> Enum.filter(&is_valid_scenario/1)
    |> Enum.map(fn scenario ->
      {
        String.to_atom(scenario.id),
        %{
          outcome: String.to_atom(scenario.outcome),
          latency_ms: scenario.latency_ms,
          system: scenario.system
        }
      }
    end)
    |> Map.new()
  end

  defp build_result_map(_scenarios) do
    %{}
  end

  # Process DMAIC metadata for SPC and RevOps tracking
  defp process_dmaic_metadata(metadata, state) when is_map(metadata) do
    # Extract metadata fields with defaults
    iteration = Map.get(metadata, :iteration, state.current_iteration)
    pass_rate = Map.get(metadata, :pass_rate, 0.0)
    scenario = Map.get(metadata, :scenario, nil)
    latency_ms = Map.get(metadata, :latency_ms, 0)

    # Update SPC history (maintain 50-item ring buffer)
    updated_spc_history =
      (state.spc_history ++ [pass_rate])
      |> Enum.take(-50)

    # Recompute SPC statistics
    updated_spc_stats = compute_spc_stats(updated_spc_history)

    # Update RevOps funnel if scenario is in the funnel stages
    updated_revops = update_revops_funnel(state.revops_funnel, scenario)

    # Build scenario result for DMAIC phase bucketing
    scenario_result = %{
      scenario: scenario,
      iteration: iteration,
      pass_count: trunc(pass_rate * 12),  # Approximation for display
      fail_count: trunc((1.0 - pass_rate) * 12),
      latency_ms: latency_ms
    }

    # Update scenario results (maintain 20-item ring buffer)
    updated_scenario_results =
      (state.scenario_results ++ [scenario_result])
      |> Enum.take(-20)

    # Update YAWLv6 snapshot if scenario is checkpoint
    updated_yawlv6_sim =
      if scenario == :yawl_v6_checkpoint do
        Map.get(state, :yawlv6_sim, nil)
      else
        state.yawlv6_sim
      end

    # Check for out-of-control SPC conditions (pass_rate < LCL)
    lcl = Map.get(updated_spc_stats, :lcl, 0.0)
    if pass_rate < lcl do
      Logger.warning(
        "SPC out of control: pass_rate=#{Float.round(pass_rate * 100, 1)}% < LCL=#{Float.round(lcl * 100, 1)}% | iteration=#{iteration}"
      )
    end

    %{
      state
      | spc_history: updated_spc_history,
        spc_stats: updated_spc_stats,
        revops_funnel: updated_revops,
        scenario_results: updated_scenario_results,
        yawlv6_sim: updated_yawlv6_sim
    }
  end

  defp process_dmaic_metadata(_metadata, state) do
    state
  end

  # Compute SPC statistics: mean, sigma, UCL, LCL
  defp compute_spc_stats(spc_history) when is_list(spc_history) and length(spc_history) > 0 do
    count = length(spc_history)
    mean = Enum.sum(spc_history) / count

    # Calculate standard deviation
    variance =
      spc_history
      |> Enum.map(fn rate -> (rate - mean) * (rate - mean) end)
      |> Enum.sum()
      |> then(&(&1 / count))

    sigma = :math.sqrt(variance)

    # 3-sigma control limits (95.7% of variation)
    ucl = min(1.0, mean + 3 * sigma)
    lcl = max(0.0, mean - 3 * sigma)

    %{
      mean: mean,
      sigma: sigma,
      ucl: ucl,
      lcl: lcl
    }
  end

  defp compute_spc_stats(_) do
    %{mean: 0.0, sigma: 0.0, ucl: 1.0, lcl: 0.0}
  end

  # Update RevOps funnel based on scenario
  defp update_revops_funnel(funnel, scenario) when is_map(funnel) do
    case scenario do
      :icp_qualification ->
        # ICP qualification moves contacts to qualified stage
        qualified = trunc(funnel.contacts * 0.20)
        Map.put(funnel, :qualified, qualified)

      :outreach_sequence_execution ->
        # Outreach moves qualified to enrolled
        enrolled = trunc(funnel.qualified * 0.20)
        Map.put(funnel, :enrolled, enrolled)

      :deal_progression ->
        # Deal progression creates deals
        deals = trunc(funnel.enrolled * 0.20)
        Map.put(funnel, :deals, deals)

      :contract_closure ->
        # Contracts convert deals to signed contracts
        contracts = trunc(funnel.deals * 0.20)
        Map.put(funnel, :contracts, contracts)

      _ ->
        funnel
    end
  end

  defp update_revops_funnel(funnel, _) do
    funnel
  end

  @doc """
  Advance the RevOps funnel based on a passing scenario result.
  Failing scenarios do NOT advance the funnel (unlike the internal update_revops_funnel/2).
  """
  @spec update_funnel_from_scenario(map(), map()) :: map()
  def update_funnel_from_scenario(funnel, %{scenario: scenario, outcome: :pass}) do
    update_revops_funnel(funnel, scenario)
  end

  def update_funnel_from_scenario(funnel, _failed_or_unknown), do: funnel

  @doc """
  Calculate 3-sigma SPC control limits from a list of pass-rate floats.
  Returns %{mean: float, sigma: float, ucl: float, lcl: float}.
  """
  @spec calculate_control_limits([float()]) :: map()
  def calculate_control_limits(history) when is_list(history) do
    compute_spc_stats(history)
  end

  defp is_valid_scenario(scenario) when is_map(scenario) do
    with {:ok, _id} <- validate_field(scenario, :id, &is_binary/1),
         {:ok, _outcome} <- validate_field(scenario, :outcome, &is_binary/1),
         {:ok, _latency} <- validate_field(scenario, :latency_ms, &is_integer/1),
         {:ok, _system} <- validate_field(scenario, :system, &is_binary/1) do
      true
    else
      {:error, _reason} -> false
    end
  end

  defp is_valid_scenario(_scenario) do
    false
  end

  defp calculate_pass_rate(passes, fails) when passes + fails > 0 do
    Float.round(passes / (passes + fails) * 100, 1)
  end

  defp calculate_pass_rate(_passes, _fails) do
    0.0
  end

end
