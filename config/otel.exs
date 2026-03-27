import Config

# OpenTelemetry Configuration — Distributed Tracing & Metrics
#
# This configuration sets up OpenTelemetry exporters to send traces and metrics
# to an OTLP (OpenTelemetry Protocol) collector.
# - HTTP/protobuf (this file): default port 4318 (collector HTTP OTLP).
# - gRPC (Weaver live-check): use WEAVER_OTLP_ENDPOINT in test.exs / weaver.exs, typically :4317.
# Override with: OTEL_EXPORTER_OTLP_ENDPOINT
#
# SDK: batch span processing with HTTP/protobuf export.

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
  otlp_protocol: :http_protobuf,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")
