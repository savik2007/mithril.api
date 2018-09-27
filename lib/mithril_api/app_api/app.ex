defmodule Mithril.AppAPI.App do
  use Ecto.Schema

  alias Mithril.ClientAPI.Client

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "apps" do
    field(:scope, :string)
    field(:user_id, :binary_id)
    belongs_to(:client, Client, foreign_key: :client_id)

    timestamps()
  end
end
