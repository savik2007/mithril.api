defmodule Mithril.Authorization.GrantType.RefreshToken do
  @moduledoc false

  import Ecto.Changeset
  import Mithril.Authorization.GrantType

  alias Mithril.Error
  alias Mithril.TokenAPI

  @refresh_token TokenAPI.token_type(:refresh)

  def authorize(attrs) do
    with %Ecto.Changeset{valid?: true} <- changeset(attrs),
         {:ok, connection} <- get_connection(attrs["client_id"], attrs["client_secret"]),
         {:ok, token} <- get_token(attrs["refresh_token"], @refresh_token),
         :ok <- validate_client_match(connection.client, token),
         :ok <- validate_token_expiration(token),
         {:ok, approval} <- validate_approval_authorization(token) do
      create_access_token(connection.client, token, approval)
    end
  end

  defp changeset(attrs) do
    types = %{refresh_token: :string, client_id: :string, client_secret: :string}

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(Map.keys(types))
  end

  defp validate_client_match(client, token) do
    case token.details["client_id"] == client.id do
      true -> :ok
      _ -> Error.invalid_grant("Token not found or expired.")
    end
  end

  defp create_access_token(client, token, app) do
    TokenAPI.create_access_token(%{
      user_id: token.user_id,
      details: %{
        grant_type: @refresh_token,
        client_id: client.id,
        scope: app.scope
      }
    })
  end
end
