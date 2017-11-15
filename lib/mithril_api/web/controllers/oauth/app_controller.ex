defmodule Mithril.OAuth.AppController do
  use Mithril.Web, :controller

  alias Mithril.Web.TokenView
  alias Mithril.Authorization.App

  action_fallback Mithril.Web.FallbackController

  def authorize(conn, %{"app" => app_params}) do
    user_id = conn
              |> Plug.Conn.get_req_header("x-consumer-id")
              |> List.first()
    api_key = conn
              |> Plug.Conn.get_req_header("api-key")
              |> List.first()
    params = Map.merge(app_params, %{"user_id" => user_id, "api_key" => api_key})

    with %{"token" => token} <- App.grant(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", generate_location(token))
      |> render(TokenView, "show.json", token: token)
    end
  end

  defp generate_location(token) do
    redirect_uri = URI.parse(token.details.redirect_uri)

    new_redirect_uri =
      Map.update! redirect_uri, :query, fn (query) ->
        query =
          if query, do: URI.decode_query(query), else: %{}

        query
        |> Map.merge(%{code: token.value})
        |> URI.encode_query
      end

    URI.to_string(new_redirect_uri)
  end
end
