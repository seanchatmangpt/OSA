defmodule OptimalSystemAgent.A2A.ConfigValidator do
  @moduledoc """
  Validates A2A agent card configuration structures.

  Ensures that A2A agent cards have required fields and valid
  capabilities before registering or communicating with agents.
  """

  @valid_capabilities ~w(streaming tools stateless push_notifications)

  @doc """
  Validates an A2A agent card configuration.

  ## Required fields
    * `name` - agent identifier (string)
    * `version` - agent version (string)

  ## Optional fields
    * `display_name` - human-readable name
    * `description` - agent description
    * `url` - agent endpoint URL
    * `capabilities` - list of supported capabilities
    * `input_schema` - JSON Schema for input validation

  ## Returns
    * `{:ok, validated_card}` - normalized and validated card
    * `{:error, reason}` - human-readable validation error
  """
  @spec validate_agent_card(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_agent_card(card) when is_map(card) do
    with :ok <- validate_name(card),
         :ok <- validate_version(card),
         :ok <- validate_capabilities(card),
         :ok <- validate_input_schema(card) do
      {:ok, normalize_card(card)}
    end
  end

  def validate_agent_card(_), do: {:error, "Agent card must be a map"}

  @doc """
  Validates multiple agent cards (e.g., from a discovery endpoint).

  Returns `{:ok, cards}` or `{:error, reason}`.
  """
  @spec validate_agent_cards([map()]) :: {:ok, [map()]} | {:error, String.t()}
  def validate_agent_cards(cards) when is_list(cards) do
    results =
      Enum.reduce(cards, {[], []}, fn card, {valid, errors} ->
        case validate_agent_card(card) do
          {:ok, validated} -> {[validated | valid], errors}
          {:error, reason} -> {valid, [{Map.get(card, "name", "unknown"), reason} | errors]}
        end
      end)

    case results do
      {valid, []} -> {:ok, Enum.reverse(valid)}
      {_, errors} -> {:error, format_errors(errors)}
    end
  end

  def validate_agent_cards(_), do: {:error, "Agent cards must be a list"}

  # ── Private helpers ──────────────────────────────────────────────

  defp validate_name(%{"name" => name}) when is_binary(name) and name != "" do
    :ok
  end

  defp validate_name(_),
    do: {:error, "Missing or invalid 'name' field (must be non-empty string)"}

  defp validate_version(%{"version" => version}) when is_binary(version) and version != "" do
    :ok
  end

  defp validate_version(_),
    do: {:error, "Missing or invalid 'version' field (must be non-empty string)"}

  defp validate_capabilities(%{"capabilities" => caps}) when is_list(caps) do
    invalid = Enum.reject(caps, &(&1 in @valid_capabilities))

    case invalid do
      [] ->
        :ok

      _ ->
        {:error,
         "Invalid capabilities: #{Enum.join(invalid, ", ")}. " <>
           "Valid: #{Enum.join(@valid_capabilities, ", ")}"}
    end
  end

  defp validate_capabilities(_), do: :ok

  defp validate_input_schema(%{"input_schema" => schema}) when is_map(schema) do
    cond do
      Map.get(schema, "type") != "object" ->
        {:error, "input_schema.type must be 'object'"}

      not is_map(Map.get(schema, "properties", %{})) ->
        {:error, "input_schema.properties must be a map"}

      true ->
        :ok
    end
  end

  defp validate_input_schema(_), do: :ok

  defp normalize_card(card) do
    card
    |> Map.put_new("display_name", Map.get(card, "name", ""))
    |> Map.put_new("description", "")
    |> Map.put_new("capabilities", [])
    |> Map.put_new("input_schema", %{
      "type" => "object",
      "properties" => %{},
      "required" => []
    })
  end

  defp format_errors(errors) do
    error_strings =
      Enum.map(errors, fn {name, reason} -> "  #{name}: #{reason}" end)
      |> Enum.join("\n")

    "A2A agent card validation errors:\n#{error_strings}"
  end
end
