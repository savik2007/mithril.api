defmodule Mithril.OAuth.TokenController do
  use Mithril.Web, :controller

  alias Core.Authorization.Tokens
  alias Core.TokenAPI
  alias Mithril.Web.TokenView
  alias Mithril.Web.UserView

  action_fallback(Mithril.Web.FallbackController)

  def init_factor(conn, attrs) do
    with {:ok, resp} <-
           attrs
           |> put_token_value(conn)
           |> Tokens.init_factor() do
      send_response(conn, resp, "token-without-details.json")
    end
  end

  def approve_factor(conn, attrs) do
    with {:ok, token} <-
           attrs
           |> put_token_value(conn)
           |> Tokens.approve_factor() do
      conn
      |> put_status(:created)
      |> put_view(TokenView)
      |> render("show.json", token: token)
    end
  end

  def update_password(conn, attrs) do
    with {:ok, user} <-
           attrs
           |> put_token_value(conn)
           |> TokenAPI.update_user_password() do
      conn
      |> put_view(UserView)
      |> render("show.json", user: user)
    end
  end

  def create(conn, %{"token" => token_params}) do
    with {:ok, resp} <-
           token_params
           |> put_token_value(conn)
           |> put_header_value(conn, "drfo")
           |> Tokens.create_by_grant_type(conn.assigns.grant_types) do
      send_response(conn, resp, "show.json")
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
    |> put_view(TokenView)
    |> render(view, token: token)
  end

  defp send_response(conn, token, view) do
    conn
    |> put_status(:created)
    |> put_view(TokenView)
    |> render(view, token: token)
  end
end
