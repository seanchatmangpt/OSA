import Config

# OpenTelemetry Configuration — Distributed Tracing & Metrics
#
# This configuration sets up OpenTelemetry exporters to send traces and metrics
# to an OTLP (OpenTelemetry Protocol) collector.
# gRPC export to OTLP collector on port 4317 (standard OTLP gRPC port).
# This works with both OTEL Collector and Weaver live-check natively.
# Override with: OTEL_EXPORTER_OTLP_ENDPOINT
#
# SDK: batch span processing with gRPC export.

config :opentelemetry, :resource,
  service: [name: "osa", version: "1.0.0"]

config :opentelemetry,
  tracer: :global,
  processors: [
    otel_batch_processor: %{
      exporter: {:opentelemetry_exporter, %{}}
    }
  ]

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
