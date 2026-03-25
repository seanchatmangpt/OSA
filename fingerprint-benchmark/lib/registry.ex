defmodule FingerprintBenchmark.Registry do
  @moduledoc """
  Fingerprint Registry — Store and retrieve process DNA fingerprints.
  """

  use GenServer

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(_opts) do
    # Create ETS table for fingerprints
    table = :ets.new(:fingerprint_registry, [:named_table, :public, :set])

    # Load existing fingerprints (in production: from database)
    load_initial_fingerprints(table)

    {:ok, %{table: table}}
  end

  @doc """
  Register a fingerprint.
  """
  def register(fingerprint) do
    GenServer.call(__MODULE__, {:register, fingerprint})
  end

  @doc """
  Retrieve a fingerprint by ID.
  """
  def get(fingerprint_id) do
    case :ets.lookup(:fingerprint_registry, fingerprint_id) do
      [{^fingerprint_id, fingerprint}] -> {:ok, fingerprint}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Find fingerprints by organization.
  """
  def find_by_organization(organization) do
    :ets.tab2list(:fingerprint_registry)
    |> Enum.filter(fn {_id, fp} -> fp.organization == organization end)
    |> Enum.map(fn {_id, fp} -> fp end)
  end

  @doc """
  Find fingerprints by process type.
  """
  def find_by_process(process_name) do
    :ets.tab2list(:fingerprint_registry)
    |> Enum.filter(fn {_id, fp} -> fp.process == process_name end)
    |> Enum.map(fn {_id, fp} -> fp end)
  end

  @doc """
  Search fingerprints by criteria.
  """
  def search(criteria) do
    :ets.tab2list(:fingerprint_registry)
    |> Enum.filter(fn {_id, fp} -> matches_criteria?(fp, criteria) end)
    |> Enum.map(fn {_id, fp} -> fp end)
  end

  # Server callbacks

  def handle_call({:register, fingerprint}, _from, state) do
    :ets.insert(:fingerprint_registry, {fingerprint.fingerprint_id, fingerprint})
    {:reply, {:ok, fingerprint.fingerprint_id}, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp load_initial_fingerprints(table) do
    # In production: Load from database
    # For now: Initialize with sample data
    sample = %{
      fingerprint_id: "fp-sample-001",
      organization: "benchmark-baseline",
      process: "order-to-cash",
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      process_dna: %{
        structure: %{steps: 6, decision_points: 2, parallel_paths: 1, loops: 0},
        timing: %{median_cycle_time_hours: 48.0, p95_cycle_time_hours: 120.0, throughput_per_day: 50},
        quality: %{error_rate: 0.02, rework_rate: 0.08, first_touch_resolution: 0.75},
        participants: %{unique_roles: 4, handoffs: 5, automation_level: 0.40}
      },
      signal_encoding: %{
        mode: "data", genre: "fingerprint", type: "direct",
        format: "json", structure: "process_dna_v1"
      },
      hash: "sha256:baseline"
    }

    :ets.insert(table, {sample.fingerprint_id, sample})
  end

  defp matches_criteria?(fingerprint, criteria) do
    Enum.all?(criteria, fn {key, value} ->
      case key do
        :organization -> fingerprint.organization == value
        :process -> fingerprint.process == value
        :industry -> Map.get(fingerprint, :industry) == value
        :size -> Map.get(fingerprint, :size) == value
        _ -> true
      end
    end)
  end
end
