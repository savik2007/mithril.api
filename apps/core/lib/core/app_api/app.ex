defmodule Core.AppAPI.App do
  @moduledoc false
  use Ecto.Schema

  alias Core.Clients.Client
  alias Core.UserAPI.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "apps" do
    field(:scope, :string)
    belongs_to(:user, User)
    belongs_to(:client, Client)

    timestamps()
  end
end
