defmodule Mithril.UserRoleAPI.UserRole do
  use Ecto.Schema

  alias Mithril.Clients.Client
  alias Mithril.RoleAPI.Role
  alias Mithril.UserAPI.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_roles" do
    belongs_to(:user, User)
    belongs_to(:role, Role)
    belongs_to(:client, Client)

    timestamps()
  end
end
