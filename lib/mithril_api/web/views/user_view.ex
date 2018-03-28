defmodule Mithril.Web.UserView do
  @moduledoc false

  use Mithril.Web, :view
  alias Mithril.Web.UserView

  @fields ~w(id email tax_id person_id settings is_blocked block_reason inserted_at updated_at)a

  def render("index.json", %{users: users}) do
    render_many(users, UserView, "user.json")
  end

  def render("show.json", %{user: user}) do
    render_one(user, UserView, "user.json")
  end

  def render("user.json", %{user: user}) do
    Map.take(user, @fields)
  end

  def render("urgent.json", %{user: user, urgent: true, expires_at: expires_at}) do
    urgent = %{
      roles: render_many(user.roles, Mithril.Web.RoleView, "show.json"),
      token: %{
        expires_at: expires_at
      }
    }

    user
    |> Map.take(@fields)
    |> Map.put(:urgent, urgent)
  end
end
