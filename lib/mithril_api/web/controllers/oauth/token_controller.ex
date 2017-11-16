defmodule Mithril.OAuth.TokenController do
  use Mithril.Web, :controller

  alias Mithril.Authorization.Token

  action_fallback Mithril.Web.FallbackController

  def create(conn, %{"token" => token_params}) do
    with {:ok, resp} <- token_params
                        |> put_token_value(conn)
                        |> Token.authorize() do
      send_response(conn, resp)
    end
  end

  defp put_token_value(token_params, conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> Map.put(token_params, "token_value", token)
      _ -> token_params
    end
  end

  defp send_response(conn, %{token: token, urgent: urgent}) do
    conn
    |> put_status(:created)
    |> assign(:urgent, urgent)
    |> render(Mithril.Web.TokenView, "show.json", token: token)
  end
  defp send_response(conn, token) do
    conn
    |> put_status(:created)
    |> render(Mithril.Web.TokenView, "show.json", token: token)
  end
end
