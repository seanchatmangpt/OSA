defmodule OptimalSystemAgent.Yawl.CaseLifecycle do
  @moduledoc """
  GenServer client for the YAWL embedded-server case lifecycle endpoints.

  Communicates with the lightweight `yawl-embedded-server` (fat JAR, no Tomcat)
  over HTTP, using the same `Req`-based pattern as `OptimalSystemAgent.Yawl.Client`.

  ## Endpoints used

  | Function             | Method | Path                                           |
  |----------------------|--------|------------------------------------------------|
  | `launch_case/3`      | POST   | /api/cases/launch                              |
  | `list_workitems/1`   | GET    | /api/cases/{id}/workitems                      |
  | `start_workitem/2`   | POST   | /api/cases/{id}/workitems/{wid}/start          |
  | `complete_workitem/3`| POST   | /api/cases/{id}/workitems/{wid}/complete       |
  | `checkpoint/1`       | GET    | /api/cases/{id}/checkpoint                     |
  | `restore_checkpoint/2`| POST  | /api/cases/{id}/checkpoint                     |
  | `cancel_case/1`      | DELETE | /api/cases/{id}                                |

  ## Error handling

  All public functions return `{:ok, body}` on success or `{:error, reason}` on
  failure.  The GenServer never crashes on network errors — it returns a tagged
  error tuple instead, following the Armstrong let-it-crash discipline at the
  *boundary* (errors are surfaced, not swallowed).

  ## Configuration

      config :optimal_system_agent, :yawl_url, "http://localhost:8080"
  """

  use GenServer
  require Logger

  @timeout_ms 15_000
  @name __MODULE__

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Launch a new YAWL case from a spec XML string.

  - `spec_xml` — YAWL spec XML (required)
  - `case_id`  — Stable business key; if `nil`, a UUID is generated server-side
  - `params`   — XML data for input parameters (optional, `nil` for no params)

  Returns `{:ok, %{"case_id" => "...", "runner_id" => "..."}}` or `{:error, reason}`.
  """
  @spec launch_case(String.t(), String.t() | nil, String.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def launch_case(spec_xml, case_id \\ nil, params \\ nil) do
    call({:launch_case, spec_xml, case_id, params})
  end

  @doc """
  List all work items for a running case.

  Returns `{:ok, [%{"id" => "...", "taskId" => "...", "status" => "..."}]}`.
  """
  @spec list_workitems(String.t()) :: {:ok, list(map())} | {:error, term()}
  def list_workitems(case_id), do: call({:list_workitems, case_id})

  @doc """
  Start (check out) a work item by ID.  The work item must be in `Enabled` status.

  Returns `{:ok, %{"id" => ..., "status" => "Executing"}}` or `{:error, reason}`.
  """
  @spec start_workitem(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def start_workitem(case_id, workitem_id), do: call({:start_workitem, case_id, workitem_id})

  @doc """
  Complete (check in) a work item.  The work item must be in `Executing` status.

  - `data` — Optional XML output data string (pass `""` for no output)

  Returns `{:ok, %{"id" => ..., "status" => "Complete"}}` or `{:error, reason}`.
  """
  @spec complete_workitem(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def complete_workitem(case_id, workitem_id, data \\ "<data/>") do
    call({:complete_workitem, case_id, workitem_id, data})
  end

  @doc """
  Serialize the current in-memory case state to XML for durable storage.

  Returns `{:ok, %{"xml" => "...", "case_id" => "..."}}` or `{:error, reason}`.
  """
  @spec checkpoint(String.t()) :: {:ok, map()} | {:error, term()}
  def checkpoint(case_id), do: call({:checkpoint, case_id})

  @doc """
  Restore a previously checkpointed case from XML.

  The restored case is registered under `case_id` in the server's registry.
  Returns `{:ok, %{"case_id" => ..., "runner_id" => ...}}` or `{:error, reason}`.
  """
  @spec restore_checkpoint(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def restore_checkpoint(case_id, xml), do: call({:restore_checkpoint, case_id, xml})

  @doc """
  Cancel a running case.  Removes it from the server's in-memory registry.

  Returns `:ok` on success (HTTP 204) or `{:error, reason}` on failure.
  """
  @spec cancel_case(String.t()) :: :ok | {:error, term()}
  def cancel_case(case_id), do: call({:cancel_case, case_id})

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    base_url = Application.get_env(:optimal_system_agent, :yawl_url, "http://localhost:8080")
    {:ok, %{base_url: base_url}}
  end

  @impl true
  def handle_call({:launch_case, spec_xml, case_id, params}, _from, %{base_url: base} = state) do
    body =
      %{"spec_xml" => spec_xml}
      |> maybe_put("case_id", case_id)
      |> maybe_put("params", params)

    result = post(base <> "/api/cases/launch", body)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:list_workitems, case_id}, _from, %{base_url: base} = state) do
    result = get(base <> "/api/cases/#{URI.encode(case_id)}/workitems")
    {:reply, result, state}
  end

  @impl true
  def handle_call({:start_workitem, case_id, wid}, _from, %{base_url: base} = state) do
    url = base <> "/api/cases/#{URI.encode(case_id)}/workitems/#{URI.encode(wid)}/start"
    result = post(url, %{})
    {:reply, result, state}
  end

  @impl true
  def handle_call({:complete_workitem, case_id, wid, data}, _from, %{base_url: base} = state) do
    url = base <> "/api/cases/#{URI.encode(case_id)}/workitems/#{URI.encode(wid)}/complete"
    result = post(url, %{"data" => data})
    {:reply, result, state}
  end

  @impl true
  def handle_call({:checkpoint, case_id}, _from, %{base_url: base} = state) do
    result = get(base <> "/api/cases/#{URI.encode(case_id)}/checkpoint")
    {:reply, result, state}
  end

  @impl true
  def handle_call({:restore_checkpoint, case_id, xml}, _from, %{base_url: base} = state) do
    url = base <> "/api/cases/#{URI.encode(case_id)}/checkpoint"
    result = post(url, %{"xml" => xml})
    {:reply, result, state}
  end

  @impl true
  def handle_call({:cancel_case, case_id}, _from, %{base_url: base} = state) do
    url = base <> "/api/cases/#{URI.encode(case_id)}"

    result =
      case Req.delete(url, receive_timeout: @timeout_ms) do
        {:ok, %{status: 204}} -> :ok
        {:ok, %{status: 404}} -> {:error, :not_found}
        {:ok, %{status: status}} -> {:error, {:http_error, status}}
        {:error, _} -> {:error, :yawl_unavailable}
      end

    {:reply, result, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp call(msg) do
    try do
      GenServer.call(@name, msg, @timeout_ms)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  defp post(url, body) do
    case Req.post(url, json: body, receive_timeout: @timeout_ms) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        parsed =
          case resp_body do
            map when is_map(map) -> map
            bin when is_binary(bin) -> Jason.decode!(bin)
            other -> %{"result" => other}
          end

        {:ok, parsed}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: 409}} ->
        {:error, :already_exists}

      {:ok, %{status: status, body: resp_body}} ->
        message =
          case resp_body do
            %{"error" => msg} -> msg
            bin when is_binary(bin) -> bin
            _ -> "HTTP #{status}"
          end

        {:error, {:http_error, status, message}}

      {:error, _} ->
        {:error, :yawl_unavailable}
    end
  end

  defp get(url) do
    case Req.get(url, receive_timeout: @timeout_ms) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        parsed =
          case resp_body do
            map when is_map(map) -> map
            list when is_list(list) -> list
            bin when is_binary(bin) -> Jason.decode!(bin)
            other -> %{"result" => other}
          end

        {:ok, parsed}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, _} ->
        {:error, :yawl_unavailable}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
