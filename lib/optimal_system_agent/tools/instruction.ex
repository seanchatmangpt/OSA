defmodule OptimalSystemAgent.Tools.Instruction do
  @moduledoc """
  Normalised tool instruction struct.

  An `Instruction` captures everything needed to dispatch a single tool call:

    * `tool`    — the tool name string (e.g. `"file_read"`)
    * `params`  — the argument map passed to `execute/1`
    * `context` — ambient metadata (session_id, caller, etc.)

  ## Accepted input shapes for `normalize/1`

      "file_read"
      {"file_read", %{"path" => "/tmp/x"}}
      {"file_read", %{"path" => "/tmp/x"}, %{session_id: "abc"}}
      %OptimalSystemAgent.Tools.Instruction{tool: "file_read", params: %{}, context: %{}}
  """

  defstruct tool: "", params: %{}, context: %{}

  @type t :: %__MODULE__{
          tool: String.t(),
          params: map(),
          context: map()
        }

  @doc """
  Normalize an arbitrary term into an `{:ok, Instruction.t()}` or `{:error, reason}`.
  """
  @spec normalize(term()) :: {:ok, t()} | {:error, String.t()}
  def normalize(input)

  def normalize(name) when is_binary(name) do
    trimmed = String.trim(name)

    if trimmed == "" do
      {:error, "tool name cannot be empty"}
    else
      {:ok, %__MODULE__{tool: trimmed}}
    end
  end

  def normalize({tool, params}) when is_binary(tool) and is_map(params) do
    case normalize(tool) do
      {:ok, inst} -> {:ok, %{inst | params: params}}
      err -> err
    end
  end

  def normalize({_tool, params}) when not is_map(params),
    do: {:error, "params must be a map"}

  def normalize({tool, params, context})
      when is_binary(tool) and is_map(params) and is_map(context) do
    case normalize(tool) do
      {:ok, inst} -> {:ok, %{inst | params: params, context: context}}
      err -> err
    end
  end

  def normalize({_tool, _params, context}) when not is_map(context),
    do: {:error, "context must be a map"}

  def normalize(%__MODULE__{} = inst), do: {:ok, inst}

  def normalize(_), do: {:error, "unsupported instruction format"}

  @doc """
  Same as `normalize/1` but raises `ArgumentError` on failure.
  """
  @spec normalize!(term()) :: t()
  def normalize!(input) do
    case normalize(input) do
      {:ok, inst} -> inst
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  @doc """
  Merge additional params into an existing instruction.

  Existing keys in `inst.params` are overwritten by `extra`.
  """
  @spec merge_params(t(), map()) :: t()
  def merge_params(%__MODULE__{} = inst, extra) when is_map(extra) do
    %{inst | params: Map.merge(inst.params, extra)}
  end
end
