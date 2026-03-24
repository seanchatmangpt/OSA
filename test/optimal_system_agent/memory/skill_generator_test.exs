defmodule OptimalSystemAgent.Memory.SkillGeneratorTest do
  @moduledoc """
  Unit tests for Memory.SkillGenerator module.

  Tests conversion of memory patterns into executable skills.
  Pure functions with template-based generation.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Memory.SkillGenerator

  @moduletag :capture_log

  describe "generate_from_pattern/1" do
    test "generates skill from pattern with all fields" do
      pattern = %{
        id: "pat_123",
        description: "Always use TDD for new features",
        trigger: "tdd,testing",
        response: "Apply test-first development",
        category: "decision",
        tags: "testing,elixir"
      }
      assert {:ok, path} = SkillGenerator.generate_from_pattern(pattern)
      assert is_binary(path)
      assert String.ends_with?(path, ".md")
    end

    test "generates skill with minimal fields" do
      pattern = %{
        id: "pat_456",
        description: "Minimal skill"
      }
      assert {:ok, path} = SkillGenerator.generate_from_pattern(pattern)
      assert is_binary(path)
    end

    test "returns error for invalid input" do
      assert {:error, _reason} = SkillGenerator.generate_from_pattern(nil)
    end
  end

  describe "generate_all_pending/0" do
    test "returns ok tuple with count" do
      assert {:ok, count} = SkillGenerator.generate_all_pending()
      assert is_integer(count)
      assert count >= 0
    end
  end

  describe "slugify/1" do
    test "creates slug from text" do
      slug = SkillGenerator.slugify("Use TDD for everything")
      assert is_binary(slug)
      assert slug == String.downcase(slug)
      refute String.contains?(slug, " ")
    end

    test "replaces spaces with hyphens" do
      slug = SkillGenerator.slugify("use tdd for features")
      assert String.contains?(slug, "-")
      refute String.contains?(slug, " ")
    end

    test "handles short text" do
      slug = SkillGenerator.slugify("TDD")
      assert is_binary(slug)
      assert String.length(slug) > 0
    end

    test "handles unicode content" do
      slug = SkillGenerator.slugify("使用TDD")
      assert is_binary(slug)
    end

    test "returns unnamed for empty input" do
      assert SkillGenerator.slugify("") == "unnamed"
      assert SkillGenerator.slugify(nil) == "unnamed"
    end
  end

  describe "skill_exists?/1" do
    test "returns boolean for pattern ID" do
      result = SkillGenerator.skill_exists?("pat_999")
      assert is_boolean(result)
    end

    test "returns false for empty ID" do
      assert SkillGenerator.skill_exists?("") == false
    end

    test "returns false for nil" do
      assert SkillGenerator.skill_exists?(nil) == false
    end
  end

  describe "edge cases" do
    test "handles pattern with very long description" do
      long_description = String.duplicate("test ", 50)
      pattern = %{
        id: "pat_long",
        description: long_description,
        trigger: "test",
        response: "Response"
      }
      assert {:ok, _path} = SkillGenerator.generate_from_pattern(pattern)
    end

    test "handles pattern with unicode description" do
      pattern = %{
        id: "pat_unicode",
        description: "使用TDD进行开发",
        trigger: "test",
        response: "Response"
      }
      assert {:ok, _path} = SkillGenerator.generate_from_pattern(pattern)
    end

    test "handles pattern with mixed special characters" do
      pattern = %{
        id: "pat_special",
        description: "Use Elixir & Phoenix with GenServer",
        trigger: "elixir|phoenix",
        response: "Response"
      }
      assert {:ok, _path} = SkillGenerator.generate_from_pattern(pattern)
    end
  end

  describe "integration" do
    test "full pattern to skill generation" do
      pattern = %{
        id: "pat_integration",
        description: "Always use TDD when developing",
        trigger: "tdd,testing",
        response: "Apply test-first approach",
        category: "decision",
        tags: "testing,best-practice"
      }

      assert {:ok, path} = SkillGenerator.generate_from_pattern(pattern)
      assert is_binary(path)
      assert String.ends_with?(path, ".md")
    end

    test "consistent slugification for same description" do
      desc1 = "Use TDD for Testing"
      desc2 = "use tdd for testing"

      slug1 = SkillGenerator.slugify(desc1)
      slug2 = SkillGenerator.slugify(desc2)

      assert slug1 == slug2
    end
  end
end
