# Telegram Features Reference — OpenClaw vs OSA

> What OpenClaw builds across 81 files for Telegram.
> What we have, what we need, priority order.

## OpenClaw's Telegram Feature Set (81 files)

### Core (must-have for v1)
| Feature | Files | What It Does | OSA Status |
|---------|-------|-------------|------------|
| **Long-polling** | `polling-session.ts`, `bot-updates.ts` | GET /getUpdates with offset tracking | **BUILT** ✓ |
| **Send messages** | `send.ts`, `delivery.send.ts` | POST /sendMessage with HTML formatting | **BUILT** ✓ (Markdown) |
| **Message routing** | `bot-message.ts`, `bot-message-dispatch.ts`, `conversation-route.ts` | Route inbound → agent session | **BUILT** ✓ |
| **Markdown → HTML** | `format.ts` | Convert agent's Markdown to Telegram HTML (entities) | **MISSING** — we send raw Markdown |
| **Token validation** | `probe.ts`, `token.ts` | Validate bot token via getMe before starting | **MISSING** — we start blindly |
| **Error handling** | `network-errors.ts`, `network-config.ts` | Classify errors, retry transient, fail permanent | **PARTIAL** — basic backoff only |

### Streaming (high-value UX)
| Feature | Files | What It Does | OSA Status |
|---------|-------|-------------|------------|
| **Live streaming** | `draft-stream.ts`, `draft-chunking.ts` | Edit message in real-time as agent generates tokens (like ChatGPT) | **MISSING** |
| **Typing indicator** | `runtime-telegram-typing.ts`, `sendchataction-401-backoff.ts` | Show "typing..." while agent thinks | **MISSING** |
| **Chunked delivery** | `lane-delivery.ts`, `lane-delivery-text-deliverer.ts` | Split long responses into multiple messages | **MISSING** |

### Security (important)
| Feature | Files | What It Does | OSA Status |
|---------|-------|-------------|------------|
| **Allowlist** | `allow-from.ts`, `dm-access.ts` | Only respond to specific phone numbers/user IDs | **MISSING** |
| **Group access** | `group-access.ts`, `group-config-helpers.ts` | Control which groups the bot responds in | **MISSING** |
| **Audit** | `audit.ts`, `audit-membership-runtime.ts` | Log who talks to the bot | **MISSING** |

### Groups & Threads
| Feature | Files | What It Does | OSA Status |
|---------|-------|-------------|------------|
| **Group mentions** | `bot-handlers.ts` | Only respond when @mentioned in groups | **MISSING** |
| **Thread support** | `thread-bindings.ts`, `reply-threading.ts` | Reply in correct thread, bind sessions to threads | **MISSING** |
| **Forum topics** | `forum-service-message.ts` | Handle Telegram forum (topic) groups | **MISSING** |

### Rich Media
| Feature | Files | What It Does | OSA Status |
|---------|-------|-------------|------------|
| **Media sending** | `delivery.resolve-media.ts`, `caption.ts` | Send images, files, voice with captions | **MISSING** |
| **Voice messages** | `voice.ts` | Receive/send voice messages | **MISSING** |
| **Stickers** | `sticker-cache.ts` | Handle sticker messages | **MISSING** |
| **Inline buttons** | `inline-buttons.ts`, `button-types.ts`, `model-buttons.ts` | Interactive buttons in messages | **MISSING** |

### Advanced
| Feature | Files | What It Does | OSA Status |
|---------|-------|-------------|------------|
| **Tool approvals** | `exec-approvals.ts`, `exec-approvals-handler.ts`, `approval-buttons.ts` | Show approve/deny buttons when agent wants to run a tool | **MISSING** |
| **Native commands** | `bot-native-commands.ts`, `bot-native-command-menu.ts` | /help, /new, /model slash commands | **MISSING** |
| **Multi-account** | `accounts.ts`, `account-inspect.ts` | Multiple bot tokens (personal + work) | **MISSING** |
| **Webhook mode** | `webhook.ts` | Alternative to polling (for production/hosting) | **PARTIAL** — route exists but not connected |
| **Proxy support** | `proxy.ts`, `fetch.ts` | HTTP proxy for restricted networks | **MISSING** |
| **Message cache** | `sent-message-cache.ts` | Track sent messages for editing/deleting | **MISSING** |
| **Target writeback** | `target-writeback.ts`, `targets.ts` | Remember which chat IDs to deliver to | **MISSING** |

---

## Priority Build Order for OSA

### Phase 1: Make It Work (what we have + 3 fixes)
1. ✅ Long-polling + message routing + send (DONE)
2. **Token validation** — call `getMe` on init, verify token works before starting poll
3. **Typing indicator** — send `chatAction: typing` while agent processes
4. **Markdown → HTML** — convert Markdown to Telegram HTML entities (Telegram displays HTML better than Markdown)

