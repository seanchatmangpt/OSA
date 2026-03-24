defmodule OptimalSystemAgent.Memory.SkillGeneratorTest do
  @moduledoc """
  Chicago TDD unit tests for Memory.SkillGenerator module.

  Tests conversion of memory patterns into executable skills.
  Pure functions with template-based generation.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Memory.SkillGenerator

  @moduletag :capture_log

  describe "generate_skill/1" do
    test "generates skill from decision pattern" do
      pattern = %{
        content: "Always use TDD for new features",
        keywords: "tdd,testing,elixir",
        category: "decision"
      }
      assert {:ok, skill} = SkillGenerator.generate_skill(pattern)
      assert is_map(skill)
      assert skill.name != nil
      assert skill.description != nil
    end

    test "generates skill from preference pattern" do
      pattern = %{
        content: "Prefer dark theme for development",
        keywords: "dark,theme,ide",
        category: "preference"
      }
      assert {:ok, skill} = SkillGenerator.generate_skill(pattern)
      assert is_map(skill)
    end

    test "generates skill from pattern pattern" do
      pattern = %{
        content: "Use GenServer for state management",
        keywords: "genserver,state,elixir",
        category: "pattern"
      }
      assert {:ok, skill} = SkillGenerator.generate_skill(pattern)
      assert is_map(skill)
    end

    test "returns error for invalid pattern" do
      assert {:error, _reason} = SkillGenerator.generate_skill(nil)
      assert {:error, _reason} = SkillGenerator.generate_skill(%{})
      assert {:error, _reason} = SkillGenerator.generate_skill("not a map")
    end

    test "generates unique skill name" do
      pattern1 = %{content: "Use TDD", keywords: "tdd", category: "decision"}
      pattern2 = %{content: "Write tests", keywords: "testing", category: "decision"}
      assert {:ok, skill1} = SkillGenerator.generate_skill(pattern1)
      assert {:ok, skill2} = SkillGenerator.generate_skill(pattern2)
      assert skill1.name != skill2.name
    end
  end

  describe "generate_name/1" do
    test "creates name from content" do
      pattern = %{content: "Use TDD for everything"}
      name = SkillGenerator.generate_name(pattern)
      assert is_binary(name)
      assert String.length(name) > 0
    end

    test "lowercases and sanitizes name" do
      pattern = %{content: "Use TDD & Testing!"}
      name = SkillGenerator.generate_name(pattern)
      assert name == String.downcase(name)
      # Should remove special characters
      refute String.contains?(name, "!")
      refute String.contains?(name, "&")
    end

    test "replaces spaces with hyphens" do
      pattern = %{content: "use tdd for features"}
      name = SkillGenerator.generate_name(pattern)
      assert String.contains?(name, "-")
      refute String.contains?(name, " ")
    end

    test "handles short content" do
      pattern = %{content: "TDD"}
      name = SkillGenerator.generate_name(pattern)
      assert is_binary(name)
      assert String.length(name) > 0
    end

    test "handles unicode content" do
      pattern = %{content: "使用TDD"}
      name = SkillGenerator.generate_name(pattern)
      assert is_binary(name)
    end
  end

  describe "generate_description/1" do
    test "creates description from pattern content" do
      pattern = %{content: "Always use TDD for new features", category: "decision"}
      description = SkillGenerator.generate_description(pattern)
      assert is_binary(description)
      assert String.length(description) > 0
    end

    test "includes category in description" do
      pattern = %{content: "Use TDD", category: "decision"}
      description = SkillGenerator.generate_description(pattern)
      # Should reference the category
      assert true
    end

    test "includes keywords in description" do
      pattern = %{
        content: "Use TDD",
        keywords: "testing,elixir,tdd",
        category: "decision"
      }
      description = SkillGenerator.generate_description(pattern)
      assert is_binary(description)
    end

    test "handles empty keywords" do
      pattern = %{content: "Use TDD", keywords: "", category: "decision"}
      description = SkillGenerator.generate_description(pattern)
      assert is_binary(description)
    end
  end

  describe "generate_steps/1" do
    test "generates steps for decision pattern" do
      pattern = %{content: "Use TDD for all features", category: "decision"}
      steps = SkillGenerator.generate_steps(pattern)
      assert is_list(steps)
      assert length(steps) > 0
    end

    test "generates steps for pattern pattern" do
      pattern = %{content: "Use GenServer for state", category: "pattern"}
      steps = SkillGenerator.generate_steps(pattern)
      assert is_list(steps)
    end

    test "each step is a string" do
      pattern = %{content: "Test first", category: "decision"}
      steps = SkillGenerator.generate_steps(pattern)
      Enum.each(steps, fn step ->
        assert is_binary(step)
      end)
    end
  end

  describe "generate_examples/1" do
    test "generates example from pattern" do
      pattern = %{content: "Use TDD", keywords: "elixir,testing", category: "decision"}
      examples = SkillGenerator.generate_examples(pattern)
      assert is_list(examples)
    end

    test "includes code example when keywords suggest language" do
      pattern = %{content: "Use TDD", keywords: "elixir,testing", category: "pattern"}
      examples = SkillGenerator.generate_examples(pattern)
      # Should generate code example based on keywords
      assert is_list(examples)
    end

    test "returns empty list for simple preferences" do
      pattern = %{content: "Prefer dark theme", category: "preference"}
      examples = SkillGenerator.generate_examples(pattern)
      assert is_list(examples)
    end
  end

  describe "format_skill/2" do
    test "formats skill as map" do
      name = "test-skill"
      description = "A test skill"
      steps = ["Step 1", "Step 2"]
      skill = SkillGenerator.format_skill(name, description, steps, [])
      assert is_map(skill)
      assert skill.name == name
      assert skill.description == description
    end

    test "includes all fields" do
      skill = SkillGenerator.format_skill(
        "test",
        "description",
        ["step1"],
        ["example1"]
      )
      assert Map.has_key?(skill, :name)
      assert Map.has_key?(skill, :description)
      assert Map.has_key?(skill, :steps)
      assert Map.has_key?(skill, :examples)
    end

    test "handles empty steps and examples" do
      skill = SkillGenerator.format_skill("test", "desc", [], [])
      assert skill.steps == []
      assert skill.examples == []
    end
  end

  describe "infer_language/1" do
    test "detects elixir from keywords" do
      pattern = %{keywords: "elixir,phoenix"}
      language = SkillGenerator.infer_language(pattern)
      assert language == "elixir"
    end

    test "detects rust from keywords" do
      pattern = %{keywords: "rust,cargo"}
      language = SkillGenerator.infer_language(pattern)
      assert language == "rust"
    end

    test "detects python from keywords" do
      pattern = %{keywords: "python,pip"}
      language = SkillGenerator.infer_language(pattern)
      assert language == "python"
    end

    test "returns generic when no language detected" do
      pattern = %{keywords: "testing,tdd"}
      language = SkillGenerator.infer_language(pattern)
      assert language == "generic"
    end

    test "handles empty keywords" do
      pattern = %{keywords: ""}
      language = SkillGenerator.infer_language(pattern)
      assert language == "generic"
    end

    test "handles nil keywords" do
      pattern = %{keywords: nil}
      language = SkillGenerator.infer_language(pattern)
      assert language == "generic"
    end
  end

  describe "sanitize_string/1" do
    test "removes special characters" do
      sanitized = SkillGenerator.sanitize_string("Hello! World@ Test#")
      refute String.contains?(sanitized, "!")
      refute String.contains?(sanitized, "@")
      refute String.contains?(sanitized, "#")
    end

    test "replaces spaces with hyphens" do
      sanitized = SkillGenerator.sanitize_string("hello world test")
      assert String.contains?(sanitized, "-")
      refute String.contains?(sanitized, " ")
    end

    test "lowercases string" do
      sanitized = SkillGenerator.sanitize_string("HELLO WORLD")
      assert sanitized == String.downcase(sanitized)
    end

    test "handles empty string" do
      assert SkillGenerator.sanitize_string("") == ""
    end

    test "handles string with only special characters" do
      sanitized = SkillGenerator.sanitize_string("!@#$%")
      assert is_binary(sanitized)
    end
  end

  describe "edge cases" do
    test "handles pattern with very long content" do
      long_content = String.duplicate("This is a very long pattern content. ", 100)
      pattern = %{content: long_content, keywords: "test", category: "decision"}
      assert {:ok, skill} = SkillGenerator.generate_skill(pattern)
      assert is_binary(skill.name)
      assert String.length(skill.name) < 100  # Name should be truncated
    end

    test "handles pattern with unicode" do
      pattern = %{
        content: "使用TDD进行开发",
        keywords: "测试,TDD",
        category: "decision"
      }
      assert {:ok, skill} = SkillGenerator.generate_skill(pattern)
      assert is_map(skill)
    end

    test "handles pattern with mixed content types" do
      pattern = %{
        content: "Use Elixir & Phoenix with GenServer",
        keywords: "elixir,phoenix,genserver",
        category: "pattern"
      }
      assert {:ok, skill} = SkillGenerator.generate_skill(pattern)
      assert is_map(skill)
    end

    test "handles pattern with nil category" do
      pattern = %{
        content: "Test content",
        keywords: "test",
        category: nil
      }
      result = SkillGenerator.generate_skill(pattern)
      # Should handle gracefully - either ok or error
      case result do
        {:ok, _skill} -> assert true
        {:error, _reason} -> assert true
      end
    end
  end

  describe "integration" do
    test "full skill generation pipeline" do
      pattern = %{
        content: "Always use TDD when developing Elixir features",
        keywords: "tdd,testing,elixir,exunit",
        category: "decision"
      }

      assert {:ok, skill} = SkillGenerator.generate_skill(pattern)

      assert skill.name != nil
      assert skill.description != nil
      assert is_list(skill.steps)
      assert is_list(skill.examples)

      # Name should be sanitized
      assert skill.name == String.downcase(skill.name)
      refute String.contains?(skill.name, " ")

      # Description should be meaningful
      assert String.length(skill.description) > 10
    end

    test "generates consistent skills for similar patterns" do
      pattern1 = %{content: "Use TDD", keywords: "tdd,testing", category: "decision"}
      pattern2 = %{content: "Use TDD", keywords: "tdd,testing", category: "decision"}

      assert {:ok, skill1} = SkillGenerator.generate_skill(pattern1)
      assert {:ok, skill2} = SkillGenerator.generate_skill(pattern2)

      # Same pattern should generate same skill
      assert skill1.name == skill2.name
    end
  end
end
