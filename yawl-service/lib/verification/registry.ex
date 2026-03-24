defmodule YawlService.Verification.Registry do
  @moduledoc """
  ETS-based registry for storing verification results.
  """

  use GenServer

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(_opts) do
    # Create ETS table for verifications
    table = :ets.new(:verification_registry, [:named_table, :public, :set])
    {:ok, %{table: table}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
