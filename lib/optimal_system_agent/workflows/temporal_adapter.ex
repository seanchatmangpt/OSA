defmodule OptimalSystemAgent.Workflows.TemporalAdapter do
  @moduledoc """
  Temporal IO adapter for durable workflow execution.

  Features:
  - Exactly-once execution guarantees
  - Automatic retry with exponential backoff
  - Workflow state persistence and recovery
  - Long-running operation support

  ## Configuration

  Reads from environment variables:
  - `TEMPORAL_HOST` - Temporal server host (default: "localhost")
  - `TEMPORAL_PORT` - Temporal server port (default: 7233)
  - `TEMPORAL_NAMESPACE` - Temporal namespace (default: "default")

  ## Usage

  Start a workflow:
      {:ok, execution_id} = TemporalAdapter.start_workflow("my-workflow", %{
        "task_queue" => "my-task-queue",
        "workflow_id" => "unique-id",
        "input" => %{key: "value"}
      })

  Signal a running workflow:
      {:ok, :sent} = TemporalAdapter.signal_workflow("my-workflow", %{
        "name" => "update-step",
        "input" => %{step: 2}
      })

  Query workflow state:
      {:ok, state} = TemporalAdapter.query_workflow("my-workflow")
  """

  require Logger

  @type workflow_id :: String.t()
  @type execution_params :: map()
  @type signal :: map()
  @type workflow_state :: map()

  @doc """
  Start a Temporal workflow execution.

  ## Parameters
    - `workflow_id`: Unique identifier for the workflow type
    - `execution_params`: Map containing:
      - `task_queue` (required): Task queue for the workflow
      - `workflow_id` (required): Unique execution ID
      - `input` (optional): Workflow input parameters
      - `execution_timeout` (optional): Timeout in seconds (default: 300)
      - `task_timeout` (optional): Task timeout in seconds (default: 30)

  ## Returns
    - `{:ok, execution_id}` on success
    - `{:error, reason}` on failure
  """
  @spec start_workflow(workflow_id() | nil, execution_params() | nil) :: {:ok, String.t()} | {:error, term()}
  def start_workflow(nil, _), do: {:error, :missing_workflow_id}
  def start_workflow(_, nil), do: {:error, :missing_execution_params}

  def start_workflow(workflow_id, execution_params) when is_binary(workflow_id) and is_map(execution_params) do
    Logger.info("[TemporalAdapter] Starting workflow: #{workflow_id}")

    with :ok <- validate_required_params(execution_params, ["task_queue", "workflow_id"]),
         {:ok, base_url} <- build_base_url(),
         {:ok, body} <- build_start_request(workflow_id, execution_params),
         {:ok, response} <- post_workflow(base_url, body) do
      handle_start_response(response)
    else
      {:error, reason} = error ->
        Logger.error("[TemporalAdapter] Failed to start workflow #{workflow_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Send a signal to a running workflow.

  ## Parameters
    - `workflow_id`: Workflow execution ID
    - `signal`: Signal name (string) or map containing:
      - `name` (required): Signal name
      - `input` (optional): Signal payload

  ## Returns
    - `{:ok, :sent}` on success
    - `{:error, reason}` on failure
  """
  @spec signal_workflow(workflow_id() | nil, signal() | String.t() | nil) :: {:ok, :sent} | {:error, term()}
  def signal_workflow(nil, _), do: {:error, :missing_workflow_id}
  def signal_workflow(_, nil), do: {:error, :missing_signal}

  def signal_workflow(_workflow_id, signal) when is_binary(signal) and signal not in ["pause", "skip_stage", "abort"] do
    {:error, :invalid_signal}
  end

  def signal_workflow(workflow_id, signal) when is_binary(workflow_id) and (is_map(signal) or is_binary(signal)) do
    Logger.info("[TemporalAdapter] Sending signal to workflow: #{workflow_id}")

    with :ok <- validate_required_params(signal, ["name"]),
         {:ok, base_url} <- build_base_url(),
         {:ok, body} <- build_signal_request(workflow_id, signal),
         {:ok, response} <- post_signal(base_url, body) do
      handle_signal_response(response)
    else
      {:error, reason} = error ->
        Logger.error("[TemporalAdapter] Failed to signal workflow #{workflow_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Query the current state of a running workflow.

  ## Parameters
    - `workflow_id`: Workflow execution ID

  ## Returns
    - `{:ok, state}` on success, where state is a map of workflow state
    - `{:error, reason}` on failure
  """
  @spec query_workflow(workflow_id() | nil) :: {:ok, workflow_state()} | {:error, term()}
  def query_workflow(nil), do: {:error, :missing_workflow_id}

  def query_workflow(workflow_id) when is_binary(workflow_id) do
    Logger.debug("[TemporalAdapter] Querying workflow: #{workflow_id}")

    with {:ok, base_url} <- build_base_url(),
         {:ok, response} <- get_workflow_state(base_url, workflow_id) do
      handle_query_response(response)
    else
      {:error, reason} = error ->
        Logger.error("[TemporalAdapter] Failed to query workflow #{workflow_id}: #{inspect(reason)}")
        error
    end
  end

  # ── Public: Configuration Helpers ─────────────────────────────────────────

  @doc "Get the Temporal host from environment or default."
  def get_temporal_host, do: System.get_env("TEMPORAL_HOST", "localhost")

  @doc "Get the Temporal namespace from environment or default."
  def get_namespace, do: System.get_env("TEMPORAL_NAMESPACE", "default")

  # ── Private: Configuration ─────────────────────────────────────────────

  defp temporal_host, do: get_temporal_host()
  defp temporal_port, do: System.get_env("TEMPORAL_PORT", "7233") |> String.to_integer()
  defp temporal_namespace, do: get_namespace()

  defp build_base_url do
    host = temporal_host()
    port = temporal_port()
    namespace = temporal_namespace()

    base_url = "http://#{host}:#{port}/api/v1/namespaces/#{namespace}"

    {:ok, base_url}
  rescue
    e -> {:error, "Invalid Temporal configuration: #{inspect(e)}"}
  end

  # ── Private: Validation ────────────────────────────────────────────────

  defp validate_required_params(params, required_fields) do
    missing =
      required_fields
      |> Enum.reject(fn field -> Map.has_key?(params, field) end)
      |> Enum.reject(fn field -> Map.has_key?(params, String.to_atom(field)) end)

    if missing == [] do
      :ok
    else
      {:error, "Missing required parameters: #{Enum.join(missing, ", ")}"}
    end
  end

  # ── Private: Request Building ──────────────────────────────────────────

  defp build_start_request(workflow_id, params) do
    task_queue = Map.get(params, "task_queue") || Map.get(params, :task_queue)
    execution_id = Map.get(params, "workflow_id") || Map.get(params, :workflow_id)
    input = Map.get(params, "input") || Map.get(params, :input, %{})
    execution_timeout = Map.get(params, "execution_timeout", 300)
    task_timeout = Map.get(params, "task_timeout", 30)

    request = %{
      workflowType: %{
        name: workflow_id
      },
      taskQueue: %{
        name: task_queue
      },
      workflowId: execution_id,
      input: encode_input(input),
      workflowExecutionTimeout: "#{execution_timeout}s",
      workflowTaskTimeout: "#{task_timeout}s"
    }

    {:ok, request}
  end

  defp build_signal_request(_workflow_id, signal) do
    signal_name = Map.get(signal, "name") || Map.get(signal, :name)
    signal_input = Map.get(signal, "input") || Map.get(signal, :input, %{})

    request = %{
      signalName: signal_name,
      input: encode_input(signal_input)
    }

    {:ok, request}
  end

  defp encode_input(input) when is_map(input) or is_list(input) do
    case Jason.encode(input) do
      {:ok, json} -> [json]
      {:error, _} -> []
    end
  end

  defp encode_input(input), do: [input]

  # ── Private: HTTP Requests ──────────────────────────────────────────────

  defp post_workflow(base_url, body) do
    url = "#{base_url}/workflows"

    case Req.post(url,
           json: body,
           receive_timeout: 10_000,
           headers: [{"accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, "HTTP #{status}: #{inspect(response_body)}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "Temporal connection error: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Temporal request error: #{inspect(reason)}"}
    end
  end

  defp post_signal(base_url, body) do
    url = "#{base_url}/workflows/#{workflow_id_from_body(body)}/signals"

    case Req.post(url,
           json: body,
           receive_timeout: 10_000,
           headers: [{"accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, :sent}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, "HTTP #{status}: #{inspect(response_body)}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "Temporal connection error: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Temporal request error: #{inspect(reason)}"}
    end
  end

  defp get_workflow_state(base_url, workflow_id) do
    url = "#{base_url}/workflows/#{workflow_id}"

    case Req.get(url,
           receive_timeout: 10_000,
           headers: [{"accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :workflow_not_found}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, "HTTP #{status}: #{inspect(response_body)}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "Temporal connection error: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Temporal request error: #{inspect(reason)}"}
    end
  end

  # ── Private: Response Handling ──────────────────────────────────────────

  defp handle_start_response(response) when is_map(response) do
    execution_id = Map.get(response, "executionId") || Map.get(response, "execution")
    run_id = Map.get(response, "runId")

    cond do
      execution_id != nil ->
        Logger.info("[TemporalAdapter] Workflow started: #{execution_id}")
        {:ok, execution_id}

      run_id != nil ->
        Logger.info("[TemporalAdapter] Workflow started with run_id: #{run_id}")
        {:ok, run_id}

      true ->
        {:error, "No execution ID in response: #{inspect(response)}"}
    end
  end

  defp handle_start_response(response), do: {:error, "Unexpected response: #{inspect(response)}"}

  defp handle_signal_response(:sent), do: {:ok, :sent}
  defp handle_signal_response({:error, _} = error), do: error

  defp handle_query_response(response) when is_map(response) do
    # Extract workflow state from Temporal response
    state = %{
      status: Map.get(response, "status"),
      history_length: Map.get(response, "historyLength"),
      execution: Map.get(response, "execution"),
      workflow_type: Map.get(response, "workflowType")
    }

    {:ok, state}
  end

  defp handle_query_response(response), do: {:error, "Unexpected response: #{inspect(response)}"}

  # ── Private: Helpers ────────────────────────────────────────────────────

  defp workflow_id_from_body(%{workflowId: id}), do: id
  defp workflow_id_from_body(%{"workflowId" => id}), do: id
  defp workflow_id_from_body(_), do: ""
end
