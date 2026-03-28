defmodule OptimalSystemAgent.Observability.TelemetryOtelBridge do
  @moduledoc """
  Bridges `:telemetry` events from OSA providers into OpenTelemetry spans.

  Attaches to `[:osa, :providers, :chat, :complete]` and emits an OTEL span
  `"osa.providers.chat.complete"` with attributes from the event metadata,
  including `chatmangpt.run.correlation_id` for cross-service trace correlation.

  The bridge is purely additive — if OpenTelemetry SDK is unavailable it no-ops
  gracefully. Existing `:telemetry` event subscribers are unaffected.
  """

  require Logger

  @event [:osa, :providers, :chat, :complete]
  @span_name "osa.providers.chat.complete"
  @handler_id "osa.telemetry_otel_bridge.chat_complete"

  @doc """
  Attach the bridge handler to `[:osa, :providers, :chat, :complete]`.

  Safe to call multiple times — returns `:ok` even if already attached.
  """
  @spec attach() :: :ok
  def attach do
    case :telemetry.attach(@handler_id, @event, &__MODULE__.handle_event/4, nil) do
      :ok ->
        Logger.debug("[TelemetryOtelBridge] Attached to #{inspect(@event)}")
        :ok

      {:error, :already_exists} ->
        :ok
    end
  rescue
    _ -> :ok
  end

  @doc false
  def handle_event(@event, measurements, metadata, _config) do
    duration_ms = Map.get(measurements, :duration, 0)
    provider = Map.get(metadata, :provider, :unknown) |> to_string()
    model = Map.get(metadata, :model, "unknown")
    correlation_id = Map.get(metadata, :correlation_id) || Process.get(:chatmangpt_correlation_id)

    attrs = [
      {"osa.provider", provider},
      {"osa.model", to_string(model)},
      {"osa.duration_ms", duration_ms}
    ]

    attrs =
      if correlation_id do
        [{"chatmangpt.run.correlation_id", to_string(correlation_id)} | attrs]
      else
        attrs
      end

    emit_otel_span(@span_name, attrs, duration_ms)
  rescue
    e ->
      Logger.debug("[TelemetryOtelBridge] handle_event error: #{Exception.message(e)}")
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp emit_otel_span(span_name, attrs, duration_ms) do
    tracer = :opentelemetry.get_tracer(:optimal_system_agent)

    span_opts = %{
      attributes: attrs,
      kind: :internal
    }

    token = :otel_tracer.start_span(tracer, span_name, span_opts)

    # Record the measured duration as an attribute on the span
    :otel_span.set_attributes(token, [{"osa.duration_ms", duration_ms}])

    :otel_span.end_span(token)
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end
end
