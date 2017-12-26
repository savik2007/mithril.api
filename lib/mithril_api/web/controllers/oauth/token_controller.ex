defmodule Mithril.OAuth.TokenController do
  use Mithril.Web, :controller

  alias Mithril.Authorization.Token
  alias Mithril.TokenAPI
  alias Mithril.Web.TokenView

  action_fallback Mithril.Web.FallbackController

  def init_factor(conn, attrs) do
    with {:ok, resp} <- attrs
                         |> put_token_value(conn)
                         |> TokenAPI.init_factor() do
      send_response(conn, resp, "token-without-details.json")
    end
  end

  def approve_factor(conn, attrs) do
    with {:ok, token} <- attrs
                         |> put_token_value(conn)
                         |> TokenAPI.approve_factor() do
      conn
      |> put_status(:created)
      |> render(TokenView, "show.json", token: token)
    end
  end

  def create(conn, %{"token" => token_params}) do
    with {:ok, resp} <- token_params
                        |> put_token_value(conn)
                        |> Token.authorize() do
      send_response(conn, resp, "show.json")
    end
  end

  def create_change_pwd_token(conn, token_params) do
    with {:ok, resp} <- Token.authorize(token_params) do
      send_response(conn, resp, "show.json")
    end
  end

  defp put_token_value(token_params, conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> Map.put(token_params, "token_value", token)
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
