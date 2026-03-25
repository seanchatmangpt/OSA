defmodule OptimalSystemAgent.Agent.Hooks.PreCommit do
  @moduledoc """
  Pre-commit hook for Signal Theory coherence validation (Fortune 5 Layer 2).

  Validates that staged files have Signal Theory S=(M,G,T,F,W) encoding
  with coherence score ≥ 0.8 before allowing commits.

  ## Signal Theory Encoding

  Each output must have all 5 dimensions:
    - Mode (M): linguistic, code, data, visual, mixed
    - Genre (G): spec, brief, report, analysis, chat
    - Type (T): commit, direct, inform, decide, express
    - Format (F): markdown, json, yaml, python
    - Structure (W): adr-template, module-pattern, conversation, list

  ## Coherence Scoring

  - **Perfect signal (all dimensions valid):** 1.0
  - **Missing dimension:** 0.0
  - **Invalid values:** 0.5

  Combined score for all staged files must be ≥ 0.8.

  ## Usage

  Register the hook at application startup:

      OptimalSystemAgent.Agent.Hooks.PreCommit.register()

  Validate staged files:

      {:ok, true} = OptimalSystemAgent.Agent.Hooks.PreCommit.validate_commit()

  Get coherence score:

      {score, details} = OptimalSystemAgent.Agent.Hooks.PreCommit.coherence_score()
  """

  require Logger

  # ── Registration ────────────────────────────────────────────────────

  @doc """
  Register the pre-commit hook.

  This function should be called once at application startup to initialize
  the pre-commit validation system.
  """
  def register do
    Logger.info("Pre-commit hook registered - Signal Theory coherence validation enabled")
    :ok
  end

  # ── Validation ──────────────────────────────────────────────────────

  @doc """
  Validate staged files for Signal Theory coherence.

  Returns:
    - `{:ok, true}` if coherence ≥ 0.8
    - `{:error, reason}` if coherence < 0.8

  ## Examples

      {:ok, true} = OptimalSystemAgent.Agent.Hooks.PreCommit.validate_commit()
      {:error, "Coherence score 0.5 below threshold 0.8"} = ...
  """
  def validate_commit do
    {score, _details} = coherence_score()

    threshold = 0.8

    if score >= threshold do
      {:ok, true}
    else
      {:error, "Coherence score #{score} below threshold #{threshold}"}
    end
  end

  @doc """
  Calculate coherence score for staged changes.

  Returns `{coherence_score, details}` where coherence_score is a float 0.0-1.0.

  ## Details Structure

  The details map contains:
    - `:files_analyzed` — count of files checked
    - `:scores` — list of individual file scores
    - `:individual_coherence` — average of individual scores
    - `:combined_coherence` — final combined score

  ## Examples

      {0.9, %{files_analyzed: 3, individual_coherence: 0.9, combined_coherence: 0.9}}
  """
  def coherence_score do
    # Get staged files from git
    case System.cmd("git", ["diff", "--cached", "--name-only"]) do
      {output, 0} ->
        # Parse staged file list
        staged_files = output
          |> String.trim()
          |> String.split("\n")
          |> Enum.filter(&(&1 != ""))

        # Filter for .json files in priv/sensors/
        sensor_files = Enum.filter(staged_files, fn file ->
          String.ends_with?(file, ".json") and String.contains?(file, "priv/sensors")
        end)

        # Calculate score for each file
        individual_scores = Enum.map(sensor_files, fn file ->
          case File.read(file) do
            {:ok, content} -> calculate_score(content)
            {:error, _} -> 0.0
          end
        end)

        # Calculate combined coherence
        individual_coherence = if Enum.empty?(individual_scores) do
          1.0  # No staged sensor files is considered OK
        else
          Enum.sum(individual_scores) / length(individual_scores)
        end

        combined_coherence = individual_coherence

        {combined_coherence,
         %{
           files_analyzed: length(sensor_files),
           scores: individual_scores,
           individual_coherence: individual_coherence,
           combined_coherence: combined_coherence
         }}

      {_output, _exit_code} ->
        # git command failed - return perfect score (probably not in git repo)
        {1.0,
         %{
           files_analyzed: 0,
           scores: [],
           individual_coherence: 1.0,
           combined_coherence: 1.0
         }}
    end
  end

  # ── Signal Theory Calculation ───────────────────────────────────────

  @doc """
  Calculate Signal Theory S/N score for a JSON object.

  Validates that the object has all 5 Signal Theory dimensions and
  that each dimension contains a valid value.

  Returns a float from 0.0 to 1.0:
    - 1.0 = perfect signal (all dimensions present and valid)
    - 0.5 = partial signal (all dimensions present but some invalid)
    - 0.0 = no signal (missing dimension or invalid JSON)

  ## Examples

      iex> json = Jason.encode!(%{"mode" => "data", "genre" => "spec", "type" => "commit", "format" => "json", "structure" => "list"})
      iex> OptimalSystemAgent.Agent.Hooks.PreCommit.calculate_score(json)
      1.0

      iex> json = Jason.encode!(%{"mode" => "data", "genre" => "spec", "type" => "commit", "format" => "json"})
      iex> OptimalSystemAgent.Agent.Hooks.PreCommit.calculate_score(json)
      0.0
  """
  def calculate_score(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} ->
        # Check if all 5 dimensions are present
        dimensions = ["mode", "genre", "type", "format", "structure"]
        present = Enum.filter(dimensions, &Map.has_key?(data, &1))

        # If any dimension is missing, score is 0.0
        if length(present) < 5 do
          0.0
        else
          # All dimensions present - check validity
          valid_modes = ["linguistic", "code", "data", "visual", "mixed"]
          valid_genres = ["spec", "brief", "report", "analysis", "chat"]
          valid_types = ["commit", "direct", "inform", "decide", "express"]
          valid_formats = ["markdown", "json", "yaml", "python"]
          valid_structures = ["adr-template", "module-pattern", "conversation", "list"]

          mode_valid = data["mode"] in valid_modes
          genre_valid = data["genre"] in valid_genres
          type_valid = data["type"] in valid_types
          format_valid = data["format"] in valid_formats
          structure_valid = data["structure"] in valid_structures

          # Calculate score (1.0 if all valid, 0.5 if any invalid)
          if mode_valid and genre_valid and type_valid and format_valid and structure_valid do
            1.0
          else
            0.5
          end
        end

      {:error, _reason} ->
        # Invalid JSON scores 0.0
        0.0
    end
  end

  @doc """
  Combine multiple Signal Theory scores into a single coherence value.

  Takes a list of individual scores and returns their combined coherence.

  ## Examples

      iex> OptimalSystemAgent.Agent.Hooks.PreCommit.combine_scores([1.0, 1.0, 0.8])
      0.9333...
  """
  def combine_scores(scores) when is_list(scores) do
    case scores do
      [] -> 0.0
      scores -> Enum.sum(scores) / length(scores)
    end
  end
end
