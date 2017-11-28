defmodule Mithril.Authorization.GrantType.Password do
  @moduledoc false
  import Ecto.Changeset

  alias Mithril.Authorization.GrantType.Error, as: GrantTypeError
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authorization.GrantType.AccessToken2FA

  @request_otp "REQUEST_OTP"
  @request_apps "REQUEST_APPS"
  @request_factor "REQUEST_FACTOR"

  def next_step(:request_otp), do: @request_otp
  def next_step(:request_apps), do: @request_apps


  def authorize(attrs) do
    with %Ecto.Changeset{valid?: true} <- changeset(attrs),
         client <- Mithril.ClientAPI.get_client_with_type(attrs["client_id"]),
         :ok <- validate_client(client),
         user <- Mithril.UserAPI.get_user_by([email: attrs["email"]]),
         {:ok, user} <- AccessToken2FA.validate_user(user),
         {:ok, user} <- match_with_user_password(user, attrs["password"]),
         :ok <- validate_token_scope(client.client_type.scope, attrs["scope"]),
         factor <- Authentication.get_factor_by([user_id: user.id, is_active: true]),
         {:ok, token} <- create_access_token(factor, user, client, attrs["scope"]),
         {_, nil} <- Mithril.TokenAPI.deactivate_old_tokens(token),
         sms_send_response <- maybe_send_otp(factor, token),
         {:ok, next_step} <- map_next_step(sms_send_response)
      do
      {:ok, %{token: token, urgent: %{next_step: next_step}}}
    end
  end

#  def authorize(%{"email" => email, "password" => password, "client_id" => client_id, "scope" => scope})
#      when not (is_nil(email) or is_nil(password) or is_nil(client_id) or is_nil(scope))
#    do
#    client = Mithril.ClientAPI.get_client_with_type(client_id)
#
#    case allowed_to_login?(client) do
#      :ok ->
#        user = Mithril.UserAPI.get_user_by([email: email])
#        create_token(client, user, password, scope)
#      {:error, message} ->
#        GrantTypeError.invalid_client(message)
#    end
#  end

  defp changeset(attrs) do
    types = %{email: :string, password: :string, client_id: :string, scope: :string}

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(Map.keys(types))
  end

  defp validate_client(nil) do
    {:error, {:access_denied, "Invalid client id."}}
  end
  defp validate_client(client) do
    case "password" in Map.get(client.settings, "allowed_grant_types", []) do
      true -> :ok
      false -> {:error, {:access_denied, "Client is not allowed to issue login token."}}
    end
  end

  defp match_with_user_password(user, password) do
    if Comeonin.Bcrypt.checkpw(password, Map.get(user, :password, "")) do
      set_login_error_counter(user, 0)
      {:ok, user}
    else
      increase_login_error_counter_or_block_user(user)
      {:error, {:access_denied, "Identity, password combination is wrong."}}
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

  def map_next_step(:ok), do: {:ok, @request_otp}
  def map_next_step({:ok, :request_app}), do: {:ok, @request_apps}
  def map_next_step({:error, :factor_not_set}), do: {:ok, @request_factor}
  def map_next_step({:error, :sms_not_sent}), do: {:error, {:service_unavailable, "SMS not send. Try later"}}
end
