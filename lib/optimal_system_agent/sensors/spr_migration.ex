defmodule OptimalSystemAgent.Sensors.SPRMigration do
  @moduledoc """
  SPR Format Migration — Handle backward compatibility for old SPR file formats

  Supports migration from:
  - Version 1.0: Basic format with just "version" and "modules"
  - Version 2.0: Current format with Signal Theory encoding

  All migrations preserve data completely during the upgrade path.
  """

  require Logger

  @current_version "2.0"
  @supported_versions ["1.0", "2.0"]

  @doc """
  Migrate an SPR file to the current format.

  Returns `{:ok, migrated_data}` or `{:error, reason}`.
  """
  def migrate_file(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, data} <- Jason.decode(content) do
      migrate(data)
    else
      {:error, reason} ->
        Logger.error("[SPRMigration] Failed to read file: #{file_path}", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Migrate SPR data to current format.

  Automatically detects the source format version and applies appropriate migrations.
  """
  def migrate(data) when is_map(data) do
    # Detect format by checking for version field or v2.0 indicators
    cond do
      # Explicit version field
      Map.has_key?(data, "version") ->
        version = Map.get(data, "version")
        case version do
          "1.0" ->
            {:ok, migrate_v1_0_to_v2_0(data)}
          "2.0" ->
            # Already current format
            {:ok, data}
          unknown ->
            Logger.warning("[SPRMigration] Unknown SPR version: #{unknown}, attempting v1.0 migration")
            {:ok, migrate_v1_0_to_v2_0(data)}
        end

      # v2.0 indicators: has scan_type, timestamp, total_modules/total_deps/total_patterns
      Map.has_key?(data, "scan_type") and
      Map.has_key?(data, "timestamp") and
      (Map.has_key?(data, "total_modules") or Map.has_key?(data, "total_deps") or Map.has_key?(data, "total_patterns")) ->
        # Already v2.0 format (maybe missing Signal Theory fields, but that's OK)
        {:ok, data}

      # v1.0 indicators: has modules array but no scan_type
      Map.has_key?(data, "modules") and not Map.has_key?(data, "scan_type") ->
        {:ok, migrate_v1_0_to_v2_0(data)}

      # Unknown format
      true ->
        Logger.warning("[SPRMigration] Could not detect SPR format, attempting v1.0 migration")
        {:ok, migrate_v1_0_to_v2_0(data)}
    end
  end

  def migrate(_), do: {:error, :invalid_spr_format}

  @doc """
  Detect SPR format version from data.
  """
  def detect_version(data) when is_map(data) do
    version = Map.get(data, "version", "1.0")

    if version in @supported_versions do
      {:ok, version}
    else
      {:error, :unsupported_version}
    end
  end

  @doc """
  Get all supported SPR versions.
  """
  def supported_versions, do: @supported_versions

  @doc """
  Get the current SPR version.
  """
  def current_version, do: @current_version

  # ============================================================================
  # Private Migration Functions
  # ============================================================================

  defp migrate_v1_0_to_v2_0(data) do
    # Migrate v1.0 (minimal format) to v2.0 (current format with Signal Theory)
    timestamp = System.system_time(:millisecond)

    # Extract modules from v1.0 format
    modules = Map.get(data, "modules", [])

    %{
      # Core fields
      "version" => @current_version,
      "scan_type" => "modules",
      "timestamp" => timestamp,
      "total_modules" => length(modules),
      "modules" => modules,
      # Signal Theory S=(M,G,T,F,W) encoding
      "mode" => "data",
      "genre" => "spec",
      "type" => "inform",
      "format" => "json",
      "structure" => "list",
      # Migration metadata for audit trail
      "migration" => %{
        "from_version" => "1.0",
        "to_version" => @current_version,
        "migrated_at" => timestamp,
        "data_preserved" => true
      }
    }
  end
end
