defmodule OptimalSystemAgent.Memory.SkillGenerator do
  @moduledoc """
  Converts mature SICA patterns into SKILL.md files on disk.

  A pattern is considered mature when its occurrence count reaches 5 or more.
  Generated skills are written to ~/.osa/skills/{slug}/SKILL.md in the exact
  format that Tools.Registry.parse_skill_file/1 expects (YAML frontmatter
  between --- markers).

  The `source` frontmatter field carries `auto:{pattern_id}` so that
  skill_exists?/1 can detect duplicates by scanning the skills directory.
  """

  require Logger

  alias OptimalSystemAgent.Memory.Consolidator

  @maturity_threshold 5

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Generate a SKILL.md from a single pattern struct or map.

  Writes to ~/.osa/skills/{slug}/SKILL.md and hot-reloads the registry.
  Returns {:ok, path} on success or {:error, reason} on failure.
  """
  @spec generate_from_pattern(map()) :: {:ok, String.t()} | {:error, term()}
  def generate_from_pattern(pattern) do
    id = pattern[:id] || pattern["id"] || ""
    description = pattern[:description] || pattern["description"] || "unnamed pattern"
    trigger = pattern[:trigger] || pattern["trigger"] || ""
    response = pattern[:response] || pattern["response"] || ""
    category = pattern[:category] || pattern["category"] || "context"
    tags_raw = pattern[:tags] || pattern["tags"] || ""

    slug = slugify(description)
    skills_dir = resolve_skills_dir()
    dir = Path.join(skills_dir, slug)
    path = Path.join(dir, "SKILL.md")

    triggers =
      trigger
      |> String.split(~r/[|,]/, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    tags =
      tags_raw
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    content = render_skill_md(slug, description, triggers, tags, category, id, response)

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(path, content) do
      Logger.info("[SkillGenerator] wrote skill #{slug} -> #{path}")
      reload_registry()
      {:ok, path}
    else
      {:error, reason} ->
        Logger.warning("[SkillGenerator] failed to write #{path}: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.warning("[SkillGenerator] generate_from_pattern error: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  @doc """
  Generate skills for all mature patterns not yet on disk.

  Loads all patterns via Consolidator.load_all/0, filters to those with
  occurrences >= 5, skips any whose skill file already exists, and calls
  generate_from_pattern/1 for the rest.

  Returns {:ok, count} where count is the number of new skills written.
  """
  @spec generate_all_pending() :: {:ok, non_neg_integer()}
  def generate_all_pending do
    patterns = Consolidator.load_all()

    mature =
      Enum.filter(patterns, fn p ->
        occurrences = p[:occurrences] || p["occurrences"] || 0
        occurrences >= @maturity_threshold
      end)

    count =
      Enum.reduce(mature, 0, fn pattern, acc ->
        id = pattern[:id] || pattern["id"] || ""

        if skill_exists?(id) do
          acc
        else
          case generate_from_pattern(pattern) do
            {:ok, _path} -> acc + 1
            {:error, _} -> acc
          end
        end
      end)

    {:ok, count}
  rescue
    e ->
      Logger.warning("[SkillGenerator] generate_all_pending error: #{Exception.message(e)}")
      {:ok, 0}
  end

  @doc """
  Check whether a skill already exists for the given pattern ID.

  Scans ~/.osa/skills/ for any SKILL.md containing "source: auto:{pattern_id}"
  in its frontmatter. Returns true if found, false otherwise.
  """
  @spec skill_exists?(String.t()) :: boolean()
  def skill_exists?(pattern_id) when is_binary(pattern_id) and pattern_id != "" do
    skills_dir = resolve_skills_dir()
    marker = "source: auto:#{pattern_id}"

    skills_dir
    |> Path.join("**/SKILL.md")
    |> Path.wildcard()
    |> Enum.any?(fn path ->
      case File.read(path) do
        {:ok, content} -> String.contains?(content, marker)
        _ -> false
      end
    end)
  rescue
    _ -> false
  end

  def skill_exists?(_), do: false

  @doc """
  Convert a description string into a kebab-case directory slug.

  Downcases, replaces spaces and non-alphanumeric characters with hyphens,
  collapses consecutive hyphens, and trims leading/trailing hyphens.
  """
  @spec slugify(String.t()) :: String.t()
  def slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.replace(~r/-{2,}/, "-")
    |> String.trim("-")
  end

  def slugify(_), do: "unnamed"

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp resolve_skills_dir do
    Application.get_env(:optimal_system_agent, :skills_dir, "~/.osa/skills")
    |> Path.expand()
  end

  defp render_skill_md(slug, description, triggers, tags, category, pattern_id, response) do
    triggers_yaml =
      case triggers do
        [] -> "[]"
        list -> "\n" <> Enum.map_join(list, "\n", fn t -> "  - #{t}" end)
      end

    tags_yaml =
      case tags do
        [] -> "[]"
        list -> "\n" <> Enum.map_join(list, "\n", fn t -> "  - #{t}" end)
      end

    """
    ---
    name: #{slug}
    description: #{description}
    triggers: #{triggers_yaml}
    tools: []
    category: #{category}
    source: auto:#{pattern_id}
    tags: #{tags_yaml}
    ---

    #{response}
    """
  end

  defp reload_registry do
    try do
      OptimalSystemAgent.Tools.Registry.reload_skills()
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end
end
