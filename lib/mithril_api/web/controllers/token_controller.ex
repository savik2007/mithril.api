defmodule Mithril.Web.TokenController do
  use Mithril.Web, :controller

  alias Mithril.{TokenAPI, UserAPI}
  alias Mithril.TokenAPI.Token
  alias Mithril.Authorization.Tokens
  alias Scrivener.Page

  action_fallback(Mithril.Web.FallbackController)

  def index(conn, params) do
    with %Page{} = paging <- TokenAPI.list_tokens(params) do
      render(conn, "index.json", tokens: paging.entries, paging: paging)
    end
  end

  def create(conn, %{"token" => token_params}) do
    with {:ok, %Token{} = token} <- TokenAPI.create_token(token_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", token_path(conn, :show, token))
      |> render("show.json", token: token)
    end
  end

  def create_access_token(conn, %{"token" => token_params, "user_id" => user_id}) do
    user = UserAPI.get_user!(user_id)

    with {:ok, %Token{} = token} <- TokenAPI.create_access_token(user, token_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", token_path(conn, :show, token))
      |> render("show.json", token: token)
    end
  end

  def show(conn, %{"id" => id}) do
    token = TokenAPI.get_token!(id)
    render(conn, "show.json", token: token)
  end

  def verify(conn, %{"token_id" => value}) do
    api_key =
      conn
      |> Plug.Conn.get_req_header("api-key")
      |> List.first()

    with {:ok, %Token{} = token} <- Tokens.verify_client_token(value, api_key) do
      render(conn, "show.json", token: token)
    end
  end

  def user(conn, %{"token_id" => value}) do
    with {:ok, %Token{} = token} <- Tokens.verify(value) do
      user = Mithril.UserAPI.get_full_user(token.user_id, token.details["client_id"])
      render(conn, Mithril.Web.UserView, "urgent.json", user: user, urgent: true, expires_at: token.expires_at)
    end
  end

  def update(conn, %{"id" => id, "token" => token_params}) do
    token = TokenAPI.get_token!(id)

    with {:ok, %Token{} = token} <- TokenAPI.update_token(token, token_params) do
      render(conn, "show.json", token: token)
    end
  end

  def delete(conn, %{"id" => id}) do
    token = TokenAPI.get_token!(id)

    with {:ok, %Token{}} <- TokenAPI.delete_token(token) do
      send_resp(conn, :no_content, "")
    end
  end

  def delete_by_user(conn, %{"user_id" => _} = params) do
    with {_, nil} <- TokenAPI.delete_tokens_by_params(params) do
      send_resp(conn, :no_content, "")
    end
  end

  def delete_by_user_ids(conn, %{"user_ids" => ids}) do
    with {_, nil} <-
           ids
           |> String.split(",")
           |> TokenAPI.delete_tokens_by_user_ids() do
      send_resp(conn, :no_content, "")
    end
  end
end
