defmodule Mithril.Web.GlobalUserRoleController do
  use Mithril.Web, :controller

  alias Core.GlobalUserRoleAPI
  alias Core.GlobalUserRoleAPI.GlobalUserRole

  action_fallback(Mithril.Web.FallbackController)

  def create(conn, %{"user_id" => user_id, "global_user_role" => user_role_params}) do
    user_role_attrs = Map.put(user_role_params, "user_id", user_id)

    with {:ok, %GlobalUserRole{} = global_user_role} <- GlobalUserRoleAPI.create_global_user_role(user_role_attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", user_global_role_path(conn, :show, global_user_role.user_id, global_user_role.id))
      |> render("show.json", global_user_role: global_user_role)
    end
  end

  def show(conn, %{"id" => id}) do
    global_user_role = GlobalUserRoleAPI.get_global_user_role!(id)
    render(conn, "show.json", global_user_role: global_user_role)
  end
end
