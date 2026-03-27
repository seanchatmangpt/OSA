defmodule OptimalSystemAgent.Yawl.SpecLibraryTest do
  @moduledoc """
  Tests for YAWL spec library discovery and loading.

  Pure file I/O tests — compatible with --no-start.
  Tests that depend on the actual ~/yawlv6 checkout are tagged
  :requires_yawlv6 and are skipped when the directory is absent.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Yawl.SpecLibrary

  # ---------------------------------------------------------------------------
  # spec_path/0
  # ---------------------------------------------------------------------------

  describe "spec_path/0" do
    test "returns a binary string" do
      path = SpecLibrary.spec_path()
      assert is_binary(path)
    end

    test "defaults to a path containing 'yawlv6'" do
      # Remove any override so we test the default resolution.
      original = System.get_env("YAWLV6_SPECS_PATH")

      try do
        System.delete_env("YAWLV6_SPECS_PATH")
        path = SpecLibrary.spec_path()
        assert String.contains?(path, "yawlv6")
      after
        if original, do: System.put_env("YAWLV6_SPECS_PATH", original)
      end
    end

    test "respects YAWLV6_SPECS_PATH environment variable" do
      custom = "/tmp/custom_yawl_specs"
      original = System.get_env("YAWLV6_SPECS_PATH")

      try do
        System.put_env("YAWLV6_SPECS_PATH", custom)
        path = SpecLibrary.spec_path()
        assert path == custom
      after
        if original do
          System.put_env("YAWLV6_SPECS_PATH", original)
        else
          System.delete_env("YAWLV6_SPECS_PATH")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list_patterns/0
  # ---------------------------------------------------------------------------

  describe "list_patterns/0" do
    test "returns a list (empty when specs path absent)" do
      patterns = SpecLibrary.list_patterns()
      assert is_list(patterns)
    end

    @tag :requires_yawlv6
    test "includes WCP-1 through WCP-5 (basic patterns)" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(specs_path) do
        patterns = SpecLibrary.list_patterns()
        ids = Enum.map(patterns, & &1.id)

        for n <- 1..5 do
          assert "WCP-#{n}" in ids, "Expected WCP-#{n} in pattern list, got: #{inspect(ids)}"
        end
      end
    end

    @tag :requires_yawlv6
    test "each pattern has required fields with correct types" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(specs_path) do
        patterns = SpecLibrary.list_patterns()
        assert length(patterns) > 0, "Expected at least one pattern"

        for pattern <- patterns do
          assert is_binary(pattern.id), "id must be a string"
          assert is_binary(pattern.name), "name must be a string"
          assert is_binary(pattern.category), "category must be a string"
          assert is_binary(pattern.path), "path must be a string"
          assert String.starts_with?(pattern.id, "WCP-"), "id must start with WCP-"
        end
      end
    end

    @tag :requires_yawlv6
    test "patterns are sorted by WCP number" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(specs_path) do
        patterns = SpecLibrary.list_patterns()
        ids = Enum.map(patterns, & &1.id)

        numbers =
          Enum.map(ids, fn "WCP-" <> n -> String.to_integer(n) end)

        assert numbers == Enum.sort(numbers), "Patterns must be sorted by WCP number"
      end
    end

    @tag :requires_yawlv6
    test "WCP-1 is in the 'basic' category" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(specs_path) do
        patterns = SpecLibrary.list_patterns()
        wcp1 = Enum.find(patterns, fn p -> p.id == "WCP-1" end)
        assert wcp1 != nil, "WCP-1 must be present"
        assert wcp1.category == "basic"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # load_spec/1
  # ---------------------------------------------------------------------------

  describe "load_spec/1" do
    test "returns {:error, :not_found} for completely unknown pattern" do
      assert {:error, :not_found} = SpecLibrary.load_spec("NONEXISTENT_PATTERN_XYZ_99999")
    end

    test "returns {:error, :not_found} when specs directory does not exist" do
      original = System.get_env("YAWLV6_SPECS_PATH")

      try do
        System.put_env("YAWLV6_SPECS_PATH", "/tmp/definitely_absent_yawl_specs_dir_abc")
        assert {:error, :not_found} = SpecLibrary.load_spec("WCP-1")
      after
        if original do
          System.put_env("YAWLV6_SPECS_PATH", original)
        else
          System.delete_env("YAWLV6_SPECS_PATH")
        end
      end
    end

    @tag :requires_yawlv6
    test "returns {:ok, xml} for WCP-1 (dash format)" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(specs_path) do
        assert {:ok, xml} = SpecLibrary.load_spec("WCP-1")
        assert is_binary(xml)
        assert String.length(xml) > 0
        assert String.contains?(xml, "specificationSet") or String.contains?(xml, "WCP")
      end
    end

    @tag :requires_yawlv6
    test "returns {:ok, xml} for WCP-1 using no-dash format 'WCP1'" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(specs_path) do
        result = SpecLibrary.load_spec("WCP1")
        assert {:ok, xml} = result
        assert is_binary(xml)
      end
    end

    @tag :requires_yawlv6
    test "returns {:ok, xml} for WCP-1 using zero-padded format 'WCP01'" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(specs_path) do
        result = SpecLibrary.load_spec("WCP01")
        assert {:ok, xml} = result
        assert is_binary(xml)
      end
    end

    @tag :requires_yawlv6
    test "load_spec/1 returns consistent result for equivalent IDs" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(specs_path) do
        {:ok, xml_dash} = SpecLibrary.load_spec("WCP-2")
        {:ok, xml_no_dash} = SpecLibrary.load_spec("WCP2")
        {:ok, xml_padded} = SpecLibrary.load_spec("WCP02")

        assert xml_dash == xml_no_dash,
               "WCP-2 and WCP2 should return the same XML"

        assert xml_dash == xml_padded,
               "WCP-2 and WCP02 should return the same XML"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list_real_data/0
  # ---------------------------------------------------------------------------

  describe "list_real_data/0" do
    test "returns a list (empty when specs path absent)" do
      datasets = SpecLibrary.list_real_data()
      assert is_list(datasets)
    end

    @tag :requires_yawlv6
    test "includes known datasets when yawlv6 present" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(Path.join(specs_path, "real-data")) do
        datasets = SpecLibrary.list_real_data()
        names = Enum.map(datasets, & &1.name)

        # At least one of the known datasets must be present
        known = ["order-management", "repair-process", "traffic-fine-management"]
        found = Enum.filter(known, &(&1 in names))
        assert length(found) > 0, "Expected at least one known dataset, got: #{inspect(names)}"
      end
    end

    @tag :requires_yawlv6
    test "each dataset entry has name and path fields" do
      specs_path = SpecLibrary.spec_path()

      if File.dir?(Path.join(specs_path, "real-data")) do
        datasets = SpecLibrary.list_real_data()

        for ds <- datasets do
          assert is_binary(ds.name)
          assert is_binary(ds.path)
          # Path may be a file (flat layout) or directory (legacy layout)
          assert File.exists?(ds.path), "Dataset path must exist: #{ds.path}"
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # load_real_data/1
  # ---------------------------------------------------------------------------

  describe "load_real_data/1" do
    test "returns {:error, :not_found} for nonexistent dataset" do
      assert {:error, :not_found} = SpecLibrary.load_real_data("nonexistent_dataset_xyz_abc")
    end

    @tag :requires_yawlv6
    test "returns {:ok, xml} for 'order-management' when present" do
      specs_path = SpecLibrary.spec_path()
      real_data = Path.join(specs_path, "real-data")

      # Works for both flat file and subdirectory layout
      if File.dir?(real_data) do
        result = SpecLibrary.load_real_data("order-management")

        case result do
          {:ok, xml} ->
            assert is_binary(xml)
            assert String.length(xml) > 0

          {:error, :not_found} ->
            # Dataset not present in this exampleSpecs checkout — skip
            :ok
        end
      end
    end

    @tag :requires_yawlv6
    test "returns {:ok, xml} for 'repair-process' when present" do
      specs_path = SpecLibrary.spec_path()
      real_data = Path.join(specs_path, "real-data")

      if File.dir?(real_data) do
        result = SpecLibrary.load_real_data("repair-process")

        case result do
          {:ok, xml} ->
            assert is_binary(xml)
            assert String.length(xml) > 0

          {:error, :not_found} ->
            :ok
        end
      end
    end

    @tag :requires_yawlv6
    test "returns {:ok, xml} for 'traffic-fine-management' when present" do
      specs_path = SpecLibrary.spec_path()
      real_data = Path.join(specs_path, "real-data")

      if File.dir?(real_data) do
        result = SpecLibrary.load_real_data("traffic-fine-management")

        case result do
          {:ok, xml} ->
            assert is_binary(xml)
            assert String.length(xml) > 0

          {:error, :not_found} ->
            :ok
        end
      end
    end
  end
end
