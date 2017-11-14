defmodule Mithril.Web.UserController do
  @moduledoc false

  use Mithril.Web, :controller

  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Scrivener.Page

  action_fallback Mithril.Web.FallbackController

  def index(conn, params) do
    with %Page{} = paging <- UserAPI.list_users(params) do
      render(conn, "index.json", users: paging.entries, paging: paging)
    end
  end

  def create(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- UserAPI.create_user(user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", user_path(conn, :show, user))
      |> render("show.json", user: user)
    end
  end

  def show(conn, %{"id" => id}) do
    user = UserAPI.get_user!(id)
    render(conn, "show.json", user: user)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = UserAPI.get_user!(id)

    with {:ok, %User{} = user} <- UserAPI.update_user(user, user_params) do
      render(conn, "show.json", user: user)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = UserAPI.get_user!(id)
    with {:ok, %User{}} <- UserAPI.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  def change_password(conn, %{"user_id" => id, "user" => user_params}) do
    user = UserAPI.get_user!(id)
    with {:ok, %User{} = user} <- UserAPI.change_user_password(user, user_params) do
      render(conn, "show.json", user: user)
    end
  end

  def send_otp(conn, %{"user_id" => id}) do
    user = UserAPI.get_user!(id)
    with {:ok, %User{} = user} <- UserAPI.send_otp(user) do
      render(conn, "show.json", user: user)
    end
  end

  def block(conn, %{"user_id" => id} = user_params) do
    with %User{is_blocked: false} = user <- UserAPI.get_user!(id),
         {:ok, %User{} = user} <- UserAPI.block_user(user, get_in(user_params, ["user", "block_reason"]))
      do
      render(conn, "show.json", user: user)
    else
      %User{is_blocked: true} -> {:error, {:conflict, "user already blocked"}}
      err -> err
    end
  end

  def unblock(conn, %{"user_id" => id} = user_params) do
    data = %{"is_blocked" => false, "block_reason" => get_in(user_params, ["user", "block_reason"])}

    with %User{is_blocked: true} = user <- UserAPI.get_user!(id),
         {:ok, %User{} = user} <- UserAPI.update_user(user, data)
      do
      render(conn, "show.json", user: user)
    else
      %User{is_blocked: false} -> {:error, {:conflict, "user already unblocked"}}
      err -> err
    end
  end
end
