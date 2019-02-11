defmodule Core.GlobalUserRoleAPI.GlobalUserRole do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "global_user_roles" do
    belongs_to(:role, Core.RoleAPI.Role)
    belongs_to(:user, Core.UserAPI.User)

    timestamps()
  end
end
