defmodule Mithril.Web.GlobalUserRoleView do
  use Mithril.Web, :view
  alias Mithril.Web.UserRoleView
  alias Mithril.RoleAPI.Role

  def render("show.json", %{global_user_role: global_user_role}) do
    render_one(global_user_role, __MODULE__, "global_user_role.json")
  end

  def render("global_user_role.json", %{global_user_role: global_user_role}) do
    %{
      id: global_user_role.id,
      user_id: global_user_role.user_id,
      role_id: global_user_role.role_id,
      role_name: global_user_role.role.name,
      created_at: global_user_role.inserted_at,
      updated_at: global_user_role.updated_at,
      scope: global_user_role.role.scope
    }
  end
end
