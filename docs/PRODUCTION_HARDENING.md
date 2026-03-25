# OSA Production Hardening Guide

> **Scope:** Configure OSA for cloud deployment with Prometheus monitoring, BEAM memory limits, and durable event queues.

---

## Overview

OSA production hardening provides three critical capabilities for enterprise deployments:

1. **Prometheus `/metrics` endpoint** — Observable, cloud-native metrics
2. **BEAM memory limit enforcement** — Prevent OOM crashes with configurable heap caps
3. **AMQP durable queue fallback** — Survive restarts with durable event queues

All features are **disabled by default** (MVP configuration). Enable via environment variables.

---

## Feature 1: Prometheus Metrics Endpoint

### Endpoint

```
GET /metrics (no auth required)
Content-Type: text/plain; version=0.0.4
```

### Format

OpenMetrics-compatible Prometheus text format:

```
# HELP osa_tool_executions_ms Tool execution duration in milliseconds
# TYPE osa_tool_executions_ms histogram
osa_tool_executions_ms_bucket{tool="grep_files",le="10"} 5
osa_tool_executions_ms_bucket{tool="grep_files",le="50"} 8
...
osa_tool_executions_ms_count{tool="grep_files"} 12
osa_tool_executions_ms_sum{tool="grep_files"} 2460

# HELP osa_provider_latency_ms Provider API call latency in milliseconds
# TYPE osa_provider_latency_ms histogram
...

# HELP osa_noise_filter_total Noise filter outcomes
# TYPE osa_noise_filter_total counter
osa_noise_filter_total{outcome="filtered"} 42
osa_noise_filter_total{outcome="clarify"} 15
osa_noise_filter_total{outcome="pass"} 143

# HELP osa_signal_weight_total Signal weight distribution
# TYPE osa_signal_weight_total counter
osa_signal_weight_total{bucket="0.0-0.2"} 10
osa_signal_weight_total{bucket="0.2-0.5"} 25
...
```

### Usage

**Prometheus scrape configuration:**

```yaml
scrape_configs:
  - job_name: osa
    static_configs:
      - targets: ['localhost:8089']
    metrics_path: '/metrics'
```

**Curl test:**

```bash
curl http://localhost:8089/metrics | head -20
```

### Metrics Exposed

| Metric | Type | Labels | Notes |
|--------|------|--------|-------|
| `osa_tool_executions_ms` | histogram | `tool` | Duration per tool execution |
| `osa_provider_latency_ms` | histogram | `provider` | Latency per LLM provider |
| `osa_noise_filter_total` | counter | `outcome` | Filtered/clarify/pass decisions |
| `osa_signal_weight_total` | counter | `bucket` | Distribution across weight buckets |
| `osa_noise_filter_rate_percent` | gauge | none | Percentage of filtered+clarify |

---

## Feature 2: BEAM Memory Limit Enforcement

### Configuration

**Environment Variables:**

```bash
BEAM_MAX_HEAP_SIZE=2000000000    # 2GB (default), in bytes
BEAM_MAX_HEAP_SIZE=4000000000    # 4GB
BEAM_MAX_HEAP_SIZE=0             # Disabled (unlimited)
```

### Behavior

- **Heap limit exceeded:** VM terminates gracefully with heap size exceeded error
- **Graceful shutdown:** Supervisor tree allows time for cleanup before kill
- **Monitoring:** Monitor `max_heap_size` via Prometheus or system observability

### Default

- **Development:** 2GB (allows large agent context windows)
- **Production (Docker):** Match container memory limit minus 512MB for system overhead
  - Container 4GB → `BEAM_MAX_HEAP_SIZE=3500000000`
  - Container 8GB → `BEAM_MAX_HEAP_SIZE=7500000000`

### Implementation

The limit is enforced in `config/runtime.exs`:

```elixir
:erlang.system_flag(:max_heap_size, max_heap_bytes)
```

Only applied if `config_env() != :test` (disabled in test to avoid flakiness).

### Docker Example

```dockerfile
FROM elixir:1.19 as runtime
ENV BEAM_MAX_HEAP_SIZE=3500000000
ENV MIX_ENV=prod
EXPOSE 8089
ENTRYPOINT ["mix", "osa.serve"]
```

### Monitoring

**Check current limit:**

```bash
iex> :erlang.system_info(:max_heap_size)
# Returns map with size, kill, error_logger flags in test
# Returns integer bytes in production
```

---

## Feature 3: AMQP Durable Queue Fallback

### Configuration

**Environment Variables:**

