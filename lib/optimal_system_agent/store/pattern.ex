defmodule OptimalSystemAgent.Store.Pattern do
  @moduledoc """
  Ecto schema for the patterns table.

  Patterns are learned by SICA (the self-improving cognitive agent) from
  repeated interactions. Each record captures a trigger condition, the
  recommended response, and a running success rate that SICA uses to
  weight future decisions.

  The `category` field maps to VIGIL error taxonomy so patterns discovered
  during error recovery can be cross-referenced with their originating signal.

  IDs are caller-assigned strings (typically a UUID or a content hash).
  Timestamps are ISO8601 strings managed by the application layer.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "patterns" do
    field(:description, :string)
    field(:trigger, :string)
    field(:response, :string)
    field(:category, :string)
    field(:occurrences, :integer, default: 1)
    field(:success_rate, :float, default: 1.0)
    field(:tags, :string)
    field(:created_at, :string)
    field(:last_seen, :string)
  end

  @required_fields [:id, :description, :created_at, :last_seen]
  @optional_fields [
    :trigger,
    :response,
    :category,
    :occurrences,
    :success_rate,
    :tags
  ]

  @doc "Build a changeset for inserting or updating a SICA pattern."
  def changeset(pattern \\ %__MODULE__{}, attrs) do
    pattern
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> then(&put_default_if_not_in_attrs(&1, attrs, :occurrences, 1))
    |> then(&put_default_if_not_in_attrs(&1, attrs, :success_rate, 1.0))
    |> validate_required(@required_fields)
    |> validate_number(:occurrences, greater_than_or_equal_to: 1)
    |> validate_number(:success_rate,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
  end

  defp put_default_if_not_in_attrs(changeset, attrs, field, default) do
    if Map.has_key?(attrs, field) or Map.has_key?(attrs, to_string(field)) do
      changeset
    else
      Ecto.Changeset.force_change(changeset, field, default)
    end
  end
end
