defmodule OptimalSystemAgent.Store.MemoryEntry do
  @moduledoc """
  Ecto schema for the memories table.

  Memories are keyed by a SHA256 hash of their content so duplicate entries
  are idempotent. Timestamps are stored as ISO8601 strings rather than using
  Ecto's native timestamps/2 because memory access time is updated frequently
  and we want full control over the values without touching Ecto's
  auto-managed fields.

  Categories map to the SICA classification taxonomy:
    decision | preference | pattern | lesson | context | project

  Scope controls visibility:
    global (persists across all sessions) | workspace | session
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "memories" do
    field(:content, :string)
    field(:category, :string)
    field(:scope, :string, default: "global")
    field(:source, :string, default: "agent")
    field(:tags, :string)
    field(:keywords, :string)
    field(:description, :string)
    field(:links, :string)
    field(:signal_weight, :float, default: 0.5)
    field(:relevance, :float, default: 1.0)
    field(:access_count, :integer, default: 0)
    field(:session_id, :string)
    field(:created_at, :string)
    field(:accessed_at, :string)
    field(:updated_at, :string)
  end

  @required_fields [:id, :content, :category, :created_at, :accessed_at, :updated_at]
  @optional_fields [
    :scope,
    :source,
    :tags,
    :keywords,
    :description,
    :links,
    :signal_weight,
    :relevance,
    :access_count,
    :session_id
  ]

  @valid_categories ~w(decision preference pattern lesson context project)
  @valid_scopes ~w(global workspace session)
  @valid_sources ~w(user agent system sica)

  @doc "Build a changeset for inserting or updating a memory entry."
  def changeset(memory \\ %__MODULE__{}, attrs) do
    memory
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:category, @valid_categories)
    |> validate_inclusion(:scope, @valid_scopes)
    |> validate_inclusion(:source, @valid_sources)
    |> validate_number(:signal_weight,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:relevance,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:access_count, greater_than_or_equal_to: 0)
  end
end
