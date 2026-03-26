defmodule OptimalSystemAgent.Integrations.FIBO.CLI do
  @moduledoc """
  FIBO CLI wrapper — Invokes `bos deal` commands to execute SPARQL CONSTRUCT.

  This module handles all interactions with the BusinessOS `bos` CLI tool,
  which wraps the data-modelling-sdk and communicates with Oxigraph triplestore.

  Functions:
    - `create_deal/1` — Call `bos deal create` with deal parameters
    - `verify_compliance/1` — Call `bos deal verify` to check compliance rules

  All commands executed asynchronously via Port. Results parsed from JSON output.
  Timeouts enforced at caller level (DealCoordinator).

  Error Handling:
    - Non-zero exit code → {:error, stderr_output}
    - JSON parse failure → {:error, "invalid json response"}
    - Missing fields → {:error, "missing required field"}
  """

  require Logger

  @doc """
  Create a deal via `bos deal create`.

  Invokes: `bos deal create --name NAME --counterparty PARTY --amount AMOUNT --currency CURRENCY`

  Returns list of RDF triples (as Strings) on success, or error tuple.

  ## Examples

      iex> CLI.create_deal(%{name: "ACME Widget", counterparty: "ACME", amount_usd: 500_000})
      {:ok, ["<http://example.org/deal/abc123> rdf:type fibo:Deal .", ...]}
  """
  @spec create_deal(map()) :: {:ok, [String.t()]} | {:error, String.t()}
  def create_deal(input) do
    args = [
      "deal", "create",
      "--name", to_string(input.name),
      "--counterparty", to_string(input.counterparty),
      "--amount", to_string(input.amount_usd),
      "--currency", to_string(input[:currency] || "USD")
    ]

    case execute_bos_command(args) do
      {:ok, output} ->
        case parse_create_response(output) do
          {:ok, triples} ->
            Logger.debug("[FIBO.CLI] Created deal with #{Enum.count(triples)} RDF triples")
            {:ok, triples}

          {:error, reason} ->
            Logger.error("[FIBO.CLI] Failed to parse create response: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("[FIBO.CLI] create_deal command failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Verify deal compliance via `bos deal verify`.

  Invokes: `bos deal verify --deal-id DEAL_ID`

  Returns map of compliance check results: %{"check_name" => true|false, ...}

  ## Examples

      iex> CLI.verify_compliance(%{id: "deal_123"})
      {:ok, %{"counterparty_verified" => true, "amount_valid" => true, "settlement_date_ok" => true}}
  """
  @spec verify_compliance(struct()) :: {:ok, map()} | {:error, String.t()}
  def verify_compliance(deal) do
    args = [
      "deal", "verify",
      "--deal-id", to_string(deal.id)
    ]

    case execute_bos_command(args) do
      {:ok, output} ->
        case parse_verify_response(output) do
          {:ok, checks} ->
            Logger.debug("[FIBO.CLI] Verified deal #{deal.id}: #{inspect(checks)}")
            {:ok, checks}

          {:error, reason} ->
            Logger.error("[FIBO.CLI] Failed to parse verify response: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("[FIBO.CLI] verify_compliance command failed: #{reason}")
        {:error, reason}
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Helpers
  # ───────────────────────────────────────────────────────────────────────────

  @spec execute_bos_command([String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  defp execute_bos_command(args) do
    # Allow test environment to mock the bos command
    if Application.get_env(:optimal_system_agent, :fibo_mock_cli, false) do
      mock_bos_command(args)
    else
      real_bos_command(args)
    end
  end

  @spec real_bos_command([String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  defp real_bos_command(args) do
    command = "bos"

    case System.cmd(command, args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {error_output, exit_code} ->
        {:error, "exit code #{exit_code}: #{error_output}"}
    end
  rescue
    e ->
      {:error, "command execution failed: #{inspect(e)}"}
  end

  @spec mock_bos_command([String.t()]) :: {:ok, String.t()}
  defp mock_bos_command(["deal", "create" | _args]) do
    # Mock response for create_deal
    mock_response = %{
      "rdf_triples" => [
        "<http://example.org/deal/#{random_id()}> rdf:type fibo:Deal .",
        "<http://example.org/deal/#{random_id()}> fibo:hasCounterparty <http://example.org/org/counterparty> .",
        "<http://example.org/deal/#{random_id()}> fibo:hasAmount \"1000000.0\"^^xsd:double ."
      ]
    }
    {:ok, Jason.encode!(mock_response)}
  end

  defp mock_bos_command(["deal", "verify" | _args]) do
    # Mock response for verify_compliance
    mock_response = %{
      "compliance_checks" => %{
        "counterparty_verified" => true,
        "amount_valid" => true,
        "settlement_date_ok" => true
      }
    }
    {:ok, Jason.encode!(mock_response)}
  end

  defp mock_bos_command(_args) do
    {:error, "unknown command"}
  end

  defp random_id do
    :erlang.unique_integer([:positive]) |> Integer.to_string(36)
  end

  @spec parse_create_response(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  defp parse_create_response(output) do
    try do
      data = Jason.decode!(output)

      case data do
        %{"rdf_triples" => triples} when is_list(triples) ->
          {:ok, triples}

        %{"error" => error} ->
          {:error, error}

        _ ->
          {:error, "missing rdf_triples field in response"}
      end
    rescue
      e ->
        {:error, "json parse error: #{inspect(e)}"}
    end
  end

  @spec parse_verify_response(String.t()) :: {:ok, map()} | {:error, String.t()}
  defp parse_verify_response(output) do
    try do
      data = Jason.decode!(output)

      case data do
        %{"compliance_checks" => checks} when is_map(checks) ->
          {:ok, checks}

        %{"error" => error} ->
          {:error, error}

        _ ->
          {:error, "missing compliance_checks field in response"}
      end
    rescue
      e ->
        {:error, "json parse error: #{inspect(e)}"}
    end
  end
end
