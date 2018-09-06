defmodule Mithril.AppAPI.App do
  use Ecto.Schema

  alias Mithril.UserAPI.User
  alias Mithril.Clients.Client

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "apps" do
    field(:scope, :string)
    belongs_to(:user, User)
    belongs_to(:client, Client)

    timestamps()
  end
end
