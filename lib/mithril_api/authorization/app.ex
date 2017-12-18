defmodule Mithril.Authorization.App do
  @moduledoc false

  alias Mithril.Error
  alias Mithril.ClientAPI.Client
  alias Mithril.Utils.RedirectUriChecker

  # NOTE: Mark password token as used.
  #
  # On every approval a new token is created.
  # Current (session) token with it's scopes is still valid until it expires.
  # E.g. session expiration should be sufficiently short.
  def grant(%{"user_id" => _, "client_id" => _, "redirect_uri" => _, "scope" => _} = params) do
    params
    |> find_client()
    |> check_client_is_blocked()
    |> find_user()
    |> validate_redirect_uri()
    |> validate_client_scope()
    |> validate_user_scope()
    |> update_or_create_app()
    |> create_token()
  end
  def grant(_) do
    message = "Request must include at least client_id, redirect_uri and scopes parameters."
    Error.invalid_request(message)
  end

  defp find_client(%{"client_id" => client_id} = params) do
    case Mithril.ClientAPI.get_client_with_type(client_id) do
      nil -> Error.invalid_client("Client not found.")
      client -> Map.put(params, "client", client)
    end
  end

  defp find_user({:error, _} = err), do: err
  defp find_user(%{"user_id" => user_id, "client" => %{id: client_id}} = params) do
    case Mithril.UserAPI.get_full_user(user_id, client_id) do
      nil -> Error.invalid_user("User not found.")
      user -> Map.put(params, "user", user)
    end
  end

  defp validate_redirect_uri({:error, _} = err), do: err
  defp validate_redirect_uri(%{"client" => client, "redirect_uri" => redirect_uri} = params) do
    if Regex.match?(RedirectUriChecker.generate_redirect_uri_regexp(client.redirect_uri), redirect_uri) do
      params
    else
      message = "The redirection URI provided does not match a pre-registered value."
      Error.access_denied(message)
    end
  end

  defp validate_client_scope({:error, _} = err), do: err
  defp validate_client_scope(%{"client" => %{client_type: %{scope: client_type_scope}}, "scope" => scope} = params) do
    allowed_scopes = String.split(client_type_scope, " ", trim: true)
    requested_scopes = String.split(scope, " ", trim: true)
    if Mithril.Utils.List.subset?(allowed_scopes, requested_scopes) do
      params
    else
      message = "Scope is not allowed by client type."
      Error.invalid_request(message)
    end
  end

  defp validate_user_scope({:error, _} = err), do: err
  defp validate_user_scope(%{"user" => %{roles: user_roles}, "scope" => scope} = params) do
    allowed_scopes = user_roles |> Enum.map_join(" ", &(&1.scope)) |> String.split(" ", trim: true)
    requested_scopes = String.split(scope, " ", trim: true)
    if Mithril.Utils.List.subset?(allowed_scopes, requested_scopes) do
      params
    else
      message = "User requested scope that is not allowed by role based access policies."
      Error.invalid_request(message)
    end
  end

  defp update_or_create_app({:error, _} = err), do: err
  defp update_or_create_app(%{"user" => user, "client_id" => client_id, "scope" => scope} = params) do
    app =
      case Mithril.AppAPI.get_app_by([user_id: user.id, client_id: client_id]) do
        nil ->
          {:ok, app} = Mithril.AppAPI.create_app(%{user_id: user.id, client_id: client_id, scope: scope})

          app
        app ->
          aggregated_scopes = String.split(scope, " ", trim: true) ++ String.split(app.scope, " ", trim: true)
          aggregated_scope = aggregated_scopes |> Enum.uniq() |> Enum.join(" ")

          Mithril.AppAPI.update_app(app, %{scope: aggregated_scope})
      end

    Map.put(params, "app", app)
  end

  defp create_token({:error, _} = err), do: err
  defp create_token(%{"user" => user, "client" => client, "redirect_uri" => redirect_uri, "scope" => scope} = params) do
    {:ok, token} =
      Mithril.TokenAPI.create_authorization_code(%{
        user_id: user.id,
        details: %{
          client_id: client.id,
          grant_type: "password",
          redirect_uri: redirect_uri,
          scope_request: scope
        }
      })

    Map.put(params, "token", token)
  end

  defp check_client_is_blocked({:error, _} = err), do: err
  defp check_client_is_blocked(%{"client" => %Client{is_blocked: false}} = params), do: params
  defp check_client_is_blocked(%{"client" => _client}), do: Error.access_denied("Authentication failed")
end
