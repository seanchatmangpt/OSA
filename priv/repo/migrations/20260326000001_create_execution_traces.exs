defmodule OptimalSystemAgent.Store.Repo.Migrations.CreateExecutionTraces do
  use Ecto.Migration

  def change do
    create table(:execution_traces, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :trace_id, :string, null: false
      add :span_id, :string, null: false
      add :parent_span_id, :string
      add :agent_id, :string, null: false
      add :tool_id, :string
      add :status, :string, null: false
      add :duration_ms, :integer
      add :timestamp_us, :bigint, null: false
      add :error_reason, :string
      timestamps()
    end

    # Index for trace retrieval: get full trace by trace_id
    create index(:execution_traces, [:trace_id])

    # Index for agent queries: traces_for_agent(agent_id, time_range)
    create index(:execution_traces, [:agent_id, :timestamp_us])

    # Index for status queries: find all errors
    create index(:execution_traces, [:status])

    # Composite index for range queries (agent + time range)
    create index(:execution_traces, [:agent_id, :timestamp_us, :status])
  end
end
