defmodule OptimalSystemAgent.Tools.Pipeline do
  @moduledoc """
  Combinators for sequencing and composing tool instructions.

  All combinators accept raw instruction inputs (strings, 2-tuples, 3-tuples,
  or `Instruction` structs) and normalise them internally via
  `OptimalSystemAgent.Tools.Instruction.normalize/1`.

  ## Options (all combinators)

  * `:executor` — `(tool_name, params) -> {:ok, result} | {:error, reason}`.
    Defaults to a no-op that returns `{:ok, params}`.

  ## Examples

      executor = fn name, params ->
        OptimalSystemAgent.Tools.Registry.execute(name, params)
      end

      # Run instructions sequentially, piping output into next input
      Pipeline.pipe(["file_read", {"file_write", %{"content" => "..."}}], executor: executor)

      # Run instructions in parallel, collect results
      Pipeline.parallel([{"web_search", %{"q" => "elixir"}}, "list_skills"], executor: executor)
  """

  alias OptimalSystemAgent.Tools.Instruction

  @type executor :: (String.t(), map() -> {:ok, any()} | {:error, String.t()})

  @doc """
  Run `instructions` sequentially. Each step's output map is merged into the
  next step's params before execution. Short-circuits on the first error.
  """
  @spec pipe([term()], keyword()) :: {:ok, map()} | {:error, String.t()}
  def pipe(instructions, opts \\ []) do
    executor = Keyword.get(opts, :executor, fn _tool, params -> {:ok, params} end)

    Enum.reduce_while(instructions, {:ok, %{}}, fn raw, {:ok, acc} ->
      case Instruction.normalize(raw) do
        {:ok, inst} ->
          merged = Map.merge(acc, inst.params)

          case executor.(inst.tool, merged) do
            {:ok, result} -> {:cont, {:ok, result}}
            {:error, _} = err -> {:halt, err}
          end

        {:error, _} = err ->
          {:halt, err}
      end
    end)
  end

  @doc """
  Run all `instructions` concurrently. Returns `{:ok, [results]}` when all
  succeed, or `{:error, [reasons]}` listing every failure.
  """
  @spec parallel([term()], keyword()) :: {:ok, [any()]} | {:error, [String.t()]}
  def parallel(instructions, opts \\ []) do
    executor = Keyword.get(opts, :executor, fn _tool, params -> {:ok, params} end)

    tasks =
      Enum.map(instructions, fn raw ->
        Task.async(fn ->
          case Instruction.normalize(raw) do
            {:ok, inst} -> executor.(inst.tool, inst.params)
            err -> err
          end
        end)
      end)

    results = Task.await_many(tasks, 30_000)
    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, Enum.map(results, fn {:ok, v} -> v end)}
    else
      {:error, Enum.map(errors, fn {:error, e} -> e end)}
    end
  end

  @doc """
  Try each instruction in turn and return the first success. If all fail,
  returns the last error.
  """
  @spec fallback([term()], keyword()) :: {:ok, any()} | {:error, String.t()}
  def fallback(instructions, opts \\ []) do
    executor = Keyword.get(opts, :executor, fn _tool, params -> {:ok, params} end)

    Enum.reduce_while(instructions, {:error, "no instructions"}, fn raw, _acc ->
      case Instruction.normalize(raw) do
        {:ok, inst} ->
          case executor.(inst.tool, inst.params) do
            {:ok, _} = ok -> {:halt, ok}
            {:error, _} = err -> {:cont, err}
          end

        {:error, _} = err ->
          {:cont, err}
      end
    end)
  end

  @doc """
  Retry a single `instruction` up to `:attempts` times (default 3).
  Returns the first success or the last error.
  """
  @spec retry(term(), keyword()) :: {:ok, any()} | {:error, String.t()}
  def retry(instruction, opts \\ []) do
    executor = Keyword.get(opts, :executor, fn _tool, params -> {:ok, params} end)
    attempts = Keyword.get(opts, :attempts, 3)

    case Instruction.normalize(instruction) do
      {:error, _} = err ->
        err

      {:ok, inst} ->
        Enum.reduce_while(1..attempts, {:error, "not attempted"}, fn _i, _acc ->
          case executor.(inst.tool, inst.params) do
            {:ok, _} = ok -> {:halt, ok}
            {:error, _} = err -> {:cont, err}
          end
        end)
    end
  end
end
