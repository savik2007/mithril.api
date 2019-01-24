defmodule Mithril.GlobalUserRoleAPI.GlobalUserRole do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "global_user_roles" do
    belongs_to(:role, Mithril.RoleAPI.Role)
    belongs_to(:user, Mithril.UserAPI.User)

    timestamps()
  end
end
