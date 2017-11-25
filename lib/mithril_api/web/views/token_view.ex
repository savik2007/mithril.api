defmodule Mithril.Web.TokenView do
  @moduledoc false

  use Mithril.Web, :view
  alias Mithril.Web.TokenView

  @fields ~w(id name value expires_at user_id details)a

  def render("index.json", %{tokens: tokens}) do
    render_many(tokens, TokenView, "token.json")
  end

  def render("show.json", %{token: token}) do
    render_one(token, TokenView, "token.json")
  end

  def render("token.json", %{token: token}) do
    Map.take(token, @fields)
  end

  def render("token-without-details.json", %{token: token}) do
    Map.take(token, List.delete(@fields, :details))
  end

  def render("unprocessable_entity.json", %{errors: errors}) do
    errors
  end

  def render("unauthorized.json", %{errors: errors}) do
    errors
  end

  def render("bad_request.json", %{errors: errors}) do
    errors
  end
end
