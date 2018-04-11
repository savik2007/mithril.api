defmodule Mithril.OAuth.TokenController do
  use Mithril.Web, :controller

  alias Mithril.Authorization.Token
  alias Mithril.TokenAPI
  alias Mithril.Web.TokenView

  action_fallback(Mithril.Web.FallbackController)

  def init_factor(conn, attrs) do
    with {:ok, resp} <-
           attrs
           |> put_token_value(conn)
           |> TokenAPI.init_factor() do
      send_response(conn, resp, "token-without-details.json")
    end
  end

  def approve_factor(conn, attrs) do
    with {:ok, token} <-
           attrs
           |> put_token_value(conn)
           |> TokenAPI.approve_factor() do
      conn
      |> put_status(:created)
      |> render(TokenView, "show.json", token: token)
    end
  end

  def update_password(conn, attrs) do
    with {:ok, user} <-
           attrs
           |> put_token_value(conn)
           |> TokenAPI.update_user_password() do
      conn
      |> render(Mithril.Web.UserView, "show.json", user: user)
    end
  end

  def create(conn, %{"token" => token_params}) do
    with {:ok, resp} <-
           token_params
           |> put_token_value(conn)
           |> put_header_value(conn, "drfo")
           |> Token.authorize() do
      send_response(conn, resp, "show.json")
    end
  end

  def nonce(conn, _) do
    with {:ok, jwt, _} <- conn |> get_req_header("client-id") |> TokenAPI.generate_nonce_for_client() do
      render(conn, TokenView, "raw.json", json: %{token: jwt})
    end
  end

  defp put_token_value(token_params, conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> Map.put(token_params, "token_value", token)
      _ -> token_params
    end
  end

  defp put_header_value(token_params, conn, header_name) do
    case get_req_header(conn, header_name) do
      [value] -> Map.put(token_params, header_name, value)
      _ -> token_params
    end
  end

  defp send_response(conn, %{token: token, urgent: urgent}, view) do
    conn
    |> put_status(:created)
    |> assign(:urgent, urgent)
    |> render(TokenView, view, token: token)
  end

  defp send_response(conn, token, view) do
    conn
    |> put_status(:created)
    |> render(TokenView, view, token: token)
  end
end
