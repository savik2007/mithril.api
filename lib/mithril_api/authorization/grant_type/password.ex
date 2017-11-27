defmodule Mithril.Authorization.GrantType.Password do
  @moduledoc false
  alias Mithril.Authorization.GrantType.Error, as: GrantTypeError
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authorization.GrantType.AccessToken2FA

  @request_otp "REQUEST_OTP"
  @request_apps "REQUEST_APPS"
  @request_factor "REQUEST_FACTOR"
  @resend_otp "RESEND_OTP"

  def next_step(:resend_otp), do: @resend_otp
  def next_step(:request_otp), do: @request_otp
  def next_step(:request_apps), do: @request_apps

  def authorize(%{"email" => email, "password" => password, "client_id" => client_id, "scope" => scope})
      when not (is_nil(email) or is_nil(password) or is_nil(client_id) or is_nil(scope))
    do
    client = Mithril.ClientAPI.get_client_with_type(client_id)

    case allowed_to_login?(client) do
      :ok ->
        user = Mithril.UserAPI.get_user_by([email: email])
        create_token(client, user, password, scope)
      {:error, message} ->
        GrantTypeError.invalid_client(message)
    end
  end
  def authorize(_) do
    message = "Request must include at least email, password, client_id and scope parameters."
    GrantTypeError.invalid_request(message)
  end

  defp allowed_to_login?(nil),
       do: {:error, "Invalid client id."}
  defp allowed_to_login?(client) do
    allowed_grant_types = Map.get(client.settings, "allowed_grant_types", [])

    if "password" in allowed_grant_types do
      :ok
    else
      {:error, "Client is not allowed to issue login token."}
    end
  end

  defp create_token(_, nil, _, _),
       do: GrantTypeError.invalid_grant("Identity not found.")
  defp create_token(client, user, password, scope) do
    with {:ok, user} <- match_with_user_password(user, password),
         {:ok, user} <- AccessToken2FA.validate_user(user),
         :ok <- validate_token_scope(client.client_type.scope, scope),
         factor <- Authentication.get_factor_by([user_id: user.id, is_active: true]),
         {:ok, token} <- create_access_token(factor, user, client, scope),
         {_, nil} <- Mithril.TokenAPI.deactivate_old_tokens(token)
      do
      next_step = case maybe_send_otp(factor, token) do
        :ok -> @request_otp
        {:ok, :request_app} -> @request_apps
        {:error, :factor_not_set} -> @request_factor
        {:error, :sms_not_sent} -> @resend_otp
      end
      {:ok, %{token: token, urgent: %{next_step: next_step}}}
    end
  end

  defp match_with_user_password(user, password) do
    if Comeonin.Bcrypt.checkpw(password, Map.get(user, :password, "")) do
      set_login_error_counter(user, 0)
      {:ok, user}
    else
      increase_login_error_counter_or_block_user(user)
      GrantTypeError.invalid_grant("Identity, password combination is wrong.")
    end
  end

  defp increase_login_error_counter_or_block_user(%User{} = user) do
    login_error = user.priv_settings.login_error_counter + 1
    login_error_max = Confex.get_env(:mithril_api, :"2fa")[:user_login_error_max]

    set_login_error_counter(user, login_error)
    if login_error_max <= login_error do
        UserAPI.block_user(user, "Passed invalid password more than USER_LOGIN_ERROR_MAX")
    end
  end
  defp set_login_error_counter(%User{priv_settings: priv_settings} = user, counter) do
    data = priv_settings
           |> Map.from_struct()
           |> Map.put(:login_error_counter, counter)
    UserAPI.update_user_priv_settings(user, data)
  end

  defp validate_token_scope(client_scope, required_scope) do
    allowed_scopes = String.split(client_scope, " ", trim: true)
    required_scopes = String.split(required_scope, " ", trim: true)
    if Mithril.Utils.List.subset?(allowed_scopes, required_scopes) do
      :ok
    else
      GrantTypeError.invalid_scope(allowed_scopes)
    end
  end

  defp create_access_token(%Factor{}, %User{} = user, client, _scope) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "password",
        "client_id" => client.id,
        "scope" => "", # 2FA access token requires no scopes
        "redirect_uri" => client.redirect_uri
      }
    }
    Mithril.TokenAPI.create_2fa_access_token(data)
  end
  defp create_access_token(_factor, %User{} = user, client, scope) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "password",
        "client_id" => client.id,
        "scope" => scope,
        "redirect_uri" => client.redirect_uri
      }
    }
    Mithril.TokenAPI.create_access_token(data)
  end

  defp maybe_send_otp(%Factor{} = factor, token), do: Authentication.send_otp(factor, token)
  defp maybe_send_otp(_, _), do: {:ok, :request_app}
end