```bash
USE_AMQP_QUEUE=true                          # Enable (default: false)
AMQP_URL=amqp://user:password@localhost:5672 # RabbitMQ URL
AMQP_QUEUE_NAME=osa_events                   # Queue name (optional)
```

### Fallback Chain

```
Redis (fast, in-memory)
    ↓ [if unavailable]
AMQP (durable, survives restarts)
    ↓ [if unavailable]
Local ETS (ephemeral, in-memory)
```

### Queue Configuration

**Main queue:** `osa_events` (configurable)
- **Durable:** Yes (survives broker restart)
- **Auto-delete:** No
- **TTL:** 1 hour (`x-message-ttl: 3600000`)
- **DLQ:** `osa_events.dlq` (automatic)

**Dead Letter Queue:** `osa_events.dlq`
- Receives messages after 3 failed attempts
- No expiration (archived for analysis)

### API

**Publish event:**

```elixir
OptimalSystemAgent.Events.AMQPQueue.publish("orchestrate_complete", %{
  session_id: "sess_123",
  agent: "researcher",
  status: "complete"
})
# Returns :ok or {:error, reason}
```

**Check status:**

```elixir
OptimalSystemAgent.Events.AMQPQueue.status()  # :connected | :disconnected
OptimalSystemAgent.Events.AMQPQueue.queue_depth()  # non_neg_integer
```

### Docker Compose Example

```yaml
version: '3.8'
services:
  rabbitmq:
    image: rabbitmq:3.13-management
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest

  osa:
    build: .
    ports:
      - "8089:8089"
    environment:
      USE_AMQP_QUEUE: "true"
      AMQP_URL: "amqp://guest:guest@rabbitmq:5672/"
    depends_on:
      - rabbitmq
```

### Monitoring

**Queue depth:**

```bash
iex> OptimalSystemAgent.Events.AMQPQueue.queue_depth()
42
```

**RabbitMQ management UI:**

```
http://localhost:15672  (guest/guest)
Navigate to Queues → osa_events
```

---

## Implementation Files

| File | Purpose |
|------|---------|
| `lib/optimal_system_agent/channels/http/api/metrics_routes.ex` | Prometheus endpoint handler |
| `lib/optimal_system_agent/channels/http.ex` | Router registration (forward to metrics) |
| `lib/optimal_system_agent/events/amqp_queue.ex` | AMQP queue manager (GenServer) |
| `config/runtime.exs` | BEAM memory limit configuration |
| `test/channels/http/api/metrics_routes_test.exs` | Metrics endpoint tests (8 tests) |
| `test/events/amqp_queue_test.exs` | AMQP queue tests (10 tests) |
| `test/config_beam_memory_test.exs` | BEAM config tests (4 tests) |

---

## Testing

**Full suite (no-auth mode):**

```bash
cd OSA
mix test
```

**Specific feature tests:**

```bash
mix test test/channels/http/api/metrics_routes_test.exs
mix test test/events/amqp_queue_test.exs
mix test test/config_beam_memory_test.exs
```

**Manual curl test:**

```bash
mix osa.serve &
sleep 3
curl http://localhost:8089/metrics | head -20
pkill -f "mix osa.serve"
```

---

## Deployment Checklist

- [ ] Metrics endpoint accessible on `/metrics` (no auth)
- [ ] Prometheus scrape config points to `/metrics`
- [ ] BEAM_MAX_HEAP_SIZE set in Docker/Kubernetes environment
- [ ] USE_AMQP_QUEUE enabled only if RabbitMQ available
- [ ] AMQP_URL configured (test connection before deploy)
- [ ] DLQ monitoring configured (`osa_events.dlq`)
- [ ] All tests passing: `mix test`
- [ ] Manual smoke test: `curl http://localhost:8089/metrics`

---

## Troubleshooting

### Metrics endpoint returns 404

- Check HTTP routing in `lib/optimal_system_agent/channels/http.ex`
- Verify forward statement: `forward("/metrics", to: OptimalSystemAgent.Channels.HTTP.API.MetricsRoutes)`

### AMQP connection fails

- Verify AMQP_URL format: `amqp://user:password@host:port/`
- Check RabbitMQ is running: `nc -zv localhost 5672`
- Enable verbose logging: `LOGGER_LEVEL=debug`

### BEAM heap exceeded errors

- Increase BEAM_MAX_HEAP_SIZE in environment
- Monitor agent context usage: check tool output truncation
- Reduce max_tool_output_bytes if context too large

---

## See Also

- **Prometheus:** https://prometheus.io/
- **OpenMetrics:** https://openmetrics.io/
- **RabbitMQ:** https://www.rabbitmq.com/
- **BEAM Flags:** https://www.erlang.org/doc/man/erl#max_heap_size
