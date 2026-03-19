defmodule OptimalSystemAgent.Store.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :content, :text, null: false
      add :category, :string, null: false
      add :scope, :string, null: false, default: "global"
      add :source, :string, null: false, default: "agent"
      add :tags, :text
      add :keywords, :text
      add :description, :text
      add :links, :text
      add :signal_weight, :float, null: false, default: 0.5
      add :relevance, :float, null: false, default: 1.0
      add :access_count, :integer, null: false, default: 0
      add :session_id, :string
      add :created_at, :string, null: false
      add :accessed_at, :string, null: false
      add :updated_at, :string, null: false
    end

    create index(:memories, [:category])
    create index(:memories, [:scope])
    create index(:memories, [:session_id])
    create index(:memories, [:signal_weight])
    create index(:memories, [:relevance])
  end
end
