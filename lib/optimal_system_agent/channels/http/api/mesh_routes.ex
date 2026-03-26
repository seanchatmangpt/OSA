defmodule OptimalSystemAgent.Channels.HTTP.API.MeshRoutes do
  @moduledoc """
  HTTP routes for Data Mesh Consumer operations.

  Provides REST endpoints for:
    - POST /api/mesh/domains — Register a domain
    - GET /api/mesh/discover — Discover datasets in a domain
    - GET /api/mesh/lineage — Query dataset lineage
    - GET /api/mesh/quality — Check data quality

  All endpoints delegate to OptimalSystemAgent.Integrations.Mesh.Consumer GenServer.
  """

  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared

  require Logger

  alias OptimalSystemAgent.Integrations.Mesh.Consumer

  plug :match
  plug :dispatch

  # =========================================================================
  # POST /api/mesh/domains — Register Domain
  # =========================================================================

  post "/domains" do
    conn = Plug.Conn.fetch_query_params(conn)
    body = read_body_as_json(conn)

    case body do
      {:ok, params} ->
        domain_name = params["domain_name"] || params["domain"]
        owner = params["owner"]
        description = params["description"] || ""

        case validate_register_domain_params(domain_name, owner) do
          :ok ->
            metadata = %{
              "owner" => owner,
              "description" => description,
              "tags" => Map.get(params, "tags", [])
            }

            case Consumer.register_domain(
              Consumer,
              domain_name,
              metadata
            ) do
              {:ok, response} ->
                Logger.info("[MeshRoutes] registered domain=#{domain_name}")
                json(conn, 200, %{"status" => "registered", "domain" => response})

              {:error, reason} ->
                Logger.warning("[MeshRoutes] register_domain failed: #{inspect(reason)}")
                json_error(conn, 400, "registration_failed", error_message(reason))
            end

          {:error, error} ->
            json_error(conn, 400, "invalid_params", error)
        end

      {:error, reason} ->
        json_error(conn, 400, "invalid_json", error_message(reason))
    end
  end

  # =========================================================================
  # GET /api/mesh/discover — Discover Datasets
  # =========================================================================

  get "/discover" do
    conn = Plug.Conn.fetch_query_params(conn)
    domain_name = conn.query_params["domain"]

    case validate_query_param(domain_name, "domain") do
      :ok ->
        case Consumer.discover_datasets(Consumer, domain_name) do
          {:ok, datasets} ->
            Logger.debug("[MeshRoutes] discovered #{length(datasets)} datasets in domain=#{domain_name}")
            json(conn, 200, %{
              "status" => "success",
              "domain" => domain_name,
              "dataset_count" => length(datasets),
              "datasets" => datasets
            })

          {:error, reason} ->
            Logger.warning("[MeshRoutes] discover_datasets failed: #{inspect(reason)}")
            json_error(conn, 400, "discovery_failed", error_message(reason))
        end

      {:error, error} ->
        json_error(conn, 400, "invalid_params", error)
    end
  end

  # =========================================================================
  # GET /api/mesh/lineage — Query Lineage
  # =========================================================================

  get "/lineage" do
    conn = Plug.Conn.fetch_query_params(conn)
    domain_name = conn.query_params["domain"]
    dataset_name = conn.query_params["dataset"]
    depth = parse_depth(conn.query_params["depth"])

    case validate_lineage_params(domain_name, dataset_name) do
      :ok ->
        case Consumer.query_lineage(Consumer, domain_name, dataset_name, depth: depth) do
          {:ok, lineage} ->
            Logger.debug("[MeshRoutes] queried lineage domain=#{domain_name} dataset=#{dataset_name}")
            json(conn, 200, %{
              "status" => "success",
              "domain" => domain_name,
              "dataset" => dataset_name,
              "depth" => depth,
              "lineage" => lineage
            })

          {:error, reason} ->
            Logger.warning("[MeshRoutes] query_lineage failed: #{inspect(reason)}")
            json_error(conn, 400, "lineage_query_failed", error_message(reason))
        end

      {:error, error} ->
        json_error(conn, 400, "invalid_params", error)
    end
  end

  # =========================================================================
  # GET /api/mesh/quality — Check Quality
  # =========================================================================

  get "/quality" do
    conn = Plug.Conn.fetch_query_params(conn)
    domain_name = conn.query_params["domain"]
    dataset_name = conn.query_params["dataset"]

    case validate_quality_params(domain_name, dataset_name) do
      :ok ->
        case Consumer.check_quality(Consumer, domain_name, dataset_name) do
          {:ok, quality} ->
            Logger.debug("[MeshRoutes] checked quality domain=#{domain_name} dataset=#{dataset_name}")
            json(conn, 200, %{
              "status" => "success",
              "domain" => domain_name,
              "dataset" => dataset_name,
              "quality_metrics" => quality
            })

          {:error, reason} ->
            Logger.warning("[MeshRoutes] check_quality failed: #{inspect(reason)}")
            json_error(conn, 400, "quality_check_failed", error_message(reason))
        end

      {:error, error} ->
        json_error(conn, 400, "invalid_params", error)
    end
  end

  # =========================================================================
  # Catch-all for unmapped routes
  # =========================================================================

  match _ do
    json_error(conn, 404, "not_found", "Mesh route not found")
  end

  # =========================================================================
  # Helpers
  # =========================================================================

  defp read_body_as_json(conn) do
    case Plug.Conn.read_body(conn, limit: 65536) do
      {:ok, body, _conn} ->
        case Jason.decode(body) do
          {:ok, params} when is_map(params) -> {:ok, params}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:error, :read_error}
  end

  defp validate_register_domain_params(domain_name, owner) do
    cond do
      not is_binary(domain_name) or String.length(domain_name) == 0 ->
        {:error, "domain_name is required and must be a non-empty string"}

      not is_binary(owner) or String.length(owner) == 0 ->
        {:error, "owner is required and must be a non-empty string"}

      true ->
        :ok
    end
  end

  defp validate_query_param(value, param_name) do
    if is_binary(value) and String.length(value) > 0 do
      :ok
    else
      {:error, "#{param_name} is required and must be a non-empty string"}
    end
  end

  defp validate_lineage_params(domain_name, dataset_name) do
    cond do
      not is_binary(domain_name) or String.length(domain_name) == 0 ->
        {:error, "domain is required and must be a non-empty string"}

      not is_binary(dataset_name) or String.length(dataset_name) == 0 ->
        {:error, "dataset is required and must be a non-empty string"}

      true ->
        :ok
    end
  end

  defp validate_quality_params(domain_name, dataset_name) do
    cond do
      not is_binary(domain_name) or String.length(domain_name) == 0 ->
        {:error, "domain is required and must be a non-empty string"}

      not is_binary(dataset_name) or String.length(dataset_name) == 0 ->
        {:error, "dataset is required and must be a non-empty string"}

      true ->
        :ok
    end
  end

  defp parse_depth(depth_str) do
    case Integer.parse(depth_str || "5") do
      {depth, ""} when depth > 0 and depth <= 5 -> depth
      _ -> 5
    end
  rescue
    _ -> 5
  end

  defp error_message({:error, reason}), do: error_message(reason)

  defp error_message(:invalid_domain_name), do: "Invalid domain name format"
  defp error_message(:invalid_dataset_name), do: "Invalid dataset name format"
  defp error_message(:missing_owner), do: "Domain owner is required"
  defp error_message(:invalid_metadata), do: "Invalid metadata format"
  defp error_message(:invalid_depth), do: "Depth must be between 1 and 5"
  defp error_message(:timeout), do: "Operation timed out"
  defp error_message(:parse_error), do: "Failed to parse response"
  defp error_message(_), do: "Operation failed"
end
