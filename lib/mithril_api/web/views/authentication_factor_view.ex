defmodule Mithril.Web.AuthenticationFactorView do
  use Mithril.Web, :view
  alias Mithril.Web.UserView

  @fields ~w(id factor is_active type user_id inserted_at updated_at)a

  def render("index.json", %{factors: factors}) do
    render_many(factors, __MODULE__, "factor.json", as: :factor)
  end

  def render("show.json", %{factor: factor}) do
    render_one(factor, __MODULE__, "factor.json", as: :factor)
  end

  def render("factor.json", %{factor: factor}) do
    factor
    |> Map.take(@fields)
    |> Map.put(:user, UserView.render("show.json", %{user: factor.user}))
  end
end
