# WS8: Multi-Transport Resilience — Build Guide

> **Agent:** CONFIG-RESILIENCE (Agent-H) — combined with WS7
> **Priority:** P3 — Depends on all previous workstreams
> **Scope:** Frontend-heavy

---

## Objective

Implement ClawX's graceful degradation pattern. The desktop app should work with reduced functionality when the backend is unavailable, with automatic reconnection and sync-on-reconnect.

---

## What Already Exists

### Connection Handling
- **Store:** `desktop/src/lib/stores/connection.svelte.ts` — Backend connectivity status
- **API Client:** `desktop/src/lib/api/client.ts` — HTTP API client
- **SSE:** `desktop/src/lib/api/sse.ts` — SSE streaming
- Status banner shows "Backend offline" when unavailable

### What's Missing
1. **Transport fallback chain** — Single transport (HTTP), no fallback
2. **Offline data caching** — No local cache when backend down
3. **Sync-on-reconnect** — No queued operations replayed on reconnect
4. **Retry with backoff** — No exponential backoff on failed requests
5. **Request queue** — No queue for operations during offline period

---

## Build Plan

### Step 1: Enhanced API Client

Enhance `desktop/src/lib/api/client.ts`:

```typescript
// Transport priority chain (stolen from ClawX)
// 1. Tauri IPC commands (if available — for future native commands)
// 2. HTTP to localhost:9089 (primary)
// 3. Cached response (if HTTP fails and we have cached data)

class ResilientApiClient {
  private cache: Map<string, { data: unknown; timestamp: number }>;
  private offlineQueue: QueuedRequest[];
  private retryConfig: { maxRetries: 3; backoffMs: 1000; maxBackoff: 30000 };

  async get<T>(path: string, opts?: RequestOpts): Promise<T> {
    try {
      const result = await this.httpRequest('GET', path, opts);
      this.cache.set(path, { data: result, timestamp: Date.now() });
      return result;
    } catch (error) {
      // Fallback to cache
      const cached = this.cache.get(path);
      if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
        return cached.data as T;
      }
      throw error;
    }
  }

  async post<T>(path: string, body: unknown): Promise<T> {
    try {
      return await this.httpRequest('POST', path, { body });
    } catch (error) {
      // Queue for replay on reconnect
      this.offlineQueue.push({ method: 'POST', path, body, timestamp: Date.now() });
      throw error;
    }
  }
}
```

### Step 2: Exponential Backoff

```typescript
async function withRetry<T>(fn: () => Promise<T>, config: RetryConfig): Promise<T> {
  let lastError: Error;
  for (let attempt = 0; attempt < config.maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      const delay = Math.min(
        config.backoffMs * Math.pow(2, attempt),
        config.maxBackoff
      );
      await new Promise(r => setTimeout(r, delay));
    }
  }
  throw lastError;
}
```

### Step 3: Enhanced Connection Store

Enhance `desktop/src/lib/stores/connection.svelte.ts`:

```typescript
// States: connected → reconnecting → offline → connected
// Health check interval: 10s when connected, 5s when reconnecting
// Backoff: 1s → 2s → 4s → 8s → 16s → 30s (cap)
// On reconnect: flush offline queue, refresh all stores
```

Add:
- `offlineQueueSize` — Number of queued operations
- `lastConnectedAt` — When we last had connection
- `reconnectAttempts` — Current attempt count
- `syncOnReconnect()` — Flush queue + refresh stores

### Step 4: SSE Reconnection

Enhance `desktop/src/lib/api/sse.ts`:
- Auto-reconnect SSE on disconnect (with backoff)
- Track last event ID for resumption
- Emit store-level events for reconnection state changes

### Step 5: Offline Indicators

Add visual indicators throughout the app:
- Status bar at bottom: "Connected" | "Reconnecting (attempt 3)..." | "Offline (5 queued)"
- Stale data indicator on cached responses: "Last updated 2m ago"
- Queue flush progress on reconnect

### Step 6: Local Cache with Tauri Store

Use Tauri's store plugin for persistent offline cache:
- Cache key API responses to disk
- TTL per endpoint (signals: 5min, agents: 30min, settings: 1hr)
- Clear on manual refresh

### Territory (Agent-H — shared with WS7)
```
CAN MODIFY:
  desktop/src/lib/api/client.ts              # API client enhancement
  desktop/src/lib/api/sse.ts                 # SSE reconnection
  desktop/src/lib/stores/connection.svelte.ts # Connection store
  desktop/src/lib/components/layout/         # Status indicators

CANNOT MODIFY:
  lib/                                        # Backend
  desktop/src/lib/components/signals/        # WS1 territory
  desktop/src/lib/components/tasks/          # WS2/WS5 territory
```

---

## Verification

```bash
cd desktop && npm run check && npm run build
# Start app with backend running → verify "Connected"
# Kill backend → verify "Reconnecting..." then "Offline"
# Navigate to pages → verify cached data shows with "stale" indicator
# Restart backend → verify auto-reconnect + queue flush
# Verify no data loss during offline period
```

---

## Stolen Patterns Applied

| From | Pattern | How We Apply It |
|------|---------|----------------|
| ClawX | IPC → WS → HTTP fallback | HTTP → Cache fallback chain |
| ClawX | Graceful degradation | App works offline with cached data |
| ClawX | Exponential backoff | Reconnection with 1s→30s backoff |
| ClawX | Debounced restarts | Connection store debounces reconnect |
| ClawX | Error normalization | Standard error codes + user-friendly messages |
