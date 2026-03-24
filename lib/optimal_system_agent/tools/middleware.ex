defmodule OptimalSystemAgent.Tools.Middleware do
  @moduledoc """
  Middleware behaviour and executor for tool instructions.

  Middleware modules form a pipeline that wraps tool execution. Each
  middleware receives an `Instruction`, may transform it, then calls
  `next.(updated_instruction)` to continue the chain.

  ## Defining middleware

  ```elixir
  defmodule MyApp.Tools.Middleware.Audit do
    @behaviour OptimalSystemAgent.Tools.Middleware
    require Logger

    @impl true
    def call(instruction, next, _opts) do
      Logger.info("[Audit] invoking \#{instruction.tool}")
      result = next.(instruction)
      Logger.info("[Audit] \#{instruction.tool} returned \#{inspect(result)}")
      result
    end
  end
  ```

  ## Running the pipeline

  ```elixir
  OptimalSystemAgent.Tools.Middleware.execute(instruction, [MyApp.Tools.Middleware.Audit], executor)
  ```

  Built-in middleware: `Validation`, `Timing`, `Logging`.
  """

  alias OptimalSystemAgent.Tools.Instruction

  @doc "Process an instruction, optionally transforming it, then call `next`."
  @callback call(
              instruction :: Instruction.t(),
              next :: (Instruction.t() -> any()),
              opts :: keyword()
            ) :: any()

  @doc """
  Execute `instruction` through the `middleware` chain, terminating with `executor`.

  Middleware is applied left-to-right: the first element wraps outermost,
  the last element wraps closest to the executor.

  `opts` is forwarded to each middleware as the third argument, allowing
  middleware like `Validation` to receive configuration (e.g. `:required`).
  """
  @spec execute(Instruction.t(), [module()], (Instruction.t() -> any()), keyword()) :: any()
  def execute(%Instruction{} = inst, [], executor, _opts), do: executor.(inst)

  def execute(%Instruction{} = inst, [mw | rest], executor, opts) do
    mw.call(inst, fn updated -> execute(updated, rest, executor, opts) end, opts)
  end

  @doc false
  def execute(%Instruction{} = inst, middleware, executor),
    do: execute(inst, middleware, executor, [])

  # ---------------------------------------------------------------------------
  # Built-in middleware
  # ---------------------------------------------------------------------------

  defmodule Validation do
    @moduledoc "Validates that all required params are present before executing."
    @behaviour OptimalSystemAgent.Tools.Middleware

    @impl true
    def call(instruction, next, opts) do
      required = Keyword.get(opts, :required, [])
      missing = Enum.reject(required, &Map.has_key?(instruction.params, &1))

      if missing == [] do
        next.(instruction)
      else
        {:error, "missing required params: #{Enum.join(missing, ", ")}"}
      end
    end
  end

  defmodule Timing do
    @moduledoc "Records wall-clock execution time in microseconds."
    @behaviour OptimalSystemAgent.Tools.Middleware

    @impl true
    def call(instruction, next, _opts) do
      start = System.monotonic_time(:microsecond)
      result = next.(instruction)
      elapsed = System.monotonic_time(:microsecond) - start

      case result do
        {:ok, val} -> {:ok, val, elapsed}
        other -> other
      end
    end
  end

  defmodule Logging do
    @moduledoc "Logs instruction dispatch at debug level."
    @behaviour OptimalSystemAgent.Tools.Middleware
    require Logger

    @impl true
    def call(instruction, next, _opts) do
      Logger.debug("[Tools.Middleware] executing #{instruction.tool}")
      result = next.(instruction)
      Logger.debug("[Tools.Middleware] #{instruction.tool} -> #{inspect(result)}")
      result
    end
  end
end
