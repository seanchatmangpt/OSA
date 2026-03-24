defmodule OptimalSystemAgent.Memory.SkillGeneratorRealTest do
  @moduledoc """
  Chicago TDD integration tests for Memory.SkillGenerator (slugify/1 only).

  NO MOCKS. Tests real string transformation logic.
  Every gap found is a real bug or missing behavior.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  alias OptimalSystemAgent.Memory.SkillGenerator

  describe "SkillGenerator.slugify/1" do
    test "CRASH: converts spaces to hyphens" do
      assert SkillGenerator.slugify("my skill name") == "my-skill-name"
    end

    test "CRASH: downcases input" do
      assert SkillGenerator.slugify("My Skill") == "my-skill"
    end

    test "CRASH: replaces special characters" do
      result = SkillGenerator.slugify("skill@#$!name")
      assert result == "skill-name"
    end

    test "CRASH: collapses consecutive hyphens" do
      result = SkillGenerator.slugify("my  skill  name")
      assert result == "my-skill-name"
    end

    test "CRASH: trims leading hyphens" do
      result = SkillGenerator.slugify("---skill---")
      assert result == "skill"
    end

    test "CRASH: trims trailing hyphens" do
      result = SkillGenerator.slugify("skill---")
      assert result == "skill"
    end

    test "CRASH: empty string returns unnamed (gap fixed)" do
      # GAP FIXED: slugify("") now returns "unnamed" instead of ""
      assert SkillGenerator.slugify("") == "unnamed"
    end

    test "CRASH: non-string input returns unnamed" do
      assert SkillGenerator.slugify(nil) == "unnamed"
    end

    test "CRASH: number input returns unnamed" do
      result = SkillGenerator.slugify(42)
      assert result == "unnamed"
    end

    test "CRASH: underscore stays as hyphen" do
      result = SkillGenerator.slugify("my_skill_name")
      assert result == "my-skill-name"
    end

    test "CRASH: leading/trailing spaces handled" do
      result = SkillGenerator.slugify("  hello world  ")
      assert result == "hello-world"
    end
  end
end
