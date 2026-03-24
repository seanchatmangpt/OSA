defmodule OptimalSystemAgent.Workflows.Definitions.AutonomousPI do
  @moduledoc """
  Autonomous Process Improvement (PI) Workflow Definition.

  5-stage workflow for autonomous process improvement:
    1. Discovery: OCPM finds inefficiencies from event logs
    2. Planning: Agent fleet designs improvement proposal
    3. Execution: Multi-agent BFT consensus on proposal
    4. Validation: Signal Theory quality gates verify results
    5. Iteration: Continuous improvement loop

  This workflow definition is used by TemporalAdapter for durable execution.
  """

  @type stage :: :discovery | :planning | :execution | :validation | :iteration
  @type t :: %__MODULE__{
          workflow_id: String.t(),
          process_id: String.t(),
          current_stage: stage,
          stages: [stage()],
          state: map(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct workflow_id: nil,
            process_id: nil,
            current_stage: :discovery,
            stages: [:discovery, :planning, :execution, :validation, :iteration],
            state: %{},
            created_at: nil,
            updated_at: nil

  @doc """
  Create a new autonomous PI workflow.
  """
  @spec new(String.t(), keyword()) :: t()
  def new(process_id, opts \\ []) do
    workflow_id = Map.get(opts, :workflow_id, "pi-#{process_id}-#{System.unique_integer([:positive])}")
    initial_state = Map.get(opts, :state, %{})

    %__MODULE__{
      workflow_id: workflow_id,
      process_id: process_id,
      current_stage: :discovery,
      stages: [:discovery, :planning, :execution, :validation, :iteration],
      state: initial_state,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Advance to the next stage in the workflow.
  """
  @spec advance_stage(t()) :: {:ok, t()} | {:error, :already_complete}
  def advance_stage(%__MODULE__{current_stage: :iteration} = workflow) do
    {:error, :already_complete}
  end

  def advance_stage(%__MODULE__{stages: stages, current_stage: current} = workflow) do
    stage_index = Enum.find_index(stages, fn s -> s == current end)
    next_stage = Enum.at(stages, stage_index + 1)

    {:ok, %{
      workflow
      | current_stage: next_stage,
        updated_at: DateTime.utc_now()
    }}
  end

  @doc """
  Update workflow state.
  """
  @spec update_state(t(), map()) :: t()
  def update_state(%__MODULE__{} = workflow, new_state) do
    %{workflow | state: Map.merge(workflow.state, new_state), updated_at: DateTime.utc_now()}
  end

  @doc """
  Get stage description.
  """
  @spec stage_description(stage()) :: String.t()
  def stage_description(:discovery), do: "OCPM finds inefficiencies from event logs"
  def stage_description(:planning), do: "Agent fleet designs improvement proposal"
  def stage_description(:execution), do: "Multi-agent BFT consensus on proposal"
  def stage_description(:validation), do: "Signal Theory quality gates verify results"
  def stage_description(:iteration), do: "Continuous improvement loop"

  @doc """
  Check if workflow is complete.
  """
  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{current_stage: :iteration}), do: true
  def complete?(%__MODULE__{}), do: false

  @doc """
  Get progress percentage (0-100).
  """
  @spec progress(t()) :: non_neg_integer()
  def progress(%__MODULE__{stages: stages, current_stage: current}) do
    stage_index = Enum.find_index(stages, fn s -> s == current end)
    round((stage_index / length(stages)) * 100)
  end

  @doc """
  Convert to Temporal workflow input format.
  """
  @spec to_temporal_input(t()) :: map()
  def to_temporal_input(%__MODULE__{} = workflow) do
    %{
      "workflow_id" => workflow.workflow_id,
      "process_id" => workflow.process_id,
      "current_stage" => Atom.to_string(workflow.current_stage),
      "stages" => Enum.map(workflow.stages, &Atom.to_string/1),
      "state" => workflow.state,
      "created_at" => DateTime.to_iso8601(workflow.created_at),
      "updated_at" => DateTime.to_iso8601(workflow.updated_at),
      "progress" => progress(workflow)
    }
  end

  @doc """
  Create workflow from Temporal output format.
  """
  @spec from_temporal_output(map()) :: {:ok, t()} | {:error, term()}
  def from_temporal_output(data) when is_map(data) do
    with {:ok, workflow_id} <- parse_string(data, "workflow_id"),
         {:ok, process_id} <- parse_string(data, "process_id"),
         {:ok, current_stage} <- parse_atom(data, "current_stage"),
         {:ok, created_at} <- parse_datetime(data, "created_at"),
         {:ok, updated_at} <- parse_datetime(data, "updated_at") do
      stages = Map.get(data, "stages", [:discovery, :planning, :execution, :validation, :iteration])
              |> Enum.map(&String.to_existing_atom/1)

      state = Map.get(data, "state", %{})

      workflow = %__MODULE__{
        workflow_id: workflow_id,
        process_id: process_id,
        current_stage: current_stage,
        stages: stages,
        state: state,
        created_at: created_at,
        updated_at: updated_at
      }

      {:ok, workflow}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_format}
    end
  end

  # Private helpers

  defp parse_string(data, key) do
    case Map.get(data, key) do
      nil -> {:error, {:missing, key}}
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, {:invalid_type, key}}
    end
  end

  defp parse_atom(data, key) do
    case Map.get(data, key) do
      nil -> {:error, {:missing, key}}
      value when is_binary(value) ->
        try do
          {:ok, String.to_existing_atom(value)}
        rescue
          ArgumentError -> {:error, {:invalid_atom, key}}
        end
      _ -> {:error, {:invalid_type, key}}
    end
  end

  defp parse_datetime(data, key) do
    case Map.get(data, key) do
      nil -> {:ok, DateTime.utc_now()}
      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, dt, _} -> {:ok, dt}
          {:error, _} -> {:error, {:invalid_datetime, key}}
        end
      _ -> {:error, {:invalid_type, key}}
    end
  end
end
