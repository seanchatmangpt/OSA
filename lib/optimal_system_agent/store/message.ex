defmodule OptimalSystemAgent.Store.Message do
  @moduledoc "Ecto schema for persisted session messages (SQLite)."
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field(:session_id, :string)
    field(:role, :string)
    field(:content, :string)
    field(:tool_calls, :map)
    field(:tool_call_id, :string)
    field(:token_count, :integer)
    field(:channel, :string)
    field(:metadata, :map, default: %{})
    timestamps()
  end

  @required ~w(session_id role content)a
  @optional ~w(tool_calls tool_call_id token_count channel metadata)a

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end
end
