defmodule Mithril.Authorization do
  @moduledoc false

  import Ecto.Changeset
  import Mithril.Authorization.GrantType

  alias Ecto.UUID
  alias Mithril.{AppAPI, ClientAPI, UserAPI, Error}
  alias Mithril.UserAPI.User
  alias Mithril.ClientAPI.Client
  alias Mithril.Utils.RedirectUriChecker

  @trusted_client_id trusted_client_id()

  # NOTE: Mark password token as used.
  #
  # On every approval a new token is created.
  # Current (session) token with it's scopes is still valid until it expires.
  # E.g. session expiration should be sufficiently short.
  def create_approval(params) do
    with %Ecto.Changeset{valid?: true} = changeset <- changeset(params),
         client_id <- get_change(changeset, :client_id),
         {:ok, client} <- fetch_client(client_id),
         # user validation
         user <- UserAPI.get_full_user(get_change(changeset, :user_id), client_id),
         :ok <- validate_user_is_blocked(user),
         # client validation
         {:ok, scope} <- prepare_scope_by_client(client, user, get_change(changeset, :scope)),
         redirect_uri <- get_change(changeset, :redirect_uri),
         :ok <- validate_redirect_uri(client, redirect_uri),
         # scope validation
         :ok <- validate_client_allowed_scope(client, scope),
         :ok <- validate_user_allowed_scope(user, scope),
         # entities creation
         :ok <- create_or_update_app(user, client, scope),
         {:ok, token} <- create_token(user, client, scope, redirect_uri) do
      {:ok, %{token: token, urgent: %{redirect_uri: redirect_uri}}}
    end
  end

  defp changeset(attrs) do
    types = %{user_id: UUID, client_id: UUID, redirect_uri: :string, scope: :string}
    required = ~w(user_id client_id redirect_uri)a
    optional = ~w(scope)a

    {%{}, types}
    |> cast(attrs, required ++ optional)
    |> validate_required(required)
  end

  defp validate_redirect_uri(%{} = client, redirect_uri) do
    if Regex.match?(RedirectUriChecker.generate_redirect_uri_regexp(client.redirect_uri), redirect_uri) do
      :ok
    else
      message = "The redirection URI provided does not match a pre-registered value."
      Error.access_denied(message)
    end
  end

  defp create_or_update_app(%User{} = user, %Client{} = client, scope) do
    case AppAPI.get_app_by(user_id: user.id, client_id: client.id) do
      nil ->
        {:ok, app} = AppAPI.create_app(%{user_id: user.id, client_id: client.id, scope: scope})

      app ->
        aggregated_scopes = String.split(scope, " ", trim: true) ++ String.split(app.scope, " ", trim: true)
        aggregated_scope = aggregated_scopes |> Enum.uniq() |> Enum.join(" ")

        AppAPI.update_app(app, %{scope: aggregated_scope})
    end
    :ok
  end

  defp create_token(user, %Client{id: @trusted_client_id} = client, scope, redirect_uri) do
    # get grant_type from token
    grant_type = "password"

    Mithril.TokenAPI.create_authorization_code(%{
      user_id: user.id,
      details: %{
        client_id: client.id,
        grant_type: "password",
        redirect_uri: redirect_uri,
        scope_request: scope
      }
    })
  end

  defp create_token(user, %Client{id: @trusted_client_id} = client, scope, redirect_uri) do
    Mithril.TokenAPI.create_authorization_code(%{
      user_id: user.id,
      details: %{
        client_id: client.id,
        grant_type: "password",
        redirect_uri: redirect_uri,
        scope_request: scope
      }
    })
  end
end
