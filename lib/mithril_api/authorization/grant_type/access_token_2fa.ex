defmodule Mithril.Authorization.GrantType.AccessToken2FA do
  @moduledoc false
  import Ecto.Changeset

  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.TokenAPI
  alias Mithril.TokenAPI.Token
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authorization.GrantType.Password

  def authorize(params) do
    with %Ecto.Changeset{valid?: true} <- changeset(params),
         :ok <- validate_authorization_header(params),
         {:ok, non_validated_token} <- get_token(params["token_value"]),
         user <- UserAPI.get_user(non_validated_token.user_id),
         {:ok, user} <- validate_user(user),
         {:ok, token_2fa} <- validate_token(non_validated_token),
         %Factor{} = factor <- get_auth_factor_by_user_id(user.id),
         :ok <- check_factor_value(factor),
         :ok <- verify_otp(factor, token_2fa, params["otp"], user),
         {:ok, token} <- create_access_token(token_2fa),
         {_, nil} <- TokenAPI.deactivate_old_tokens(token)
      do
      {:ok, %{token: token, urgent: %{next_step: Password.next_step(:request_apps)}}}
    end
  end

  def refresh(params) do
    with :ok <- validate_authorization_header(params),
         {:ok, non_validated_token} <- get_token(params["token_value"]),
         user <- UserAPI.get_user(non_validated_token.user_id),
         {:ok, user} <- validate_user(user),
         {:ok, token_2fa} <- validate_token(non_validated_token),
         %Factor{} = factor <- get_auth_factor_by_user_id(user.id),
         :ok <- check_factor_value(factor),
         {:ok, token} <- create_2fa_access_token(token_2fa),
         {_, nil} <- TokenAPI.deactivate_old_tokens(token)
      do
      {:ok, %{token: token, urgent: %{next_step: Password.next_step(:request_otp)}}}
    end
  end

  defp changeset(attrs) do
    types = %{otp: :integer}

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(Map.keys(types))
  end

  def validate_authorization_header(%{"token_value" => token_value}) when is_binary(token_value) do
    :ok
  end
  def validate_authorization_header(_) do
    {:error, {:access_denied, "Authorization header required."}}
  end

  defp get_token(token_value) do
    case TokenAPI.get_token_by([value: token_value]) do
      %Token{} = token -> {:ok, token}
      _ -> {:error, {:access_denied, "Invalid token"}}
    end
  end

  defp validate_token(%Token{name: "2fa_access_token"} = token) do
    case TokenAPI.expired?(token) do
      true -> {:error, {:access_denied, "Token expired"}}
      _ -> {:ok, token}
    end
  end
  defp validate_token(%Token{}) do
    {:error, {:access_denied, "Invalid token type"}}
  end

  def validate_user(%User{is_blocked: false} = user), do: {:ok, user}
  def validate_user(%User{is_blocked: true}), do: {:error, {:access_denied, "User blocked."}}
  def validate_user(_), do: {:error, {:access_denied, "User not found."}}

  defp get_auth_factor_by_user_id(user_id) do
    case Authentication.get_factor_by([user_id: user_id, is_active: true]) do
      %Factor{} = factor -> factor
      _ -> {:error, %{conflict: "Not found authentication factor for user."}}
    end
  end
  defp check_factor_value(%Factor{factor: factor}) when is_binary(factor) and byte_size(factor) > 0 do
    :ok
  end
  defp check_factor_value(_) do
    {:error, {:conflict, "Factor not set"}}
  end

  def verify_otp(factor, token, otp, user) do
    case Authentication.verify_otp(factor, token, otp) do
      {_, _, :verified} ->
        set_otp_error_counter(user, 0)
        :ok
      _ ->
        increase_otp_error_counter_or_block_user(user)
        {:error, {:access_denied, "Invalid OTP code"}}
    end
  end

  defp create_access_token(%Token{} = token) do
    Mithril.TokenAPI.create_access_token(%{
      user_id: token.user_id,
      details: token.details
    })
  end

  defp create_2fa_access_token(%Token{} = token) do
    Mithril.TokenAPI.create_2fa_access_token(%{
      user_id: token.user_id,
      details: token.details
    })
  end

  defp increase_otp_error_counter_or_block_user(%User{priv_settings: priv_settings} = user) do
    otp_error_max = Confex.get_env(:mithril_api, :"2fa")[:user_otp_error_max]
    otp_error = priv_settings.otp_error_counter + 1
    set_otp_error_counter(user, otp_error)
    if otp_error_max <= otp_error do
        UserAPI.block_user(user, "Passed invalid OTP more than USER_OTP_ERROR_MAX")
    end
  end
  defp set_otp_error_counter(%User{priv_settings: priv_settings} = user, counter) do
    data = priv_settings
           |> Map.from_struct()
           |> Map.put(:otp_error_counter, counter)
    UserAPI.update_user_priv_settings(user, data)
  end
end
