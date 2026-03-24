defmodule OptimalSystemAgent.Memory.Consolidator do
  @moduledoc """
  Pattern consolidation for the SICA learning engine.

  Two consolidation modes:

    - **Incremental** (every 5 interactions) — Merge similar patterns, prune
      entries not seen in 7 days with fewer than 2 occurrences.
    - **Full** (every 50 interactions) — Same as incremental but with a stricter
      3-day staleness window and skill-candidate identification.

  Pattern similarity is measured with Jaccard similarity on description words.
  Two patterns are considered mergeable when their triggers match exactly and
  their descriptions share >= 70% of words.

  All SQLite writes go through `OptimalSystemAgent.Store.Pattern` via Ecto.
  """

  require Logger

  alias OptimalSystemAgent.Store.{Repo, Pattern}
  import Ecto.Query

  @similarity_threshold 0.7
  @stale_days_incremental 7
  @stale_days_full 3
  @maturity_threshold 5
  @consolidation_threshold 0.8

  # Category weights for consolidation (higher = more important)
  @category_weights %{
    "decision" => 5,
    "preference" => 4,
    "pattern" => 3,
    "lesson" => 2,
    "context" => 1
  }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Run an incremental consolidation pass.

  Loads all patterns from SQLite, merges similar ones, prunes stale single-
  occurrence entries, and returns a report map.
  """
  @spec incremental() :: map()
  def incremental do
    patterns = load_all()
    run_pass(patterns, @stale_days_incremental, :incremental)
  end

  @doc """
  Run a full consolidation pass.

  Same as incremental but uses a 3-day staleness window and additionally
  identifies skill-generation candidates (patterns seen >= 5 times).
  """
  @spec full() :: map()
  def full do
    patterns = load_all()
    run_pass(patterns, @stale_days_full, :full)
  end

  @doc """
  Upsert a pattern by trigger key.

  If a pattern with the same trigger exists, its occurrence count is
  incremented. Otherwise a new record is inserted.
  """
  @spec upsert(map()) :: :ok
  def upsert(attrs) when is_map(attrs) do
    trigger = attrs.trigger
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Repo.get_by(Pattern, trigger: trigger) do
      nil ->
        id = generate_id(trigger)

        %Pattern{}
        |> Pattern.changeset(%{
          id: id,
          description: attrs.description,
          trigger: trigger,
          response: to_string(attrs.response),
          category: attrs[:category] || "context",
          occurrences: 1,
          success_rate: 1.0,
          tags: attrs[:tags] || "",
          created_at: now,
          last_seen: now
        })
        |> Repo.insert()
        |> case do
          {:ok, _} ->
            :ok

          {:error, changeset} ->
            Logger.warning("[Consolidator] insert failed: #{inspect(changeset.errors)}")
        end

      existing ->
        existing
        |> Pattern.changeset(%{occurrences: existing.occurrences + 1, last_seen: now})
        |> Repo.update()
        |> case do
          {:ok, _} ->
            :ok

          {:error, changeset} ->
            Logger.warning("[Consolidator] update failed: #{inspect(changeset.errors)}")
        end
    end
  rescue
    e ->
      Logger.warning("[Consolidator] upsert error: #{Exception.message(e)}")
  end

  @doc "Load all patterns from SQLite as plain maps."
  @spec load_all() :: [map()]
  def load_all do
    Repo.all(Pattern)
    |> Enum.map(&to_map/1)
  rescue
    e ->
      Logger.warning("[Consolidator] load_all error: #{Exception.message(e)}")
      []
  end

  @doc "Load solution/correction patterns from SQLite."
  @spec load_solutions() :: [map()]
  def load_solutions do
    from(p in Pattern, where: p.category == "solution" or p.category == "correction")
    |> Repo.all()
    |> Enum.map(&to_map/1)
  rescue
    e ->
      Logger.warning("[Consolidator] load_solutions error: #{Exception.message(e)}")
      []
  end

  @doc """
  Consolidate a list of memory entries by merging similar ones.

  Uses keyword similarity and category matching to determine which entries
  should be merged. Returns a deduplicated list with merged entries.
  """
  @spec consolidate(list(map())) :: list(map())
  def consolidate(entries) when is_list(entries) do
    consolidate_entries(entries, [])
  end

  @doc """
  Calculate similarity score between two memory entries.

  Uses Jaccard similarity on keywords and factors in category match.
  Returns 0.0 to 1.0 where 1.0 is identical.
  """
  @spec similarity_score(map(), map()) :: float()
  def similarity_score(entry1, entry2) do
    kw_score = keyword_similarity(Map.get(entry1, :keywords) || Map.get(entry1, "keywords") || "",
                                  Map.get(entry2, :keywords) || Map.get(entry2, "keywords") || "")

    # Apply category factor: same category = 1.0, different category = 0.8 (penalty)
    cat_factor =
      if normalize_category(entry1) == normalize_category(entry2), do: 1.0, else: 0.8

    kw_score * cat_factor
  end

  @doc """
  Merge two memory entries into a single entry.

  Combines keywords, preserves higher weight category, keeps most recent
  accessed_at, and combines content.
  """
  @spec merge_entries(map(), map()) :: map()
  def merge_entries(entry1, entry2) do
    kw1 = Map.get(entry1, :keywords) || Map.get(entry1, "keywords") || ""
    kw2 = Map.get(entry2, :keywords) || Map.get(entry2, "keywords") || ""

    cat1 = normalize_category(entry1)
    cat2 = normalize_category(entry2)

    at1 = Map.get(entry1, :accessed_at) || Map.get(entry1, "accessed_at") || ""
    at2 = Map.get(entry2, :accessed_at) || Map.get(entry2, "accessed_at") || ""

    most_recent = if at1 > at2, do: at1, else: at2

    %{
      id: Map.get(entry1, :id) || Map.get(entry1, "id") || Map.get(entry2, :id) || Map.get(entry2, "id"),
      content: combine_content(Map.get(entry1, :content) || Map.get(entry1, "content") || "",
                               Map.get(entry2, :content) || Map.get(entry2, "content") || ""),
      keywords: keyword_union(kw1, kw2),
      category: higher_weight_category(cat1, cat2),
      accessed_at: most_recent
    }
  end

  @doc """
  Combine two keyword strings into a deduplicated union.

  Splits on comma, trims whitespace, deduplicates, and rejoins.
  """
  @spec keyword_union(String.t(), String.t()) :: String.t()
  def keyword_union(keywords1, keywords2) do
    (String.split(to_string(keywords1 || ""), ",", trim: true) ++
     String.split(to_string(keywords2 || ""), ",", trim: true))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.join(",")
  end

  @doc """
  Select the higher weight category between two options.

  Categories have weights: decision=5, preference=4, pattern=3, lesson=2, context=1.
  Unknown categories are treated as weight 0.
  """
  @spec higher_weight_category(String.t(), String.t()) :: String.t()
  def higher_weight_category(cat1, cat2) do
    w1 = Map.get(@category_weights, normalize_category(cat1), 0)
    w2 = Map.get(@category_weights, normalize_category(cat2), 0)

    if w1 >= w2, do: normalize_category(cat1), else: normalize_category(cat2)
  end

  @doc """
  Return the consolidation threshold value.

  Entries with similarity >= this threshold are candidates for merging.
  """
  @spec consolidation_threshold() :: float()
  def consolidation_threshold, do: @consolidation_threshold

  @doc "Run a single consolidation pass on patterns."
  @spec run_pass(list(map()), integer(), atom()) :: map()
  def run_pass(patterns, stale_days, mode) do
    {merged, merge_count} = merge_similar(patterns)

    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-stale_days * 86_400, :second)
      |> DateTime.to_iso8601()

    {active, pruned} =
      Enum.split_with(merged, fn p ->
        p.occurrences >= 2 or (p.last_seen || "") >= cutoff
      end)

    pruned_ids = Enum.map(pruned, & &1.id)
    delete_by_ids(pruned_ids)

    base = %{
      type: mode,
      patterns_before: length(patterns),
      patterns_after: length(active),
      merged: merge_count,
      pruned: length(pruned),
      timestamp: DateTime.utc_now()
    }

    if mode == :full do
      mature = active |> Enum.filter(&(&1.occurrences >= @maturity_threshold)) |> Enum.map(& &1.id)

      # Auto-generate skills from mature patterns
      if length(mature) > 0 do
        try do
          OptimalSystemAgent.Memory.SkillGenerator.generate_all_pending()
        rescue
          e -> Logger.debug("[Consolidator] Skill generation skipped: #{inspect(e)}")
        end
      end

      Map.merge(base, %{skill_candidates: length(mature), skill_candidate_ids: mature})
    else
      base
    end
  end

  @doc "Merge similar patterns using Jaccard similarity."
  @spec merge_similar(list(map())) :: {list(map()), integer()}
  def merge_similar(patterns) do
    {result, count} =
      Enum.reduce(patterns, {[], 0}, fn pattern, {acc, merge_count} ->
        case find_similar_in(pattern, acc) do
          nil ->
            {[pattern | acc], merge_count}

          existing ->
            merged = merge_two(existing, pattern)
            updated = Enum.map(acc, fn p -> if p.id == existing.id, do: merged, else: p end)
            {updated, merge_count + 1}
        end
      end)

    {Enum.reverse(result), count}
  end

  @doc "Find a similar pattern in the candidate list."
  @spec find_similar_in(map(), list(map())) :: map() | nil
  def find_similar_in(pattern, candidates) do
    Enum.find(candidates, fn c ->
      c.id != pattern.id and
        c.trigger == pattern.trigger and
        jaccard(pattern.description, c.description) >= @similarity_threshold
    end)
  end

  @doc "Merge two pattern entries into one."
  @spec merge_two(map(), map()) :: map()
  def merge_two(a, b) do
    total = a.occurrences + b.occurrences
    weighted = (a.success_rate * a.occurrences + b.success_rate * b.occurrences) / max(total, 1)

    merged_tags =
      [a.tags || "", b.tags || ""]
      |> Enum.flat_map(&String.split(&1, ","))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
      |> Enum.join(",")

    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Repo.get(Pattern, a.id) do
      nil ->
        :ok

      record ->
        record
        |> Pattern.changeset(%{
          occurrences: total,
          success_rate: min(1.0, weighted),
          tags: merged_tags,
          last_seen: now
        })
        |> Repo.update()
    end

    Map.merge(a, %{
      occurrences: total,
      success_rate: min(1.0, weighted),
      tags: merged_tags,
      last_seen: now
    })
  rescue
    e ->
      Logger.warning("[Consolidator] merge_two error: #{Exception.message(e)}")
      a
  end

  @doc "Calculate Jaccard similarity between two strings."
  @spec jaccard(String.t(), String.t()) :: float()
  def jaccard(a, b) when is_binary(a) and is_binary(b) do
    wa = a |> String.downcase() |> String.split(~r/\W+/, trim: true) |> MapSet.new()
    wb = b |> String.downcase() |> String.split(~r/\W+/, trim: true) |> MapSet.new()
    inter = MapSet.intersection(wa, wb) |> MapSet.size()
    union = MapSet.union(wa, wb) |> MapSet.size()
    if union == 0, do: 0.0, else: inter / union
  end

  def jaccard(_, _), do: 0.0

  @doc "Delete patterns by their IDs."
  @spec delete_by_ids(list(String.t())) :: :ok
  def delete_by_ids([]), do: :ok

  def delete_by_ids(ids) do
    Repo.delete_all(from(p in Pattern, where: p.id in ^ids))
  rescue
    e ->
      Logger.warning("[Consolidator] delete_by_ids error: #{Exception.message(e)}")
  end

  @doc "Convert a Pattern struct to a plain map."
  @spec to_map(%Pattern{}) :: map()
  def to_map(%Pattern{} = p) do
    %{
      id: p.id,
      description: p.description,
      trigger: p.trigger,
      response: p.response,
      category: p.category,
      occurrences: p.occurrences,
      success_rate: p.success_rate,
      tags: p.tags,
      created_at: p.created_at,
      last_seen: p.last_seen
    }
  end

  @doc "Generate a unique ID from a seed string."
  @spec generate_id(String.t()) :: String.t()
  def generate_id(seed) do
    ts = System.system_time(:nanosecond) |> to_string()
    :crypto.hash(:sha256, seed <> ts) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  # ---------------------------------------------------------------------------
  # Private helpers for memory entry consolidation
  # ---------------------------------------------------------------------------

  defp consolidate_entries([], acc), do: Enum.reverse(acc)

  defp consolidate_entries([entry | rest], acc) do
    case find_similar_entry(entry, acc) do
      nil ->
        consolidate_entries(rest, [entry | acc])

      similar ->
        merged = merge_entries(similar, entry)
        updated = Enum.map(acc, fn e -> if e.id == similar.id, do: merged, else: e end)
        consolidate_entries(rest, updated)
    end
  end

  defp find_similar_entry(entry, candidates) do
    Enum.find(candidates, fn c ->
      c.id != entry.id and
        similarity_score(c, entry) >= @consolidation_threshold
    end)
  end

  defp keyword_similarity(kw1, kw2) do
    set1 = kw1 |> String.downcase() |> String.split(~r/\s*,\s*/, trim: true) |> MapSet.new()
    set2 = kw2 |> String.downcase() |> String.split(~r/\s*,\s*/, trim: true) |> MapSet.new()

    inter = MapSet.intersection(set1, set2) |> MapSet.size()
    union = MapSet.union(set1, set2) |> MapSet.size()

    if union == 0, do: 0.0, else: inter / union
  end

  defp normalize_category(entry) when is_binary(entry), do: String.downcase(entry)

  defp normalize_category(entry) do
    entry
    |> Map.get(:category)
    |> Kernel.||(Map.get(entry, "category"))
    |> Kernel.||("context")
    |> to_string()
    |> String.downcase()
  end

  defp combine_content("", content2), do: content2
  defp combine_content(content1, ""), do: content1
  defp combine_content(content1, content2), do: "#{content1}\n\n#{content2}"
end
