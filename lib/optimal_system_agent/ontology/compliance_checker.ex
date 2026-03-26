defmodule OptimalSystemAgent.Ontology.ComplianceChecker do
  @moduledoc """
  Policy violation detection via SPARQL queries

  Queries `compliance-violations.rq` to detect violations of governance policies.
  When violations are found, emits healing actions to the reflex arc system.

  Integrates with OptimalSystemAgent.Healing.ReflexArcs to auto-remediate
  violations when they are detected.

  Signal Theory: S=(data,audit,inform,json,violation)
  """

  require Logger
  alias OptimalSystemAgent.Ontology.OxigraphClient
  alias OptimalSystemAgent.Events.Bus

  @compliance_violations_query """
  PREFIX chatman: <https://ontology.chatmangpt.com/core#>
  PREFIX dcterms: <http://purl.org/dc/terms/>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

  SELECT ?violation ?resource ?policy ?severity ?remediation WHERE {
    ?violation a chatman:ComplianceViolation ;
      chatman:affectsResource ?resource ;
      chatman:breachesPolicy ?policy ;
      chatman:severity ?severity ;
      chatman:suggestedRemediation ?remediation .
  }
  ORDER BY DESC(?severity) ?resource
  """

  @doc """
  Check for all active compliance violations

  Returns {:ok, violations} where violations is a list of violation maps,
  each containing: violation_id, resource, policy, severity, remediation.

  Severity levels: "critical" > "high" > "medium" > "low"
  """
  @spec check_violations() :: {:ok, list(map())} | {:error, term()}
  def check_violations do
    case OxigraphClient.query_select(@compliance_violations_query) do
      {:ok, rows} ->
        violations =
          Enum.map(rows, fn row ->
            %{
              violation_id: Map.get(row, "violation"),
              resource: Map.get(row, "resource"),
              policy: Map.get(row, "policy"),
              severity: Map.get(row, "severity"),
              remediation: Map.get(row, "remediation"),
              detected_at_ms: System.monotonic_time(:millisecond)
            }
          end)

        if Enum.any?(violations, &critical_violation?/1) do
          Logger.warning(
            "[ComplianceChecker] Found #{length(violations)} violations, #{count_critical(violations)} critical"
          )
        else
          Logger.info("[ComplianceChecker] Found #{length(violations)} violations")
        end

        {:ok, violations}

      {:error, reason} ->
        Logger.error("[ComplianceChecker] Failed to check violations: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Check violations for a specific resource (e.g., agent, tool, service)

  Returns {:ok, violations} or {:error, reason}
  """
  @spec check_resource_violations(String.t()) :: {:ok, list(map())} | {:error, term()}
  def check_resource_violations(resource_id) do
    query = """
    PREFIX chatman: <https://ontology.chatmangpt.com/core#>
    PREFIX dcterms: <http://purl.org/dc/terms/>

    SELECT ?violation ?policy ?severity ?remediation WHERE {
      ?violation a chatman:ComplianceViolation ;
        chatman:affectsResource "#{resource_id}" ;
        chatman:breachesPolicy ?policy ;
        chatman:severity ?severity ;
        chatman:suggestedRemediation ?remediation .
    }
    ORDER BY DESC(?severity)
    """

    case OxigraphClient.query_select(query) do
      {:ok, rows} ->
        violations =
          Enum.map(rows, fn row ->
            %{
              violation_id: Map.get(row, "violation"),
              resource: resource_id,
              policy: Map.get(row, "policy"),
              severity: Map.get(row, "severity"),
              remediation: Map.get(row, "remediation"),
              detected_at_ms: System.monotonic_time(:millisecond)
            }
          end)

        {:ok, violations}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check and auto-remediate violations

  Checks for violations and if any exist, emits healing actions
  through the ReflexArcs system.

  Returns {:ok, %{violations: [...], remediated: N}} or {:error, reason}
  """
  @spec check_and_remediate() :: {:ok, map()} | {:error, term()}
  def check_and_remediate do
    case check_violations() do
      {:ok, violations} ->
        remediated =
          Enum.reduce(violations, 0, fn violation, count ->
            emit_healing_action(violation)
            count + 1
          end)

        Logger.info(
          "[ComplianceChecker] Remediated #{remediated}/#{length(violations)} violations"
        )

        {:ok, %{violations: violations, remediated: remediated}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private

  defp critical_violation?(%{severity: "critical"}), do: true
  defp critical_violation?(_), do: false

  defp count_critical(violations) do
    Enum.count(violations, &critical_violation?/1)
  end

  defp emit_healing_action(violation) do
    # Emit healing action to ReflexArcs
    action = %{
      type: :compliance_violation_detected,
      resource: Map.get(violation, :resource),
      policy: Map.get(violation, :policy),
      severity: Map.get(violation, :severity),
      remediation_hint: Map.get(violation, :remediation),
      timestamp_ms: System.monotonic_time(:millisecond)
    }

    Bus.emit(:healing_action, action)
    Logger.debug(
      "Emitted healing action for violation: #{Map.get(violation, :violation_id)}"
    )
    :ok
  end
end
