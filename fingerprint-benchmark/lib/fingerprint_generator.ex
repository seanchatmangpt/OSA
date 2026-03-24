defmodule FingerprintBenchmark.Generator do
  @moduledoc """
  Process DNA Fingerprint Generator

  Extracts deterministic process fingerprints from event logs using Signal Theory.
  """

  @doc """
  Generate process DNA fingerprint from event logs.
  """
  def generate(event_logs, opts \\ []) do
    organization = Keyword.get(opts, :organization, "unknown")
    process_name = Keyword.get(opts, :process, "unknown")

    # Extract process structure
    structure = extract_structure(event_logs)

    # Calculate timing metrics
    timing = calculate_timing(event_logs)

    # Calculate quality metrics
    quality = calculate_quality(event_logs)

    # Calculate participant metrics
    participants = calculate_participants(event_logs)

    # Build process DNA
    process_dna = %{
      structure: structure,
      timing: timing,
      quality: quality,
      participants: participants
    }

    # Generate fingerprint
    fingerprint = %{
      fingerprint_id: generate_id(),
      organization: organization,
      process: process_name,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      process_dna: process_dna,
      signal_encoding: signal_encoding(),
      hash: compute_hash(process_dna)
    }

    {:ok, fingerprint}
  end

  # Extract process structure
  defp extract_structure(event_logs) do
    steps = count_unique_steps(event_logs)
    decision_points = count_decision_points(event_logs)
    parallel_paths = detect_parallel_paths(event_logs)
    loops = detect_loops(event_logs)

    %{
      steps: steps,
      decision_points: decision_points,
      parallel_paths: parallel_paths,
      loops: loops
    }
  end

  # Calculate timing metrics
  defp calculate_timing(event_logs) do
    cycle_times = extract_cycle_times(event_logs)

    %{
      median_cycle_time_hours: median(cycle_times) / 3600,
      p95_cycle_time_hours: percentile(cycle_times, 95) / 3600,
      throughput_per_day: length(event_logs) / 30.0  # Assume 30-day window
    }
  end

  # Calculate quality metrics
  defp calculate_quality(event_logs) do
    total_events = length(event_logs)
    error_events = count_errors(event_logs)
    rework_events = count_rework(event_logs)

    %{
      error_rate: error_events / total_events,
      rework_rate: rework_events / total_events,
      first_touch_resolution: calculate_ftr(event_logs)
    }
  end

  # Calculate participant metrics
  defp calculate_participants(event_logs) do
    unique_roles = count_unique_roles(event_logs)
    handoffs = count_handoffs(event_logs)
    automated_events = count_automated(event_logs)

    %{
      unique_roles: unique_roles,
      handoffs: handoffs,
      automation_level: automated_events / length(event_logs)
    }
  end

  # Signal Theory encoding
  defp signal_encoding do
    %{
      mode: "data",
      genre: "fingerprint",
      type: "direct",
      format: "json",
      structure: "process_dna_v1"
    }
  end

  # Compute SHA-256 hash
  defp compute_hash(process_dna) do
    json = Jason.encode!(process_dna)
    <<hash::binary-256>> = :crypto.hash(:sha256, json)
    "sha256:" <> Base.encode16(hash, case: :lower)
  end

  # Helper functions

  defp count_unique_steps(event_logs) do
    event_logs
    |> Enum.map(fn e -> Map.get(e, "event_name", "") end)
    |> Enum.uniq()
    |> length()
  end

  defp count_decision_points(event_logs) do
    event_logs
    |> Enum.count(fn e ->
      name = Map.get(e, "event_name", "")
      String.contains?(String.downcase(name), ["decision", "approve", "review"])
    end)
  end

  defp detect_parallel_paths(event_logs) do
    # Simplified: count concurrent event groups
    event_logs
    |> Enum.group_by(fn e -> Map.get(e, "timestamp", "") end)
    |> Enum.count(fn {_ts, events} -> length(events) > 1 end)
    |> max(0)
  end

  defp detect_loops(event_logs) do
    # Simplified: detect repeated event patterns
    events = Enum.map(event_logs, fn e -> Map.get(e, "event_name", "") end)
    detect_repeats(events)
  end

  defp detect_repeats(events) when length(events) < 3, do: 0
  defp detect_repeats(events) do
    events
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.count(fn chunk -> length(Enum.uniq(chunk)) < 3 end)
  end

  defp extract_cycle_times(event_logs) do
    # Group by case/process instance
    cases = Enum.group_by(event_logs, fn e -> Map.get(e, "case_id", "default") end)

    Enum.map(cases, fn {_case_id, events} ->
      timestamps = Enum.map(events, fn e ->
        ts = Map.get(e, "timestamp", "")
        parse_timestamp(ts)
      end)

      timestamps = Enum.reject(timestamps, &is_nil/1)
      if length(timestamps) >= 2 do
        Enum.max(timestamps) - Enum.min(timestamps)
      else
        0
      end
    end)
    |> Enum.reject(&(&1 == 0))
  end

  defp parse_timestamp(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, dt, _} -> DateTime.to_unix(dt)
      _ -> nil
    end
  end

  defp count_errors(event_logs) do
    Enum.count(event_logs, fn e ->
      status = Map.get(e, "status", "")
      String.downcase(status) in ["error", "failed", "exception"]
    end)
  end

  defp count_rework(event_logs) do
    # Count events that repeat for same case
    cases = Enum.group_by(event_logs, fn e -> Map.get(e, "case_id", "") end)

    Enum.reduce(cases, 0, fn {_case_id, events}, acc ->
      event_names = Enum.map(events, fn e -> Map.get(e, "event_name", "") end)
      duplicates = length(event_names) - length(Enum.uniq(event_names))
      acc + max(0, duplicates)
    end)
  end

  defp calculate_ftr(event_logs) do
    cases = Enum.group_by(event_logs, fn e -> Map.get(e, "case_id", "") end)

    total = map_size(cases)
    if total == 0, do: 0.0, else:
      single_touch = Enum.count(cases, fn {_case_id, events} -> length(events) == 1 end)
      single_touch / total
  end

  defp count_unique_roles(event_logs) do
    event_logs
    |> Enum.map(fn e -> Map.get(e, "role", "unknown") end)
    |> Enum.uniq()
    |> length()
  end

  defp count_handoffs(event_logs) do
    # Count role changes within cases
    cases = Enum.group_by(event_logs, fn e -> Map.get(e, "case_id", "") end)

    Enum.reduce(cases, 0, fn {_case_id, events}, acc ->
      sorted = Enum.sort_by(events, fn e -> Map.get(e, "timestamp", "") end)
      roles = Enum.map(sorted, fn e -> Map.get(e, "role", "") end)

      handoffs = Enum.chunk_every(roles, 2, 1, :discard)
      |> Enum.count(fn [r1, r2] -> r1 != r2 end)

      acc + handoffs
    end)
  end

  defp count_automated(event_logs) do
    Enum.count(event_logs, fn e ->
      Map.get(e, "automated", false) == true
    end)
  end

  defp median(list) when length(list) == 0, do: 0.0
  defp median(list) do
    sorted = Enum.sort(list)
    mid = div(length(sorted), 2)
    if rem(length(sorted), 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end

  defp percentile(list, p) when length(list) == 0, do: 0.0
  defp percentile(list, p) do
    sorted = Enum.sort(list)
    idx = trunc(length(sorted) * p / 100)
    Enum.at(sorted, min(idx, length(sorted) - 1))
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12)
    |> Base.encode16(case: :lower)
    |> then(&:binary_part(&1, 0, 12))
    |> then<>("fp-" <> &1)
  end
end
