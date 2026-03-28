defmodule OptimalSystemAgent.SDKFacadeTest do
  @moduledoc """
  Tests for the SDK facade module.

  Tests pure functions and struct construction from OptimalSystemAgent.SDK
  and its nested submodules (Config, Message, Permission, Tier, Session, etc.).
  Does NOT start GenServers — tests stubs and no-op paths only.
  """
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # SDK.Config struct
  # ---------------------------------------------------------------------------

  describe "SDK.Config" do
    test "has correct default values" do
      config = %OptimalSystemAgent.SDK.Config{}

      assert config.provider == :ollama
      assert config.model == nil
      assert config.permission == :accept_edits
      assert config.http_port == 9089
      assert config.session_id == nil
    end

    test "accepts custom values" do
      config = %OptimalSystemAgent.SDK.Config{
        provider: :anthropic,
        model: "claude-3-opus",
        permission: :plan_only,
        http_port: 3000,
        session_id: "my-session"
      }

      assert config.provider == :anthropic
      assert config.model == "claude-3-opus"
      assert config.permission == :plan_only
      assert config.http_port == 3000
      assert config.session_id == "my-session"
    end
  end

  # ---------------------------------------------------------------------------
  # SDK.Message struct
  # ---------------------------------------------------------------------------

  describe "SDK.Message" do
    test "new/2 creates a message with defaults" do
      msg = OptimalSystemAgent.SDK.Message.new(:user, "hello")

      assert msg.role == :user
      assert msg.content == "hello"
      assert msg.tool_calls == []
      assert msg.tool_call_id == nil
      assert msg.metadata == %{}
    end

    test "new/3 accepts options" do
      msg =
        OptimalSystemAgent.SDK.Message.new(:assistant, "response",
          tool_calls: [%{id: "tc1", name: "file_read"}],
          tool_call_id: "tc1",
          metadata: %{tokens: 42}
        )

      assert msg.role == :assistant
      assert msg.content == "response"
      assert length(msg.tool_calls) == 1
      assert msg.tool_call_id == "tc1"
      assert msg.metadata == %{tokens: 42}
    end

    test "supports all role types" do
      for role <- [:user, :assistant, :system, :tool] do
        msg = OptimalSystemAgent.SDK.Message.new(role, "test")
        assert msg.role == role
      end
    end

    test "default struct is valid" do
      msg = %OptimalSystemAgent.SDK.Message{}
      assert msg.role == :user
      assert msg.content == ""
    end
  end

  # ---------------------------------------------------------------------------
  # SDK.Permission
  # ---------------------------------------------------------------------------

  describe "SDK.Permission.build_hook/1" do
    test ":read_only profile allows only safe tools" do
      hook = OptimalSystemAgent.SDK.Permission.build_hook(:read_only)

      assert hook.("file_read", %{}) == :allow
      assert hook.("dir_list", %{}) == :allow
      assert hook.("glob", %{}) == :allow
      assert hook.("shell_execute_read", %{}) == :allow
    end

    test ":read_only profile blocks dangerous tools" do
      hook = OptimalSystemAgent.SDK.Permission.build_hook(:read_only)

      assert {:deny, reason} = hook.("file_write", %{})
      assert is_binary(reason)
      assert String.contains?(reason, "file_write")
      assert String.contains?(reason, "read_only")

      assert {:deny, _} = hook.("shell_execute", %{})
      assert {:deny, _} = hook.("delegate", %{})
    end

    test ":plan_only profile allows everything" do
      hook = OptimalSystemAgent.SDK.Permission.build_hook(:plan_only)

      assert hook.("file_write", %{}) == :allow
      assert hook.("shell_execute", %{}) == :allow
      assert hook.("delegate", %{}) == :allow
    end

    test "default profile allows everything" do
      hook = OptimalSystemAgent.SDK.Permission.build_hook(:custom)

      assert hook.("file_write", %{}) == :allow
      assert hook.("anything", %{}) == :allow
    end

    test ":accept_edits profile allows everything" do
      hook = OptimalSystemAgent.SDK.Permission.build_hook(:accept_edits)

      assert hook.("file_write", %{}) == :allow
    end
  end

  # ---------------------------------------------------------------------------
  # SDK.Tier pure functions
  # ---------------------------------------------------------------------------

  describe "SDK.Tier" do
    test "tier_for_complexity/1 maps correctly" do
      assert OptimalSystemAgent.SDK.Tier.tier_for_complexity(1) == :fast
      assert OptimalSystemAgent.SDK.Tier.tier_for_complexity(2) == :fast
      assert OptimalSystemAgent.SDK.Tier.tier_for_complexity(3) == :fast
      assert OptimalSystemAgent.SDK.Tier.tier_for_complexity(4) == :balanced
      assert OptimalSystemAgent.SDK.Tier.tier_for_complexity(5) == :balanced
      assert OptimalSystemAgent.SDK.Tier.tier_for_complexity(6) == :balanced
      assert OptimalSystemAgent.SDK.Tier.tier_for_complexity(7) == :powerful
      assert OptimalSystemAgent.SDK.Tier.tier_for_complexity(10) == :powerful
    end

    test "supported_providers/0 returns known providers" do
      providers = OptimalSystemAgent.SDK.Tier.supported_providers()

      assert :ollama in providers
      assert :anthropic in providers
      assert :openai in providers
      assert :gemini in providers
    end

    test "max_response_tokens/1 returns correct limits" do
      assert OptimalSystemAgent.SDK.Tier.max_response_tokens(:fast) == 4096
      assert OptimalSystemAgent.SDK.Tier.max_response_tokens(:balanced) == 8192
      assert OptimalSystemAgent.SDK.Tier.max_response_tokens(:powerful) == 16384
      assert OptimalSystemAgent.SDK.Tier.max_response_tokens(:unknown) == 16384
    end

    test "temperature/1 returns correct values" do
      assert OptimalSystemAgent.SDK.Tier.temperature(:fast) == 0.3
      assert OptimalSystemAgent.SDK.Tier.temperature(:balanced) == 0.5
      assert OptimalSystemAgent.SDK.Tier.temperature(:powerful) == 0.7
      assert OptimalSystemAgent.SDK.Tier.temperature(:custom) == 0.7
    end

    test "max_agents/1 returns correct limits" do
      assert OptimalSystemAgent.SDK.Tier.max_agents(:fast) == 1
      assert OptimalSystemAgent.SDK.Tier.max_agents(:balanced) == 3
      assert OptimalSystemAgent.SDK.Tier.max_agents(:powerful) == 8
    end

    test "max_iterations/1 returns correct limits" do
      assert OptimalSystemAgent.SDK.Tier.max_iterations(:fast) == 5
      assert OptimalSystemAgent.SDK.Tier.max_iterations(:balanced) == 15
      assert OptimalSystemAgent.SDK.Tier.max_iterations(:powerful) == 30
    end

    test "tier_info/1 returns a complete info map" do
      info = OptimalSystemAgent.SDK.Tier.tier_info(:fast)

      assert info.tier == :fast
      assert is_map(info.budget)
      assert info.temperature == 0.3
      assert info.max_iterations == 5
      assert info.max_agents == 1
    end
  end

  # ---------------------------------------------------------------------------
  # SDK.Session pure functions (no-op / stub paths)
  # ---------------------------------------------------------------------------

  describe "SDK.Session" do
    test "close/1 returns :ok" do
      assert OptimalSystemAgent.SDK.Session.close("any-id") == :ok
    end

    test "get_messages/1 returns empty list" do
      assert OptimalSystemAgent.SDK.Session.get_messages("any-id") == []
    end

    test "session_stats/1 returns zeroed stats" do
      stats = OptimalSystemAgent.SDK.Memory.session_stats("session-xyz")
      assert stats.session_id == "session-xyz"
      assert stats.messages == 0
      assert stats.tokens == 0
    end
  end

  # ---------------------------------------------------------------------------
  # SDK.Tool stubs
  # ---------------------------------------------------------------------------

  describe "SDK.Tool" do
    test "define/4 returns :ok" do
      assert OptimalSystemAgent.SDK.Tool.define("my_tool", "desc", %{}, fn _ -> {:ok, 1} end) == :ok
    end

    test "undefine/1 returns :ok" do
      assert OptimalSystemAgent.SDK.Tool.undefine("my_tool") == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # SDK.Agent stubs
  # ---------------------------------------------------------------------------

  describe "SDK.Agent" do
    test "define/2 returns :ok" do
      assert OptimalSystemAgent.SDK.Agent.define("my_agent", %{role: "helper"}) == :ok
    end

    test "undefine/1 returns :ok" do
      assert OptimalSystemAgent.SDK.Agent.undefine("my_agent") == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # SDK.Command stubs
  # ---------------------------------------------------------------------------

  describe "SDK.Command" do
    test "execute/2 returns stub response" do
      assert {:ok, msg} = OptimalSystemAgent.SDK.Command.execute("ls")
      assert String.contains?(msg, "not yet available")
    end

    test "list/0 returns empty list" do
      assert OptimalSystemAgent.SDK.Command.list() == []
    end

    test "register/3 returns :ok" do
      assert OptimalSystemAgent.SDK.Command.register("cmd", "desc", "tpl") == :ok
    end
  end
end
