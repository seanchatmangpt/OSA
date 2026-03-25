defmodule OptimalSystemAgent.Tools.Builtins.BusinessOSAPI do
  @moduledoc """
  BusinessOS API integration tool.

  Allows OSA agents to call BusinessOS REST endpoints with automatic
  JWT authentication. Used by the businessos-gateway agent for CRM,
  project management, and app generation operations.

  Configuration via environment variables:
    BUSINESSOS_API_URL  — Base URL (default: http://localhost:8001)
    BUSINESSOS_API_TOKEN — JWT bearer token
  """

  @behaviour OptimalSystemAgent.Tools.Behaviour

  require Logger

  @default_base_url "http://localhost:8001"
  @default_timeout 30_000

  @impl true
  def safety, do: :sandboxed

  @impl true
  def name, do: "businessos_api"

  @impl true
  def description do
    """
    Call BusinessOS REST API endpoints. Supports CRM (clients, deals, pipelines),
    project management (projects, tasks), app generation, and workspace operations.
    Authentication is handled automatically via BUSINESSOS_API_TOKEN env var.
    """
  end

  @impl true
  def parameters do
    %{
      "type" => "object",
      "properties" => %{
        "endpoint" => %{
          "type" => "string",
          "description" => "API path (e.g. /api/crm/clients, /api/projects, /api/osa/generate)"
        },
        "method" => %{
          "type" => "string",
          "enum" => ["GET", "POST", "PUT", "DELETE"],
          "description" => "HTTP method"
        },
        "body" => %{
          "type" => "object",
          "description" => "Request body for POST/PUT requests (JSON object)"
        }
      },
      "required" => ["endpoint", "method"]
    }
  end

  @impl true
  def execute(%{"endpoint" => endpoint, "method" => method} = params) do
    unless is_binary(endpoint) and is_binary(method) do
      {:error, "endpoint and method must be strings"}
    else
      body = Map.get(params, "body")
      do_request(endpoint, method, body)
    end
  end

  def execute(_), do: {:error, "Missing required parameters: endpoint, method"}

  # ── Private ──────────────────────────────────────────────────────────

  defp base_url do
    System.get_env("BUSINESSOS_API_URL") || @default_base_url
  end

  defp auth_token do
    System.get_env("BUSINESSOS_API_TOKEN") || ""
  end

  defp headers do
    token = auth_token()

    base = [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

    if token != "" do
      [{"Authorization", "Bearer #{token}"} | base]
    else
      base
    end
  end

  defp do_request(endpoint, method, body) do
    url = base_url() <> endpoint
    method_atom = String.to_existing_atom(String.downcase(method))

    req_opts =
      [url: url, method: method_atom, headers: headers(), receive_timeout: @default_timeout]
      |> maybe_put_body(method, body)

    case Req.request(req_opts) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        decoded =
          case Jason.decode(resp_body) do
            {:ok, decoded} -> decoded
            {:error, _} -> resp_body
          end

        {:ok, %{status: status, data: decoded}}

      {:ok, %{status: status, body: resp_body}} ->
        Logger.warning("[BusinessOSAPI] #{method} #{endpoint} returned #{status}")

        {:error, "HTTP #{status}: #{truncate(resp_body, 500)}"}

      {:error, %Req.TransportError{reason: reason}} ->
        Logger.warning("[BusinessOSAPI] Connection failed: #{inspect(reason)}")

        {:error, "Connection failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp maybe_put_body(opts, method, body) when method in ["POST", "PUT"] and is_map(body) do
    Keyword.put(opts, :json, body)
  end

  defp maybe_put_body(opts, _method, _body), do: opts

  defp truncate(str, max) when byte_size(str) > max do
    String.slice(str, 0, max) <> "..."
  end

  defp truncate(str, _max), do: str
end
