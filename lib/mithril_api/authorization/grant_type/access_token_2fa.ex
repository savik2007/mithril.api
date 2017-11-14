defmodule Mithril.Authorization.GrantType.AccessToken2FA do
  @moduledoc false
  import Ecto.Changeset

  alias Mithril.OTP
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.TokenAPI
  alias Mithril.TokenAPI.Token
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authorization.GrantType.Error, as: GrantTypeError

  @otp_error_max Confex.get_env(:mithril_api, :user_otp_error_max)

  def authorize(params) do
    with %Ecto.Changeset{valid?: true} <- changeset(params),
         :ok <- validate_authorization_header(params),
         {:ok, token} <- validate_token(params["token_value"]),
         {:ok, user} <- validate_user(token.user_id),
         %Factor{} = factor <- get_auth_factor_by_user_id(user.id),
         :ok <- verify_otp(factor, params["otp"])
      do
        token
        |> create_access_token()
        |> deactivate_old_tokens()
    end
  end

  def refresh(params) do
    :ok
  end

  defp changeset(attrs) do
    types = %{otp: :string}

    changeset =
      {%{}, types}
      |> cast(attrs, Map.keys(types))
      |> validate_required(Map.keys(types))
  end

  defp validate_authorization_header(%{"token_value" => token_value}) when is_binary(token_value) do
    :ok
  end
  defp validate_authorization_header(_) do
    {:error, {:access_denied, "Authorization header required."}}
  end

  defp validate_token(token_value) do
    with %Token{name: "2fa_access_token"} = token <- TokenAPI.get_token_by([value: token_value]),
         false <- TokenAPI.expired?(token)
      do
      {:ok, token}
    else
      %Token{} -> {:error, {:access_denied, "Invalid token type"}}
      true -> {:error, {:access_denied, "Token expired"}}
      nil -> {:error, {:access_denied, "Invalid token"}}
    end
  end

  defp validate_user(user_id) do
    case UserAPI.get_user(user_id) do
      %User{is_blocked: false} = user -> {:ok, user}
      %User{is_blocked: true} -> {:error, {:access_denied, "User blocked"}}
      _ -> {:error, {:access_denied, "User not found"}}
    end
  end
  defp get_auth_factor_by_user_id(user_id) do

    case Authentication.get_factor_by([user_id: user_id, is_active: true]) do
      %Factor{} = factor -> factor
      _ -> {:error, %{conflict: "Not found authentication factor for user."}}

    end
  end

  defp verify_otp(%Factor{} = factor, otp) do
    # ToDo: write a code - OTP.verify()
    :ok
  end

  defp create_access_token(%Token{} = token) do
    Mithril.TokenAPI.create_access_token(%{
      user_id: token.user_id,
      details: token.details
    })
  end

  defp deactivate_old_tokens({:ok, %Token{} = token}) do
    Mithril.TokenAPI.deactivate_old_tokens(token)
    {:ok, token}
  end
  defp deactivate_old_tokens({:error, _, _} = error), do: error

  defp check_otp_error_counter({:error, _, _} = err, %User{priv_settings: priv_settings} = user) do
    otp_error = priv_settings.otp_error_counter + 1
    case @otp_error_max <= otp_error do
      true ->
        UserAPI.block_user(user, "Passed invalid password more than USER_otp_error_MAX")
      _ ->
        data = priv_settings
               |> Map.from_struct()
               |> Map.put(:otp_error_counter, otp_error)
        UserAPI.update_user_priv_settings(user, data)
    end
    err
  end
  defp check_otp_error_counter({:ok, user}, _) do
    {:ok, user}
  end
end