### Phase 2: Make It Good (streaming + security)
5. **Live streaming** — edit message in real-time as tokens arrive (huge UX win)
6. **Allowlist** — only respond to configured user IDs / phone numbers
7. **Long message chunking** — split responses > 4096 chars into multiple messages
8. **Group @mention** — only respond when mentioned in groups

### Phase 3: Make It Great (rich features)
9. **Tool approval buttons** — inline keyboard for approve/deny
10. **Native slash commands** — /help, /new, /model, /status
11. **Thread support** — reply in threads, bind sessions to topics
12. **Media support** — send images, files from agent responses

---

## What We Need to Add to Our Telegram Adapter NOW

### 1. Token Validation (in init)

```elixir
# In init/1, after getting the token:
case validate_token(token) do
  {:ok, bot_info} ->
    Logger.info("[Telegram] Bot connected: @#{bot_info["username"]}")
    # continue with polling...
  {:error, reason} ->
    Logger.error("[Telegram] Invalid token: #{reason}")
    :ignore
end

defp validate_token(token) do
  case Req.get("https://api.telegram.org/bot#{token}/getMe") do
    {:ok, %{status: 200, body: %{"ok" => true, "result" => info}}} ->
      {:ok, info}
    {:ok, %{status: 401}} ->
      {:error, "unauthorized — token is invalid"}
    {:ok, %{body: %{"description" => desc}}} ->
      {:error, desc}
    {:error, reason} ->
      {:error, inspect(reason)}
  end
end
```

### 2. Typing Indicator

```elixir
# Before processing each message, send typing action:
defp send_typing(token, chat_id) do
  Req.post("https://api.telegram.org/bot#{token}/sendChatAction",
    json: %{chat_id: chat_id, action: "typing"})
end

# In dispatch_update, before calling Loop.process_message:
send_typing(state.token, chat_id)
```

### 3. Markdown → HTML Conversion

Telegram's HTML mode is more reliable than Markdown. Convert:
- `**bold**` → `<b>bold</b>`
- `*italic*` → `<i>italic</i>`
- `` `code` `` → `<code>code</code>`
- ` ```lang\nblock\n``` ` → `<pre><code class="language-lang">block</code></pre>`
- `[text](url)` → `<a href="url">text</a>`

```elixir
defp markdown_to_html(text) do
  text
  |> String.replace(~r/\*\*(.+?)\*\*/, "<b>\\1</b>")
  |> String.replace(~r/\*(.+?)\*/, "<i>\\1</i>")
  |> String.replace(~r/`([^`]+)`/, "<code>\\1</code>")
  |> String.replace(~r/```(\w*)\n([\s\S]*?)```/, "<pre><code>\\2</code></pre>")
  |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, "<a href=\"\\2\">\\1</a>")
end

# In send_message, use parse_mode: "HTML" instead of "Markdown"
```

### 4. Message Length Chunking

Telegram max is 4096 chars per message. Split long responses:

```elixir
@max_message_length 4096

defp chunk_message(text) when byte_size(text) <= @max_message_length, do: [text]
defp chunk_message(text) do
  text
  |> String.codepoints()
  |> Enum.chunk_every(@max_message_length)
  |> Enum.map(&Enum.join/1)
end

# In send_message, iterate over chunks
```

### 5. Live Streaming (Phase 2 — biggest UX feature)

The idea: instead of waiting for the full response, send a message immediately
and edit it every ~500ms as new tokens arrive.

```
Agent starts generating → send "..." message → get message_id
Every 500ms: editMessageText(message_id, current_text + "▌")
Agent finishes: editMessageText(message_id, final_text)
```

This requires hooking into the SSE `streaming_token` events from the agent loop
and accumulating tokens, then periodically editing the Telegram message.
OpenClaw calls this "draft streaming" — the message is a "draft" that gets
progressively edited until the agent finishes.

---

## Configuration Needed

For the Telegram adapter to work properly, these env vars should be supported:

```bash
# Required
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHI...

# Optional (future)
TELEGRAM_ALLOW_FROM=123456789,987654321    # user IDs or phone numbers
TELEGRAM_WEBHOOK_URL=https://your-server.com/channels/telegram/webhook
TELEGRAM_WEBHOOK_SECRET=random-secret-for-hmac
TELEGRAM_GROUP_POLICY=mention              # mention | open | disabled
```

The onboarding wizard currently collects `TELEGRAM_BOT_TOKEN`. The other
settings can be added later via /setup or by editing ~/.osa/.env.
