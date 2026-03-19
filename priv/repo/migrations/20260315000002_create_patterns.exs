defmodule OptimalSystemAgent.Store.Repo.Migrations.CreatePatterns do
  use Ecto.Migration

  def change do
    create table(:patterns, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :description, :text, null: false
      add :trigger, :text
      add :response, :text
      add :category, :string
      add :occurrences, :integer, null: false, default: 1
      add :success_rate, :float, null: false, default: 1.0
      add :tags, :text
      add :created_at, :string, null: false
      add :last_seen, :string, null: false
    end

    create index(:patterns, [:category])
    create index(:patterns, [:occurrences])
  end
end
