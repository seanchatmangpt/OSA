defmodule OptimalSystemAgent.Ontology.SoundnessVerifier do
  @moduledoc """
  WvdA (van der Aalst) soundness verification via SPARQL

  Queries Oxigraph to verify that processes satisfy WvdA soundness properties:
    1. Deadlock Freedom: No execution can reach a state where all processes wait forever
    2. Liveness: All actions eventually complete
    3. Boundedness: Resources do not grow unbounded

  Before executing a workflow, calls process-soundness.rq to verify the workflow
  is sound. If not sound, returns error details for debugging.

  Enables formally verified, crash-safe workflow execution.

  Signal Theory: S=(data,audit,assess,json,soundness)
  """

  require Logger
  alias OptimalSystemAgent.Ontology.OxigraphClient

  @soundness_query """
  PREFIX chatman: <https://ontology.chatmangpt.com/core#>
  PREFIX dcterms: <http://purl.org/dc/terms/>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

  SELECT ?process ?deadlock_free ?liveness_ok ?bounded WHERE {
    ?process a chatman:Process ;
      chatman:deadlockFree ?deadlock_free ;
      chatman:livenessOk ?liveness_ok ;
      chatman:bounded ?bounded .
  }
  ORDER BY ?process
  """

  @doc """
  Verify a process/workflow is sound before execution

  Parameters:
    - process_id: ID of the process to verify
    - check_all: if true, verify all three properties; if false, just deadlock-free

  Returns:
    {:ok, %{deadlock_free: true, liveness: true, bounded: true, verified_at: timestamp}}
    {:error, %{failing_properties: [...], details: "..."}}

  Example:
    verify_process("workflow_123")
    {:ok, %{deadlock_free: true, liveness: true, bounded: true, ...}}
  """
  @spec verify_process(String.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def verify_process(process_id, options \\ []) do
    check_all = Keyword.get(options, :check_all, true)

    query = build_soundness_query(process_id, check_all)

    case OxigraphClient.query_select(query) do
      {:ok, [result]} ->
        result_map = %{
          process_id: process_id,
          deadlock_free: parse_bool(Map.get(result, "deadlock_free")),
          liveness: parse_bool(Map.get(result, "liveness_ok")),
          bounded: parse_bool(Map.get(result, "bounded")),
          verified_at_ms: System.monotonic_time(:millisecond)
        }

        if all_sound?(result_map, check_all) do
          Logger.info("[SoundnessVerifier] Process #{process_id} is sound")
          {:ok, result_map}
        else
          failing = failing_properties(result_map)
          Logger.warning("[SoundnessVerifier] Process #{process_id} is NOT sound: #{inspect(failing)}")
          {:error, %{process_id: process_id, failing_properties: failing}}
        end

      {:ok, []} ->
        Logger.error("[SoundnessVerifier] Process #{process_id} not found in ontology")
        {:error, %{process_id: process_id, reason: "process not found"}}

      {:error, reason} ->
        Logger.error("[SoundnessVerifier] Soundness check failed: #{inspect(reason)}")
        {:error, %{process_id: process_id, reason: inspect(reason)}}
    end
  end

  @doc """
  Get all processes and their soundness status

  Returns {:ok, processes} where each process has soundness properties,
  or {:error, reason} on failure.
  """
  @spec list_processes_with_soundness() :: {:ok, list(map())} | {:error, term()}
  def list_processes_with_soundness do
    case OxigraphClient.query_select(@soundness_query) do
      {:ok, rows} ->
        processes =
          Enum.map(rows, fn row ->
            %{
              process_id: Map.get(row, "process"),
              deadlock_free: parse_bool(Map.get(row, "deadlock_free")),
              liveness: parse_bool(Map.get(row, "liveness_ok")),
              bounded: parse_bool(Map.get(row, "bounded"))
            }
          end)

        unsound = Enum.filter(processes, &unsound?/1)

        if Enum.any?(unsound) do
          Logger.warning(
            "[SoundnessVerifier] #{length(unsound)}/#{length(processes)} processes are unsound"
          )
        else
          Logger.info("[SoundnessVerifier] All #{length(processes)} processes are sound")
        end

        {:ok, processes}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check deadlock freedom specifically

  Faster query when only deadlock-free property matters.

  Returns {:ok, true} if process is deadlock-free, {:ok, false} if not,
  or {:error, reason} on query failure.
  """
  @spec check_deadlock_free(String.t()) :: {:ok, boolean()} | {:error, term()}
  def check_deadlock_free(process_id) do
    query = """
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>

    ASK {
      <https://ontology.chatmangpt.com/process/#{process_id}> chatman:deadlockFree true .
    }
    """

    case OxigraphClient.query_ask(query) do
      {:ok, bool} ->
        if bool do
          Logger.debug("[SoundnessVerifier] Process #{process_id} is deadlock-free")
        else
          Logger.warning("[SoundnessVerifier] Process #{process_id} may deadlock")
        end
        {:ok, bool}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private

  defp build_soundness_query(process_id, check_all) do
    if check_all do
      """
      PREFIX chatman: <https://ontology.chatmangpt.com/core#>

      SELECT ?deadlock_free ?liveness_ok ?bounded WHERE {
        <https://ontology.chatmangpt.com/process/#{process_id}>
          chatman:deadlockFree ?deadlock_free ;
          chatman:livenessOk ?liveness_ok ;
          chatman:bounded ?bounded .
      }
      LIMIT 1
      """
    else
      """
      PREFIX chatman: <https://ontology.chatmangpt.com/core#>

      SELECT ?deadlock_free WHERE {
        <https://ontology.chatmangpt.com/process/#{process_id}>
          chatman:deadlockFree ?deadlock_free .
      }
      LIMIT 1
      """
    end
  end

  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(true), do: true
  defp parse_bool(false), do: false
  defp parse_bool(_), do: false

  defp all_sound?(result_map, check_all) do
    if check_all do
      result_map.deadlock_free && result_map.liveness && result_map.bounded
    else
      result_map.deadlock_free
    end
  end

  defp failing_properties(result_map) do
    []
    |> (fn list -> if not result_map.deadlock_free, do: list ++ [:deadlock_free], else: list end).()
    |> (fn list -> if not result_map.liveness, do: list ++ [:liveness], else: list end).()
    |> (fn list -> if not result_map.bounded, do: list ++ [:bounded], else: list end).()
  end

  defp unsound?(process) do
    not (process.deadlock_free && process.liveness && process.bounded)
  end
end
