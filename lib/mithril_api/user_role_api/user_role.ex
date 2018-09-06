defmodule Mithril.UserRoleAPI.UserRole do
  use Ecto.Schema

  alias Mithril.UserAPI.User
  alias Mithril.RoleAPI.Role
  alias Mithril.Clients.Client

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_roles" do
    belongs_to(:user, User)
    belongs_to(:role, Role)
    belongs_to(:client, Client)

    timestamps()
  end
end
