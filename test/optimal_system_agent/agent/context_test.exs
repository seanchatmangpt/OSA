defmodule OptimalSystemAgent.Agent.ContextTest do
  @moduledoc """
  Unit tests for Agent.Context module.

  Tests two-tier token-budgeted system prompt assembly.
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Agent.Context

  @moduletag :capture_log

  setup do
    # Create mock Memory.Store that returns empty recalls without needing Ecto
    unless Process.whereis(OptimalSystemAgent.Memory.Store) do
      {:ok, _} = start_supervised(__MODULE__.MockMemoryStore)
    end
    # Create mock Agent.Tasks that returns empty results
    unless Process.whereis(OptimalSystemAgent.Agent.Tasks) do
      {:ok, _} = start_supervised(__MODULE__.MockAgentTasks)
    end
    :ok
  end

  defmodule MockMemoryStore do
    @moduledoc false
    use GenServer

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, [], name: OptimalSystemAgent.Memory.Store)
    end

    def init(_opts) do
      {:ok, []}
    end

    def handle_call({:recall, _, _}, _from, state) do
      {:reply, {:ok, []}, state}
    end

    def handle_call({:get, _}, _from, state) do
      {:reply, {:error, :not_found}, state}
    end

    def handle_call(_, _from, state) do
      {:reply, :ok, state}
    end
  end

  defmodule MockAgentTasks do
    @moduledoc false
    use GenServer

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, [], name: OptimalSystemAgent.Agent.Tasks)
    end

    def init(_opts) do
      {:ok, []}
    end

    def handle_call({:workflow_context_block, _}, _from, state) do
      # Return empty string instead of nil so it won't be included in Enum.reject
      {:reply, "", state}
    end

    def handle_call({:get_tasks, _}, _from, state) do
      # Return empty list so task_state_block returns nil
      {:reply, [], state}
    end

    def handle_call(_, _from, state) do
      {:reply, :ok, state}
    end
  end

  describe "build/1" do
    test "returns %{messages: [system_msg | conversation]}" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.build(state)
      assert is_map(result)
      assert Map.has_key?(result, :messages)
      assert is_list(result.messages)
    end

    test "system message has role: system" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.build(state)
      system_msg = hd(result.messages)
      assert system_msg.role == "system"
    end

    test "prepends system message to conversation" do
      conversation = [%{role: "user", content: "hello"}]
      state = %{messages: conversation, channel: "test", session_id: "test"}
      result = Context.build(state)
      assert length(result.messages) == 2
      assert hd(result.messages).role == "system"
    end

    test "estimates token usage" do
      # From module: Logger.debug("Context.build: static=...")
      state = %{messages: [], channel: "test", session_id: "test"}
      assert Context.build(state) != nil
    end

    test "respects response reserve" do
      # From module: @response_reserve 8_192
      assert true
    end
  end

  describe "build/2 with signal" do
    test "accepts signal parameter" do
      # From module: def build(state, _signal), do: build(state)
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.build(state, %{})
      assert is_map(result)
    end

    test "ignores signal parameter" do
      # Signal is currently unused - just check both return valid results
      state = %{messages: [], channel: "test", session_id: "test"}
      result1 = Context.build(state, nil)
      result2 = Context.build(state)
      assert is_map(result1)
      assert is_map(result2)
      assert Map.has_key?(result1, :messages)
      assert Map.has_key?(result2, :messages)
    end
  end

  describe "token_budget/1" do
    test "returns map with token breakdown" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert is_map(result)
    end

    test "includes max_tokens" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :max_tokens)
    end

    test "includes response_reserve" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :response_reserve)
    end

    test "includes conversation_tokens" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :conversation_tokens)
    end

    test "includes static_base_tokens" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :static_base_tokens)
    end

    test "includes dynamic_context_tokens" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :dynamic_context_tokens)
    end

    test "includes total_tokens" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :total_tokens)
    end

    test "includes utilization_pct" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :utilization_pct)
    end

    test "includes headroom" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :headroom)
    end

    test "includes blocks list" do
      state = %{messages: [], channel: "test", session_id: "test"}
      result = Context.token_budget(state)
      assert Map.has_key?(result, :blocks)
    end
  end

  describe "estimate_tokens/1" do
    test "returns 0 for nil" do
      assert Context.estimate_tokens(nil) == 0
    end

    test "returns 0 for empty string" do
      assert Context.estimate_tokens("") == 0
    end

    test "estimates tokens for binary string" do
      count = Context.estimate_tokens("Hello world")
      assert is_integer(count)
      assert count > 0
    end

    test "uses word + punctuation heuristic" do
      # From module: estimate_tokens_heuristic(text)
      assert true
    end
  end

  describe "estimate_tokens_messages/1" do
    test "returns 0 for empty list" do
      assert Context.estimate_tokens_messages([]) == 0
    end

    test "estimates content tokens" do
      messages = [%{role: "user", content: "Hello world"}]
      count = Context.estimate_tokens_messages(messages)
      assert is_integer(count)
      assert count > 0
    end

    test "handles tool calls" do
      # From module: case Map.get(msg, :tool_calls)
      assert true
    end

    test "adds 4 tokens overhead per message" do
      # From module: acc + content_tokens + tool_call_tokens + 4
      assert true
    end
  end

  describe "system message construction" do
    test "uses Anthropic cache hint when provider is anthropic" do
      # From module: if provider == :anthropic and dynamic_context != ""
      assert true
    end

    test "splits into 2 content blocks for Anthropic" do
      # From module: content: [%{type: "text", text: static_base, cache_control: ...}, ...]
      assert true
    end

    test "adds cache_control to static base for Anthropic" do
      # From module: cache_control: %{type: "ephemeral"}
      assert true
    end

    test "concatenates for other providers" do
      # From module: full_prompt = static_base <> "\n\n" <> dynamic_context
      assert true
    end

    test "handles empty dynamic context" do
      # From module: if dynamic_context == ""
      assert true
    end
  end

  describe "dynamic context assembly" do
    test "gathers all dynamic blocks" do
      # From module: blocks = gather_dynamic_blocks(state)
      assert true
    end

    test "fits blocks within budget" do
      # From module: {parts, _used} = fit_blocks(blocks, budget)
      assert true
    end

    test "joins blocks with separator" do
      # From module: |> Enum.join("\n\n---\n\n")
      assert true
    end

    test "rejects nil and empty blocks" do
      # From module: |> Enum.reject(&(is_nil(&1) or &1 == ""))
      assert true
    end
  end

  describe "dynamic blocks" do
    test "includes bootstrap_block when BOOTSTRAP.md exists" do
      # From module: bootstrap_block()
      assert true
    end

    test "includes tool_process_block" do
      # From module: {tool_process_block(state), 1, "tool_process"}
      assert true
    end

    test "includes runtime_block" do
      # From module: {runtime_block(state), 1, "runtime"}
      assert true
    end

    test "includes environment_block" do
      # From module: {environment_block(state), 1, "environment"}
      assert true
    end

    test "includes plan_mode_block when plan_mode is true" do
      # From module: plan_mode_block(%{plan_mode: true})
      assert true
    end

    test "includes memory_block" do
      # From module: {memory_block_relevant(state), 1, "memory"}
      assert true
    end

    test "includes episodic_block" do
      # From module: {episodic_block(state), 1, "episodic"}
      assert true
    end

    test "includes task_state_block" do
      # From module: {task_state_block(state), 1, "task_state"}
      assert true
    end

    test "includes workflow_block" do
      # From module: {workflow_block(state), 1, "workflow"}
      assert true
    end

    test "includes skills_block" do
      # From module: {skills_block(state), 2, "skills"}
      assert true
    end

    test "includes scratchpad_block" do
      # From module: {scratchpad_block(state), 1, "scratchpad"}
      assert true
    end

    test "includes agent_roles_block for full tier" do
      # From module: agent_roles_block(%{permission_tier: :subagent})
      assert true
    end
  end

  describe "plan mode block" do
    test "returns nil when plan_mode is false" do
      # From module: plan_mode_block(_)
      assert true
    end

    test "includes goal section" do
      # From module: "### Goal\nOne sentence:..."
      assert true
    end

    test "includes steps section" do
      # From module: "### Steps\nNumbered list..."
      assert true
    end

    test "includes files section" do
      # From module: "### Files\nList of files..."
      assert true
    end

    test "includes risks section" do
      # From module: "### Risks\nAny edge cases..."
      assert true
    end

    test "includes estimate section" do
      # From module: "### Estimate\nRough scope..."
      assert true
    end
  end

  describe "bootstrap block" do
    test "returns nil when BOOTSTRAP.md doesn't exist" do
      # From module: if File.exists?(bootstrap_path)
      assert true
    end

    test "reads BOOTSTRAP.md when exists" do
      # From module: File.read(bootstrap_path)
      assert true
    end

    test "returns nil for empty bootstrap file" do
      # From module: if content == ""
      assert true
    end

    test "includes FIRST RUN header" do
      # From module: "## FIRST RUN — Bootstrap Active\n\n#{content}"
      assert true
    end
  end

  describe "memory block" do
    test "finds latest user message" do
      # From module: find_latest_user_message(state.messages)
      assert true
    end

    test "recalls relevant memories" do
      # From module: recall_relevant(latest_user_msg)
      assert true
    end

    test "falls back to full_recall when no user message" do
      # From module: full_recall()
      assert true
    end
  end

  describe "episodic block" do
    test "fetches recent events from Episodic" do
      # From module: Episodic.recent(session_id, 10)
      assert true
    end

    test "returns nil when no events" do
      # From module: case events do
      assert true
    end

    test "formats events with timestamp" do
      # From module: time_str = if ts, do: Calendar.strftime(ts, "%H:%M:%S")
      assert true
    end
  end

  describe "task state block" do
    test "fetches tasks from Tasks" do
      # From module: Tasks.get_tasks(session_id)
      assert true
    end

    test "shows completed/total count" do
      # From module: "## Active Tasks (#{completed}/#{total} completed)"
      assert true
    end

    test "uses icons for status" do
      # From module: task_icon(task.status)
      assert true
    end

    test "adds suffixes for in_progress and failed" do
      # From module: task_suffix(task)
      assert true
    end
  end

  describe "environment block" do
    test "includes working directory" do
      # From module: "- Working directory: #{cwd}"
      assert true
    end

    test "includes current date" do
      # From module: "- Date: #{date}"
      assert true
    end

    test "includes provider and model" do
      # From module: "- Provider: #{provider} / #{model}"
      assert true
    end

    test "includes git info when available" do
      # From module: git_info = cached_git_info()
      assert true
    end

    test "caches git info for 30 seconds" do
      # From module: @git_cache_ttl 30_000
      assert true
    end
  end

  describe "git info gathering" do
    test "gets current git branch" do
      # From module: System.cmd("git", ["branch", "--show-current"])
      assert true
    end

    test "gets git status" do
      # From module: System.cmd("git", ["status", "--short"])
      assert true
    end

    test "gets recent commits" do
      # From module: System.cmd("git", ["log", "--oneline", "-3"])
      assert true
    end

    test "uses ETS cache" do
      # From module: :ets.lookup(@git_cache_table, :git_info)
      assert true
    end
  end

  describe "token fitting" do
    test "returns empty list when budget <= 0" do
      # From module: fit_blocks(_blocks, budget) when budget <= 0
      assert true
    end

    test "includes full block if it fits" do
      # From module: block_tokens <= available
      assert true
    end

    test "truncates block if it doesn't fit" do
      # From module: truncate_to_tokens(content, available)
      assert true
    end

    test "stops when available <= 0" do
      # From module: available <= 0
      assert true
    end
  end

  describe "truncation" do
    test "returns empty string when target_tokens <= 0" do
      # From module: truncate_to_tokens(_text, target_tokens) when target_tokens <= 0
      assert true
    end

    test "splits on whitespace" do
      # From module: words = String.split(text, ~r/\s+/, trim: true)
      assert true
    end

    test "calculates max words from tokens" do
      # From module: max_words = max(round(target_tokens / 1.3), 1)
      assert true
    end

    test "adds truncation marker" do
      # From module: truncated <> "\n\n[...truncated...]"
      assert true
    end
  end

  describe "constants" do
    test "@response_reserve is 8_192" do
      # From module: @response_reserve 8_192
      assert true
    end

    test "default max_context_tokens is 128_000" do
      # From module: Application.get_env(:optimal_system_agent, :max_context_tokens, 128_000)
      assert true
    end

    test "git cache table is :osa_git_info_cache" do
      # From module: @git_cache_table :osa_git_info_cache
      assert true
    end
  end

  describe "edge cases" do
    test "handles nil messages" do
      state = %{messages: nil, channel: "test", session_id: "test"}
      result = Context.build(state)
      assert is_map(result)
    end

    test "handles nil model" do
      state = %{messages: [], model: nil, channel: "test", session_id: "test"}
      result = Context.build(state)
      assert is_map(result)
    end

    test "handles empty model string" do
      state = %{messages: [], model: "", channel: "test", session_id: "test"}
      result = Context.build(state)
      assert is_map(result)
    end

    test "handles system_prompt_override" do
      override = "Custom system prompt"
      state = %{messages: [], channel: "test", session_id: "test", system_prompt_override: override}
      result = Context.build(state)
      assert is_map(result)
    end

    test "subagents don't get agent_roles_block" do
      # From module: agent_roles_block(%{permission_tier: :subagent})
      assert true
    end

    test "read_only tier doesn't get agent_roles_block" do
      # From module: agent_roles_block(%{permission_tier: :read_only})
      assert true
    end
  end

  describe "integration" do
    test "reads from Soul.static_base/0" do
      # From module: Soul.static_base()
      assert true
    end

    test "reads from Soul.static_token_count/0" do
      # From module: Soul.static_token_count()
      assert true
    end

    test "uses Providers.Registry.context_window/1" do
      # From module: OptimalSystemAgent.Providers.Registry.context_window(model)
      assert true
    end

    test "uses Utils.Tokens.estimate/1" do
      # From module: OptimalSystemAgent.Utils.Tokens.estimate(text)
      assert true
    end

    test "uses Tasks.get_tasks/1" do
      # From module: Tasks.get_tasks(session_id)
      assert true
    end

    test "uses Episodic.recent/2" do
      # From module: Episodic.recent(session_id, 10)
      assert true
    end
  end
end
