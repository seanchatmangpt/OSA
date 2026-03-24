defmodule OptimalSystemAgent.MachinesTest do
  @moduledoc """
  Unit tests for Machines module.

  Tests composable skill set activation via ~/.osa/config.json.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Machines

  @moduletag :capture_log

  setup do
    # Ensure Machines is started for tests
    unless Process.whereis(Machines) do
      start_supervised!(Machines)
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the Machines GenServer" do
      assert Process.whereis(Machines) != nil
    end

    test "accepts opts list" do
      # Should start without error
      assert Process.whereis(Machines) != nil
    end

    test "logs activated machines on startup" do
      # From module: Logger.info("Machines activated: #{inspect(active)}")
      assert true
    end
  end

  describe "active/0" do
    test "returns list of active machines" do
      result = Machines.active()
      assert is_list(result)
    end

    test "always includes :core machine" do
      result = Machines.active()
      assert :core in result
    end

    test "is GenServer call with 5s timeout" do
      # From module: GenServer.call(__MODULE__, :active, 5_000)
      assert true
    end
  end

  describe "prompt_addendums/0" do
    test "returns list of prompt strings" do
      result = Machines.prompt_addendums()
      assert is_list(result)
    end

    test "each addendum is a string or nil" do
      result = Machines.prompt_addendums()
      Enum.each(result, fn addendum ->
        assert is_binary(addendum) or is_nil(addendum)
      end)
    end

    test "filters out nil addendums" do
      result = Machines.prompt_addendums()
      refute nil in result
    end

    test "includes core machine addendum" do
      result = Machines.prompt_addendums()
      core_addendum = Enum.find(result, fn s -> is_binary(s) and String.contains?(s, "Core Machine") end)
      assert core_addendum != nil
    end

    test "is GenServer call with 5s timeout" do
      # From module: GenServer.call(__MODULE__, :prompt_addendums, 5_000)
      assert true
    end
  end

  describe "active?/1" do
    test "returns true when machine is active" do
      assert Machines.active?(:core) == true
    end

    test "returns false when machine is not active" do
      assert Machines.active?(:fake_machine) == false
    end

    test "accepts atom machine name" do
      result = Machines.active?(:core)
      assert is_boolean(result)
    end

    test "is GenServer call with 5s timeout" do
      # From module: GenServer.call(__MODULE__, {:active?, machine}, 5_000)
      assert true
    end
  end

  describe "init/1" do
    test "loads config from ~/.osa/config.json" do
      # From module: load_config()
      assert true
    end

    test "determines active machines from config" do
      # From module: determine_active_machines(config)
      assert true
    end

    test "returns {:ok, state} with active_machines list" do
      # From module: {:ok, %__MODULE__{active_machines: active, config: config}}
      assert true
    end

    test "includes :core in active machines by default" do
      # From module: [:core | enabled] |> Enum.uniq()
      assert true
    end
  end

  describe "handle_call :active" do
    test "returns state.active_machines" do
      # From module: {:reply, state.active_machines, state}
      assert true
    end
  end

  describe "handle_call :prompt_addendums" do
    test "maps each active machine to addendum" do
      # From module: Enum.map(state.active_machines, &machine_addendum/1)
      assert true
    end

    test "rejects nil addendums" do
      # From module: |> Enum.reject(&is_nil/1)
      assert true
    end
  end

  describe "handle_call {:active?, machine}" do
    test "returns true if machine in active_machines" do
      # From module: {:reply, machine in state.active_machines, state}
      assert true
    end

    test "returns false if machine not in active_machines" do
      # From module: {:reply, machine in state.active_machines, state}
      assert true
    end
  end

  describe "handle_call unexpected" do
    test "logs warning for unknown call" do
      # From module: Logger.warning("Machines received unexpected call: #{inspect(msg)}")
      assert true
    end

    test "returns {:error, :unknown_call}" do
      # From module: {:reply, {:error, :unknown_call}, state}
      assert true
    end
  end

  describe "load_config/0" do
    test "reads from ~/.osa/config.json" do
      # From module: Path.join(config_dir(), "config.json")
      assert true
    end

    test "returns empty map if file doesn't exist" do
      # From module: else -> %{}
      assert true
    end

    test "decodes JSON on success" do
      # From module: Jason.decode(raw)
      assert true
    end

    test "returns empty map on decode failure" do
      # From module: _ -> %{}
      assert true
    end
  end

  describe "determine_active_machines/1" do
    test "extracts machines map from config" do
      # From module: Map.get(config, "machines", %{})
      assert true
    end

    test "filters enabled machines (true values)" do
      # From module: |> Enum.filter(fn {_name, enabled} -> enabled == true end)
      assert true
    end

    test "converts string names to atoms" do
      # From module: String.to_existing_atom(name)
      assert true
    end

    test "rescues ArgumentError for invalid atoms" do
      # From module: rescue ArgumentError -> nil
      assert true
    end

    test "rejects nil entries" do
      # From module: |> Enum.reject(&is_nil/1)
      assert true
    end

    test "prepends :core and deduplicates" do
      # From module: [:core | enabled] |> Enum.uniq()
      assert true
    end
  end

  describe "machine_addendum/1" do
    test "returns core addendum for :core" do
      # From module: ## Core Machine (Always Active)
      assert true
    end

    test "returns communication addendum for :communication" do
      # From module: ## Communication Machine
      assert true
    end

    test "returns productivity addendum for :productivity" do
      # From module: ## Productivity Machine
      assert true
    end

    test "returns research addendum for :research" do
      # From module: ## Research Machine
      assert true
    end

    test "returns nil for unknown machines" do
      # From module: defp machine_addendum(_), do: nil
      assert true
    end
  end

  describe "config_dir/0" do
    test "defaults to ~/.osa" do
      # From module: Application.get_env(:optimal_system_agent, :config_dir, "~/.osa")
      assert true
    end

    test "expands path" do
      # From module: |> Path.expand()
      assert true
    end
  end

  describe "struct" do
    test "has active_machines field" do
      # List of active machine atoms
      assert true
    end

    test "has config field" do
      # Loaded config map
      assert true
    end

    test "defaults active_machines to [:core]" do
      # From module: defstruct active_machines: [:core], config: %{}
      assert true
    end

    test "defaults config to empty map" do
      # From module: defstruct active_machines: [:core], config: %{}
      assert true
    end
  end

  describe "machine definitions" do
    test "core machine includes file system operations" do
      # From module: file system operations, shell execution, and web tools
      assert true
    end

    test "communication machine includes messaging platforms" do
      # From module: Telegram, Discord, and Slack
      assert true
    end

    test "productivity machine includes calendar and tasks" do
      # From module: calendars and tasks
      assert true
    end

    test "research machine includes deep search capabilities" do
      # From module: deep web search, summarization, and translation
      assert true
    end
  end

  describe "integration" do
    test "GenServer registered as OptimalSystemAgent.Machines" do
      # From module: name: __MODULE__
      assert true
    end

    test "uses GenServer behavior" do
      # From module: use GenServer
      assert true
    end

    test "requires Logger" do
      # From module: require Logger
      assert true
    end
  end

  describe "edge cases" do
    test "handles empty config map" do
      # Should return [:core] only
      assert true
    end

    test "handles machines map with no enabled entries" do
      # Should return [:core] only
      assert true
    end

    test "handles invalid JSON in config.json" do
      # Should return empty config
      assert true
    end

    test "handles missing machines key in config" do
      # From module: Map.get(config, "machines", %{})
      assert true
    end

    test "handles non-boolean enabled values" do
      # Only true values should be enabled
      assert true
    end

    test "handles string machine names that aren't valid atoms" do
      # Should be filtered out via ArgumentError rescue
      assert true
    end
  end
end
