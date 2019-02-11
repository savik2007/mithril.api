defmodule Mithril.OAuth.NonceController do
  use Mithril.Web, :controller

  alias Core.Authentication
  alias Mithril.NonceValidator
  alias Mithril.Web.FallbackController
  alias Mithril.Web.TokenView

  plug(Plugination, [validator: NonceValidator, error_handler: FallbackController] when action in [:nonce])

  action_fallback(Mithril.Web.FallbackController)

  def nonce(conn, %{"client_id" => client_id}) do
    with {:ok, jwt, _} <- Authentication.generate_nonce_for_client(client_id) do
      render(conn, TokenView, "raw.json", json: %{token: jwt})
    end
  end
end
