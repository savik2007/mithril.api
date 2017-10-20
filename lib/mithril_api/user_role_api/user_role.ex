defmodule Mithril.UserRoleAPI.UserRole do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_roles" do
    field :user_id, :binary_id

    belongs_to :role, Mithril.RoleAPI.Role
    belongs_to :client, Mithril.ClientAPI.Client

    timestamps()
  end
end
