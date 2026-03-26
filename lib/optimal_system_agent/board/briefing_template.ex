defmodule OptimalSystemAgent.Board.BriefingTemplate do
  @moduledoc """
  Maps L3 RDF properties to board-level language.

  No LLM is required for the mapping itself. This module provides:

    1. `render_structured/1` — deterministic, human-readable briefing built
       directly from the RDF map. Used as the Armstrong fallback when the LLM
       is unavailable.

    2. `llm_prompt/1` — builds the prompt sent to Claude Sonnet. Instructs the
       model to translate process metrics into board-level business language
       without surfacing technical terms.

  RDF property keys match the L3 `bos:BoardIntelligence` inference chain.
  Values are expected as plain strings or nil.
  """

  alias OptimalSystemAgent.Observability.Telemetry

  @property_labels %{
    "bos:organizationalHealthSummary" => "Overall organizational health",
    "bos:topRisk" => "Highest priority risk",
    "bos:processVelocityTrend" => "Process velocity",
    "bos:complianceStatus" => "Regulatory compliance",
    "bos:weeklyROIDelta" => "Estimated value impact this week",
    "bos:issuesAutoResolved" => "Issues detected and resolved autonomously",
    "bos:issuesPendingEscalation" => "Items requiring board awareness",
    "bos:structuralIssueCount" => "Structural issues requiring your decision",
    "bos:operationalIssueCount" => "Operational issues resolved autonomously",
    "bos:highestConwayScore" => "Worst org boundary bottleneck score",
    "bos:worstQueueStability" => "Most unstable process queue ratio",
    "bos:conwayViolationCount" => "Departments with structural bottlenecks",
    "bos:littlesLawStabilityIndex" => "Average queue stability index",
    "bos:queueGrowthRisk" => "Departments with growing queues"
  }

  # Section-to-property mapping drives the structured fallback layout
  @section_properties %{
    summary: [
      "bos:organizationalHealthSummary",
      "bos:topRisk",
      "bos:complianceStatus"
    ],
    process_health: [
      "bos:processVelocityTrend",
      "bos:issuesAutoResolved"
    ],
    risk_compliance: [
      "bos:topRisk",
      "bos:complianceStatus"
    ],
    velocity: [
      "bos:processVelocityTrend",
      "bos:weeklyROIDelta"
    ],
    autonomous_actions: [
      "bos:issuesAutoResolved",
      "bos:issuesPendingEscalation"
    ]
  }

  @doc """
  Renders a structured plaintext briefing directly from the RDF map.

  This is the Armstrong fallback — it never calls any external service and
  always returns a valid, board-readable string.

  Format:
      BOARD INTELLIGENCE BRIEFING — <date>

      SUMMARY
      • <label>: <value>
      ...

      PROCESS HEALTH
      ...

      RISK & COMPLIANCE
      ...

      VELOCITY
      ...

      ACTIONS TAKEN AUTONOMOUSLY
      ...
  """
  @spec render_structured(map()) :: String.t()
  def render_structured(rdf_map) do
    {:ok, span} = Telemetry.start_span("board.briefing_render", %{
      "component" => "briefing_template"
    })

    date = Date.utc_today() |> Date.to_string()

    # Section 6: STRUCTURAL DECISIONS REQUIRED (only when Conway violations present)
    structural_count = Map.get(rdf_map, "bos:structuralIssueCount", 0)

    structural_section =
      if structural_count > 0 do
        conway_score = Map.get(rdf_map, "bos:highestConwayScore")
        score_pct = if conway_score, do: "#{round(conway_score * 100)}%", else: "unknown"

        """
        STRUCTURAL DECISIONS REQUIRED
        #{structural_count} department(s) have org boundary bottlenecks this system cannot fix.
        Worst boundary consumption: #{score_pct} of cycle time.
        These are Conway's Law violations — the org chart is the bottleneck.
        Only you can decide: reorganize, add a liaison role, or accept the constraint.\
        """
      else
        ""
      end

    sections =
      [
        build_header(date),
        build_section("SUMMARY", @section_properties.summary, rdf_map, :bullets),
        build_section("PROCESS HEALTH", @section_properties.process_health, rdf_map, :prose),
        build_section("RISK & COMPLIANCE", @section_properties.risk_compliance, rdf_map, :prose),
        build_section("VELOCITY", @section_properties.velocity, rdf_map, :prose),
        build_section(
          "ACTIONS TAKEN AUTONOMOUSLY",
          @section_properties.autonomous_actions,
          rdf_map,
          :prose
        ),
        structural_section
      ]
      |> Enum.reject(&(&1 == ""))

    # Count sections rendered (excluding empty structural section)
    section_count = length(sections)
    has_structural_issues = structural_count > 0
    structural_issue_count = if is_integer(structural_count), do: structural_count, else: 0

    Telemetry.end_span(
      Map.merge(span, %{
        "attributes" => Map.merge(span["attributes"], %{
          "section_count" => section_count,
          "has_structural_issues" => has_structural_issues,
          "structural_issue_count" => structural_issue_count
        })
      }),
      :ok
    )

    Enum.join(sections, "\n\n")
  end

  @doc """
  Builds the prompt sent to Claude Sonnet for board-level translation.

  The prompt instructs the model to:
  - Write exclusively in executive business language
  - Never mention SPARQL, RDF, conformance scores, fitness scores, or any
    technical infrastructure term
  - Use business vocabulary: risk, velocity, compliance, value, efficiency
  - Structure output into the 5 named sections
  - Be concise — the board chair reads this in under two minutes
  """
  @spec llm_prompt(map()) :: String.t()
  def llm_prompt(rdf_map) do
    date = Date.utc_today() |> Date.to_string()
    data_section = format_data_for_prompt(rdf_map)

    """
    You are an organizational intelligence system briefing the board chair.

    Your task: Translate the following process metrics into a board-level business briefing.

    RULES:
    - Never mention SPARQL, RDF, conformance scores, fitness, triples, ontology, or any technical term.
    - Use only business language: risk, velocity, compliance, value, efficiency, outcomes.
    - Be direct and concise. The board chair reads this in under two minutes.
    - Format the output as 5 sections (or 6 if Conway violations are present) with these headers (in order):
        BOARD INTELLIGENCE BRIEFING — #{date}
        SUMMARY
        PROCESS HEALTH
        RISK & COMPLIANCE
        VELOCITY
        ACTIONS TAKEN AUTONOMOUSLY
        STRUCTURAL DECISIONS REQUIRED (only if bos:structuralIssueCount > 0)
    - SUMMARY: 3 bullet points (•) covering the most important facts.
    - PROCESS HEALTH: 2–3 sentences on operational status.
    - RISK & COMPLIANCE: 2–3 sentences on risk exposure and regulatory standing.
    - VELOCITY: 1–2 sentences on throughput and value delivery trends.
    - ACTIONS TAKEN AUTONOMOUSLY: What the system detected and resolved this week without human intervention.
    - Section 6 (STRUCTURAL DECISIONS REQUIRED) — include ONLY if bos:structuralIssueCount > 0.
      Conway violations are org design problems: the department boundary IS the bottleneck.
      Do NOT suggest the system can fix these. Be clear: only the board chair can decide.
      Each violation: state the department, what percentage of cycle time is consumed at boundaries, and the three choices (reorganize, add liaison, accept constraint).

    DATA:
    #{data_section}
    """
  end

  @doc """
  Returns the human-readable label for an RDF property key.
  Returns the raw key if no label is registered.
  """
  @spec property_label(String.t()) :: String.t()
  def property_label(property_key) do
    Map.get(@property_labels, property_key, property_key)
  end

  @doc """
  Returns all registered property labels as a map.
  Useful for inspection and testing.
  """
  @spec all_labels() :: %{String.t() => String.t()}
  def all_labels, do: @property_labels

  # ── Private ──────────────────────────────────────────────────────────────────

  defp build_header(date) do
    "BOARD INTELLIGENCE BRIEFING — #{date}"
  end

  defp build_section(title, property_keys, rdf_map, :bullets) do
    lines =
      property_keys
      |> Enum.flat_map(fn key ->
        case Map.get(rdf_map, key) do
          nil -> []
          "" -> []
          value -> ["• #{property_label(key)}: #{value}"]
        end
      end)

    case lines do
      [] -> "#{title}\n• No data available."
      _ -> "#{title}\n#{Enum.join(lines, "\n")}"
    end
  end

  defp build_section(title, property_keys, rdf_map, :prose) do
    lines =
      property_keys
      |> Enum.flat_map(fn key ->
        case Map.get(rdf_map, key) do
          nil -> []
          "" -> []
          value -> ["#{property_label(key)}: #{value}."]
        end
      end)

    case lines do
      [] -> "#{title}\nNo data available."
      _ -> "#{title}\n#{Enum.join(lines, " ")}"
    end
  end

  defp format_data_for_prompt(rdf_map) do
    rdf_map
    |> Enum.map(fn {key, value} ->
      label = property_label(key)
      "#{label}: #{value}"
    end)
    |> Enum.join("\n")
  end
end
