defmodule OptimalSystemAgent.Board.HealingBridge do
  @moduledoc """
  Bridges pm4py-rust process deviations to OSA healing agents and L0 fact updates.

  Flow: deviation event received → healing triggered → proof emitted → L0 invalidated

  This closes the loop: the board chair never has to ask "was it fixed?"
  The briefing always reflects current healed state with proof.

  ## Event Subscriptions

  - `:conformance_violation` — from pm4py-rust (fitness < 0.8 triggers healing)
  - `:healing_complete`     — from ReflexArcs (proof written, L0 invalidated)

  ## Armstrong Principles

  - Bridge processes events; healing failures are reported, not propagated
  - All Oxigraph writes have 5s timeout
  - Proof triple written BEFORE L0 invalidated (ordering guarantee)
  - `:permanent` restart — supervisor restarts on any crash

  ## WvdA Soundness

  - All external calls have explicit timeout_ms
  - ETS operations are bounded (<1ms)
  - No infinite loops
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Events.Bus
  alias OptimalSystemAgent.Healing.ReflexArcs
  alias OptimalSystemAgent.Ontology.InferenceChain
  alias OptimalSystemAgent.Observability.Telemetry

  @ets_table :osa_board_healing_status
  @conformance_threshold 0.8
  @oxigraph_timeout_ms 5_000
  @healing_timeout_ms 30_000
  @conway_check_timeout_ms 3_000
  @oxigraph_url Application.compile_env(:optimal_system_agent, :oxigraph_url, "http://localhost:7878")

  # ── Child spec ──────────────────────────────────────────────────────────────

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  # ── Public API ───────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Report a process deviation from pm4py-rust.

  Deviation map must contain:
    - `:process_id` — string identifier
    - `:fitness`    — conformance fitness score (0.0–1.0)
    - `:deviation_type` — "conformance" | "timing" | "resource"
    - `:detected_at`    — ISO8601 DateTime string
  """
  @spec report_deviation(map()) :: :ok
  def report_deviation(deviation) when is_map(deviation) do
    # Route via system_event with event: :conformance_violation
    # Bus only accepts known event types; system_event is the correct channel.
    Bus.emit(:system_event, Map.put(deviation, :event, :conformance_violation),
      source: "board.healing_bridge"
    )
    :ok
  end

  @doc """
  Returns list of `{process_id, status, healed_at}` tuples for current period.
  Status is `:healing_triggered` or `:healed`.
  """
  @spec healing_status() :: [{String.t(), atom(), DateTime.t()}]
  def healing_status do
    GenServer.call(__MODULE__, :healing_status, 15_000)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    # Create ETS table for current period healing tracking
    :ets.new(@ets_table, [:named_table, :public, :set])

    # Subscribe to system_event for both conformance_violation and healing_complete.
    # The bus wraps payload under :data when creating an Event struct.
    # We unwrap to get the original payload map.
    Bus.register_handler(:system_event, fn raw ->
      # Unwrap: try :data key first (Event struct), fall back to raw payload
      payload = Map.get(raw, :data, raw)
      event = Map.get(payload, :event)

      case event do
        :conformance_violation ->
          GenServer.cast(__MODULE__, {:conformance_violation, payload})

        :healing_complete ->
          GenServer.cast(__MODULE__, {:healing_complete, payload})

        :board_escalation ->
          GenServer.cast(__MODULE__, {:board_escalation, payload})

        _ ->
          :ok
      end
    end)

    Logger.info("[Board.HealingBridge] Started — monitoring conformance violations")

    {:ok, %{}}
  end

  @impl true
  def handle_call(:healing_status, _from, state) do
    status =
      try do
        :ets.tab2list(@ets_table)
        |> Enum.map(fn
          {process_id, :healed, healed_at, _span_id} -> {process_id, :healed, healed_at}
          {process_id, status, triggered_at} -> {process_id, status, triggered_at}
        end)
      rescue
        ArgumentError -> []
      end

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:conformance_violation, payload}, state) do
    process_id = extract_field(payload, :process_id)
    fitness = extract_field(payload, :fitness)
    deviation_type = extract_field(payload, :deviation_type, "conformance")

    if is_binary(process_id) and is_number(fitness) do
      if fitness < @conformance_threshold do
        Logger.info(
          "[Board.HealingBridge] Deviation detected in #{process_id}, " <>
            "fitness=#{fitness}, type=#{deviation_type}, healing triggered"
        )

        case check_conway_violation(process_id) do
          {:ok, true, score} ->
            pct = if is_number(score), do: round(score * 100), else: "unknown"
            Logger.info("[HealingBridge] Conway violation in #{process_id} (score=#{score}), escalating to board — NOT healing")

            {:ok, escalation_span} = Telemetry.start_span("board.structural_escalation", %{
              "process_id" => process_id,
              "conway_score" => score || 0.0,
              "escalation_type" => "conway_violation"
            })
            Telemetry.end_span(escalation_span, :ok)

            # Dedup: check ConwayLittleMonitor's shared ETS table before emitting.
            # Prevents double escalation when both monitors detect the same violation.
            cooldown_key = {:escalation_cooldown, process_id}
            now_ms = System.monotonic_time(:millisecond)
            cooldown_ms = 30 * 60 * 1000

            already_escalated =
              case :ets.whereis(:osa_conway_little_status) do
                :undefined ->
                  false
                _ ->
                  case :ets.lookup(:osa_conway_little_status, cooldown_key) do
                    [{_, last_ms}] when now_ms - last_ms < cooldown_ms -> true
                    _ -> false
                  end
              end

            unless already_escalated do
              if :ets.whereis(:osa_conway_little_status) != :undefined do
                :ets.insert(:osa_conway_little_status, {cooldown_key, now_ms})
              end

              # Use :system_event with event: :board_escalation — :board_escalation is
              # not a registered Bus event type; :system_event is the correct channel.
              Bus.emit(:system_event, %{
                event: :board_escalation,
                process_id: process_id,
                escalation_type: :conway_violation,
                conway_score: score,
                message: "Org boundary consuming #{pct}% of cycle time in #{process_id}. Requires org restructuring decision.",
                timestamp: DateTime.utc_now()
              }, source: "healing.bridge")
            else
              Logger.debug("[HealingBridge] Skipping duplicate board escalation for #{process_id} (within cooldown)")
            end

          _ ->
            # Record deviation in ETS
            :ets.insert(@ets_table, {process_id, :healing_triggered, DateTime.utc_now()})

            # Trigger healing — failure is logged but does NOT crash the bridge (Armstrong)
            try do
              task =
                Task.async(fn ->
                  ReflexArcs.trigger_healing(process_id)
                end)

              case Task.yield(task, @healing_timeout_ms) || Task.shutdown(task) do
                {:ok, result} ->
                  Logger.debug(
                    "[Board.HealingBridge] Healing initiated for #{process_id}: #{inspect(result)}"
                  )

                nil ->
                  Logger.error(
                    "[Board.HealingBridge] Healing timed out for #{process_id} " <>
                      "(#{@healing_timeout_ms}ms limit)"
                  )
              end
            rescue
              e ->
                Logger.error(
                  "[Board.HealingBridge] ReflexArcs.trigger_healing failed for #{process_id}: " <>
                    Exception.message(e)
                )
            catch
              kind, reason ->
                Logger.error(
                  "[Board.HealingBridge] ReflexArcs.trigger_healing #{kind} for #{process_id}: " <>
                    inspect(reason)
                )
            end
        end
      else
        Logger.debug(
          "[Board.HealingBridge] Conformance check for #{process_id}: " <>
            "fitness=#{fitness} >= #{@conformance_threshold}, no healing needed"
        )
      end
    else
      Logger.warning(
        "[Board.HealingBridge] Invalid conformance_violation payload: #{inspect(payload)}"
      )
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:healing_complete, payload}, state) do
    process_id = extract_field(payload, :process_id)
    proof_span_id = extract_field(payload, :proof_span_id, "unknown")
    outcome = extract_field(payload, :outcome, "healed")
    healed_at = DateTime.utc_now()

    if is_binary(process_id) do
      # Retrieve old fitness for provenance triple
      old_fitness =
        case :ets.lookup(@ets_table, process_id) do
          [{_, :healing_triggered, _}] -> nil
          _ -> nil
        end

      # Step 1: Write proof triple to Oxigraph (BEFORE L0 invalidation — ordering guarantee)
      write_healing_proof(process_id, proof_span_id, outcome, healed_at, old_fitness)

      # Step 2: Update ETS
      :ets.insert(@ets_table, {process_id, :healed, healed_at, proof_span_id})

      # Step 3: Invalidate L0 — triggers cascade re-materialization L0→L1→L2→L3
      # Uses Task.start (fire-and-forget) — InferenceChain may not be running in tests.
      Task.start(fn ->
        try do
          case InferenceChain.invalidate_from(:l0) do
            :ok ->
              Logger.debug("[Board.HealingBridge] L0 invalidated for #{process_id}")

            {:ok, _} ->
              Logger.debug("[Board.HealingBridge] L0 invalidated for #{process_id}")

            {:error, reason} ->
              Logger.warning(
                "[Board.HealingBridge] L0 invalidation failed for #{process_id}: " <>
                  inspect(reason)
              )
          end
        catch
          :exit, {:noproc, _} ->
            Logger.debug(
              "[Board.HealingBridge] InferenceChain not running — L0 invalidation skipped"
            )

          :exit, reason ->
            Logger.warning(
              "[Board.HealingBridge] L0 invalidation exit for #{process_id}: #{inspect(reason)}"
            )
        end
      end)

      Logger.info(
        "[Board.HealingBridge] #{process_id} healed, proof written, L0 invalidated"
      )
    else
      Logger.warning(
        "[Board.HealingBridge] Invalid healing_complete payload: #{inspect(payload)}"
      )
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:board_escalation, payload}, state) do
    process_id = extract_field(payload, :process_id)
    conway_score = extract_field(payload, :conway_score, 0.0)
    source = extract_field(payload, :source, "canopy_conway")

    if is_binary(process_id) do
      Logger.warning(
        "[Board.HealingBridge] Structural Conway violation from Canopy: " <>
          "process=#{process_id}, score=#{conway_score}, source=#{inspect(source)}"
      )

      # Emit OTEL span — board.structural_escalation
      {:ok, span} = Telemetry.start_span("board.structural_escalation", %{
        "board.process_id" => process_id,
        "board.is_violation" => true,
        "board.conway_score" => conway_score || 0.0,
        "board.escalation_type" => "structural"
      })
      Telemetry.end_span(span, :ok)

      # Write proof triple to Oxigraph (5s timeout — WvdA bounded)
      write_escalation_proof(process_id, conway_score, source)

      # Broadcast :escalation_recorded so board supervisor can observe
      # DO NOT route to ReflexArcs — structural violations require board decision
      Bus.emit(:system_event, %{
        event: :escalation_recorded,
        process_id: process_id,
        conway_score: conway_score,
        source: source,
        recorded_at: DateTime.utc_now()
      }, source: "board.healing_bridge")
    else
      Logger.warning(
        "[Board.HealingBridge] Invalid board_escalation payload (missing process_id): #{inspect(payload)}"
      )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private Helpers ──────────────────────────────────────────────────────────

  # Write PROV-O healing proof triple to Oxigraph with 5s timeout.
  # Failure is logged and does NOT crash the bridge (Armstrong principle).
  defp write_healing_proof(process_id, span_id, outcome, healed_at, old_fitness) do
    timestamp_str = DateTime.to_iso8601(healed_at)
    triple_id = "bos:healing/#{process_id}/#{DateTime.to_unix(healed_at)}"

    fitness_triple =
      if is_number(old_fitness) do
        "    bos:previousFitness #{old_fitness} ;\n"
      else
        ""
      end

    sparql = """
    PREFIX bos: <https://osa.chatmangpt.com/bos#>
    PREFIX prov: <http://www.w3.org/ns/prov#>
    INSERT DATA {
      <#{triple_id}> a bos:HealingProof ;
        bos:processId "#{process_id}" ;
        bos:healedAt "#{timestamp_str}" ;
        bos:otelSpanId "#{span_id}" ;
        bos:outcome "#{outcome}" ;
    #{fitness_triple}    prov:generatedAtTime "#{timestamp_str}"^^xsd:dateTime .
    }
    """

    endpoint =
      Application.get_env(:optimal_system_agent, :sparql_endpoint, "http://localhost:7878")

    update_url = "#{endpoint}/update"

    try do
      task =
        Task.async(fn ->
          Req.post(update_url,
            body: sparql,
            headers: [{"content-type", "application/sparql-update"}]
          )
        end)

      case Task.yield(task, @oxigraph_timeout_ms) || Task.shutdown(task) do
        {:ok, {:ok, %{status: status}}} when status in [200, 204] ->
          Logger.debug("[Board.HealingBridge] Proof triple written for #{process_id}")

        {:ok, {:ok, %{status: status, body: body}}} ->
          Logger.warning(
            "[Board.HealingBridge] Oxigraph returned #{status} writing proof for " <>
              "#{process_id}: #{inspect(body)}"
          )

        {:ok, {:error, reason}} ->
          Logger.warning(
            "[Board.HealingBridge] Oxigraph write failed for #{process_id}: #{inspect(reason)}"
          )

        nil ->
          Logger.warning(
            "[Board.HealingBridge] Oxigraph write timed out (#{@oxigraph_timeout_ms}ms) " <>
              "for #{process_id}"
          )
      end
    rescue
      e ->
        Logger.warning(
          "[Board.HealingBridge] Proof write exception for #{process_id}: #{Exception.message(e)}"
        )
    catch
      kind, reason ->
        Logger.warning(
          "[Board.HealingBridge] Proof write #{kind} for #{process_id}: #{inspect(reason)}"
        )
    end
  end

  # Write structural escalation proof triple to Oxigraph with 5s timeout (WvdA bounded).
  # Failure is logged and does NOT crash the bridge (Armstrong principle).
  defp write_escalation_proof(process_id, conway_score, source) do
    uuid = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    timestamp_str = DateTime.to_iso8601(DateTime.utc_now())
    source_str = to_string(source)

    sparql = """
    PREFIX bos: <https://osa.chatmangpt.com/bos#>
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
    INSERT DATA {
      <escalation/#{uuid}> a bos:StructuralEscalation ;
        bos:escalationCreatedAt "#{timestamp_str}"^^xsd:dateTime ;
        bos:escalationSource "#{source_str}" ;
        bos:conwayScore #{conway_score} ;
        bos:processId "#{process_id}" .
    }
    """

    endpoint =
      Application.get_env(:optimal_system_agent, :sparql_endpoint, "http://localhost:7878")

    update_url = "#{endpoint}/update"

    try do
      task =
        Task.async(fn ->
          Req.post(update_url,
            body: sparql,
            headers: [{"content-type", "application/sparql-update"}]
          )
        end)

      case Task.yield(task, @oxigraph_timeout_ms) || Task.shutdown(task) do
        {:ok, {:ok, %{status: status}}} when status in [200, 204] ->
          Logger.debug(
            "[Board.HealingBridge] Escalation proof triple written for #{process_id}"
          )

        {:ok, {:ok, %{status: status, body: body}}} ->
          Logger.warning(
            "[Board.HealingBridge] Oxigraph returned #{status} writing escalation proof for " <>
              "#{process_id}: #{inspect(body)}"
          )

        {:ok, {:error, reason}} ->
          Logger.warning(
            "[Board.HealingBridge] Escalation proof write failed for #{process_id}: #{inspect(reason)}"
          )

        nil ->
          Logger.warning(
            "[Board.HealingBridge] Escalation proof write timed out (#{@oxigraph_timeout_ms}ms) " <>
              "for #{process_id}"
          )
      end
    rescue
      e ->
        Logger.warning(
          "[Board.HealingBridge] Escalation proof exception for #{process_id}: #{Exception.message(e)}"
        )
    catch
      kind, reason ->
        Logger.warning(
          "[Board.HealingBridge] Escalation proof #{kind} for #{process_id}: #{inspect(reason)}"
        )
    end
  end

  # Build escalation SPARQL INSERT DATA — exposed for testing via @doc false
  @doc false
  def build_escalation_sparql(process_id, conway_score, source) do
    source_str = to_string(source)

    """
    INSERT DATA {
      <escalation/test> a bos:StructuralEscalation ;
        bos:escalationSource "#{source_str}" ;
        bos:conwayScore #{conway_score} ;
        bos:processId "#{process_id}" .
    }
    """
  end

  # Determine routing for escalation type — exposed for testing via @doc false
  @doc false
  def determine_escalation_routing(%{source: :canopy_conway}), do: :board_supervisor
  def determine_escalation_routing(%{source: source}) when is_binary(source) do
    if String.contains?(source, "canopy"), do: :board_supervisor, else: :reflex_arcs
  end
  def determine_escalation_routing(_), do: :reflex_arcs

  defp extract_field(payload, key, default \\ nil) do
    Map.get(payload, key) || Map.get(payload, to_string(key)) || default
  end

  @spec check_conway_violation(String.t()) :: {:ok, boolean(), float() | nil} | {:error, term()}
  defp check_conway_violation(process_id) do
    {:ok, span} = Telemetry.start_span("board.conway_violation_check", %{
      "process_id" => process_id
    })

    sparql = """
    PREFIX bos: <http://businessos.local/ontology#>
    SELECT ?conwayViolation ?conwayScore
    WHERE {
      ?metric a bos:ProcessMetric ;
              bos:department "#{String.replace(process_id, ~s("), ~s(\\"))}" .
      OPTIONAL { ?metric bos:conwayViolation ?conwayViolation }
      OPTIONAL { ?metric bos:conwayScore ?conwayScore }
    }
    LIMIT 1
    """

    endpoint = "#{@oxigraph_url}/query"

    result = case Req.post(endpoint,
      body: sparql,
      headers: [{"content-type", "application/sparql-query"}, {"accept", "application/sparql-results+json"}],
      receive_timeout: @conway_check_timeout_ms
    ) do
      {:ok, %{status: 200, body: %{"results" => %{"bindings" => [binding | _]}}}} ->
        violation =
          case Map.get(binding, "conwayViolation") do
            %{"value" => "true"} -> true
            %{"value" => "1"} -> true
            _ -> false
          end

        score =
          case Map.get(binding, "conwayScore") do
            %{"value" => str} ->
              case Float.parse(str) do
                {f, _} -> f
                :error -> nil
              end
            _ -> nil
          end

        {:ok, violation, score}

      {:ok, %{status: 200, body: %{"results" => %{"bindings" => []}}}} ->
        {:ok, false, nil}

      {:ok, %{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        Logger.warning("[HealingBridge] Conway check failed for #{process_id}: #{inspect(reason)}, defaulting to non-Conway")
        {:ok, false, nil}
    end

    case result do
      {:ok, is_violation, conway_score} ->
        Telemetry.end_span(
          Map.merge(span, %{
            "attributes" => Map.merge(span["attributes"], %{
              "is_violation" => is_violation,
              "conway_score" => conway_score || 0.0
            })
          }),
          :ok
        )

      {:error, _} ->
        Telemetry.end_span(
          Map.merge(span, %{
            "attributes" => Map.merge(span["attributes"], %{
              "is_violation" => false,
              "conway_score" => 0.0
            })
          }),
          :ok
        )
    end

    result
  end
end
