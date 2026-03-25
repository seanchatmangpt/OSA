defmodule OptimalSystemAgent.Channels.HTTP.API.MarketplaceRoutes do
  @moduledoc """
  Agent Commerce Marketplace (Innovation 9) -- HTTP API endpoints.

  Endpoints:
    POST /api/v1/marketplace/publish             Publish a new skill
    GET  /api/v1/marketplace/search              Search skills (query param)
    GET  /api/v1/marketplace/skills              List all skills (paginated)
    GET  /api/v1/marketplace/skills/:id          Get skill details
    POST /api/v1/marketplace/skills/:id/acquire  Acquire a skill
    POST /api/v1/marketplace/skills/:id/rate     Rate a skill (1-5)
    GET  /api/v1/marketplace/stats               Marketplace statistics
    GET  /api/v1/marketplace/revenue/:publisher_id  Revenue report for publisher

  Forwarded prefix: /marketplace
  """

  use Plug.Router
  import OptimalSystemAgent.Channels.HTTP.API.Shared
  require Logger

  alias OptimalSystemAgent.Commerce.Marketplace

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason)
  plug(:dispatch)

  # ===========================================================================
  # POST /api/v1/marketplace/publish
  # ===========================================================================

  post "/publish" do
    publisher_id = conn.assigns[:user_id] || "anonymous"
    params = conn.body_params

    required = ~w(name description instructions)

    missing =
      required
      |> Enum.filter(fn field -> is_nil(Map.get(params, field)) or Map.get(params, field) == "" end)

    cond do
      missing != [] ->
        fields = Enum.join(missing, ", ")
        json_error(conn, 400, "invalid_request", "Missing required fields: #{fields}")

      true ->
        # Convert string keys to atom keys for the marketplace
        skill_params = atomize_keys(params)

        case Marketplace.publish_skill(publisher_id, skill_params) do
          {:ok, skill_id} ->
            json(conn, 201, %{skill_id: skill_id, status: "published"})

          {:error, reason} ->
            json_error(conn, 422, "publish_failed", to_string(reason))
        end
    end
  end

  # ===========================================================================
  # GET /api/v1/marketplace/search
  # ===========================================================================

  get "/search" do
    conn = Plug.Conn.fetch_query_params(conn)
    query = conn.query_params["q"] || ""
    category = conn.query_params["category"]
    min_rating = conn.query_params["min_rating"]
    sort = conn.query_params["sort"]
    page = parse_positive_int(conn.query_params["page"], 1)
    per_page = conn.query_params["per_page"] |> parse_positive_int(20) |> min(100)

    filters =
      %{}
      |> maybe_put_map(:page, page)
      |> maybe_put_map(:per_page, per_page)
      |> maybe_put_map(:category, category)
      |> maybe_put_map(:min_rating, parse_float(min_rating))
      |> maybe_put_map(:sort, sort)

    results = Marketplace.search_skills(query, filters)
    json(conn, 200, results)
  end

  # ===========================================================================
  # GET /api/v1/marketplace/skills
  # ===========================================================================

  get "/skills" do
    {page, per_page} = pagination_params(conn)
    results = Marketplace.list_skills(page: page, per_page: per_page)
    json(conn, 200, results)
  end

  # ===========================================================================
  # GET /api/v1/marketplace/skills/:id
  # ===========================================================================

  get "/skills/:id" do
    case Marketplace.get_skill(id) do
      {:ok, skill} ->
        json(conn, 200, Marketplace.skill_summary(skill))

      {:error, "skill_not_found"} ->
        json_error(conn, 404, "not_found", "Skill '#{id}' not found")
    end
  end

  # ===========================================================================
  # POST /api/v1/marketplace/skills/:id/acquire
  # ===========================================================================

  post "/skills/:id/acquire" do
    buyer_id = conn.assigns[:user_id] || "anonymous"

    case Marketplace.acquire_skill(buyer_id, id) do
      {:ok, acquisition} ->
        json(conn, 201, %{
          status: "acquired",
          skill_id: acquisition.skill_id,
          buyer_id: acquisition.buyer_id,
          acquired_at: DateTime.to_iso8601(acquisition.acquired_at),
          license: acquisition.license
        })

      {:error, "skill_not_found"} ->
        json_error(conn, 404, "not_found", "Skill '#{id}' not found")

      {:error, reason} ->
        json_error(conn, 422, "acquisition_failed", to_string(reason))
    end
  end

  # ===========================================================================
  # POST /api/v1/marketplace/skills/:id/rate
  # ===========================================================================

  post "/skills/:id/rate" do
    rater_id = conn.assigns[:user_id] || "anonymous"
    params = conn.body_params
    rating_value = Map.get(params, "rating")

    cond do
      is_nil(rating_value) ->
        json_error(conn, 400, "invalid_request", "Missing required field: rating")

      not is_number(rating_value) ->
        json_error(conn, 400, "invalid_request", "Rating must be a number between 1 and 5")

      rating_value < 1 or rating_value > 5 ->
        json_error(conn, 400, "invalid_request", "Rating must be between 1 and 5")

      true ->
        rating_int = trunc(rating_value)

        case Marketplace.rate_skill(rater_id, id, rating_int) do
          {:ok, result} ->
            json(conn, 200, %{status: "rated", rating: result.rating, new_average: result.new_average})

          {:error, "skill_not_found"} ->
            json_error(conn, 404, "not_found", "Skill '#{id}' not found")

          {:error, reason} ->
            json_error(conn, 422, "rating_failed", to_string(reason))
        end
    end
  end

  # ===========================================================================
  # GET /api/v1/marketplace/stats
  # ===========================================================================

  get "/stats" do
    try do
      stats = Marketplace.marketplace_stats()
      json(conn, 200, stats)
    rescue
      e ->
        Logger.error("[Marketplace] Stats failed: #{Exception.message(e)}")
        json_error(conn, 500, "internal_error", Exception.message(e))
    end
  end

  # ===========================================================================
  # GET /api/v1/marketplace/revenue/:publisher_id
  # ===========================================================================

  get "/revenue/:publisher_id" do
    report = Marketplace.revenue_report(publisher_id)
    json(conn, 200, report)
  end

  # ===========================================================================
  # Catch-all
  # ===========================================================================

  match _ do
    json_error(conn, 404, "not_found", "Marketplace endpoint not found")
  end

  # ===========================================================================
  # Private helpers
  # ===========================================================================

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        atom_key =
          key
          |> String.replace("-", "_")
          |> String.to_atom()

        {atom_key, value}

      other ->
        other
    end)
  end

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, key, value), do: Map.put(map, key, value)

  defp parse_float(nil), do: nil

  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_float(n) when is_number(n), do: n / 1
end
