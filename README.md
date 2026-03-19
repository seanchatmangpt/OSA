# OSAorigin

A stripped-to-core rebuild of [OSA](https://github.com/Miosa-osa/OSA) — same stack, bare foundation.

OSA accumulated features faster than it verified them. This repo inverts that approach: start from a working messaging layer and add one layer at a time, confirming each is properly wired before moving forward.

---

## What Is This

OSAorigin is a local AI agent runtime built on Elixir/OTP. It runs a ReAct loop (Reason → Act → Observe) using a local or cloud LLM, executes file and shell tools, and exposes itself over CLI and HTTP. A Tauri 2 + SvelteKit 5 desktop app connects over HTTP/SSE for visual testing.

The backend is intentionally minimal. Features stripped from the original OSA are listed below with the phase they belong to. Each phase will be added and verified before the next one starts.

---

## Current State (Phase 0 — Bare Messaging)

**What is in:**

- ReAct agent loop as a GenServer with bounded iterations (default: 20)
- Ollama provider — local (`localhost:11434`) and Ollama Cloud
- Core tools: `file_read`, `file_write`, `file_edit`, `dir_list`, `file_grep`, `file_glob`, `shell_execute`, `task_write`, `ask_user`
- CLI channel for terminal interaction
- HTTP channel (Bandit + Plug, port 8089) for desktop and API access
- Server-Sent Events (SSE) for streaming to the desktop
- Phoenix PubSub event bus (standalone, no Phoenix framework)
- SQLite3 persistence via Ecto
- System prompt loading from `~/.osa/` (IDENTITY.md, SOUL.md, SYSTEM.md)
- Signal classification (Mode + Weight only)
- Noise filter (short-circuits low-signal messages before the agent loop)
- Desktop GUI (Tauri 2 + SvelteKit 5) — kept intact for visual testing

**What is stripped (future phases):**

| Phase | Capability |
|-------|-----------|
| 1 | Memory system (`memory_save`, `memory_recall`, session search, episodic memory) |
| 2 | Advanced tools (`web_fetch`, `web_search`, git, GitHub, diff, `multi_file_edit`) |
| 3 | Full signal classification (5-tuple, genre routing, strategy selection) |
| 4 | Sub-agents and orchestrator |
| 5 | MCP protocol |
| 6 | Swarm patterns (parallel, pipeline, debate, review loop) |
| 7 | Channel adapters (Telegram, Discord, Slack, WhatsApp, etc.) |
| 8 | Sandbox (Docker isolation), Computer Use, browser control |
| 9 | Learning engine, conversation tracking, communication coach |
| 10 | Multi-tenant platform, fleet management, governance, treasury |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend runtime | Elixir 1.17+ / OTP 27+ |
| Desktop shell | Tauri 2 + SvelteKit 5 + Svelte 5 |
| Database | SQLite3 via Ecto (`~/.osa/osa.db`) |
| HTTP server | Bandit 1.6 + Plug |
| HTTP client | Req 0.5 |
| Event bus | Phoenix PubSub (standalone) |
| Terminal (desktop) | xterm.js |
| JSON | Jason |
| Schema validation | ex_json_schema |

---

## Quick Start

**Prerequisites:**

- Elixir 1.17+ and OTP 27+
- Ollama running locally (`ollama serve`) with at least one model pulled
- Node.js 20+ and Rust (for desktop only)

**Backend (CLI):**

```bash
mix deps.get
mix ecto.setup
mix chat
```

**Desktop:**

```bash
cd desktop
npm install
npm run tauri:dev
```

The desktop app connects to the backend HTTP channel on port 8089. Start the backend first.

---

## Configuration

Default provider is Ollama local at `localhost:11434`. The active model is set in `config/config.exs`:

```elixir
config :optimal_system_agent,
  default_provider: :ollama,
  ollama_url: "http://localhost:11434",
  ollama_model: "your-model-name"
```

Run `osagent setup` (release build only) for interactive configuration.

**Environment variables:**

| Variable | Purpose |
|----------|---------|
| `OLLAMA_API_KEY` | Ollama Cloud authentication |
| `ANTHROPIC_API_KEY` | Anthropic API (Phase 0: not yet wired in) |
| `OPENAI_API_KEY` | OpenAI-compatible endpoint (Phase 0: not yet wired in) |
| `OPENROUTER_API_KEY` | OpenRouter (Phase 0: not yet wired in) |
| `OSA_SANDBOX_ENABLED` | Enable Docker sandbox isolation (default: `false`) |

**User config directory:** `~/.osa/`

Place `IDENTITY.md`, `SOUL.md`, and `SYSTEM.md` in `~/.osa/` to customize the agent's system prompt.

---

## Project Structure

```
lib/
  optimal_system_agent/
    agent/          # ReAct loop, GenServer, provider clients
    channels/       # CLI and HTTP channel adapters
    tools/          # Core tool implementations
    store/          # Ecto repo, migrations, schemas
config/
  config.exs        # Main configuration
  dev.exs
  prod.exs
  test.exs
desktop/            # Tauri 2 + SvelteKit 5 app
priv/
  repo/migrations/  # Ecto migrations
```

---

## Running Tests

```bash
mix test
```

---

## Building a Release

```bash
mix release
./_build/prod/rel/osagent/bin/osagent
```

Subcommands: `chat` (default), `setup`, `serve`, `doctor`, `version`.

---

## Relation to OSA

This repository is a clean-room rebuild. The original OSA project lives at [github.com/Miosa-osa/OSA](https://github.com/Miosa-osa/OSA). OSAorigin shares the same stack and organization but starts from a verified foundation rather than inheriting accumulated complexity.

Design references:
- beamclaw's session/loop fault-tolerance pattern (Erlang gen_statem)
- Hermes Agent's self-improving skill system concept

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

Apache-2.0. See [LICENSE](LICENSE).

**Organization:** [miosa-osa](https://github.com/Miosa-osa)
