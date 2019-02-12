defmodule Mithril.OAuth.AppController do
  use Mithril.Web, :controller
  alias Core.Authorization
  alias Mithril.Web.TokenView

  action_fallback(Mithril.Web.FallbackController)

  def authorize(conn, %{"app" => app_params, "user_id" => user_id, "api_key" => api_key}) do
    params = Map.merge(app_params, %{"user_id" => user_id, "api_key" => api_key})

    with {:ok, token} <- Authorization.create_approval(params) do
      location = generate_location(token)

      conn
      |> put_status(:created)
      |> assign(:urgent, %{redirect_uri: location})
      |> put_resp_header("location", location)
      |> put_view(TokenView)
      |> render("show.json", token: token)
    end
  end

  defp generate_location(token) do
    redirect_uri = URI.parse(token.details.redirect_uri)

    new_redirect_uri =
      Map.update!(redirect_uri, :query, fn query ->
        query = if query, do: URI.decode_query(query), else: %{}

        query
        |> Map.merge(%{code: token.value})
        |> URI.encode_query()
      end)

    URI.to_string(new_redirect_uri)
  end
end
