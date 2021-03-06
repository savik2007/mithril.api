defmodule Mithril.Web.UserRoleController do
  use Mithril.Web, :controller

  alias Core.UserRoleAPI
  alias Core.UserRoleAPI.UserRole

  action_fallback(Mithril.Web.FallbackController)

  def index(conn, params) do
    with {:ok, user_roles} <- UserRoleAPI.list_user_roles(params) do
      render(conn, "index.json", user_roles: user_roles)
    end
  end

  def create(conn, %{"user_id" => user_id, "user_role" => user_role_params}) do
    user_role_attrs = Map.put_new(user_role_params, "user_id", user_id)

    with {:ok, %UserRole{} = user_role} <- UserRoleAPI.create_user_role(user_role_attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", user_role_path(conn, :show, user_role.user_id, user_role.id))
      |> render("show.json", user_role: user_role)
    end
  end

  def show(conn, %{"id" => id}) do
    user_role = UserRoleAPI.get_user_role!(id)
    render(conn, "show.json", user_role: user_role)
  end

  def delete(conn, %{"id" => id}) do
    user_role = UserRoleAPI.get_user_role!(id)

    with {:ok, %UserRole{}} <- UserRoleAPI.delete_user_role(user_role) do
      send_resp(conn, :no_content, "")
    end
  end

  def delete_by_user(conn, %{"user_id" => _} = params) do
    with {_, nil} <- UserRoleAPI.delete_user_roles_by_params(params) do
      send_resp(conn, :no_content, "")
    end
  end
end
