defmodule Core.Authorization.GrantType.AccessToken2FATest do
  use Core.DataCase, async: false

  alias Core.OTP
  alias Core.OTP.Schema, as: OTPSchema
  alias Core.UserAPI
  alias Core.TokenAPI
  alias Core.Authentication
  alias Core.Authorization.GrantType.AccessToken2FA

  setup do
    client_type = insert(:client_type, scope: "app:authorize legal_entity:read legal_entity:write")

    client = insert(:client, client_type: client_type)

    factor_value = "+380331002030"
    factor = insert(:authentication_factor, user: client.user, factor: factor_value)
    role = insert(:role, scope: "legal_entity:read legal_entity:write")
    insert(:user_role, user: client.user, role: role, client: client)
    token = insert(:token, user: client.user, name: "2fa_access_token")

    otp_key = Authentication.generate_otp_key(token, factor_value)
    otp = insert(:otp, key: otp_key, code: 1234)

    {:ok, %{token: token, user: client.user, otp: otp, factor: factor}}
  end

  describe "authorize" do
    test "invalid OTP type", %{token: token} do
      data = %{
        "token_value" => token.value,
        "grant_type" => "authorize_2fa_access_token",
        "otp" => "invalid type"
      }

      assert %Ecto.Changeset{valid?: false} = AccessToken2FA.authorize(data)
    end

    test "other access token deactivated when 2fa access token authorized", %{
      token: token_2fa,
      user: user,
      otp: otp
    } do
      details = %{"client_id" => token_2fa.details["client_id"]}
      access_token = insert(:token, user: user, name: "access_token", details: details)

      # token is not expired before authorize
      refute :os.system_time(:seconds) >= access_token.expires_at
      refute :os.system_time(:seconds) >= token_2fa.expires_at

      data = %{
        "token_value" => token_2fa.value,
        "grant_type" => "authorize_2fa_access_token",
        "otp" => otp.code
      }

      assert {:ok, %{token: new_access_token}} = AccessToken2FA.authorize(data)
      refute TokenAPI.expired?(new_access_token)

      # now token expired
      assert :os.system_time(:seconds) >= TokenAPI.get_token!(access_token.id).expires_at
      assert :os.system_time(:seconds) >= TokenAPI.get_token!(token_2fa.id).expires_at
    end

    test "authentication factor not found for user" do
    end

    test "reached max OTP error", %{token: token_2fa, user: user, otp: otp} do
      user_otp_error_max = Confex.fetch_env!(:core, :"2fa")[:user_otp_error_max]

      data = %{
        "token_value" => token_2fa.value,
        "grant_type" => "authorize_2fa_access_token",
        "otp" => 9999
      }

      for _ <- 1..(user_otp_error_max - 1) do
        assert {:error, {:access_denied, %{type: "otp_invalid"}}} = AccessToken2FA.authorize(data)
      end

      # user have last attempt for success login
      refute UserAPI.get_user!(user.id).is_blocked

      assert {:error, {:access_denied, %{type: "otp_invalid"}}} = AccessToken2FA.authorize(data)
      # now user blocked
      db_user = UserAPI.get_user!(user.id)
      assert db_user.is_blocked
      assert user_otp_error_max == db_user.priv_settings.otp_error_counter

      # check that User is blocked and his token expired
      assert {:error, {:access_denied, %{message: "User blocked.", type: "user_blocked"}}} =
               data
               |> Map.put("otp", otp.code)
               |> AccessToken2FA.authorize()
    end

    test "OTP error counter refreshed after success login", %{
      token: token_2fa,
      user: user,
      otp: otp
    } do
      data = %{
        "token_value" => token_2fa.value,
        "grant_type" => "authorize_2fa_access_token",
        "otp" => 9999
      }

      for _ <- 1..2 do
        assert {:error, {:access_denied, %{type: "otp_invalid"}}} = AccessToken2FA.authorize(data)
      end

      db_user = UserAPI.get_user!(user.id)
      refute db_user.is_blocked
      assert 2 == db_user.priv_settings.otp_error_counter

      assert {:ok, _} =
               data
               |> Map.put("otp", otp.code)
               |> AccessToken2FA.authorize()

      db_user = UserAPI.get_user!(user.id)
      refute db_user.is_blocked
      assert 0 == db_user.priv_settings.otp_error_counter
    end
  end

  describe "refresh" do
    test "successfully created new OTP", %{token: token_2fa, factor: factor} do
      assert {:ok, %{token: token}} = AccessToken2FA.refresh(%{"token_value" => token_2fa.value})
      # generated new OTP
      otp_key = Authentication.generate_otp_key(token, factor.factor)
      assert %OTPSchema{active: true} = OTP.get_otp_by(key: otp_key)
    end

    test "user blocked", %{token: token_2fa, user: user} do
      refute user.is_blocked
      UserAPI.block_user(user)
      # check that User is blocked and his token expired
      assert {:error, {:access_denied, %{message: "User blocked."}}} =
               AccessToken2FA.refresh(%{"token_value" => token_2fa.value})
    end

    test "authentication factor not found for user" do
    end
  end
end
