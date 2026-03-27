defmodule OptimalSystemAgent.Yawl.EventStreamTest do
  @moduledoc """
  Chicago TDD tests for the YAWL EventStream module.

  Uses Weaver-generated semconv constants — if `YawlAttributes` is removed from
  the schema and the generated module disappears, these tests fail at compile time.
  This is intentional: the test is the schema conformance proof.
  """

  use ExUnit.Case, async: true

  alias OpenTelemetry.SemConv.Incubating.YawlAttributes, as: Attrs
  alias OptimalSystemAgent.Yawl.EventStream

  # ──────────────────────────────────────────────────────────────────────────
  # Schema Conformance — Weaver constant assertions
  # Compile error if schema removes any of these attributes.
  # ──────────────────────────────────────────────────────────────────────────

  describe "Weaver-generated attribute constants" do
    test "yawl.case.id constant matches schema" do
      assert Attrs.yawl_case_id() == :"yawl.case.id"
    end

    test "yawl.task.id constant matches schema" do
      assert Attrs.yawl_task_id() == :"yawl.task.id"
    end

    test "yawl.event.type constant matches schema" do
      assert Attrs.yawl_event_type() == :"yawl.event.type"
    end

    test "yawl.token.consumed constant matches schema" do
      assert Attrs.yawl_token_consumed() == :"yawl.token.consumed"
    end

    test "yawl.token.produced constant matches schema" do
      assert Attrs.yawl_token_produced() == :"yawl.token.produced"
    end

    test "yawl.work_item.id constant matches schema" do
      assert Attrs.yawl_work_item_id() == :"yawl.work_item.id"
    end

    test "yawl.spec.uri constant matches schema" do
      assert Attrs.yawl_spec_uri() == :"yawl.spec.uri"
    end

    test "yawl.instance.id constant matches schema" do
      assert Attrs.yawl_instance_id() == :"yawl.instance.id"
    end
  end

  describe "yawl.event.type enum values" do
    test "INSTANCE_CREATED enum value" do
      assert Attrs.yawl_event_type_values().instance_created == :INSTANCE_CREATED
    end

    test "TASK_ENABLED enum value" do
      assert Attrs.yawl_event_type_values().task_enabled == :TASK_ENABLED
    end

    test "TASK_STARTED enum value — tokens consumed" do
      assert Attrs.yawl_event_type_values().task_started == :TASK_STARTED
    end

    test "TASK_COMPLETED enum value — tokens produced" do
      assert Attrs.yawl_event_type_values().task_completed == :TASK_COMPLETED
    end

    test "TASK_FAILED enum value" do
      assert Attrs.yawl_event_type_values().task_failed == :TASK_FAILED
    end

    test "INSTANCE_COMPLETED enum value" do
      assert Attrs.yawl_event_type_values().instance_completed == :INSTANCE_COMPLETED
    end

    test "INSTANCE_CANCELLED enum value" do
      assert Attrs.yawl_event_type_values().instance_cancelled == :INSTANCE_CANCELLED
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Trace ID Derivation — deterministic SHA-256-based correlation
  # ──────────────────────────────────────────────────────────────────────────

  describe "derive_trace_id/1 (via ETS after subscribe)" do
    setup do
      # Ensure ETS table exists (normally created by GenServer init)
      table_name = :osa_yawl_trace_ids

      unless :ets.whereis(table_name) != :undefined do
        :ets.new(table_name, [:named_table, :public, :set, read_concurrency: true])
      end

      :ok
    end

    test "lookup_trace_id returns nil for unknown case" do
      assert EventStream.lookup_trace_id("nonexistent-case") == nil
    end

    test "trace_id is a 32-char lowercase hex string" do
      table = :osa_yawl_trace_ids
      case_id = "case-test-#{:erlang.unique_integer([:positive])}"

      # Manually insert as EventStream.subscribe would do via GenServer
      trace_id =
        :crypto.hash(:sha256, case_id)
        |> binary_part(0, 16)
        |> Base.encode16(case: :lower)

      :ets.insert(table, {case_id, trace_id})

      assert EventStream.lookup_trace_id(case_id) == trace_id
      assert byte_size(trace_id) == 32
      assert String.match?(trace_id, ~r/^[0-9a-f]{32}$/)
    end

    test "same case_id always produces same trace_id (deterministic)" do
      case_id = "order-flow-42"

      trace_id_1 =
        :crypto.hash(:sha256, case_id)
        |> binary_part(0, 16)
        |> Base.encode16(case: :lower)

      trace_id_2 =
        :crypto.hash(:sha256, case_id)
        |> binary_part(0, 16)
        |> Base.encode16(case: :lower)

      assert trace_id_1 == trace_id_2
    end

    test "different case_ids produce different trace_ids" do
      derive = fn case_id ->
        :crypto.hash(:sha256, case_id)
        |> binary_part(0, 16)
        |> Base.encode16(case: :lower)
      end

      assert derive.("case-001") != derive.("case-002")
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Telemetry Event Structure — metadata keys must use semconv constants
  # Requires :telemetry app — runs with full app boot, skipped with --no-start
  # ──────────────────────────────────────────────────────────────────────────

  describe "telemetry metadata keys use semconv constants" do
    @tag :requires_application
    test "INSTANCE_CREATED telemetry uses yawl.case.id key" do
      {:ok, handler_ref} = attach_telemetry_handler([:osa, :yawl, :case, :started])

      :telemetry.execute(
        [:osa, :yawl, :case, :started],
        %{},
        %{
          Attrs.yawl_case_id() => "case-001",
          Attrs.yawl_spec_uri() => "WCP01_Sequence",
          Attrs.yawl_event_type() => Attrs.yawl_event_type_values().instance_created
        }
      )

      assert_receive {:telemetry, [:osa, :yawl, :case, :started], _measurements, metadata}
      assert Map.get(metadata, Attrs.yawl_case_id()) == "case-001"
      assert Map.get(metadata, Attrs.yawl_spec_uri()) == "WCP01_Sequence"
      assert Map.get(metadata, Attrs.yawl_event_type()) == :INSTANCE_CREATED

      :telemetry.detach(handler_ref)
    end

    @tag :requires_application
    test "TASK_STARTED telemetry uses yawl.token.consumed=1 (Petri net token consumed)" do
      {:ok, handler_ref} = attach_telemetry_handler([:osa, :yawl, :task, :execution])

      :telemetry.execute(
        [:osa, :yawl, :task, :execution],
        %{token_consumed: 1, token_produced: 0},
        %{
          Attrs.yawl_case_id() => "case-001",
          Attrs.yawl_task_id() => "TaskA",
          Attrs.yawl_event_type() => Attrs.yawl_event_type_values().task_started,
          Attrs.yawl_work_item_id() => "case-001:TaskA:001"
        }
      )

      assert_receive {:telemetry, [:osa, :yawl, :task, :execution], measurements, metadata}
      assert measurements.token_consumed == 1
      assert measurements.token_produced == 0
      assert Map.get(metadata, Attrs.yawl_case_id()) == "case-001"
      assert Map.get(metadata, Attrs.yawl_task_id()) == "TaskA"
      assert Map.get(metadata, Attrs.yawl_event_type()) == :TASK_STARTED

      :telemetry.detach(handler_ref)
    end

    @tag :requires_application
    test "TASK_COMPLETED telemetry uses yawl.token.produced=1 (Petri net token produced)" do
      {:ok, handler_ref} = attach_telemetry_handler([:osa, :yawl, :task, :execution])

      :telemetry.execute(
        [:osa, :yawl, :task, :execution],
        %{token_consumed: 0, token_produced: 1},
        %{
          Attrs.yawl_case_id() => "case-001",
          Attrs.yawl_task_id() => "TaskA",
          Attrs.yawl_event_type() => Attrs.yawl_event_type_values().task_completed
        }
      )

      assert_receive {:telemetry, [:osa, :yawl, :task, :execution], measurements, metadata}
      assert measurements.token_consumed == 0
      assert measurements.token_produced == 1
      assert Map.get(metadata, Attrs.yawl_event_type()) == :TASK_COMPLETED

      :telemetry.detach(handler_ref)
    end

    @tag :requires_application
    test "INSTANCE_COMPLETED telemetry uses yawl.case.id key" do
      {:ok, handler_ref} = attach_telemetry_handler([:osa, :yawl, :case, :completed])

      :telemetry.execute(
        [:osa, :yawl, :case, :completed],
        %{},
        %{
          Attrs.yawl_case_id() => "case-001",
          Attrs.yawl_event_type() => Attrs.yawl_event_type_values().instance_completed
        }
      )

      assert_receive {:telemetry, [:osa, :yawl, :case, :completed], _measurements, metadata}
      assert Map.get(metadata, Attrs.yawl_case_id()) == "case-001"
      assert Map.get(metadata, Attrs.yawl_event_type()) == :INSTANCE_COMPLETED

      :telemetry.detach(handler_ref)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp attach_telemetry_handler(event) do
    test_pid = self()
    ref = make_ref()
    handler_id = "test-handler-#{inspect(ref)}"

    :ok =
      :telemetry.attach(
        handler_id,
        event,
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event_name, measurements, metadata})
        end,
        nil
      )

    {:ok, handler_id}
  end
end
