import Config

# OpenTelemetry Configuration — Distributed Tracing & Metrics
#
# This configuration sets up OpenTelemetry exporters to send traces and metrics
# to an OTLP (OpenTelemetry Protocol) collector. The default endpoint is localhost:4317.
# Override with environment variable: OTEL_EXPORTER_OTLP_ENDPOINT
#
# SDK configuration for batch span processing with HTTP/protobuf export.

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
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
