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
  def generate_from_pattern(pattern) when is_map(pattern) do
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

  def generate_from_pattern(_), do: {:error, "pattern must be a map"}

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
    result =
      text
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.replace(~r/-{2,}/, "-")
      |> String.trim("-")

    if result == "", do: "unnamed", else: result
  end

  def slugify(_), do: "unnamed"

  @doc """
  Generate a complete skill map from a pattern.

  Takes a pattern map with keys: content (string), category (atom), keywords (list or string).
  Returns {:ok, skill_map} with name, description, steps, examples, language fields,
  or {:error, reason} if pattern is invalid.
  """
  @spec generate_skill(map() | nil) :: {:ok, map()} | {:error, term()}
  def generate_skill(pattern) when is_map(pattern) do
    with true <- Map.has_key?(pattern, :content) or Map.has_key?(pattern, "content"),
         content = pattern[:content] || pattern["content"],
         true <- is_binary(content) and String.length(content) > 0 do
      name = generate_name(pattern)
      description = generate_description(pattern)
      steps = generate_steps(pattern)
      examples = generate_examples(pattern)
      language = infer_language(pattern)

      skill = format_skill(name, description, steps, examples)
      skill = Map.put(skill, :language, language)

      {:ok, skill}
    else
      _ -> {:error, "invalid pattern: must be a map with non-empty content field"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  def generate_skill(_), do: {:error, "pattern must be a map"}

  @doc """
  Generate a skill name from pattern content.

  Lowercases, removes special characters, replaces spaces with hyphens.
  Truncates to 50 characters if needed.
  """
  @spec generate_name(map()) :: String.t()
  def generate_name(pattern) when is_map(pattern) do
    content = pattern[:content] || pattern["content"] || ""
    sanitize_string(content) |> String.slice(0..49)
  end

  def generate_name(_), do: "unnamed-skill"

  @doc """
  Generate a description from pattern content and metadata.

  Creates a 1-2 sentence description including category and keywords.
  """
  @spec generate_description(map()) :: String.t()
  def generate_description(pattern) when is_map(pattern) do
    content = pattern[:content] || pattern["content"] || "Skill"
    category = pattern[:category] || pattern["category"] || "practice"
    keywords = pattern[:keywords] || pattern["keywords"] || ""

    category_str = inspect(category) |> String.replace("\"", "")

    keywords_str =
      case keywords do
        kw when is_binary(kw) and kw != "" ->
          kw
          |> String.split(~r/[,|]/, trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.join(", ")

        kw when is_list(kw) ->
          Enum.join(kw, ", ")

        _ ->
          ""
      end

    desc = "#{content}. Category: #{category_str}."

    if keywords_str != "" do
      desc <> " Keywords: #{keywords_str}."
    else
      desc
    end
  end

  def generate_description(_), do: "Generated skill from pattern."

  @doc """
  Generate action steps from pattern content.

  Returns a list of step strings. For decision patterns, suggests apply/verify steps.
  For pattern category, suggests learn/implement/test steps.
  """
  @spec generate_steps(map()) :: list(String.t())
  def generate_steps(pattern) when is_map(pattern) do
    content = pattern[:content] || pattern["content"] || ""
    category = pattern[:category] || pattern["category"]

    case category do
      :decision ->
        [
          "Understand the decision: #{content}",
          "Apply the approach in current context",
          "Verify results align with goals",
          "Document outcomes for reference"
        ]

      :pattern ->
        [
          "Study the pattern: #{content}",
          "Identify where this pattern applies",
          "Implement the pattern in code",
          "Test and validate the implementation"
        ]

      :preference ->
        [
          "Recognize the preference: #{content}",
          "Configure tools or environment",
          "Adapt workflows accordingly"
        ]

      _ ->
        [
          "Understand: #{content}",
          "Apply in practice",
          "Verify effectiveness"
        ]
    end
  end

  def generate_steps(_), do: ["Apply the skill", "Verify results"]

  @doc """
  Generate example usage from pattern.

  Returns a list of example strings. When keywords suggest a programming language,
  includes code snippets.
  """
  @spec generate_examples(map()) :: list(String.t())
  def generate_examples(pattern) when is_map(pattern) do
    language = infer_language(pattern)
    content = pattern[:content] || pattern["content"] || ""

    case language do
      "elixir" ->
        [
          "Write tests before implementation: defmodule MyTest do ... end",
          "Use pattern matching in function clauses",
          content
        ]

      "rust" ->
        [
          "Leverage Rust's type system for correctness",
          "Use Result<T, E> for error handling",
          content
        ]

      "python" ->
        [
          "Write docstrings for all functions",
          "Use type hints in function signatures",
          content
        ]

      _ ->
        [content]
    end
    |> Enum.filter(&(&1 != ""))
  end

  def generate_examples(_), do: []

  @doc """
  Format a skill as a map with name, description, steps, and examples.

  Combines generated components into final skill structure.
  """
  @spec format_skill(String.t(), String.t(), list(String.t()), list(String.t())) :: map()
  def format_skill(name, description, steps, examples) do
    %{
      name: name,
      description: description,
      steps: steps,
      examples: examples
    }
  end

  @doc """
  Infer programming language from pattern keywords.

  Checks keywords for language hints: elixir, rust, python, go, etc.
  Returns language name or "generic" if no match.
  """
  @spec infer_language(map()) :: String.t()
  def infer_language(pattern) when is_map(pattern) do
    keywords = pattern[:keywords] || pattern["keywords"] || ""

    keywords_str =
      case keywords do
        kw when is_binary(kw) -> String.downcase(kw)
        kw when is_list(kw) -> kw |> Enum.map(&String.downcase/1) |> Enum.join(",")
        _ -> ""
      end

    cond do
      String.contains?(keywords_str, ["elixir", "phoenix", "genserver"]) -> "elixir"
      String.contains?(keywords_str, ["rust", "cargo", "tokio"]) -> "rust"
      String.contains?(keywords_str, ["python", "pip", "pytest"]) -> "python"
      String.contains?(keywords_str, ["go", "golang"]) -> "go"
      String.contains?(keywords_str, ["typescript", "javascript"]) -> "typescript"
      true -> "generic"
    end
  end

  def infer_language(_), do: "generic"

  @doc """
  Sanitize a string for use as a skill name.

  Lowercases, removes special characters, replaces spaces with hyphens,
  collapses consecutive hyphens, and trims leading/trailing hyphens.
  """
  @spec sanitize_string(String.t()) :: String.t()
  def sanitize_string(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-{2,}/, "-")
    |> String.trim("-")
  end

  def sanitize_string(_), do: ""

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
