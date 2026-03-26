defmodule OSA.MCP.ToolExecutor do
  @moduledoc """
  JTBD Scenario 9: MCP Tool Execution

  Executes MCP-registered tools and emits OTEL spans with execution details.
  Handles tool validation, execution, error handling, and timeouts.

  Chicago TDD GREEN phase: Minimal implementation to pass tests.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias OpenTelemetry.Tracer

  @doc """
  Execute a registered MCP tool with input.

  Returns {:ok, output} or {:error, reason}.
  Emits OTEL span with tool execution details.

  Options:
    - timeout_ms: maximum execution time (default 1000ms)
  """
  def execute_tool(tool_name, tool_input, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 1000)
    start_time = System.monotonic_time(:millisecond)

    # Start root span
    root_ctx = Tracer.start_span("jtbd.mcp.tool.execute")

    try do
      # Simulate tool execution with timeout check
      Task.async(fn ->
        execute_tool_internal(tool_name, tool_input)
      end)
      |> Task.await(timeout_ms)
      |> case do
        {:ok, output} ->
          # Emit successful span
          latency = System.monotonic_time(:millisecond) - start_time
          emit_success_span(tool_name, latency)
          {:ok, output}

        {:error, reason} ->
          # Emit error span
          emit_error_span(tool_name, reason)
          {:error, reason}
      end
    catch
      :exit, {:timeout, _} ->
        # Timeout occurred
        latency = System.monotonic_time(:millisecond) - start_time
        Tracer.set_attribute(:error_type, "timeout")
        Tracer.set_attribute(:duration_ms, latency)
        {:error, :timeout}

      _type, _reason ->
        Tracer.set_attribute(:status, "error")
        {:error, :tool_execution_failed}
    after
      Tracer.end_span(root_ctx)
    end
  end

  # Helper: Internal tool execution logic
  defp execute_tool_internal(tool_name, tool_input) do
    case tool_name do
      "calculate_discount" ->
        calculate_discount(tool_input)

      _ ->
        {:error, :unknown_tool}
    end
  end

  # Helper: Calculate discount (example tool)
  defp calculate_discount(input) do
    with base_amount when is_number(base_amount) <- input[:base_amount],
         quantity when is_integer(quantity) and quantity > 0 <- input[:quantity],
         customer_tier when is_binary(customer_tier) <- input[:customer_tier] do
      # Calculate discount based on tier and quantity
      discount_rate = calculate_discount_rate(customer_tier, quantity)
      discounted_amount = base_amount * (1.0 - discount_rate)
      savings = base_amount * discount_rate

      {:ok,
       %{
         discount_rate: discount_rate,
         discounted_amount: discounted_amount,
         savings: savings
       }}
    else
      _error -> {:error, :validation_failed}
    end
  end

  # Helper: Calculate discount rate based on tier and quantity
  defp calculate_discount_rate(tier, quantity) do
    base_rate =
      case tier do
        "gold" -> 0.15
        "silver" -> 0.10
        "bronze" -> 0.05
        _ -> 0.0
      end

    # Add bulk discount
    bulk_discount =
      if quantity >= 100 do
        0.05
      else if quantity >= 50 do
        0.03
      else
        0.0
      end
      end

    min(base_rate + bulk_discount, 0.3)
  end

  # Helper: Emit success span
  defp emit_success_span(tool_name, latency_ms) do
    Tracer.set_attribute(:tool_name, tool_name)
    Tracer.set_attribute(:status, "ok")
    Tracer.set_attribute(:duration_ms, latency_ms)
  end

  # Helper: Emit error span
  defp emit_error_span(tool_name, reason) do
    Tracer.set_attribute(:tool_name, tool_name)
    Tracer.set_attribute(:status, "error")
    Tracer.set_attribute(:error_type, Atom.to_string(reason))
  end
end
