defmodule Mithril.Web.UserController do
  @moduledoc false

  use Mithril.Web, :controller

  alias Core.Repo
  alias Core.UserAPI
  alias Core.UserAPI.User
  alias Scrivener.Page

  action_fallback(Mithril.Web.FallbackController)

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
    user = id |> UserAPI.get_user!() |> Repo.preload(:factor)

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

  def block(conn, %{"user_id" => id} = user_params) do
    with %User{is_blocked: false} = user <- UserAPI.get_user!(id),
         {:ok, %User{} = user} <- UserAPI.block_user(user, fetch_user_block_reason(user_params)) do
      render(conn, "show.json", user: user)
    else
      %User{is_blocked: true} -> {:error, {:conflict, "user already blocked"}}
      err -> err
    end
  end

  def unblock(conn, %{"user_id" => id} = user_params) do
    with %User{is_blocked: true} = user <- UserAPI.get_user!(id),
         {:ok, %User{} = user} <- UserAPI.unblock_user(user, fetch_user_block_reason(user_params)) do
      render(conn, "show.json", user: user)
    else
      %User{is_blocked: false} -> {:error, {:conflict, "user already unblocked"}}
      err -> err
    end
  end

  defp fetch_user_block_reason(%{"user" => %{"block_reason" => block_reason}}), do: block_reason
  defp fetch_user_block_reason(_), do: nil
end
