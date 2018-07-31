defmodule Mithril.AppAPI.App do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "apps" do
    field(:scope, :string)
    field(:user_id, :binary_id)

    belongs_to(:clients, Mithril.ClientAPI.Client, foreign_key: :client_id)

    timestamps()
  end
end
