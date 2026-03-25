defmodule OptimalSystemAgent.MCP.ConfigValidator do
  @moduledoc """
  Validates MCP server configuration structures.

  Ensures that mcp.json server entries have the required fields
  and valid transport configurations before attempting to start
  MCP server processes.
  """

  @valid_transports ~w(stdio http)

  @doc """
  Validates a single MCP server configuration map.

  ## Required fields
    * `name` - unique server identifier (string)
    * `transport` - "stdio" or "http"

  ## Transport-specific requirements
    * `stdio` - requires `command` (string)
    * `http` - requires `url` (string)

  ## Returns
    * `{:ok, validated_config}` - normalized and validated config
    * `{:error, reason}` - human-readable validation error
  """
  @spec validate_config(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_config(config) when is_map(config) do
    with :ok <- validate_name(config),
         :ok <- validate_transport(config),
         :ok <- validate_transport_fields(config) do
      {:ok, normalize_config(config)}
    end
  end

  def validate_config(_), do: {:error, "Config must be a map"}

  @doc """
  Validates a full mcp.json structure (the outer wrapper).

  Accepts three formats:
    * `%{"mcpServers" => %{...}}`
    * `%{"mcp_servers" => %{...}}`
    * `%{...}` (backward compat: top-level map)

  Returns `{:ok, server_configs}` or `{:error, reason}`.
  """
  @spec validate_config_file(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_config_file(%{"mcpServers" => servers}) when is_map(servers) do
    validate_all_servers(servers)
  end

  def validate_config_file(%{"mcp_servers" => servers}) when is_map(servers) do
    validate_all_servers(servers)
  end

  def validate_config_file(servers) when is_map(servers) do
    # Backward compat: treat top-level map as server configs
    validate_all_servers(servers)
  end

  def validate_config_file(_), do: {:error, "Config must be a map with server definitions"}

  # ── Private helpers ──────────────────────────────────────────────

  defp validate_name(%{"name" => name}) when is_binary(name) and name != "" do
    :ok
  end

  defp validate_name(_),
    do: {:error, "Missing or invalid 'name' field (must be non-empty string)"}

  defp validate_transport(%{"transport" => transport})
       when is_binary(transport) and transport in @valid_transports do
    :ok
  end

  defp validate_transport(%{"transport" => transport}) when is_binary(transport) do
    {:error,
     "Invalid transport '#{transport}'. Must be one of: #{Enum.join(@valid_transports, ", ")}"}
  end

  defp validate_transport(_), do: {:error, "Missing or invalid 'transport' field"}

  defp validate_transport_fields(%{"transport" => "stdio"} = config) do
    case Map.get(config, "command") do
      command when is_binary(command) and command != "" ->
        :ok

      _ ->
        {:error, "stdio transport requires a 'command' field (non-empty string)"}
    end
  end

  defp validate_transport_fields(%{"transport" => "http"} = config) do
    case Map.get(config, "url") do
      url when is_binary(url) and url != "" ->
        :ok

      _ ->
        {:error, "http transport requires a 'url' field (non-empty string)"}
    end
  end

  defp validate_transport_fields(_), do: :ok

  defp validate_all_servers(servers) do
    errors =
      servers
      |> Enum.reduce([], fn {name, config}, acc ->
        case validate_config(Map.put(config, "name", name)) do
          {:ok, _} -> acc
          {:error, reason} -> [{name, reason} | acc]
        end
      end)
      |> Enum.reverse()

    case errors do
      [] -> {:ok, servers}
      _ -> {:error, format_validation_errors(errors)}
    end
  end

  defp normalize_config(config) do
    config
    |> Map.put_new("args", [])
    |> Map.put_new("env", %{})
  end

  defp format_validation_errors(errors) do
    error_strings =
      Enum.map(errors, fn {name, reason} -> "  #{name}: #{reason}" end)
      |> Enum.join("\n")

    "Validation errors in server configs:\n#{error_strings}"
  end
end
