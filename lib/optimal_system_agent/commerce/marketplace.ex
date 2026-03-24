defmodule OptimalSystemAgent.Commerce.Marketplace do
  @moduledoc """
  Agent Commerce Marketplace (Innovation 9) -- An App Store for agent skills.

  Agents publish, discover, acquire, and execute autonomous capabilities (skills)
  through a self-regulating marketplace backed by ETS tables.

  Quality Scoring (Signal Theory Integration):
    Composite quality = 0.4 * S/N + 0.3 * rating + 0.3 * usage
    Where:
      S/N ratio   = successful_executions / (successful + failed)
      Rating      = weighted average (recent ratings count more via exponential decay)
      Usage       = log(1 + download_count) normalized to [0, 1]

  ETS Tables:
    :osa_marketplace_skills        set  keyed by skill_id
    :osa_marketplace_ratings       bag  keyed by {skill_id, rater_id}
    :osa_marketplace_acquisitions  bag  keyed by {skill_id, buyer_id}
    :osa_marketplace_executions    bag  keyed by {skill_id, timestamp}

  All tables are public and created by init_tables/0 called from Application.
  """

  use GenServer

  require Logger

  @skills_table :osa_marketplace_skills
  @ratings_table :osa_marketplace_ratings
  @acquisitions_table :osa_marketplace_acquisitions
  @executions_table :osa_marketplace_executions

  # Signal Theory quality weights
  @sn_weight 0.4
  @rating_weight 0.3
  @usage_weight 0.3

  # Rating exponential decay half-life in seconds (7 days)
  @rating_half_life_days 7

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @typedoc "A skill definition stored in the marketplace."
  @type skill :: %{
    skill_id: String.t(),
    name: String.t(),
    description: String.t(),
    author: String.t(),
    category: String.t(),
    instructions: String.t(),
    triggers: [String.t()],
    pricing: %{type: atom(), amount: number()},
    version: non_neg_integer(),
    tags: [String.t()],
    published_at: DateTime.t(),
    updated_at: DateTime.t(),
    # Aggregated metrics (updated on ratings/executions)
    rating_count: non_neg_integer(),
    rating_sum: number(),
    successful_executions: non_neg_integer(),
    failed_executions: non_neg_integer(),
    downloads: non_neg_integer(),
    quality_score: float()
  }

  @typedoc "An acquisition record."
  @type acquisition :: %{
    skill_id: String.t(),
    buyer_id: String.t(),
    acquired_at: DateTime.t(),
    license: :perpetual | :subscription | :per_execution
  }

  @typedoc "An execution record for billing."
  @type execution :: %{
    skill_id: String.t(),
    buyer_id: String.t(),
    executed_at: DateTime.t(),
    success: boolean(),
    duration_ms: non_neg_integer() | nil
  }

  @typedoc "An individual rating record."
  @type rating :: %{
    skill_id: String.t(),
    rater_id: String.t(),
    value: 1..5,
    rated_at: DateTime.t()
  }

  # ---------------------------------------------------------------------------
  # API
  # ---------------------------------------------------------------------------

  @doc """
  Initialize all ETS tables for the marketplace.
  Called from Application.start/2 before supervision tree starts.
  """
  @spec init_tables() :: :ok
  def init_tables do
    # Skills: set table keyed by skill_id
    if :ets.whereis(@skills_table) != :undefined do
      :ets.delete(@skills_table)
    end

    :ets.new(@skills_table, [:named_table, :public, :set])

    # Ratings: bag table keyed by {skill_id, rater_id}
    if :ets.whereis(@ratings_table) != :undefined do
      :ets.delete(@ratings_table)
    end

    :ets.new(@ratings_table, [:named_table, :public, :bag])

    # Acquisitions: bag table keyed by {skill_id, buyer_id}
    if :ets.whereis(@acquisitions_table) != :undefined do
      :ets.delete(@acquisitions_table)
    end

    :ets.new(@acquisitions_table, [:named_table, :public, :bag])

    # Executions: bag table keyed by {skill_id, timestamp}
    if :ets.whereis(@executions_table) != :undefined do
      :ets.delete(@executions_table)
    end

    :ets.new(@executions_table, [:named_table, :public, :bag])

    :ok
  end

  @doc """
  Start the Marketplace GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Publish a new skill to the marketplace.

  Returns `{:ok, skill_id}` or `{:error, reason}`.
  """
  @spec publish_skill(String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def publish_skill(publisher_id, skill_params) do
    GenServer.call(__MODULE__, {:publish_skill, publisher_id, skill_params})
  end

  @doc """
  Search for skills by query string and optional filters.

  Returns a map with results, total count, and page info.
  """
  @spec search_skills(String.t(), map()) :: map()
  def search_skills(query, filters \\ %{}) do
    GenServer.call(__MODULE__, {:search_skills, query, filters})
  end

  @doc """
  Acquire a skill for a buyer agent.

  Returns a map with skill_id, buyer_id, acquired_at, and license type.
  """
  @spec acquire_skill(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def acquire_skill(buyer_id, skill_id) do
    GenServer.call(__MODULE__, {:acquire_skill, buyer_id, skill_id})
  end

  @doc """
  Rate a skill on a 1-5 scale.

  Updates the skill's aggregate rating and records the individual rating
  for fraud detection. High-rated skills get higher visibility via
  Signal Theory S/N scoring.
  """
  @spec rate_skill(String.t(), String.t(), 1..5) :: {:ok, map()} | {:error, String.t()}
  def rate_skill(rater_id, skill_id, rating) when rating in 1..5 do
    GenServer.call(__MODULE__, {:rate_skill, rater_id, skill_id, rating})
  end

  @doc """
  Execute a skill in the context of a buyer agent.

  Loads the skill instructions, injects them into the agent context,
  tracks execution for billing, and returns the result.
  """
  @spec execute_skill(String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  def execute_skill(buyer_id, skill_id, context) do
    GenServer.call(__MODULE__, {:execute_skill, buyer_id, skill_id, context})
  end

  @doc """
  Get a revenue report for a publisher.

  Returns earnings broken down by skill for the current period.
  """
  @spec revenue_report(String.t()) :: map()
  def revenue_report(publisher_id) do
    GenServer.call(__MODULE__, {:revenue_report, publisher_id})
  end

  @doc """
  Get global marketplace statistics.

  Returns total skills, publishers, acquisitions, executions, revenue,
  top categories, and trending skills.
  """
  @spec marketplace_stats() :: map()
  def marketplace_stats do
    GenServer.call(__MODULE__, :marketplace_stats)
  end

  @doc """
  Get a single skill by ID.
  """
  @spec get_skill(String.t()) :: {:ok, skill()} | {:error, String.t()}
  def get_skill(skill_id) do
    case :ets.lookup(@skills_table, skill_id) do
      [{^skill_id, skill}] -> {:ok, skill}
      [] -> {:error, "skill_not_found"}
    end
  end

  @doc """
  List all skills, optionally paginated.
  """
  @spec list_skills(keyword()) :: %{results: [map()], total: non_neg_integer(), page: pos_integer()}
  def list_skills(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20) |> min(100)

    all_skills =
      :ets.tab2list(@skills_table)
      |> Enum.map(fn {_id, skill} -> skill end)

    total = length(all_skills)

    results =
      all_skills
      |> Enum.sort_by(& &1.quality_score, :desc)
      |> Enum.drop((page - 1) * per_page)
      |> Enum.take(per_page)
      |> Enum.map(&skill_summary/1)

    %{
      results: results,
      total: total,
      page: page
    }
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    Logger.info("[Marketplace] Agent Commerce Marketplace started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:publish_skill, publisher_id, params}, _from, state) do
    result = do_publish_skill(publisher_id, params)
    {:reply, result, state}
  end

  def handle_call({:search_skills, query, filters}, _from, state) do
    result = do_search_skills(query, filters)
    {:reply, result, state}
  end

  def handle_call({:acquire_skill, buyer_id, skill_id}, _from, state) do
    result = do_acquire_skill(buyer_id, skill_id)
    {:reply, result, state}
  end

  def handle_call({:rate_skill, rater_id, skill_id, rating}, _from, state) do
    result = do_rate_skill(rater_id, skill_id, rating)
    {:reply, result, state}
  end

  def handle_call({:execute_skill, buyer_id, skill_id, context}, _from, state) do
    result = do_execute_skill(buyer_id, skill_id, context)
    {:reply, result, state}
  end

  def handle_call({:revenue_report, publisher_id}, _from, state) do
    result = do_revenue_report(publisher_id)
    {:reply, result, state}
  end

  def handle_call(:marketplace_stats, _from, state) do
    result = do_marketplace_stats()
    {:reply, result, state}
  end

  # ---------------------------------------------------------------------------
  # Internal: Publish Skill
  # ---------------------------------------------------------------------------

  defp do_publish_skill(publisher_id, params) do
    name = Map.get(params, :name) || Map.get(params, "name")
    description = Map.get(params, :description) || Map.get(params, "description")
    category = Map.get(params, :category) || Map.get(params, "category", "general")
    instructions = Map.get(params, :instructions) || Map.get(params, "instructions")

    cond do
      is_nil(name) or name == "" ->
        {:error, "name is required"}

      is_nil(description) or description == "" ->
        {:error, "description is required"}

      is_nil(instructions) or instructions == "" ->
        {:error, "instructions are required"}

      true ->
        now = DateTime.utc_now()
        skill_id = generate_skill_id(name, publisher_id)

        author = Map.get(params, :author) || Map.get(params, "author", publisher_id)
        triggers = Map.get(params, :triggers) || Map.get(params, "triggers", [])
        pricing = normalize_pricing(Map.get(params, :pricing) || Map.get(params, "pricing", %{}))
        version = Map.get(params, :version) || Map.get(params, "version", 1)
        tags = Map.get(params, :tags) || Map.get(params, "tags", [])

        skill = %{
          skill_id: skill_id,
          name: to_string(name),
          description: to_string(description),
          author: to_string(author),
          category: to_string(category),
          instructions: to_string(instructions),
          triggers: ensure_list(triggers),
          pricing: pricing,
          version: version,
          tags: ensure_list(tags),
          published_at: now,
          updated_at: now,
          rating_count: 0,
          rating_sum: 0.0,
          successful_executions: 0,
          failed_executions: 0,
          downloads: 0,
          quality_score: 0.5
        }

        :ets.insert(@skills_table, {skill_id, skill})

        Logger.info("[Marketplace] Published skill '#{name}' (#{skill_id}) by #{publisher_id}")
        {:ok, skill_id}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal: Search Skills
  # ---------------------------------------------------------------------------

  defp do_search_skills(query, filters) do
    page = Map.get(filters, :page, 1)
    per_page = Map.get(filters, :per_page, 20) |> min(100)
    category = Map.get(filters, :category)
    min_rating = Map.get(filters, :min_rating)
    sort_by = Map.get(filters, :sort, "quality")

    all_skills =
      :ets.tab2list(@skills_table)
      |> Enum.map(fn {_id, skill} -> skill end)

    # Filter by query (name, description, tags, triggers)
    query_terms = String.downcase(query || "") |> String.split(~r/\s+/)

    filtered =
      all_skills
      |> Enum.filter(fn skill ->
        searchable =
          [
            skill.name,
            skill.description,
            skill.category,
            skill.author
            | skill.tags ++ skill.triggers
          ]
          |> Enum.map(&String.downcase/1)
          |> Enum.join(" ")

        # All query terms must match somewhere
        Enum.all?(query_terms, fn term ->
          term == "" or String.contains?(searchable, term)
        end)
      end)
      |> filter_by_category(category)
      |> filter_by_min_rating(min_rating)

    total = length(filtered)

    sorted =
      case sort_by do
        "rating" -> Enum.sort_by(filtered, & &1.quality_score, :desc)
        "downloads" -> Enum.sort_by(filtered, & &1.downloads, :desc)
        "newest" -> Enum.sort_by(filtered, & &1.published_at, {:desc, DateTime})
        "price_asc" -> Enum.sort_by(filtered, &pricing_amount(&1.pricing), :asc)
        "price_desc" -> Enum.sort_by(filtered, &pricing_amount(&1.pricing), :desc)
        _ -> Enum.sort_by(filtered, & &1.quality_score, :desc)
      end

    results =
      sorted
      |> Enum.drop((page - 1) * per_page)
      |> Enum.take(per_page)
      |> Enum.map(&skill_summary/1)

    %{
      results: results,
      total: total,
      page: page
    }
  end

  # ---------------------------------------------------------------------------
  # Internal: Acquire Skill
  # ---------------------------------------------------------------------------

  defp do_acquire_skill(buyer_id, skill_id) do
    case :ets.lookup(@skills_table, skill_id) do
      [{^skill_id, _skill}] ->
        now = DateTime.utc_now()

        acquisition = %{
          skill_id: skill_id,
          buyer_id: buyer_id,
          acquired_at: now,
          license: determine_license(skill_id)
        }

        :ets.insert(@acquisitions_table, {{skill_id, buyer_id}, acquisition})

        # Increment download count
        :ets.update_element(@skills_table, skill_id, [
          {15, 1}  # downloads field is position 15 in the tuple
        ])

        # Re-read skill to get updated download count and bump quality score
        [{^skill_id, skill}] = :ets.lookup(@skills_table, skill_id)
        updated_skill = %{skill | downloads: skill.downloads + 1}
        updated_skill = %{updated_skill | quality_score: compute_quality_score(updated_skill)}
        :ets.insert(@skills_table, {skill_id, updated_skill})

        Logger.info("[Marketplace] #{buyer_id} acquired skill #{skill_id}")
        {:ok, acquisition}

      [] ->
        {:error, "skill_not_found"}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal: Rate Skill
  # ---------------------------------------------------------------------------

  defp do_rate_skill(rater_id, skill_id, rating) do
    case :ets.lookup(@skills_table, skill_id) do
      [{^skill_id, skill}] ->
        now = DateTime.utc_now()

        # Check for existing rating (update it)
        existing =
          :ets.lookup(@ratings_table, {skill_id, rater_id})

        old_value =
          case existing do
            [{{^skill_id, ^rater_id}, _old_rating}] ->
              # Delete old rating so we can re-insert
              :ets.delete_object(@ratings_table, hd(existing))
              # Read old value from the rating map
              {{_, _}, old_r} = hd(existing)
              old_r.value

            [] ->
              nil
          end

        rating_record = %{
          skill_id: skill_id,
          rater_id: rater_id,
          value: rating,
          rated_at: now
        }

        :ets.insert(@ratings_table, {{skill_id, rater_id}, rating_record})

        # Update aggregate rating on skill
        {new_count, new_sum} =
          case old_value do
            nil ->
              # New rating
              {skill.rating_count + 1, skill.rating_sum + rating}

            old ->
              # Updated rating: subtract old, add new
              {skill.rating_count, skill.rating_sum - old + rating}
          end

        updated_skill =
          %{skill | rating_count: new_count, rating_sum: new_sum}
          |> compute_and_set_quality()

        :ets.insert(@skills_table, {skill_id, updated_skill})

        Logger.info("[Marketplace] #{rater_id} rated skill #{skill_id}: #{rating}/5")
        {:ok, %{skill_id: skill_id, rating: rating, new_average: Float.round(new_sum / new_count, 2)}}

      [] ->
        {:error, "skill_not_found"}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal: Execute Skill
  # ---------------------------------------------------------------------------

  defp do_execute_skill(buyer_id, skill_id, context) do
    case :ets.lookup(@skills_table, skill_id) do
      [{^skill_id, skill}] ->
        start_time = System.monotonic_time(:millisecond)

        try do
          # Build the execution context by merging skill instructions with caller context
          execution_context = %{
            skill_id: skill_id,
            skill_name: skill.name,
            instructions: skill.instructions,
            author: skill.author,
            buyer_id: buyer_id,
            user_context: context,
            executed_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }

          # The actual execution would be delegated to the agent loop or
          # a skill execution engine. For now, we return the prepared context
          # and track the execution for billing.
          result = %{
            status: "executed",
            skill_id: skill_id,
            skill_name: skill.name,
            context: execution_context,
            cost: pricing_amount(skill.pricing)
          }

          # Record successful execution
          duration = System.monotonic_time(:millisecond) - start_time
          record_execution(skill_id, buyer_id, true, duration)

          # Update skill metrics
          [{^skill_id, current}] = :ets.lookup(@skills_table, skill_id)

          updated =
            %{current | successful_executions: current.successful_executions + 1}
            |> compute_and_set_quality()

          :ets.insert(@skills_table, {skill_id, updated})

          {:ok, result}
        rescue
          e ->
            # Record failed execution
            duration = System.monotonic_time(:millisecond) - start_time
            record_execution(skill_id, buyer_id, false, duration)

            [{^skill_id, current}] = :ets.lookup(@skills_table, skill_id)

            updated =
              %{current | failed_executions: current.failed_executions + 1}
              |> compute_and_set_quality()

            :ets.insert(@skills_table, {skill_id, updated})

            Logger.error("[Marketplace] Skill execution failed: #{Exception.message(e)}")
            {:error, "execution_failed"}
        end

      [] ->
        {:error, "skill_not_found"}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal: Revenue Report
  # ---------------------------------------------------------------------------

  defp do_revenue_report(publisher_id) do
    period = Date.utc_today() |> Date.to_string()

    # Get all skills by this publisher
    publisher_skills =
      :ets.tab2list(@skills_table)
      |> Enum.filter(fn {_id, skill} -> skill.author == publisher_id end)
      |> Enum.map(fn {_id, skill} -> skill end)

    # Count acquisitions per skill
    skill_breakdown =
      publisher_skills
      |> Enum.map(fn skill ->
        acquisitions =
          :ets.lookup(@acquisitions_table, {skill.skill_id, :_})
          |> Enum.count()

        # Sum up execution revenue
        executions =
          :ets.tab2list(@executions_table)
          |> Enum.filter(fn {{sid, _ts}, _exec} -> sid == skill.skill_id end)
          |> Enum.map(fn {_key, exec} -> exec end)

        execution_count = length(executions)

        # Revenue = acquisitions * listing price + executions * per-execution price
        acquisition_revenue = acquisitions * pricing_amount(skill.pricing)

        execution_revenue =
          case skill.pricing.type do
            :per_execution -> execution_count * skill.pricing.amount
            _ -> 0.0
          end

        total_skill_earnings = acquisition_revenue + execution_revenue

        %{
          skill_id: skill.skill_id,
          name: skill.name,
          executions: execution_count,
          acquisitions: acquisitions,
          earnings: Float.round(total_skill_earnings, 2)
        }
      end)

    total_earnings =
      skill_breakdown
      |> Enum.map(& &1.earnings)
      |> Enum.sum()
      |> Float.round(2)

    %{
      publisher_id: publisher_id,
      total_earnings: total_earnings,
      skill_breakdown: skill_breakdown,
      period: period
    }
  end

  # ---------------------------------------------------------------------------
  # Internal: Marketplace Stats
  # ---------------------------------------------------------------------------

  defp do_marketplace_stats do
    all_skills =
      :ets.tab2list(@skills_table)
      |> Enum.map(fn {_id, skill} -> skill end)

    all_acquisitions =
      :ets.tab2list(@acquisitions_table)
      |> Enum.map(fn {_key, _acq} -> 1 end)

    all_executions =
      :ets.tab2list(@executions_table)
      |> Enum.map(fn {_key, _exec} -> 1 end)

    total_skills = length(all_skills)
    total_acquisitions = length(all_acquisitions)
    total_executions = length(all_executions)

    # Unique publishers
    publishers =
      all_skills
      |> Enum.map(& &1.author)
      |> Enum.uniq()

    # Total revenue (sum of all per-execution pricing * successful executions)
    total_revenue =
      all_skills
      |> Enum.filter(fn skill ->
        pricing_type = skill.pricing["type"] || skill.pricing[:type]
        pricing_type == "per_execution" || pricing_type == :per_execution
      end)
      |> Enum.map(fn skill ->
        successful = Map.get(skill, :successful_executions, 0)
        amount = skill.pricing["amount"] || skill.pricing[:amount] || 0
        successful * amount
      end)
      |> Enum.sum()
      |> Float.round(2)

    # Top categories
    top_categories =
      all_skills
      |> Enum.map(& &1.category)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_cat, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {cat, _count} -> cat end)

    # Trending skills (highest quality score growth, or highest downloads recently)
    trending_skills =
      all_skills
      |> Enum.sort_by(& &1.quality_score, :desc)
      |> Enum.take(5)
      |> Enum.map(&skill_summary/1)

    %{
      total_skills: total_skills,
      total_publishers: length(publishers),
      total_acquisitions: total_acquisitions,
      total_executions: total_executions,
      total_revenue: total_revenue,
      top_categories: top_categories,
      trending_skills: trending_skills
    }
  end

  # ---------------------------------------------------------------------------
  # Internal: Quality Scoring (Signal Theory Integration)
  # ---------------------------------------------------------------------------

  @doc """
  Compute the composite quality score for a skill.

  Uses Signal Theory S/N ratio combined with rating and usage metrics:
    quality = 0.4 * sn_ratio + 0.3 * normalized_rating + 0.3 * normalized_usage

  Where:
    sn_ratio         = successful / (successful + failed), clamped to [0, 1]
    normalized_rating = weighted_average / 5.0
    normalized_usage  = log(1 + downloads) / log(1 + max_downloads)
  """
  @spec compute_quality_score(skill()) :: float()
  def compute_quality_score(skill) do
    # S/N ratio: signal = successful executions, noise = failed
    total_executions = skill.successful_executions + skill.failed_executions

    sn_ratio =
      if total_executions == 0 do
        # No executions yet: neutral score of 0.5
        0.5
      else
        skill.successful_executions / total_executions
      end

    # Weighted rating using exponential decay (recent ratings matter more)
    normalized_rating =
      if skill.rating_count == 0 do
        0.5
      else
        weighted_avg = compute_weighted_rating(skill.skill_id)
        weighted_avg / 5.0
      end

    # Usage score: log-normalized downloads
    max_downloads = compute_max_downloads()
    normalized_usage = log_normalize(skill.downloads, max_downloads)

    composite =
      @sn_weight * sn_ratio + @rating_weight * normalized_rating + @usage_weight * normalized_usage

    Float.round(composite, 4)
  end

  defp compute_and_set_quality(skill) do
    %{skill | quality_score: compute_quality_score(skill)}
  end

  # Weighted average rating with exponential time decay.
  # More recent ratings contribute more to the average.
  defp compute_weighted_rating(skill_id) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    half_life = @rating_half_life_days * 24 * 3600

    ratings =
      :ets.lookup(@ratings_table, {skill_id, :_})
      |> Enum.map(fn
        {{^skill_id, _rater_id}, rating} -> rating
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    if ratings == [] do
      0.0
    else
      {weighted_sum, total_weight} =
        Enum.reduce(ratings, {0.0, 0.0}, fn rating, {wsum, tw} ->
          age_seconds = now - DateTime.to_unix(rating.rated_at)
          decay = :math.exp(-0.693 * age_seconds / half_life)
          {wsum + rating.value * decay, tw + decay}
        end)

      if total_weight > 0, do: weighted_sum / total_weight, else: 0.0
    end
  end

  defp compute_max_downloads do
    :ets.tab2list(@skills_table)
    |> Enum.map(fn {_id, skill} -> skill.downloads end)
    |> Enum.max(fn -> 1 end)
  end

  defp log_normalize(_value, max_value) when max_value <= 1, do: 0.0
  defp log_normalize(value, max_value), do: :math.log(1 + value) / :math.log(1 + max_value)

  # ---------------------------------------------------------------------------
  # Internal: Helpers
  # ---------------------------------------------------------------------------

  defp generate_skill_id(name, publisher_id) do
    hash =
      :crypto.hash(:sha256, "#{name}:#{publisher_id}:#{System.system_time(:nanosecond)}")
      |> Base.encode16(case: :lower)
      |> String.slice(0, 12)

    "skill_#{hash}"
  end

  defp normalize_pricing(%{type: type, amount: amount})
       when is_atom(type) and is_number(amount) do
    %{type: type, amount: amount}
  end

  defp normalize_pricing(%{"type" => type, "amount" => amount}) do
    %{type: to_pricing_type(type), amount: amount}
  end

  defp normalize_pricing(_), do: %{type: :free, amount: 0.0}

  defp to_pricing_type("per_execution"), do: :per_execution
  defp to_pricing_type("subscription"), do: :subscription
  defp to_pricing_type("perpetual"), do: :perpetual
  defp to_pricing_type("free"), do: :free
  defp to_pricing_type(other) when is_atom(other), do: other
  defp to_pricing_type(_), do: :free

  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(other), do: [to_string(other)]

  defp pricing_amount(%{amount: amount}) when is_number(amount), do: amount
  defp pricing_amount(_), do: 0.0

  defp determine_license(skill_id) do
    case :ets.lookup(@skills_table, skill_id) do
      [{^skill_id, skill}] -> skill.pricing.type
      [] -> :perpetual
    end
  end

  defp filter_by_category(skills, nil), do: skills

  defp filter_by_category(skills, category) do
    cat_lower = String.downcase(category)

    Enum.filter(skills, fn skill ->
      String.downcase(skill.category) == cat_lower
    end)
  end

  defp filter_by_min_rating(skills, nil), do: skills

  defp filter_by_min_rating(skills, min) when is_number(min) do
    Enum.filter(skills, fn skill ->
      if skill.rating_count > 0 do
        skill.rating_sum / skill.rating_count >= min
      else
        true
      end
    end)
  end

  defp filter_by_min_rating(skills, _), do: skills

  defp record_execution(skill_id, buyer_id, success, duration_ms) do
    now = DateTime.utc_now()

    execution = %{
      skill_id: skill_id,
      buyer_id: buyer_id,
      executed_at: now,
      success: success,
      duration_ms: duration_ms
    }

    :ets.insert(@executions_table, {{skill_id, now}, execution})
  end

  @doc """
  Return a public-safe summary of a skill (no instructions).
  """
  @spec skill_summary(skill()) :: map()
  def skill_summary(skill) do
    average_rating =
      if skill.rating_count > 0 do
        Float.round(skill.rating_sum / skill.rating_count, 2)
      else
        nil
      end

    %{
      skill_id: skill.skill_id,
      name: skill.name,
      description: skill.description,
      author: skill.author,
      category: skill.category,
      version: skill.version,
      tags: skill.tags,
      triggers: skill.triggers,
      pricing: %{type: skill.pricing.type, amount: skill.pricing.amount},
      rating: average_rating,
      rating_count: skill.rating_count,
      downloads: skill.downloads,
      quality_score: skill.quality_score,
      published_at: DateTime.to_iso8601(skill.published_at)
    }
  end
end
