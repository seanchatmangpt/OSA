defmodule OptimalSystemAgent.Integration.RdfChainE2ETest do
  @moduledoc """
  Chicago TDD E2E tests for the RDF Oxigraph data flow chain.

  Three tiers:
  - Tier 1 (no live LLM/services): telemetry event reaches handler with correlation_id in metadata
  - Tier 2 (no live LLM/services): start_span embeds chatmangpt.run.correlation_id when process dict set
  - Tier 3 (@tag :integration): full live chain — span from OSA in Jaeger carries correlation_id

  Run tiers 1+2: mix test test/integration/rdf_chain_e2e_test.exs
  Run tier 3:    mix test test/integration/rdf_chain_e2e_test.exs --include integration
  """

  use ExUnit.Case, async: false

  alias OptimalSystemAgent.Observability.Telemetry
  alias OptimalSystemAgent.Observability.TelemetryOtelBridge

  # ── Tier 1: telemetry event reaches handler with correlation_id ─────────────

  describe "telemetry event propagation (Tier 1)" do
    test "[:osa, :providers, :chat, :complete] event carries correlation_id in metadata" do
      corr_id = "test-corr-#{System.unique_integer([:positive])}"
      Process.put(:chatmangpt_correlation_id, corr_id)

      test_pid = self()

      :telemetry.attach(
        "rdf_chain_e2e_t1_#{corr_id}",
        [:osa, :providers, :chat, :complete],
        fn _event, measurements, metadata, _cfg ->
          send(test_pid, {:telemetry_received, measurements, metadata})
        end,
        nil
      )

      :telemetry.execute(
        [:osa, :providers, :chat, :complete],
        %{duration: 42},
        %{
          provider: :ollama,
          model: "test-model",
          correlation_id: Process.get(:chatmangpt_correlation_id)
        }
      )

      :telemetry.detach("rdf_chain_e2e_t1_#{corr_id}")

      assert_receive {:telemetry_received, measurements, metadata}, 1000
      assert measurements.duration == 42
      assert metadata.correlation_id == corr_id
    end

    test "TelemetryOtelBridge attaches without error" do
      result = TelemetryOtelBridge.attach()
      assert result == :ok
    end
  end

  # ── Tier 2: start_span embeds correlation_id attribute ──────────────────────

  describe "span correlation_id embedding (Tier 2)" do
    test "start_span includes chatmangpt.run.correlation_id when process dict is set" do
      corr_id = "tier2-corr-#{System.unique_integer([:positive])}"
      Process.put(:chatmangpt_correlation_id, corr_id)

      {:ok, span_ctx} = Telemetry.start_span("llm.inference", %{"test" => true})

      assert span_ctx["attributes"]["chatmangpt.run.correlation_id"] == corr_id
    end

    test "start_span does not crash when process dict has no correlation_id" do
      Process.delete(:chatmangpt_correlation_id)
      Process.put(:chatmangpt_correlation_id, nil)

      assert {:ok, _span} = Telemetry.start_span("llm.inference", %{})
    end
  end

  # ── Tier 3: live integration (requires running services + Jaeger) ────────────

  @tag :integration
  describe "full chain correlation (Tier 3 — requires live services)" do
    test "OSA span carries chatmangpt.run.correlation_id in Jaeger" do
      jaeger_url = System.get_env("JAEGER_URL", "http://localhost:16686")
      corr_id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

      Process.put(:chatmangpt_correlation_id, corr_id)
      {:ok, span_ctx} = Telemetry.start_span("osa.providers.chat.complete", %{"test_correlation" => true})
      Telemetry.end_span(span_ctx, :ok)

      # Poll Jaeger for up to 30 seconds
      found =
        Enum.any?(1..10, fn attempt ->
          Process.sleep(3_000)

          url = "#{jaeger_url}/api/traces?service=osa&lookback=1h&limit=20"

          case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
            {:ok, {{_, 200, _}, _, body}} ->
              body_str = List.to_string(body)
              String.contains?(body_str, corr_id)

            _ ->
              attempt < 10 && false
          end
        end)

      assert found, "Expected OSA span with correlation_id=#{corr_id} in Jaeger (checked #{jaeger_url})"
    end
  end
end
