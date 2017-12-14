defmodule Mithril.Authorization.GrantType.Password do
  @moduledoc false
  import Ecto.Changeset

  alias Mithril.Error
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor

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
         {:ok, user} <- validate_user(user),
         {:ok, user} <- match_with_user_password(user, attrs["password"]),
         :ok <- validate_user_password(user),
         :ok <- validate_token_scope(client.client_type.scope, attrs["scope"]),
         factor <- Authentication.get_factor_by([user_id: user.id, is_active: true]),
         {:ok, token} <- create_access_token(factor, user, client, attrs["scope"]),
         {_, nil} <- Mithril.TokenAPI.deactivate_old_tokens(token),
         sms_send_response <- maybe_send_otp(user, factor, token),
         {:ok, next_step} <- map_next_step(sms_send_response)
      do
      {:ok, %{token: token, urgent: %{next_step: next_step}}}
    end
  end

  defp validate_user_password(%User{password_set_at: password_set_at}) do
    expiration_seconds = Confex.get_env(:mithril_api, :password)[:expiration] * 60 * 60 * 24
    expire_date = NaiveDateTime.add(password_set_at, expiration_seconds, :second)
    case NaiveDateTime.compare(expire_date, NaiveDateTime.utc_now()) do
      :gt -> :ok
      _ -> {:error, {:access_denied, "The password expired"}}
    end
  end

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

  def validate_user(%User{is_blocked: false} = user), do: {:ok, user}
  def validate_user(%User{is_blocked: true}), do: Error.user_blocked("User blocked.")
  def validate_user(_), do: {:error, {:access_denied, "Identity, password combination is wrong."}}

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
  defp set_login_error_counter(%User{} = user, counter) do
    UserAPI.merge_user_priv_settings(user, %{login_error_counter: counter})
  end

  defp validate_token_scope(client_scope, required_scope) do
    allowed_scopes = String.split(client_scope, " ", trim: true)
    required_scopes = String.split(required_scope, " ", trim: true)
    if Mithril.Utils.List.subset?(allowed_scopes, required_scopes) do
      :ok
    else
      Error.invalid_scope(allowed_scopes)
    end
  end

  defp create_access_token(%Factor{}, %User{} = user, client, scope) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "password",
        "client_id" => client.id,
        "scope" => "", # 2FA access token requires no scopes
        "scope_request" => scope,
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

  defp maybe_send_otp(user, %Factor{} = factor, token), do: Authentication.send_otp(user, factor, token)
  defp maybe_send_otp(_, _, _), do: {:ok, :request_app}

  def map_next_step(:ok), do: {:ok, @request_otp}
  def map_next_step({:ok, :request_app}), do: {:ok, @request_apps}
  def map_next_step({:error, :factor_not_set}), do: {:ok, @request_factor}
  def map_next_step({:error, :sms_not_sent}), do: {:error, {:service_unavailable, "SMS not sent. Try later"}}
  def map_next_step({:error, :otp_timeout}), do: Error.otp_timeout()
end
