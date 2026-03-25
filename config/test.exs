import Config

config :logger, level: :warning

# Sandbox pool removed — singleton GenServers (Memory, TaskQueue, etc.) call
# Repo from their own processes and can't do Sandbox.checkout!(), which causes
# DBConnection.OwnershipError → rest_for_one cascade → flaky "no process" failures.
# Tests use unique IDs and don't need transaction isolation.
config :optimal_system_agent, OptimalSystemAgent.Store.Repo, pool_size: 2

# Disable all LLM calls in tests so deterministic paths are always
# exercised and tests remain fast, repeatable, and provider-independent.
config :optimal_system_agent, classifier_llm_enabled: false
config :optimal_system_agent, knowledge_backend: MiosaKnowledge.Backend.ETS
config :optimal_system_agent, compactor_llm_enabled: false
# Use a different HTTP port in tests to avoid conflicts
config :optimal_system_agent, http_port: 0

# Per-run test secret — no hardcoded secrets
config :optimal_system_agent,
  shared_secret: "osa-test-#{:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)}"

# Point at Weaver live-check receiver during test runs (future weaver live-check)
config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318"

# Disable OTEL span processors during tests to keep output clean.
# When WEAVER_LIVE_CHECK=true, weaver.exs re-enables the batch processor
# so spans are exported to the Weaver receiver for schema conformance checking.
# NOTE: Must use a keyword list, not empty list [], to avoid :badmap crash
# in opentelemetry 1.7.0 which tries to iterate the processors config at boot.
config :opentelemetry, :processors, [disabled: %{exporter: {:no_op, []}}]

if System.get_env("WEAVER_LIVE_CHECK") == "true" do
  import_config "weaver.exs"
end
