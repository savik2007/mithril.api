defmodule Mithril.Web.AuthenticationFactorView do
  use Mithril.Web, :view
  alias Mithril.Web.UserView
  alias Mithril.Authentication

  @fields ~w(id factor is_active type user_id inserted_at updated_at)a
  @type_sms Authentication.type(:sms)

  def render("index.json", %{factors: factors}) do
    render_many(factors, __MODULE__, "factor.json", as: :factor)
  end

  def render("show.json", %{factor: factor}) do
    render_one(factor, __MODULE__, "factor.json", as: :factor)
  end

  def render("factor.json", %{factor: factor}) do
    factor
    |> Map.take(@fields)
    |> mask_factor()
    |> Map.put(:user, UserView.render("show.json", %{user: factor.user}))
  end

  defp mask_factor(%{type: @type_sms, factor: factor} = fields) when is_binary(factor) and byte_size(factor) > 0 do
    masked = String.replace(factor, ~r/(?<=\+\d{5})\d{5}/, "*****")
    Map.put(fields, :factor, masked)
  end

  defp mask_factor(fields) do
    fields
  end
end
