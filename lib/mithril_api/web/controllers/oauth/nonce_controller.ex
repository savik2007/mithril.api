defmodule Mithril.OAuth.NonceController do
  use Mithril.Web, :controller

  alias Mithril.Web.TokenView
  alias Mithril.Authentication

  action_fallback(Mithril.Web.FallbackController)

  def nonce(conn, _) do
    with {:ok, jwt, _} <- conn |> get_req_header("client-id") |> Authentication.generate_nonce_for_client() do
      render(conn, TokenView, "raw.json", json: %{token: jwt})
    end
  end
end
