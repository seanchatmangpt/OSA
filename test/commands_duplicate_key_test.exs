defmodule OptimalSystemAgent.CommandsDuplicateKeyTest do
  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Commands

  describe "command key uniqueness" do
    test "no two commands share the same key" do
      names = Commands.list_commands() |> Enum.map(fn {name, _desc, _cat} -> name end)
      unique_names = Enum.uniq(names)
      duplicates = names -- unique_names
      assert duplicates == [],
        "Found duplicate command keys: #{inspect(Enum.uniq(duplicates))}"
    end
  end

  describe "specific command presence" do
    test "/tier command is present in the list" do
      names = Commands.list_commands() |> Enum.map(fn {name, _desc, _cat} -> name end)
      assert "tier" in names
    end

    test "/tier command is executable" do
      result = Commands.execute("tier", "test-session")
      refute result == :unknown
    end
  end

  describe "tier command disambiguation" do
    test "tier command count is exactly 1" do
      tier_cmds = Commands.list_commands() |> Enum.filter(fn {name, _d, _c} -> name == "tier" end)
      assert length(tier_cmds) == 1,
        "Expected exactly 1 tier command but found #{length(tier_cmds)}"
    end
  end
end
