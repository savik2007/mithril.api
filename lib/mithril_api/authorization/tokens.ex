defmodule Mithril.Authorization.Tokens do
  @moduledoc false

  import Ecto.{Query, Changeset}, warn: false

  alias Mithril.Error
  alias Mithril.Authorization.GrantType.{Password, RefreshToken, AccessToken2FA, AuthorizationCode, Signature}
  alias Mithril.{Error, Guardian}
  alias Mithril.{UserAPI, ClientAPI, TokenAPI}
  alias Mithril.UserAPI.User
  alias Mithril.TokenAPI.Token
  alias Mithril.ClientAPI.Client
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authorization.GrantType.{Password, AccessToken2FA}

  @direct ClientAPI.access_type(:direct)
  @broker ClientAPI.access_type(:broker)

  @refresh_token "refresh_token"
  @access_token "access_token"
  @access_token_2fa "2fa_access_token"
  @change_password_token "change_password_token"
  @authorization_code "authorization_code"

  @approve_factor "APPROVE_FACTOR"
  @type_field "request_authentication_factor_type"
  @factor_field "request_authentication_factor"


  @doc """
    Create new access_tokens based on grant_type the request came with
  """
  def create_by_grant_type(%{"grant_type" => grant_type} = params) when grant_type in ["password", "change_password"] do
    Password.authorize(params)
  end

  def create_by_grant_type(%{"grant_type" => "authorize_2fa_access_token"} = params) do
    AccessToken2FA.authorize(params)
  end

  def create_by_grant_type(%{"grant_type" => "refresh_2fa_access_token"} = params) do
    AccessToken2FA.refresh(params)
  end

  def create_by_grant_type(%{"grant_type" => "authorization_code"} = params) do
    AuthorizationCode.authorize(params)
  end

  def create_by_grant_type(%{"grant_type" => "digital_signature"} = params) do
    Signature.authorize(params)
  end

  def create_by_grant_type(%{"grant_type" => "refresh_token"} = params) do
    RefreshToken.authorize(params)
  end

  def create_by_grant_type(_) do
    Error.invalid_request("Request must include grant_type.")
  end

  def init_factor(attrs) do
    with :ok <- AccessToken2FA.validate_authorization_header(attrs),
         {:ok, token} <- validate_token(attrs["token_value"]),
         user <- UserAPI.get_user(token.user_id),
         {:ok, _} <- AccessToken2FA.validate_user(user),
         %Ecto.Changeset{valid?: true} <- factor_changeset(attrs),
         where_factor <- prepare_factor_where_clause(token, attrs),
         %Factor{} = factor <- Authentication.get_factor_by!(where_factor),
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
         {:ok, user} <- AccessToken2FA.validate_user(user),
         where_factor <- prepare_factor_where_clause(token),
         %Factor{} = factor <- Authentication.get_factor_by!(where_factor),
         :ok <- AccessToken2FA.verify_otp(token.details[@factor_field], token, attrs["otp"], user),
         {:ok, _} <- Authentication.update_factor(factor, %{"factor" => token.details[@factor_field]}),
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
    |> Authentication.validate_factor_format()
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

    with false <- expired?(token),
         _app <- Mithril.AppAPI.approval(token.user_id, token.details["client_id"]) do
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
         _app <- Mithril.AppAPI.approval(token.user_id, token.details["client_id"]),
         client <- ClientAPI.get_client!(token.details["client_id"]),
         :ok <- check_client_is_blocked(client),
         user <- UserAPI.get_user!(token.user_id),
         :ok <- check_user_is_blocked(user),
         {:ok, token} <- put_broker_scopes(token, client, api_key) do
      {:ok, token}
    else
      {:error, _} = err -> err
      _ -> Error.invalid_grant("Token expired or client approval was revoked.")
    end
  end

  def expired?(%Token{} = token) do
    token.expires_at <= :os.system_time(:seconds)
  end

  defp put_broker_scopes(token, client, api_key) do
    case Map.get(client.priv_settings, "access_type") do
      nil ->
        Error.access_denied("Client settings must contain access_type.")

      # Clients such as NHS Admin, MIS
      @direct ->
        {:ok, token}

      # Clients such as MSP, PHARMACY
      @broker ->
        api_key
        |> validate_api_key()
        |> fetch_client_by_secret()
        |> fetch_broker_scope()
        |> put_broker_scope_into_token_details(token)
    end
  end

  defp validate_api_key(api_key) when is_binary(api_key), do: api_key
  defp validate_api_key(_), do: Error.invalid_request("API-KEY header required.")

  defp fetch_client_by_secret({:error, _} = err), do: err

  defp fetch_client_by_secret(api_key) do
    case ClientAPI.get_client_by(secret: api_key) do
      %ClientAPI.Client{} = client ->
        client

      _ ->
        Error.invalid_request("API-KEY header is invalid.")
    end
  end

  defp fetch_broker_scope({:error, _} = err), do: err

  defp fetch_broker_scope(%ClientAPI.Client{priv_settings: %{"broker_scope" => broker_scope}}) do
    broker_scope
  end

  defp fetch_broker_scope(_) do
    Error.invalid_request("Incorrect broker settings.")
  end

  defp put_broker_scope_into_token_details({:error, _} = err, _token), do: err

  defp put_broker_scope_into_token_details(broker_scope, token) do
    details = Map.put(token.details, "broker_scope", broker_scope)
    {:ok, Map.put(token, :details, details)}
  end
end
