defmodule Mithril.Authorization do
  @moduledoc false

  import Ecto.Changeset
  import Mithril.Authorization.GrantType

  alias Ecto.UUID
  alias Mithril.AppAPI
  alias Mithril.Clients
  alias Mithril.Clients.Client
  alias Mithril.Error
  alias Mithril.TokenAPI
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.Utils.RedirectUriChecker

  # NOTE: Mark password token as used.
  #
  # On every approval a new token is created.
  # Current (session) token with it's scopes is still valid until it expires.
  # E.g. session expiration should be sufficiently short.
  def create_approval(params) do
    with %Ecto.Changeset{valid?: true} = changeset <- changeset(params),
         client_id <- get_change(changeset, :client_id),
         {:ok, client} <- get_client(client_id),
         :ok <- validate_client_is_blocked(client),
         # user validation
         user <- UserAPI.get_user_with_roles(get_change(changeset, :user_id), client_id),
         :ok <- validate_user_is_blocked(user),
         # client validation
         scope <- prepare_scope_by_client(client, user, get_change(changeset, :scope)),
         redirect_uri <- get_change(changeset, :redirect_uri),
         :ok <- validate_redirect_uri(client, redirect_uri),
         # scope validation
         :ok <- validate_scope_not_empty(scope),
         :ok <- validate_client_allowed_scope(client, scope),
         :ok <- validate_user_allowed_scope(user, scope),
         # entities creation
         :ok <- create_or_update_app(user, client, scope),
         {:ok, token} <- create_token(user, client, scope, redirect_uri) do
      {:ok, token}
    end
  end

  defp changeset(attrs) do
    types = %{user_id: UUID, client_id: UUID, redirect_uri: :string, scope: :string, token: :string}
    required = ~w(user_id client_id redirect_uri)a
    optional = ~w(scope token)a

    {%{}, types}
    |> cast(attrs, required ++ optional)
    |> validate_required(required)
  end

  def get_client(client_id) do
    case Clients.get_client_with(client_id, [:connections, :client_type]) do
      %Client{} = client -> {:ok, client}
      _ -> Error.access_denied("Invalid client id.")
    end
  end

  defp validate_client_is_blocked(%Client{is_blocked: false}), do: :ok
  defp validate_client_is_blocked(%Client{is_blocked: true}), do: Error.access_denied("Client is blocked.")

  defp validate_redirect_uri(%{connections: connections}, redirect_uri) do
    err = Error.access_denied("The redirection URI provided does not match a pre-registered value.")

    Enum.reduce_while(connections, err, fn connection, acc ->
      case Regex.match?(RedirectUriChecker.generate_redirect_uri_regexp(connection.redirect_uri), redirect_uri) do
        true -> {:halt, :ok}
        false -> {:cont, acc}
      end
    end)
  end

  defp validate_scope_not_empty(scope) when is_binary(scope) and byte_size(scope) > 0, do: :ok

  defp validate_scope_not_empty(_scope) do
    Error.invalid_request("Requested scope is empty. Scope not passed or user has no roles or global roles.")
  end

  defp create_or_update_app(%User{} = user, %Client{} = client, scope) do
    case AppAPI.get_app_by(user_id: user.id, client_id: client.id) do
      nil ->
        {:ok, _} = AppAPI.create_app(%{user_id: user.id, client_id: client.id, scope: scope})

      app ->
        aggregated_scopes = String.split(scope, " ", trim: true) ++ String.split(app.scope, " ", trim: true)
        aggregated_scope = aggregated_scopes |> Enum.uniq() |> Enum.join(" ")

        AppAPI.update_app(app, %{scope: aggregated_scope})
    end

    :ok
  end

  defp create_token(user, client, scope, redirect_uri) do
    # get grant_type from token
    grant_type = "password"

    TokenAPI.create_authorization_code(%{
      user_id: user.id,
      details: %{
        client_id: client.id,
        grant_type: grant_type,
        redirect_uri: redirect_uri,
        scope_request: scope
      }
    })
  end
end
