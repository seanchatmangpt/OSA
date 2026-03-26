defmodule OptimalSystemAgent.Board.BriefingGenerator do
  @moduledoc """
  Board Briefing Translator — Board Chair Intelligence System.

  Queries L3 RDF from Oxigraph and generates a board-level natural language
  briefing using Claude Sonnet. The output contains no process maps, no
  technical metrics, and no infrastructure terms — only business outcomes.

  ## Flow

    1. Query Oxigraph for L3 `bos:BoardIntelligence` triples via SPARQL SELECT
    2. Parse RDF result into a plain `%{property => value}` map
    3. Check freshness — warn if `bos:lastRefreshed` > 2 hours old
    4. Build LLM prompt via `BriefingTemplate.llm_prompt/1`
    5. Call `Providers.Anthropic` (claude-sonnet-4-6, max_tokens: 800)
    6. Armstrong fallback: rescue LLM failure → `BriefingTemplate.render_structured/1`
    7. Store briefing in ETS `:osa_board_briefings`
    8. Return `{:ok, briefing_text}`

  ## Armstrong Fault Tolerance

  - LLM failure → rescue → structured fallback (never crashes, always delivers)
  - Oxigraph failure → `{:error, :oxigraph_unavailable}` (caller handles retry)
  - ETS `:osa_board_briefings` initialized in `init/1` if not exists
  - GenServer call timeout: 35 s (LLM + Oxigraph combined)

  ## WvdA Soundness

  - All external calls have explicit timeouts: Oxigraph 10 s, LLM 30 s
  - ETS table bounded: single `{:last, text, datetime}` key, no growth
  - GenServer call timeout 35 s prevents indefinite caller blocking
  """

  use GenServer
  require Logger

  alias OptimalSystemAgent.Board.BriefingTemplate
  alias OptimalSystemAgent.Providers.Anthropic

  @oxigraph_url System.get_env("OXIGRAPH_URL", "http://localhost:7878")
  @oxigraph_timeout_ms 10_000
  @table :osa_board_briefings

  # Two-hour freshness threshold in seconds
  @staleness_threshold_s 7_200

  @sparql_query """
  PREFIX bos: <http://businessos.dev/ontology#>
  SELECT ?property ?value
  WHERE {
    ?briefing a bos:BoardIntelligence ;
      ?property ?value .
    FILTER(?property != rdf:type)
  }
  ORDER BY ?property
  """

  # ── Public API ──────────────────────────────────────────────────────────────

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate a board briefing from the current L3 RDF state.

  Returns `{:ok, briefing_text}` on success.
  Returns `{:error, :oxigraph_unavailable}` when Oxigraph cannot be reached.

  GenServer call timeout: 35 s.
  """
  @spec generate() :: {:ok, String.t()} | {:error, :oxigraph_unavailable | term()}
  def generate do
    GenServer.call(__MODULE__, :generate, 35_000)
  end

  @doc """
  Returns the last generated briefing stored in ETS.

  Returns `{:ok, %{text: text, generated_at: datetime, l3_freshness: atom}}` or
  `{:error, :none}` when no briefing has been generated yet.
  """
  @spec last_briefing() ::
          {:ok, %{text: String.t(), generated_at: DateTime.t(), l3_freshness: atom()}}
          | {:error, :none}
  def last_briefing do
    GenServer.call(__MODULE__, :last_briefing, 5_000)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    ensure_ets_table()
    Logger.info("[Board.BriefingGenerator] Started — Oxigraph: #{@oxigraph_url}")
    {:ok, %{}}
  end

  @impl true
  def handle_call(:generate, _from, state) do
    result = do_generate()
    {:reply, result, state}
  end

  @impl true
  def handle_call(:last_briefing, _from, state) do
    result =
      case :ets.lookup(@table, :last) do
        [{:last, text, generated_at, l3_freshness}] ->
          {:ok, %{text: text, generated_at: generated_at, l3_freshness: l3_freshness}}

        [] ->
          {:error, :none}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Internal pipeline ────────────────────────────────────────────────────────

  defp do_generate do
    with {:ok, sparql_rows} <- query_oxigraph(),
         {:ok, rdf_map} <- parse_rdf(sparql_rows) do
      {staleness_warning, l3_freshness} = check_freshness(rdf_map)
      briefing_text = build_briefing(rdf_map, staleness_warning)
      store_briefing(briefing_text, l3_freshness)
      {:ok, briefing_text}
    else
      {:error, :oxigraph_unavailable} = err ->
        Logger.warning("[Board.BriefingGenerator] Oxigraph unavailable — cannot generate briefing")
        err

      {:error, reason} ->
        Logger.warning("[Board.BriefingGenerator] Generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ── Step 1: Query Oxigraph ────────────────────────────────────────────────

  defp query_oxigraph do
    url = "#{@oxigraph_url}/query"

    headers = [
      {"accept", "application/sparql-results+json"},
      {"content-type", "application/sparql-query"}
    ]

    case Req.post(url,
           body: @sparql_query,
           headers: headers,
           receive_timeout: @oxigraph_timeout_ms
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, extract_sparql_rows(body)}

      {:ok, %{status: status}} ->
        Logger.warning("[Board.BriefingGenerator] Oxigraph returned HTTP #{status}")
        {:error, :oxigraph_unavailable}

      {:error, reason} ->
        Logger.warning("[Board.BriefingGenerator] Oxigraph connection failed: #{inspect(reason)}")
        {:error, :oxigraph_unavailable}
    end
  rescue
    _ ->
      {:error, :oxigraph_unavailable}
  end

  # ── Step 2: Parse SPARQL results into rdf_map ─────────────────────────────

  defp extract_sparql_rows(body) when is_map(body) do
    rows = get_in(body, ["results", "bindings"]) || []

    Enum.map(rows, fn row ->
      property = get_in(row, ["property", "value"]) || ""
      value = get_in(row, ["value", "value"]) || ""
      {property, value}
    end)
  end

  defp extract_sparql_rows(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> extract_sparql_rows(parsed)
      _ -> []
    end
  end

  defp extract_sparql_rows(_), do: []

  defp parse_rdf(rows) do
    rdf_map =
      Enum.reduce(rows, %{}, fn {property, value}, acc ->
        # Normalise long URIs to prefixed form for template matching
        key = uri_to_prefixed(property)
        Map.put(acc, key, value)
      end)

    {:ok, rdf_map}
  end

  defp uri_to_prefixed(uri) when is_binary(uri) do
    bos_ns = "http://businessos.dev/ontology#"

    if String.starts_with?(uri, bos_ns) do
      local = String.replace_prefix(uri, bos_ns, "")
      "bos:#{local}"
    else
      uri
    end
  end

  defp uri_to_prefixed(other), do: other

  # ── Step 3: Check freshness ──────────────────────────────────────────────

  defp check_freshness(rdf_map) do
    case Map.get(rdf_map, "bos:lastRefreshed") do
      nil ->
        {"", :unknown}

      refreshed_str ->
        case DateTime.from_iso8601(refreshed_str) do
          {:ok, refreshed_at, _offset} ->
            age_s = DateTime.diff(DateTime.utc_now(), refreshed_at, :second)

            if age_s > @staleness_threshold_s do
              hours = div(age_s, 3600)
              warning = "[Note: Data was last refreshed #{hours} hours ago and may not reflect current conditions.]\n"
              {warning, :stale}
            else
              {"", :fresh}
            end

          _ ->
            {"", :unknown}
        end
    end
  end

  # ── Steps 4–6: LLM generation with Armstrong fallback ────────────────────

  defp build_briefing(rdf_map, staleness_warning) do
    prompt = BriefingTemplate.llm_prompt(rdf_map)

    messages = [
      %{role: "user", content: prompt}
    ]

    briefing_body =
      try do
        case Anthropic.chat(messages,
               model: "claude-sonnet-4-6",
               max_tokens: 800
             ) do
          {:ok, %{content: text}} when is_binary(text) and text != "" ->
            text

          _other ->
            Logger.warning("[Board.BriefingGenerator] LLM returned unexpected result — using structured fallback")
            BriefingTemplate.render_structured(rdf_map)
        end
      rescue
        e ->
          Logger.warning(
            "[Board.BriefingGenerator] LLM call raised #{Exception.message(e)} — using structured fallback"
          )

          BriefingTemplate.render_structured(rdf_map)
      end

    case staleness_warning do
      "" -> briefing_body
      warning -> prepend_staleness_warning(briefing_body, warning)
    end
  end

  defp prepend_staleness_warning(briefing, warning) do
    # Insert warning after the first line (the briefing header)
    lines = String.split(briefing, "\n", parts: 2)

    case lines do
      [header, rest] -> "#{header}\n#{warning}\n#{rest}"
      _ -> "#{warning}\n#{briefing}"
    end
  end

  # ── Step 7: Store in ETS ─────────────────────────────────────────────────

  defp store_briefing(text, l3_freshness) do
    ensure_ets_table()
    :ets.insert(@table, {:last, text, DateTime.utc_now(), l3_freshness})
  end

  defp ensure_ets_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set])
    end

    :ok
  end
end
