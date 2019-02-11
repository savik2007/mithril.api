defmodule Core.UserRoleAPI.UserRole do
  @moduledoc false
  use Ecto.Schema

  alias Core.Clients.Client
  alias Core.RoleAPI.Role
  alias Core.UserAPI.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_roles" do
    belongs_to(:user, User)
    belongs_to(:role, Role)
    belongs_to(:client, Client)

    timestamps()
  end
end
