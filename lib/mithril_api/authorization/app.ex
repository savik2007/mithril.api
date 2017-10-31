defmodule Mithril.Authorization.App do
  @moduledoc false

  alias Mithril.ClientAPI
  alias Mithril.ClientAPI.Client

  @direct ClientAPI.access_type(:direct)
  @broker ClientAPI.access_type(:broker)

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
    |> validate_access_type()
    |> validate_redirect_uri()
    |> validate_client_scope()
    |> validate_user_scope()
    |> update_or_create_app()
    |> create_token()
  end
  def grant(_) do
    message = "Request must include at least client_id, redirect_uri and scopes parameters."
    {:error, :bad_request, %{invalid_client: message}}
  end

  defp find_client(%{"client_id" => client_id} = params) do
    case Mithril.ClientAPI.get_client_with_type(client_id) do
      nil -> {:error, :unprocessable_entity, %{invalid_client: "Client not found."}}
      client -> Map.put(params, "client", client)
    end
  end

  defp find_user({:error, status, errors}), do: {:error, status, errors}
  defp find_user(%{"user_id" => user_id, "client" => %{id: client_id}} = params) do
    case Mithril.UserAPI.get_full_user(user_id, client_id) do
      nil -> {:error, :unprocessable_entity, %{invalid_client: "User not found."}}
      user -> Map.put(params, "user", user)
    end
  end

  defp validate_access_type({:error, status, errors}), do: {:error, status, errors}
  defp validate_access_type(%{"client" => client} = params) do
    case Map.get(client.priv_settings, "access_type") do
      nil -> {:error, :unprocessable_entity, %{invalid_client: "Client settings must contain access_type."}}

      # Clients such as NHS Admin, MIS
      @direct -> params

      # Clients such as MSP, PHARMACY
      @broker ->
        params
        |> validate_api_key()
        |> find_broker()
        |> validate_broker_scope(params)
    end
  end

  defp validate_api_key(%{"api_key" => api_key}) when is_binary(api_key), do: api_key
  defp validate_api_key(_), do: {:error, :unprocessable_entity, %{api_key: "API-KEY header required."}}

  defp find_broker({:error, status, errors}), do: {:error, status, errors}
  defp find_broker(api_key) do
    case ClientAPI.get_client_broker_by_secret(api_key) do
      %ClientAPI.Client{} = broker -> broker
      _ -> {:error, :unprocessable_entity, %{api_key: "Incorrect broker settings."}}
    end
  end

  defp validate_redirect_uri({:error, status, errors}), do: {:error, status, errors}
  defp validate_redirect_uri(%{"client" => client, "redirect_uri" => redirect_uri} = params) do
    if String.starts_with?(redirect_uri, client.redirect_uri) do
      params
    else
      message = "The redirection URI provided does not match a pre-registered value."
      {:error, :unprocessable_entity, %{invalid_client: message}}
    end
  end

  defp validate_client_scope({:error, status, errors}), do: {:error, status, errors}
  defp validate_client_scope(%{"client" => %{client_type: %{scope: client_type_scope}}, "scope" => scope} = params) do
    allowed_scopes = String.split(client_type_scope, " ", trim: true)
    requested_scopes = String.split(scope, " ", trim: true)
    if Mithril.Utils.List.subset?(allowed_scopes, requested_scopes) do
      params
    else
      message = "Scope is not allowed by client type."
      {:error, :unprocessable_entity, %{invalid_client: message}}
    end
  end

  defp validate_user_scope({:error, status, errors}), do: {:error, status, errors}
  defp validate_user_scope(%{"user" => %{roles: user_roles}, "scope" => scope} = params) do
    allowed_scopes = user_roles |> Enum.map_join(" ", &(&1.scope)) |> String.split(" ", trim: true)
    requested_scopes = String.split(scope, " ", trim: true)
    if Mithril.Utils.List.subset?(allowed_scopes, requested_scopes) do
      params
    else
      message = "User requested scope that is not allowed by role based access policies."
      {:error, :unprocessable_entity, %{invalid_client: message}}
    end
  end

  defp validate_broker_scope({:error, status, errors}, _), do: {:error, status, errors}
  defp validate_broker_scope(broker, %{"scope" => scope} = params) do
    allowed_scopes = String.split(broker.priv_settings["broker_scope"], " ", trim: true)
    requested_scopes = String.split(scope, " ", trim: true)
    if Mithril.Utils.List.subset?(allowed_scopes, requested_scopes) do
      params
    else
      message = "Scope is not allowed by broker."
      {:error, :unprocessable_entity, %{scope: message}}
    end
  end

  defp update_or_create_app({:error, status, errors}), do: {:error, status, errors}
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

  defp create_token({:error, status, errors}), do: {:error, status, errors}
  defp create_token(%{"user" => user, "client" => client, "redirect_uri" => redirect_uri, "scope" => scope} = params) do
    {:ok, token} =
      Mithril.TokenAPI.create_authorization_code(%{
        user_id: user.id,
        details: %{
          client_id: client.id,
          grant_type: "password",
          redirect_uri: redirect_uri,
          scope: scope
        }
      })

    Map.put(params, "token", token)
  end

  defp check_client_is_blocked({:error, status, errors}), do: {:error, status, errors}
  defp check_client_is_blocked(%{"client" => %Client{is_blocked: false}} = params), do: params
  defp check_client_is_blocked(%{"client" => _client}) do
    {:error, :unauthorized, %{invalid_client: "Authentication failed"}}
  end
end
