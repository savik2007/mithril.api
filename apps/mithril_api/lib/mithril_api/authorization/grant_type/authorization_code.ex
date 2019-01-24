defmodule Mithril.Authorization.GrantType.AuthorizationCode do
  @moduledoc false

  import Ecto.Changeset
  import Mithril.Authorization.GrantType

  alias Ecto.Changeset
  alias Mithril.Clients.Client
  alias Mithril.Error
  alias Mithril.TokenAPI
  alias Mithril.Utils.RedirectUriChecker

  @authorization_code TokenAPI.token_type(:authorization_code)

  def authorize(attrs) do
    with %Changeset{valid?: true} <- changeset(attrs),
         {:ok, connection} <- get_connection(attrs["client_id"], attrs["client_secret"]),
         {:ok, token} <- get_token(attrs["code"], @authorization_code),
         :ok <- validate_client_match(token, connection.client),
         :ok <- validate_token_expiration(token),
         :ok <- validate_redirect_uri(token.details["redirect_uri"], attrs["redirect_uri"]),
         :ok <- validate_redirect_uri(connection.redirect_uri, attrs["redirect_uri"]),
         {:ok, _} <- validate_approval_authorization(token),
         :ok <- validate_token_is_not_used(token) do
      TokenAPI.update_token(token, %{details: Map.put_new(token.details, :used, true)})
      create_access_token(token)
    end
  end

  defp changeset(attrs) do
    types = %{client_id: :string, client_secret: :string, code: :string, redirect_uri: :string}

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(Map.keys(types))
  end

  defp validate_client_match(%{details: %{"client_id" => client_id}}, %Client{id: id}) when id == client_id, do: :ok
  defp validate_client_match(_, _), do: Error.invalid_grant("Token not found or expired.")

  defp validate_redirect_uri(redirect_uri, requested_redirect_uri) do
    case Regex.match?(RedirectUriChecker.generate_redirect_uri_regexp(redirect_uri), requested_redirect_uri) do
      true -> :ok
      _ -> Error.invalid_client("The redirection URI provided does not match a pre-registered value.")
    end
  end

  defp validate_token_is_not_used(token) do
    case Map.get(token.details, "used", false) do
      false -> :ok
      _ -> Error.access_denied("Token has already been used.")
    end
  end

  defp create_access_token(token) do
    {:ok, refresh_token} =
      TokenAPI.create_refresh_token(%{
        user_id: token.user_id,
        details: %{
          grant_type: @authorization_code,
          client_id: token.details["client_id"],
          scope: ""
        }
      })

    TokenAPI.create_access_token(%{
      user_id: token.user_id,
      details: %{
        grant_type: @authorization_code,
        client_id: token.details["client_id"],
        scope: token.details["scope_request"],
        refresh_token: refresh_token.value,
        redirect_uri: token.details["redirect_uri"]
      }
    })
  end
end
