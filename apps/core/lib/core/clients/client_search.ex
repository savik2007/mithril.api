defmodule Core.Clients.ClientSearch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Ecto.StringLike
  alias Ecto.UUID

  @primary_key false
  embedded_schema do
    field(:id, UUID)
    field(:user_id, UUID)
    field(:name, StringLike)
    field(:is_blocked, :boolean)
  end

  def changeset(%__MODULE__{} = schema, attrs) do
    cast(schema, attrs, __MODULE__.__schema__(:fields))
  end
end
