defmodule OptimalSystemAgent.Tools.Builtins.YawlSpecLibraryTest do
  @moduledoc """
  Tests for the YawlSpecLibrary tool.

  All operations are pure filesystem reads against ~/yawlv6/exampleSpecs.
  No HTTP mocking is required — this test only touches the local spec library.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Tools.Builtins.YawlSpecLibrary

  # The default specs dir the tool resolves when YAWL_SPECS_DIR is unset.
  @specs_dir Path.expand("~/yawlv6/exampleSpecs")

  # ──────────────────────────────────────────────────────────────────────────
  # list_patterns/0
  # ──────────────────────────────────────────────────────────────────────────

  describe "list_patterns" do
    test "returns at least 30 patterns (there are 43 WCP XML files)" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_patterns"})
      assert result["count"] >= 30,
             "Expected at least 30 WCP patterns, got #{result["count"]}"
    end

    test "each pattern has the required keys" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_patterns"})
      for pattern <- result["patterns"] do
        assert Map.has_key?(pattern, "wcp"),
               "Pattern missing :wcp key: #{inspect(pattern)}"
        assert Map.has_key?(pattern, "name"),
               "Pattern missing :name key: #{inspect(pattern)}"
        assert Map.has_key?(pattern, "category"),
               "Pattern missing :category key: #{inspect(pattern)}"
        assert Map.has_key?(pattern, "path"),
               "Pattern missing :path key: #{inspect(pattern)}"
      end
    end

    test "WCP identifiers are in WCPnn format (uppercase)" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_patterns"})
      for pattern <- result["patterns"] do
        assert Regex.match?(~r/^WCP\d+$/, pattern["wcp"]),
               "Unexpected WCP identifier: #{pattern["wcp"]}"
      end
    end

    test "includes WCP01 (Sequence)" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_patterns"})
      wcp_ids = Enum.map(result["patterns"], & &1["wcp"])
      assert "WCP01" in wcp_ids, "WCP01 not found in pattern list"
    end

    test "includes WCP19 (multi-instance static)" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_patterns"})
      wcp_ids = Enum.map(result["patterns"], & &1["wcp"])
      assert "WCP19" in wcp_ids, "WCP19 not found in pattern list"
    end

    test "categories list is populated and sorted" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_patterns"})
      assert is_list(result["categories"])
      assert length(result["categories"]) > 0
      assert result["categories"] == Enum.sort(result["categories"])
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # get_pattern/1
  # ──────────────────────────────────────────────────────────────────────────

  describe "get_pattern" do
    test "WCP01 returns non-empty XML containing specificationSet" do
      result = YawlSpecLibrary.execute(%{"operation" => "get_pattern", "wcp_id" => "WCP01"})

      case result do
        {:ok, map} ->
          assert is_binary(map["content"]), "Expected content to be a binary"
          assert byte_size(map["content"]) > 0, "Expected non-empty XML content"
          assert map["content"] =~ "<specificationSet",
                 "Expected XML to contain <specificationSet"

        {:error, :not_found, _msg} ->
          flunk("WCP01 not found — check YAWL_SPECS_DIR or exampleSpecs/wcp-patterns/")

        {:error, msg} ->
          flunk("Unexpected error: #{inspect(msg)}")
      end
    end

    test "WCP19 (multi-instance static) returns XML" do
      result = YawlSpecLibrary.execute(%{"operation" => "get_pattern", "wcp_id" => "WCP19"})

      case result do
        {:ok, map} ->
          assert byte_size(map["content"]) > 0
          assert map["content"] =~ "<specificationSet"

        {:error, :not_found, msg} ->
          flunk("WCP19 not found: #{msg}")

        {:error, msg} ->
          flunk("Unexpected error: #{inspect(msg)}")
      end
    end

    test "lookup is case-insensitive (wcp01 = WCP01)" do
      lower_result = YawlSpecLibrary.execute(%{"operation" => "get_pattern", "wcp_id" => "wcp01"})
      upper_result = YawlSpecLibrary.execute(%{"operation" => "get_pattern", "wcp_id" => "WCP01"})

      # Both should succeed or both should give the same error
      case {lower_result, upper_result} do
        {{:ok, l}, {:ok, u}} -> assert l["filename"] == u["filename"]
        {{:error, _, _}, {:error, _, _}} -> :ok
        _ -> flunk("Case-insensitivity mismatch between 'wcp01' and 'WCP01'")
      end
    end

    test "unknown pattern returns not_found error" do
      result = YawlSpecLibrary.execute(%{"operation" => "get_pattern", "wcp_id" => "WCP999"})
      assert {:error, :not_found, _msg} = result
    end

    test "missing wcp_id returns error without HTTP call" do
      assert {:error, msg} = YawlSpecLibrary.execute(%{"operation" => "get_pattern"})
      assert is_binary(msg)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # list_real_data/0
  # ──────────────────────────────────────────────────────────────────────────

  describe "list_real_data" do
    test "result includes RepairProcess" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_real_data"})
      filenames = Enum.map(result["files"], & &1["filename"])
      assert Enum.any?(filenames, &String.starts_with?(&1, "RepairProcess")),
             "Expected RepairProcess in #{inspect(filenames)}"
    end

    test "result includes TrafficFineManagement" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_real_data"})
      filenames = Enum.map(result["files"], & &1["filename"])
      assert Enum.any?(filenames, &String.starts_with?(&1, "TrafficFineManagement")),
             "Expected TrafficFineManagement in #{inspect(filenames)}"
    end

    test "each file entry has required keys" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_real_data"})
      for entry <- result["files"] do
        assert Map.has_key?(entry, "filename")
        assert Map.has_key?(entry, "source")
        assert Map.has_key?(entry, "path")
        assert Map.has_key?(entry, "size_bytes")
      end
    end

    test "returns at least one file" do
      assert {:ok, result} = YawlSpecLibrary.execute(%{"operation" => "list_real_data"})
      assert result["count"] >= 1
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # get_spec_xml/1
  # ──────────────────────────────────────────────────────────────────────────

  describe "get_spec_xml" do
    test "RepairProcess.yawl.xml returns non-empty content" do
      result =
        YawlSpecLibrary.execute(%{
          "operation" => "get_spec_xml",
          "filename" => "RepairProcess.yawl.xml"
        })

      case result do
        {:ok, map} ->
          assert is_binary(map["content"])
          assert byte_size(map["content"]) > 0

        {:error, :not_found, _} ->
          flunk("RepairProcess.yawl.xml not found in exampleSpecs/real-data/")

        {:error, msg} ->
          flunk("Unexpected error: #{inspect(msg)}")
      end
    end

    test "unknown filename returns not_found error" do
      result =
        YawlSpecLibrary.execute(%{
          "operation" => "get_spec_xml",
          "filename" => "DoesNotExist.yawl.xml"
        })

      assert {:error, :not_found, _msg} = result
    end

    test "missing filename parameter returns error" do
      assert {:error, msg} = YawlSpecLibrary.execute(%{"operation" => "get_spec_xml"})
      assert is_binary(msg)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Missing / invalid operation
  # ──────────────────────────────────────────────────────────────────────────

  describe "execute with bad params" do
    test "missing operation returns error" do
      assert {:error, msg} = YawlSpecLibrary.execute(%{})
      assert is_binary(msg)
    end

    test "unknown operation returns error" do
      assert {:error, msg} = YawlSpecLibrary.execute(%{"operation" => "explode"})
      assert is_binary(msg)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Behaviour / metadata
  # ──────────────────────────────────────────────────────────────────────────

  describe "tool metadata" do
    test "name is yawl_spec_library" do
      assert YawlSpecLibrary.name() == "yawl_spec_library"
    end

    test "safety is read_only" do
      assert YawlSpecLibrary.safety() == :read_only
    end

    test "parameters returns a valid JSON-schema object" do
      params = YawlSpecLibrary.parameters()
      assert params["type"] == "object"
      assert Map.has_key?(params["properties"], "operation")
      assert Map.has_key?(params["properties"], "wcp_id")
      assert Map.has_key?(params["properties"], "filename")
    end
  end
end
