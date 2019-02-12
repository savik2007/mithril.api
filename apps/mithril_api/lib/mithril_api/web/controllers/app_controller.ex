defmodule Mithril.Web.AppController do
  use Mithril.Web, :controller

  alias Core.AppAPI
  alias Core.AppAPI.App
  alias Mithril.Web.AppView
  alias Scrivener.Page

  action_fallback(Mithril.Web.FallbackController)

  def index(conn, params) do
    with %Page{} = paging <- AppAPI.list_apps(params) do
      conn
      |> put_view(AppView)
      |> render("index.json", apps: paging.entries, paging: paging)
    end
  end

  def create(conn, %{"app" => app_params}) do
    with {:ok, %App{} = app} <- AppAPI.create_app(app_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", app_path(conn, :show, app))
      |> put_view(AppView)
      |> render("show.json", app: AppAPI.get_app!(app.id))
    end
  end

  def show(conn, %{"id" => id}) do
    app = AppAPI.get_app!(id)

    conn
    |> put_view(AppView)
    |> render("show.json", app: app)
  end

  def update(conn, %{"id" => id, "app" => app_params}) do
    app = AppAPI.get_app!(id)

    with {:ok, %App{} = app} <- AppAPI.update_app(app, app_params) do
      conn
      |> put_view(AppView)
      |> render("show.json", app: app)
    end
  end

  def delete(conn, %{"id" => id}) do
    app = AppAPI.get_app!(id)

    with {:ok, _} <- AppAPI.delete_app(app) do
      send_resp(conn, :no_content, "")
    end
  end

  def delete_by_user(conn, %{"user_id" => _} = params) do
    with {:ok, _} <- AppAPI.delete_apps_by_params(params) do
      send_resp(conn, :no_content, "")
    end
  end
end
