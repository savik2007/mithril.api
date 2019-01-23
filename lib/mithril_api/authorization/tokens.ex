defmodule Mithril.Authorization.Tokens do
  @moduledoc false

  import Ecto.{Query, Changeset}, warn: false

  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authentication.Factors
  alias Mithril.Authorization.BrokerScope
  alias Mithril.Authorization.GrantType
  alias Mithril.Authorization.GrantType.AccessToken2FA
  alias Mithril.Authorization.GrantType.AuthorizationCode
  alias Mithril.Authorization.GrantType.Password
  alias Mithril.Authorization.GrantType.RefreshToken
  alias Mithril.Authorization.GrantType.Signature
  alias Mithril.Clients
  alias Mithril.Clients.Client
  alias Mithril.Error
  alias Mithril.TokenAPI
  alias Mithril.TokenAPI.Token
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User

  @access_token TokenAPI.token_type(:access)
  @access_token_2fa TokenAPI.token_type(:access_2fa)

  @approve_factor "APPROVE_FACTOR"
  @type_field "request_authentication_factor_type"
  @factor_field "request_authentication_factor"

  @grant_type_2fa_authorize "authorize_2fa_access_token"

  def grant_type(:"2fa_auth"), do: @grant_type_2fa_authorize

  @doc """
    Create new access_tokens based on grant_type from request
  """
  def create_by_grant_type(params, :all), do: create_by_grant_type(params)

  def create_by_grant_type(%{"grant_type" => grant_type} = params, allowed_grant_types) do
    case grant_type in allowed_grant_types do
      true -> create_by_grant_type(params)
      false -> Error.invalid_grant("Grant type not allowed.")
    end
  end

  def create_by_grant_type(_, _), do: Error.invalid_request("Request must include grant_type.")

  def create_by_grant_type(%{"grant_type" => grant_type} = params)
      when grant_type in ["password", "change_password"],
      do: Password.authorize(params)

  def create_by_grant_type(%{"grant_type" => @grant_type_2fa_authorize} = params), do: AccessToken2FA.authorize(params)

  def create_by_grant_type(%{"grant_type" => "refresh_2fa_access_token"} = params), do: AccessToken2FA.refresh(params)

  def create_by_grant_type(%{"grant_type" => "authorization_code"} = params), do: AuthorizationCode.authorize(params)

  def create_by_grant_type(%{"grant_type" => "digital_signature"} = params), do: Signature.authorize(params)

  def create_by_grant_type(%{"grant_type" => "refresh_token"} = params), do: RefreshToken.authorize(params)

  def create_by_grant_type(_), do: Error.invalid_request("Request must include grant_type.")

  def init_factor(attrs) do
    with :ok <- AccessToken2FA.validate_authorization_header(attrs),
         {:ok, token} <- validate_token(attrs["token_value"]),
         user <- UserAPI.get_user(token.user_id),
         :ok <- GrantType.validate_user_is_blocked(user),
         %Ecto.Changeset{valid?: true} <- factor_changeset(attrs),
         where_factor <- prepare_factor_where_clause(token, attrs),
         %Factor{} = factor <- Factors.get_factor_by!(where_factor),
         :ok <- validate_token_type(token, factor),
         token_data <- prepare_2fa_token_data(token, attrs),
         {:ok, token_2fa} <- TokenAPI.create_2fa_access_token(token_data),
         factor <- %Factor{factor: attrs["factor"], type: Authentication.type(:sms)},
         :ok <- Authentication.send_otp(user, factor, token_2fa),
         {_, nil} <- TokenAPI.deactivate_old_tokens(token_2fa) do
      {:ok, %{token: token_2fa, urgent: %{next_step: @approve_factor}}}
    else
      {:error, :sms_not_sent} -> {:error, {:service_unavailable, "SMS not sent. Try later"}}
      {:error, :otp_timeout} -> Error.otp_timeout()
      err -> err
    end
  end

  def approve_factor(attrs) do
    with :ok <- AccessToken2FA.validate_authorization_header(attrs),
         {:ok, token} <- validate_token(attrs["token_value"]),
         :ok <- validate_approve_token(token),
         user <- UserAPI.get_user(token.user_id),
         :ok <- GrantType.validate_user_is_blocked(user),
         where_factor <- prepare_factor_where_clause(token),
         %Factor{} = factor <- Factors.get_factor_by!(where_factor),
         :ok <- AccessToken2FA.verify_otp(token.details[@factor_field], token, attrs["otp"], user),
         {:ok, _} <- Factors.update_factor(factor, %{"factor" => token.details[@factor_field]}),
         {:ok, token_2fa} <- create_token_by_grant_type(token),
         {_, nil} <- TokenAPI.deactivate_old_tokens(token_2fa) do
      {:ok, token_2fa}
    end
  end

  defp factor_changeset(attrs) do
    types = %{type: :string, factor: :string}

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(Map.keys(types))
    |> validate_inclusion(:type, [Authentication.type(:sms)])
    |> Factors.validate_factor_format()
  end

  defp validate_token(token_value) do
    with %Token{} = token <- TokenAPI.get_token_by(value: token_value),
         false <- expired?(token) do
      {:ok, token}
    else
      true -> Error.token_expired()
      nil -> Error.token_invalid()
    end
  end

  defp validate_approve_token(%Token{details: %{@factor_field => _, @type_field => _}}), do: :ok
  defp validate_approve_token(_), do: Error.access_denied("Invalid token type. Init factor at first")

  defp validate_token_type(%Token{name: @access_token_2fa}, %Factor{factor: v}) when is_nil(v) or "" == v, do: :ok
  defp validate_token_type(%Token{name: @access_token}, %Factor{factor: val}) when byte_size(val) > 0, do: :ok
  defp validate_token_type(_, _), do: Error.token_invalid_type()

  defp prepare_factor_where_clause(%Token{user_id: user_id, details: %{@type_field => type}}) do
    [user_id: user_id, is_active: true, type: type]
  end

  defp prepare_factor_where_clause(%Token{} = token, %{"type" => type}) do
    [user_id: token.user_id, is_active: true, type: type]
  end

  defp create_token_by_grant_type(%Token{details: %{"grant_type" => "change_password"}} = token) do
    token
    |> prepare_token_data("user:change_password")
    |> TokenAPI.create_change_password_token()
  end

  defp create_token_by_grant_type(%Token{} = token) do
    token
    |> prepare_token_data("app:authorize")
    |> TokenAPI.create_access_token()
  end

  defp prepare_token_data(%Token{details: details} = token, default_scope) do
    # changing 2FA token to access token
    # creates token with scope that stored in detais.scope_request
    scope = Map.get(details, "scope_request", default_scope)

    details =
      details
      |> Map.drop(["request_authentication_factor", "request_authentication_factor_type"])
      |> Map.put("scope", scope)

    %{user_id: token.user_id, details: details}
  end

  defp prepare_2fa_token_data(%Token{} = token, attrs) do
    %{
      user_id: token.user_id,
      details:
        Map.merge(token.details, %{
          request_authentication_factor: attrs["factor"],
          request_authentication_factor_type: attrs["type"]
        })
    }
  end

  def verify(token_value) do
    token = TokenAPI.get_token_by_value!(token_value)

    with false <- expired?(token) do
      # if token is authorization_code or password - make sure was not used previously
      {:ok, token}
    else
      _ ->
        Error.invalid_grant("Token expired or client approval was revoked.")
    end
  end

  defp check_client_is_blocked(%Client{is_blocked: false}), do: :ok

  defp check_client_is_blocked(_) do
    Error.invalid_client("Authentication failed.")
  end

  defp check_user_is_blocked(%User{is_blocked: false}), do: :ok

  defp check_user_is_blocked(_) do
    Error.invalid_user("Authentication failed.")
  end

  def verify_client_token(token_value, api_key) do
    token = TokenAPI.get_token_by_value!(token_value)

    with false <- expired?(token),
         client <- Clients.get_client!(token.details["client_id"]),
         :ok <- check_client_is_blocked(client),
         user <- UserAPI.get_user!(token.user_id),
         :ok <- check_user_is_blocked(user),
         {:ok, token, mis_client_id} <- BrokerScope.put_broker_scope_into_token_details(token, client, api_key) do
      {:ok, token, mis_client_id}
    else
      {:error, _} = err -> err
      _ -> Error.invalid_grant("Token expired or client approval was revoked.")
    end
  end

  def expired?(%Token{} = token) do
    token.expires_at <= :os.system_time(:seconds)
  end
end
