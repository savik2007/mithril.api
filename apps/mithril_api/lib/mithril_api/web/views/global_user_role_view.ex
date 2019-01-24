defmodule Mithril.Web.GlobalUserRoleView do
  use Mithril.Web, :view

  @fields ~w(id user_id role_id inserted_at updated_at)a

  def render("show.json", %{global_user_role: global_user_role}) do
    render_one(global_user_role, __MODULE__, "global_user_role.json")
  end

  def render("global_user_role.json", %{global_user_role: %{role: role} = global_user_role}) do
    global_user_role
    |> Map.take(@fields)
    |> Map.merge(%{role_name: role.name, scope: role.scope})
  end
end
