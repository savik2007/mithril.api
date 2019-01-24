defmodule Mithril.Authorization.GrantType do
  @moduledoc false

  alias Mithril.AppAPI
  alias Mithril.AppAPI.App
  alias Mithril.Clients
  alias Mithril.Clients.Client
  alias Mithril.Clients.Connection
  alias Mithril.ClientTypeAPI.ClientType
  alias Mithril.Error
  alias Mithril.TokenAPI
  alias Mithril.TokenAPI.Token
  alias Mithril.UserAPI.User

  @scope_app_authorize "app:authorize"

  @request_api "REQUEST_API"
  @request_otp "REQUEST_OTP"
  @request_apps "REQUEST_APPS"
  @request_factor "REQUEST_FACTOR"
  @request_ds "REQUEST_LOGIN_VIA_DS"

  def next_step(:request_ds), do: @request_ds
  def next_step(:request_otp), do: @request_otp
  def next_step(:request_api), do: @request_api
  def next_step(:request_apps), do: @request_apps
  def next_step(:request_factor), do: @request_factor

  def scope_app_authorize, do: @scope_app_authorize

  def get_connection(client_id, secret) do
    case Clients.get_connection_with_client_by(client_id: client_id, secret: secret) do
      %Connection{} = connection -> {:ok, connection}
      _ -> Error.invalid_client("Invalid client id or secret.")
    end
  end

  def get_token(code, name) do
    case TokenAPI.get_token_by(value: code, name: name) do
      %Token{} = token -> {:ok, token}
      _ -> Error.token_not_found()
    end
  end

  def validate_token_expiration(token) do
    case TokenAPI.expired?(token) do
      true -> Error.token_expired()
      false -> :ok
    end
  end

  def validate_approval_authorization(token) do
    case AppAPI.approval(token.user_id, token.details["client_id"]) do
      %App{} = approval -> {:ok, approval}
      _ -> Error.access_denied("Resource owner revoked access for the client.")
    end
  end

  def validate_user_is_blocked(%User{is_blocked: false}), do: :ok
  def validate_user_is_blocked(%User{is_blocked: true}), do: Error.user_blocked("User blocked.")
  def validate_user_is_blocked(_), do: {:error, {:access_denied, "User not found."}}

  def validate_client_allowed_grant_types(nil, _grant_type), do: Error.invalid_client("Invalid client id.")

  def validate_client_allowed_grant_types(%Client{} = client, grant_type) do
    case grant_type in Map.get(client.settings, "allowed_grant_types", []) do
      true -> :ok
      false -> {:error, {:access_denied, "Client is not allowed to issue login token."}}
    end
  end

  def validate_client_allowed_scope(%Client{client_type: %ClientType{} = client_type}, requested_scope) do
    case requested_scope_allowed?(client_type.scope, requested_scope) do
      true -> :ok
      false -> Error.invalid_request("Scope is not allowed by client type.")
    end
  end

  def validate_user_allowed_scope(%User{roles: user_roles, global_roles: global_roles}, requested_scope) do
    case requested_scope_allowed?(join_user_role_scopes(user_roles ++ global_roles), requested_scope) do
      true -> :ok
      false -> Error.invalid_request("User requested scope that is not allowed by role based access policies.")
    end
  end

  def requested_scope_allowed?(allowed_scope, requested_scope) do
    allowed_scope = String.split(allowed_scope, " ", trim: true)
    requested_scope = String.split(requested_scope, " ", trim: true)
    Mithril.Utils.List.subset?(allowed_scope, requested_scope)
  end

  @doc """
  Fetch scope by itself for trusted Client and empty scope param
  """
  def prepare_scope_by_client(%Client{id: id}, %User{roles: user_roles, global_roles: global_roles}, nil) do
    trusted_client_ids = Confex.get_env(:mithril_api, :trusted_clients)

    case id in trusted_client_ids do
      true -> join_user_role_scopes(user_roles ++ global_roles)
      false -> ""
    end
  end

  def prepare_scope_by_client(_client, _user, scope), do: scope

  defp join_user_role_scopes(user_roles), do: Enum.map_join(user_roles, " ", & &1.scope)
end
