defmodule Mithril.Authorization.GrantType.Password do
  @moduledoc false
  alias Mithril.Authorization.GrantType.Error, as: GrantTypeError
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.TokenAPI.Token
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor

  @login_error_max Confex.get_env(:mithril_api, :user_login_error_max)

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
    {:ok, user}
    |> match_with_user_password(password)
    |> check_login_error_counter(user)
    |> validate_token_scope(client.client_type.scope, scope)
    |> create_access_token(client, scope)
    |> deactivate_old_tokens()
  end

  defp create_access_token({:error, err, code}, _, _), do: {:error, err, code}
  defp create_access_token({:ok, user}, client, scope) do
    data = %{
      user_id: user.id,
      details: %{
        grant_type: "password",
        client_id: client.id,
        scope: scope,
        redirect_uri: client.redirect_uri
      }
    }

    case Authentication.get_factor_by([user_id: user.id, is_active: true]) do
      %Factor{} -> Mithril.TokenAPI.create_2fa_access_token(data)
      _ -> Mithril.TokenAPI.create_access_token(data)
    end

  end

  defp deactivate_old_tokens({:ok, %Token{} = token}) do
    Mithril.TokenAPI.deactivate_old_tokens(token)
    {:ok, token}
  end
  defp deactivate_old_tokens({:error, _, _} = error), do: error

  defp validate_token_scope({:error, err, code}, _, _), do: {:error, err, code}
  defp validate_token_scope({:ok, user}, client_scope, required_scope) do
    allowed_scopes = String.split(client_scope, " ", trim: true)
    required_scopes = String.split(required_scope, " ", trim: true)
    if Mithril.Utils.List.subset?(allowed_scopes, required_scopes) do
      {:ok, user}
    else
      GrantTypeError.invalid_scope(allowed_scopes)
    end
  end

  defp match_with_user_password({:ok, user}, password) do
    if Comeonin.Bcrypt.checkpw(password, Map.get(user, :password, "")) do
      {:ok, user}
    else
      GrantTypeError.invalid_grant("Identity, password combination is wrong.")
    end
  end

  defp check_login_error_counter({:error, _, _} = err, %User{priv_settings: priv_settings} = user) do
    login_error = priv_settings.login_error_counter + 1
    case @login_error_max <= login_error do
      true ->
        UserAPI.block_user(user, "Passed invalid password more than USER_LOGIN_ERROR_MAX")
      _ ->
        data = priv_settings |> Map.from_struct() |> Map.put(:login_error_counter, login_error)
        UserAPI.update_user_priv_settings(user, data)
    end
    err
  end
  defp check_login_error_counter({:ok, user}, _) do
    {:ok, user}
  end
end
