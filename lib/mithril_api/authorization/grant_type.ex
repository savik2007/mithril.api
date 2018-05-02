defmodule Mithril.Authorization.GrantType do
  @moduledoc false

  alias Mithril.{ClientAPI, Error}
  alias Mithril.UserAPI.User
  alias Mithril.ClientAPI.Client
  alias Mithril.ClientTypeAPI.ClientType

  @scope_app_authorize "app:authorize"
  @trusted_client_id "30074b6e-fbab-4dc1-9d37-88c21dab1847"

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

  def trusted_client_id, do: @trusted_client_id
  def scope_app_authorize, do: @scope_app_authorize

  def fetch_client(client_id) do
    client_id
    |> ClientAPI.get_client_with_type()
    |> validate_client_is_blocked()
  end

  defp validate_client_is_blocked(%Client{is_blocked: false} = client), do: {:ok, client}
  defp validate_client_is_blocked(%Client{is_blocked: true}), do: Error.access_denied("Client is blocked.")
  defp validate_client_is_blocked(_), do: Error.access_denied("Invalid client id.")

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
  def prepare_scope_by_client(%Client{id: @trusted_client_id}, %User{roles: user_roles}, nil) do
    join_user_role_scopes(user_roles)
  end

  def prepare_scope_by_client(_client_id, _user, scope), do: scope

  defp join_user_role_scopes(user_roles), do: Enum.map_join(user_roles, " ", & &1.scope)
end
