defmodule Mithril.Authorization.GrantType.Password do
  @moduledoc false
  import Ecto.Changeset

  alias Mithril.Error
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authorization.LoginHistory

  @request_otp "REQUEST_OTP"
  @request_apps "REQUEST_APPS"
  @request_factor "REQUEST_FACTOR"

  @grant_type_password "password"
  @grant_type_change_password "change_password"

  def next_step(:request_otp), do: @request_otp
  def next_step(:request_apps), do: @request_apps

  def authorize(attrs) do
    grant_type = Map.get(attrs, "grant_type", @grant_type_password)

    with %Ecto.Changeset{valid?: true} <- changeset(attrs),
         client <- Mithril.ClientAPI.get_client_with_type(attrs["client_id"]),
         :ok <- validate_client(client),
         user <- UserAPI.get_user_by(email: attrs["email"]),
         {:ok, user} <- validate_user(user),
         :ok <- LoginHistory.check_failed_login(user, LoginHistory.type(:password)),
         {:ok, user} <- match_with_user_password(user, attrs["password"]),
         :ok <- validate_user_password(user, grant_type),
         :ok <- validate_token_scope_by_client(client.client_type.scope, attrs["scope"]),
         :ok <- validate_token_scope_by_grant(grant_type, attrs["scope"]),
         factor <- Authentication.get_factor_by(user_id: user.id, is_active: true),
         {:ok, token} <- create_token_by_grant_type(factor, user, client, attrs["scope"], grant_type),
         {_, nil} <- Mithril.TokenAPI.deactivate_old_tokens(token),
         sms_send_response <- maybe_send_otp(user, factor, token),
         {:ok, next_step} <- map_next_step(sms_send_response) do
      {:ok, %{token: token, urgent: %{next_step: next_step}}}
    end
  end

  defp validate_user_password(_, @grant_type_change_password), do: :ok

  defp validate_user_password(%User{id: id, password_set_at: password_set_at}, _grant_type) do
    expiration_seconds = Confex.get_env(:mithril_api, :password)[:expiration] * 60 * 60 * 24
    expire_date = NaiveDateTime.add(password_set_at, expiration_seconds, :second)

    case NaiveDateTime.compare(expire_date, NaiveDateTime.utc_now()) do
      :gt -> :ok
      _ -> {:error, {:password_expired, "The password expired for user: #{id}"}}
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
      LoginHistory.clear_logins(user, LoginHistory.type(:password))
      {:ok, user}
    else
      LoginHistory.add_failed_login(user, LoginHistory.type(:password))
      {:error, {:access_denied, "Identity, password combination is wrong."}}
    end
  end

  defp validate_token_scope_by_client(client_scope, requested_scope) do
    allowed_scopes = String.split(client_scope, " ", trim: true)
    requested_scopes = String.split(requested_scope, " ", trim: true)

    case Mithril.Utils.List.subset?(allowed_scopes, requested_scopes) do
      true -> :ok
      _ -> Error.invalid_scope(allowed_scopes)
    end
  end

  defp validate_token_scope_by_grant(@grant_type_change_password, "user:change_password"), do: :ok
  defp validate_token_scope_by_grant(@grant_type_change_password, _), do: Error.invalid_scope(["user:change_password"])
  defp validate_token_scope_by_grant(_, _requested_scope), do: :ok

  defp create_token_by_grant_type(%Factor{}, %User{} = user, client, scope, grant_type) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => grant_type,
        "client_id" => client.id,
        # 2FA access token requires no scopes
        "scope" => "",
        "scope_request" => scope,
        "redirect_uri" => client.redirect_uri
      }
    }

    Mithril.TokenAPI.create_2fa_access_token(data)
  end

  defp create_token_by_grant_type(_factor, %User{} = user, client, scope, @grant_type_password) do
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

  defp create_token_by_grant_type(_factor, %User{} = user, client, scope, @grant_type_change_password) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "change_password",
        "client_id" => client.id,
        "scope" => scope,
        "redirect_uri" => client.redirect_uri
      }
    }

    Mithril.TokenAPI.create_change_password_token(data)
  end

  defp maybe_send_otp(user, %Factor{} = factor, token), do: Authentication.send_otp(user, factor, token)
  defp maybe_send_otp(_, _, _), do: {:ok, :request_app}

  def map_next_step(:ok), do: {:ok, @request_otp}
  def map_next_step({:ok, :request_app}), do: {:ok, @request_apps}
  def map_next_step({:error, :factor_not_set}), do: {:ok, @request_factor}
  def map_next_step({:error, :sms_not_sent}), do: {:error, {:service_unavailable, "SMS not sent. Try later"}}
  def map_next_step({:error, :otp_timeout}), do: Error.otp_timeout()
end
