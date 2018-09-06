defmodule Mithril.Authorization.GrantType.Password do
  @moduledoc false

  import Ecto.Changeset
  import Mithril.Authorization.GrantType

  alias Comeonin.Bcrypt
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authentication.Factors
  alias Mithril.Authorization.LoginHistory
  alias Mithril.Clients
  alias Mithril.ClientTypeAPI.ClientType
  alias Mithril.Error
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.TokenAPI

  @grant_type_password "password"
  @grant_type_change_password "change_password"

  @cabinet_client_type ClientType.client_type(:cabinet)

  def authorize(attrs) do
    grant_type = Map.get(attrs, "grant_type", @grant_type_password)

    # check client_id and define process (with required DS or not)
    with %Ecto.Changeset{valid?: true} <- changeset(attrs),
         client <- Clients.get_client_with(attrs["client_id"], [:client_type]),
         :ok <- validate_client_allowed_grant_types(client, "password"),
         user <- UserAPI.get_user_by(email: attrs["email"]),
         :ok <- validate_user_by_client(user, client),
         :ok <- validate_user_is_blocked(user),
         :ok <- LoginHistory.check_failed_login(user, LoginHistory.type(:password)),
         {:ok, user} <- match_with_user_password(user, attrs["password"]),
         :ok <- validate_user_password(user, grant_type),
         :ok <- validate_client_allowed_scope(client, attrs["scope"]),
         :ok <- validate_token_scope_by_grant(grant_type, attrs["scope"]),
         factor <- Factors.get_factor_by(user_id: user.id, is_active: true),
         {:ok, token} <- create_token_by_grant_type(factor, user, client, attrs["scope"], grant_type),
         {_, nil} <- TokenAPI.deactivate_old_tokens(token),
         sms_send_response <- maybe_send_otp(user, factor, token),
         {:ok, next_step} <- map_next_step(sms_send_response) do
      {:ok, %{token: token, urgent: %{next_step: next_step}}}
    end
  end

  defp changeset(attrs) do
    types = %{email: :string, password: :string, client_id: :string, scope: :string}

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(Map.keys(types))
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

  defp validate_user_by_client(%User{tax_id: tax_id}, %{client_type: %{name: @cabinet_client_type}})
       when is_nil(tax_id) or tax_id == "",
       do: {:error, {:forbidden, %{message: "User is not registered"}}}

  defp validate_user_by_client(_, _), do: :ok

  defp match_with_user_password(user, password) do
    if Bcrypt.checkpw(password, Map.get(user, :password, "")) do
      LoginHistory.clear_logins(user, LoginHistory.type(:password))
      {:ok, user}
    else
      LoginHistory.add_failed_login(user, LoginHistory.type(:password))
      {:error, {:access_denied, "Identity, password combination is wrong."}}
    end
  end

  defp validate_token_scope_by_grant(@grant_type_change_password, "user:change_password"), do: :ok
  defp validate_token_scope_by_grant(@grant_type_change_password, _), do: Error.invalid_scope(["user:change_password"])
  defp validate_token_scope_by_grant(_, _requested_scope), do: :ok

  defp create_token_by_grant_type(
         _,
         %User{tax_id: tax_id},
         %{client_type: %{name: @cabinet_client_type}},
         _,
         @grant_type_password
       )
       when is_nil(tax_id) or tax_id == "" do
    {:error, {:forbidden, %{message: "User is not registered"}}}
  end

  defp create_token_by_grant_type(%Factor{}, %User{} = user, client, scope, grant_type) do
    # ToDo: find smarter way to fetch redirect_uri
    #    connection = hd(client.connections)

    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => grant_type,
        "client_id" => client.id,
        # 2FA access token requires no scopes
        "scope" => "",
        "scope_request" => scope
        #        "redirect_uri" => connection.redirect_uri
      }
    }

    TokenAPI.create_2fa_access_token(data)
  end

  defp create_token_by_grant_type(_factor, %User{} = user, client, scope, @grant_type_password) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "password",
        "client_id" => client.id,
        "scope" => scope
      }
    }

    TokenAPI.create_access_token(data)
  end

  defp create_token_by_grant_type(_factor, %User{} = user, client, scope, @grant_type_change_password) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "change_password",
        "client_id" => client.id,
        "scope" => scope
      }
    }

    TokenAPI.create_change_password_token(data)
  end

  defp maybe_send_otp(user, %Factor{} = factor, token), do: Authentication.send_otp(user, factor, token)
  defp maybe_send_otp(_, _, _), do: {:ok, :request_app}

  defp map_next_step(:ok), do: {:ok, next_step(:request_otp)}
  defp map_next_step({:ok, :request_app}), do: {:ok, next_step(:request_apps)}
  defp map_next_step({:error, :factor_not_set}), do: {:ok, next_step(:request_factor)}
  defp map_next_step({:error, :sms_not_sent}), do: {:error, {:service_unavailable, "SMS not sent. Try later"}}
  defp map_next_step({:error, :otp_timeout}), do: Error.otp_timeout()
end
