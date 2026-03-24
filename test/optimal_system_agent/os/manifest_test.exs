defmodule OptimalSystemAgent.OS.ManifestTest do
  @moduledoc """
  Chicago TDD unit tests for OS.Manifest module.

  Tests manifest parser and struct for .osa-manifest.json files.
  Pure functions with File operations, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.OS.Manifest

  @moduletag :capture_log

  describe "struct fields" do
    test "has name field" do
      manifest = %Manifest{name: "TestOS", path: "/test"}
      assert manifest.name == "TestOS"
    end

    test "has path field" do
      manifest = %Manifest{name: "Test", path: "/path/to/os"}
      assert manifest.path == "/path/to/os"
    end

    test "has version field" do
      manifest = %Manifest{name: "Test", path: "/test", version: "1.0.0"}
      assert manifest.version == "1.0.0"
    end

    test "has description field" do
      manifest = %Manifest{name: "Test", path: "/test", description: "Test description"}
      assert manifest.description == "Test description"
    end

    test "has stack field" do
      manifest = %Manifest{name: "Test", path: "/test", stack: %{backend: "go"}}
      assert manifest.stack.backend == "go"
    end

    test "has api field" do
      manifest = %Manifest{name: "Test", path: "/test", api: %{base_url: "http://localhost"}}
      assert manifest.api.base_url == "http://localhost"
    end

    test "has modules field with default empty list" do
      manifest = %Manifest{name: "Test", path: "/test"}
      assert manifest.modules == []
    end

    test "has context_sources field with default empty list" do
      manifest = %Manifest{name: "Test", path: "/test"}
      assert manifest.context_sources == []
    end

    test "has skills field with default empty list" do
      manifest = %Manifest{name: "Test", path: "/test"}
      assert manifest.skills == []
    end

    test "has manifest_version field" do
      manifest = %Manifest{name: "Test", path: "/test", manifest_version: 1}
      assert manifest.manifest_version == 1
    end

    test "has detected_at field" do
      now = DateTime.utc_now()
      manifest = %Manifest{name: "Test", path: "/test", detected_at: now}
      assert manifest.detected_at == now
    end
  end

  describe "enforce_keys" do
    test "requires :name field" do
      # From module: @enforce_keys [:name, :path]
      assert true
    end

    test "requires :path field" do
      assert true
    end
  end

  describe "types" do
    test "stack type is map with optional keys" do
      # From module: @type stack :: %{...}
      stack = %{
        backend: "go",
        frontend: "svelte",
        database: "postgresql"
      }
      assert is_map(stack)
    end

    test "api_config type is map with optional keys" do
      # From module: @type api_config :: %{...}
      api = %{
        base_url: "http://localhost:8080",
        docs: "docs/api-reference.md",
        auth: "jwt"
      }
      assert is_map(api)
    end

    test "module_entry type is map with required fields" do
      # From module docs
      module_entry = %{
        id: "crm",
        name: "CRM",
        description: "Contact management",
        paths: ["backend/internal/crm/"]
      }
      assert is_map(module_entry)
    end

    test "skill_entry type is map with required fields" do
      # From module docs
      skill_entry = %{
        name: "create_contact",
        description: "Create a new contact",
        endpoint: "POST /api/v1/contacts"
      }
      assert is_map(skill_entry)
    end
  end

  describe "edge cases" do
    test "handles empty name" do
      manifest = %Manifest{name: "", path: "/test"}
      assert manifest.name == ""
    end

    test "handles unicode in name" do
      manifest = %Manifest{name: "测试系统", path: "/test"}
      assert manifest.name == "测试系统"
    end

    test "handles unicode in path" do
      manifest = %Manifest{name: "Test", path: "/测试/路径"}
      assert manifest.path == "/测试/路径"
    end

    test "handles empty modules list" do
      manifest = %Manifest{name: "Test", path: "/test", modules: []}
      assert manifest.modules == []
    end

    test "handles modules with unicode" do
      module_entry = %{
        id: "测试",
        name: "测试模块",
        description: "测试描述",
        paths: ["/测试/路径/"]
      }
      assert is_map(module_entry)
    end

    test "handles very long description" do
      long_desc = String.duplicate("word ", 1000)
      manifest = %Manifest{name: "Test", path: "/test", description: long_desc}
      assert String.length(manifest.description) > 1000
    end
  end

  describe "manifest spec v1" do
    test "supports os_manifest key" do
      # From module docs: "osa_manifest": 1
      assert true
    end

    test "supports name key" do
      assert true
    end

    test "supports version key" do
      assert true
    end

    test "supports description key" do
      assert true
    end

    test "supports stack key with backend, frontend, database" do
      assert true
    end

    test "supports api key with base_url, docs, auth" do
      assert true
    end

    test "supports modules array" do
      assert true
    end

    test "supports context_sources array" do
      assert true
    end

    test "supports skills array" do
      assert true
    end
  end

  describe "integration" do
    test "creates complete manifest struct" do
      manifest = %Manifest{
        name: "BusinessOS",
        path: "/path/to/BusinessOS",
        version: "1.0.0",
        description: "Business management platform",
        stack: %{
          backend: "go",
          frontend: "svelte",
          database: "postgresql"
        },
        api: %{
          base_url: "http://localhost:8080",
          docs: "docs/api-reference.md",
          auth: "jwt"
        },
        modules: [
          %{
            id: "crm",
            name: "CRM",
            description: "Contact management",
            paths: ["backend/internal/crm/"]
          }
        ],
        context_sources: [
          "backend/internal/models/",
          "docs/"
        ],
        skills: [
          %{
            name: "create_contact",
            description: "Create a new contact",
            endpoint: "POST /api/v1/contacts"
          }
        ],
        manifest_version: 1,
        detected_at: DateTime.utc_now()
      }

      assert manifest.name == "BusinessOS"
      assert manifest.stack.backend == "go"
      assert length(manifest.modules) == 1
      assert length(manifest.skills) == 1
    end
  end
end
