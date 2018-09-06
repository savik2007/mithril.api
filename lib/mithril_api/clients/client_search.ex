defmodule Mithril.Clients.ClientSearch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias Mithril.Ecto.StringLike

  embedded_schema do
    field(:name, StringLike)
    field(:user_id, Ecto.UUID)
    field(:is_blocked, :boolean)
  end

  def changeset(%ClientSearch{} = schema, attrs) do
    cast(schema, attrs, ClientSearch.__schema__(:fields))
  end
end
