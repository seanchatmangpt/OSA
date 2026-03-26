defmodule OptimalSystemAgent.Integrations.Mesh.Consumer do
  @moduledoc """
  GenServer managing data mesh federation consumer operations in OSA.

  ## Architecture

  The Consumer GenServer coordinates domain registration, dataset discovery,
  lineage queries, and quality calculations via the `bos` CLI wrapper around
  SPARQL CONSTRUCT queries against the Oxigraph triplestore.

  ## Operations

    - `register_domain/3` — Register a domain with metadata
    - `discover_datasets/2` — Query all datasets for a domain
    - `query_lineage/3` — Trace dataset lineage (max 5 levels)
    - `check_quality/2` — Calculate data quality metrics

  ## Timeout & Constraints

  - Per-operation timeout: 12 seconds
  - Lineage depth limit: 5 levels max
  - Supervision: In OSA supervisor tree
  - Logging: via `Logger` (slog compatibility)
  """

  use GenServer
  require Logger

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Start the Mesh Consumer GenServer.

  Options:
    - `:name` — process registration name (defaults to __MODULE__)
    - `:bos_timeout_ms` — timeout for `bos` CLI calls (defaults to 12000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a domain in the mesh federation.

  Arguments:
    - `domain_name` — unique domain identifier
    - `metadata` — map with keys: `owner`, `description`, `tags` (all strings)

  Returns `{:ok, %{domain: domain_name, ...}}` or `{:error, reason}`.

  Timeout: 12 seconds per operation.
  """
  @spec register_domain(pid() | atom(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def register_domain(server, domain_name, metadata) when is_binary(domain_name) do
    GenServer.call(server, {:register_domain, domain_name, metadata}, 12_000)
  end

  @doc """
  Discover all datasets registered in a domain.

  Arguments:
    - `domain_name` — domain to query

  Returns `{:ok, [%{name, owner, created_at, ...}]}` or `{:error, reason}`.

  Timeout: 12 seconds per operation.
  """
  @spec discover_datasets(pid() | atom(), String.t()) ::
          {:ok, [map()]} | {:error, term()}
  def discover_datasets(server, domain_name) when is_binary(domain_name) do
    GenServer.call(server, {:discover_datasets, domain_name}, 12_000)
  end

  @doc """
  Query lineage for a dataset (upstream and downstream).

  Arguments:
    - `domain_name` — domain containing the dataset
    - `dataset_name` — dataset to trace
    - `options` — keyword list: `depth: 5` (default), `direction: :upstream|:downstream|:both`

  Returns `{:ok, %{root: dataset_name, nodes: [...], edges: [...]}}` or `{:error, reason}`.

  Timeout: 12 seconds per operation.
  """
  @spec query_lineage(pid() | atom(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def query_lineage(server, domain_name, dataset_name, options \\ [])
      when is_binary(domain_name) and is_binary(dataset_name) do
    GenServer.call(server, {:query_lineage, domain_name, dataset_name, options}, 12_000)
  end

  @doc """
  Check data quality metrics for a dataset.

  Arguments:
    - `domain_name` — domain containing the dataset
    - `dataset_name` — dataset to evaluate

  Returns `{:ok, %{completeness, accuracy, consistency, timeliness}}` or `{:error, reason}`.

  Timeout: 12 seconds per operation.
  """
  @spec check_quality(pid() | atom(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def check_quality(server, domain_name, dataset_name)
      when is_binary(domain_name) and is_binary(dataset_name) do
    GenServer.call(server, {:check_quality, domain_name, dataset_name}, 12_000)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    bos_timeout_ms = Keyword.get(opts, :bos_timeout_ms, 12_000)

    state = %{
      bos_timeout_ms: bos_timeout_ms,
      last_operation: nil,
      operation_count: 0
    }

    Logger.debug("[Mesh.Consumer] started")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_domain, domain_name, metadata}, _from, state) do
    Logger.debug("[Mesh.Consumer] register_domain domain=#{domain_name}")

    result =
      with :ok <- validate_domain_name(domain_name),
           :ok <- validate_domain_metadata(metadata),
           {:ok, output} <- invoke_bos_register_domain(domain_name, metadata, state) do
        parse_domain_response(output)
      end

    state = record_operation(state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:discover_datasets, domain_name}, _from, state) do
    Logger.debug("[Mesh.Consumer] discover_datasets domain=#{domain_name}")

    result =
      with :ok <- validate_domain_name(domain_name),
           {:ok, output} <- invoke_bos_discover_datasets(domain_name, state) do
        parse_datasets_response(output)
      end

    state = record_operation(state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:query_lineage, domain_name, dataset_name, options}, _from, state) do
    Logger.debug("[Mesh.Consumer] query_lineage domain=#{domain_name} dataset=#{dataset_name}")

    result =
      with :ok <- validate_domain_name(domain_name),
           :ok <- validate_dataset_name(dataset_name),
           {:ok, depth} <- validate_lineage_options(options),
           {:ok, output} <- invoke_bos_query_lineage(domain_name, dataset_name, depth, state) do
        parse_lineage_response(output)
      end

    state = record_operation(state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:check_quality, domain_name, dataset_name}, _from, state) do
    Logger.debug("[Mesh.Consumer] check_quality domain=#{domain_name} dataset=#{dataset_name}")

    result =
      with :ok <- validate_domain_name(domain_name),
           :ok <- validate_dataset_name(dataset_name),
           {:ok, output} <- invoke_bos_check_quality(domain_name, dataset_name, state) do
        parse_quality_response(output)
      end

    state = record_operation(state)
    {:reply, result, state}
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  defp validate_domain_name(name) when is_binary(name) and byte_size(name) > 0 do
    if String.match?(name, ~r/^[a-z0-9_-]+$/i) do
      :ok
    else
      {:error, :invalid_domain_name}
    end
  end

  defp validate_domain_name(_), do: {:error, :invalid_domain_name}

  defp validate_dataset_name(name) when is_binary(name) and byte_size(name) > 0 do
    if String.match?(name, ~r/^[a-z0-9_.-]+$/i) do
      :ok
    else
      {:error, :invalid_dataset_name}
    end
  end

  defp validate_dataset_name(_), do: {:error, :invalid_dataset_name}

  defp validate_domain_metadata(metadata) when is_map(metadata) do
    if Map.has_key?(metadata, "owner") or Map.has_key?(metadata, :owner) do
      :ok
    else
      {:error, :missing_owner}
    end
  end

  defp validate_domain_metadata(_), do: {:error, :invalid_metadata}

  defp validate_lineage_options(options) when is_list(options) do
    depth = Keyword.get(options, :depth, 5)

    if is_integer(depth) and depth > 0 and depth <= 5 do
      {:ok, depth}
    else
      {:error, :invalid_depth}
    end
  end

  defp validate_lineage_options(_), do: {:ok, 5}

  # ---------------------------------------------------------------------------
  # bos CLI invocation
  # ---------------------------------------------------------------------------

  # Invoke: bos mesh register-domain --domain <name> --owner <owner> --description <desc>
  # Returns raw JSON output from bos
  defp invoke_bos_register_domain(domain_name, metadata, state) do
    owner = Map.get(metadata, "owner") || Map.get(metadata, :owner, "unknown")
    description = Map.get(metadata, "description") || Map.get(metadata, :description, "")

    cmd = [
      "bos",
      "mesh",
      "register-domain",
      "--domain",
      domain_name,
      "--owner",
      owner,
      "--description",
      description
    ]

    execute_bos_command(cmd, state)
  end

  # Invoke: bos mesh discover-datasets --domain <name>
  defp invoke_bos_discover_datasets(domain_name, state) do
    cmd = ["bos", "mesh", "discover-datasets", "--domain", domain_name]
    execute_bos_command(cmd, state)
  end

  # Invoke: bos mesh query-lineage --domain <name> --dataset <name> --depth <int>
  defp invoke_bos_query_lineage(domain_name, dataset_name, depth, state) do
    cmd = [
      "bos",
      "mesh",
      "query-lineage",
      "--domain",
      domain_name,
      "--dataset",
      dataset_name,
      "--depth",
      Integer.to_string(depth)
    ]

    execute_bos_command(cmd, state)
  end

  # Invoke: bos mesh check-quality --domain <name> --dataset <name>
  defp invoke_bos_check_quality(domain_name, dataset_name, state) do
    cmd = [
      "bos",
      "mesh",
      "check-quality",
      "--domain",
      domain_name,
      "--dataset",
      dataset_name
    ]

    execute_bos_command(cmd, state)
  end

  # Execute bos command with timeout and capture output
  defp execute_bos_command(cmd, state) do
    timeout_ms = state.bos_timeout_ms

    try do
      case System.cmd(List.first(cmd), Enum.drop(cmd, 1),
             stdout: :string,
             timeout: timeout_ms,
             stderr_to_stdout: true
      ) do
        {output, 0} ->
          {:ok, output}

        {error_output, exit_code} ->
          Logger.warning("[Mesh.Consumer] bos command failed: exit=#{exit_code} output=#{error_output}")
          {:error, {:bos_command_failed, exit_code, error_output}}
      end
    catch
      :timeout ->
        Logger.warning("[Mesh.Consumer] bos command timeout after #{timeout_ms}ms")
        {:error, :timeout}

      reason ->
        Logger.warning("[Mesh.Consumer] bos command error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Response parsing
  # ---------------------------------------------------------------------------

  defp parse_domain_response(output) when is_binary(output) do
    case Jason.decode(output) do
      {:ok, data} when is_map(data) ->
        {:ok, data}

      {:ok, _} ->
        {:error, :invalid_response_format}

      {:error, reason} ->
        Logger.warning("[Mesh.Consumer] JSON decode failed: #{inspect(reason)}")
        {:error, :parse_error}
    end
  end

  defp parse_domain_response(_), do: {:error, :invalid_response_format}

  defp parse_datasets_response(output) when is_binary(output) do
    case Jason.decode(output) do
      {:ok, datasets} when is_list(datasets) ->
        {:ok, datasets}

      {:ok, %{"datasets" => datasets}} when is_list(datasets) ->
        {:ok, datasets}

      {:ok, _} ->
        {:error, :invalid_response_format}

      {:error, reason} ->
        Logger.warning("[Mesh.Consumer] JSON decode failed: #{inspect(reason)}")
        {:error, :parse_error}
    end
  end

  defp parse_datasets_response(_), do: {:error, :invalid_response_format}

  defp parse_lineage_response(output) when is_binary(output) do
    case Jason.decode(output) do
      {:ok, lineage} when is_map(lineage) ->
        # Validate lineage structure: should have nodes and edges
        if Map.has_key?(lineage, "nodes") and Map.has_key?(lineage, "edges") do
          {:ok, lineage}
        else
          {:ok, Map.put_new(lineage, "nodes", []) |> Map.put_new("edges", [])}
        end

      {:ok, _} ->
        {:error, :invalid_lineage_format}

      {:error, reason} ->
        Logger.warning("[Mesh.Consumer] JSON decode failed: #{inspect(reason)}")
        {:error, :parse_error}
    end
  end

  defp parse_lineage_response(_), do: {:error, :invalid_lineage_format}

  defp parse_quality_response(output) when is_binary(output) do
    case Jason.decode(output) do
      {:ok, quality} when is_map(quality) ->
        # Validate quality metrics exist
        quality_with_defaults =
          quality
          |> Map.put_new("completeness", 0.0)
          |> Map.put_new("accuracy", 0.0)
          |> Map.put_new("consistency", 0.0)
          |> Map.put_new("timeliness", 0.0)

        {:ok, quality_with_defaults}

      {:ok, _} ->
        {:error, :invalid_quality_format}

      {:error, reason} ->
        Logger.warning("[Mesh.Consumer] JSON decode failed: #{inspect(reason)}")
        {:error, :parse_error}
    end
  end

  defp parse_quality_response(_), do: {:error, :invalid_quality_format}

  # ---------------------------------------------------------------------------
  # State management
  # ---------------------------------------------------------------------------

  defp record_operation(state) do
    %{
      state
      | last_operation: DateTime.utc_now(),
        operation_count: state.operation_count + 1
    }
  end
end
