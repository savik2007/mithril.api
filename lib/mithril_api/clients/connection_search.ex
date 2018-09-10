defmodule Mithril.Clients.ConnectionSearch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.UUID
  alias Mithril.Ecto.StringLike

  embedded_schema do
    field(:client_id, UUID)
    field(:consumer_id, UUID)
    field(:redirect_uri, StringLike)
  end

  def changeset(%__MODULE__{} = schema, attrs) do
    schema
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required(:client_id)
  end
end
