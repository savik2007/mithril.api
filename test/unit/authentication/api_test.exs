defmodule Mithril.Authentication.APITest do
  use Mithril.DataCase, async: false

  import Mithril.Guardian

  alias Ecto.Changeset
  alias Mithril.UserAPI
  alias Mithril.Authentication
  alias Mithril.Authentication.{Factor, Factors}
  alias Mithril.Authorization.LoginHistory
  alias Mithril.UserAPI.User.PrivSettings
  alias Mithril.TokenAPI.Token

  @env "OTP_SMS_TEMPLATE"
  @create_attr %{"email" => "test@example.com", "password" => "p@S$w0rD1234", "tax_id" => "12342345"}

  describe "create" do
    setup do
      %{user: insert(:user)}
    end

    test "success", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms)
      }

      assert {:ok, %Factor{}} = Factors.create_factor(data)
    end

    test "success without factor", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms)
      }

      assert {:ok, %Factor{}} = Factors.create_factor(data)
    end

    test "cannot create factor without otp", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
        "factor" => "+380881002030"
      }

      assert {:ok, %Factor{} = resp} = Factors.create_factor(data)
      assert resp.user_id == user.id
      assert resp.type == Authentication.type(:sms)
      assert resp.factor == "+380881002030"
    end

    test "invalid type", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => "INVALID"
      }

      assert {:error, %Changeset{valid?: false, errors: [type: _]}} = Factors.create_factor(data)
    end

    test "factor already exists", %{user: user} do
      key = Authentication.generate_otp_key("email@example.com", "+380901002030")
      insert(:otp, key: key, code: 9912)

      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
        "factor" => "+380901002030",
        "email" => "email@example.com",
        "otp" => 9912
      }

      key = Authentication.generate_otp_key("email@example.com", "+380901002030")
      insert(:otp, key: key, code: 9912)

      assert {:ok, %Factor{}} = Factors.create_factor(data)
      assert {:error, %Changeset{valid?: false, errors: [user_id: _]}} = Factors.create_factor(data)
    end

    test "user does not exists" do
      data = %{
        "user_id" => Ecto.UUID.generate(),
        "type" => Authentication.type(:sms)
      }

      assert {:error, %Changeset{valid?: false, errors: [user: _]}} = Factors.create_factor(data)
    end
  end

  describe "verify otp" do
    test "case insensitive OTP key" do
      {:ok, jwt, _} = encode_and_sign(:email, %{email: "Email@example.com"}, token_type: "access")

      params = %{
        "type" => Authentication.type(:sms),
        "factor" => "+380901112233"
      }

      assert {:ok, otp_code} = Authentication.send_otp(params, jwt)
      assert {:ok, _, :verified} = Authentication.verify_otp("+380901112233", %Token{id: "email@example.com"}, otp_code)
    end
  end

  describe "authentication factor created when user created" do
    test "success" do
      assert {:ok, user} = UserAPI.create_user(@create_attr)
      assert %{login_hstr: [], otp_error_counter: 0} = user.priv_settings
      assert %Factor{} = Factors.get_factor_by!(user_id: user.id)
    end

    test "2fa not enabled in ENV" do
      System.put_env("USER_2FA_ENABLED", "false")

      assert {:ok, user} = UserAPI.create_user(@create_attr)
      assert_raise Ecto.NoResultsError, fn -> Factors.get_factor_by!(user_id: user.id) end

      System.put_env("USER_2FA_ENABLED", "true")
    end

    test "2fa not enabled in ENV but passed param 2fa_enable" do
      System.put_env("USER_2FA_ENABLED", "false")
      data = Map.put(@create_attr, "2fa_enable", true)
      assert {:ok, user} = UserAPI.create_user(data)
      assert %Factor{} = Factors.get_factor_by!(user_id: user.id)
      System.put_env("USER_2FA_ENABLED", "true")
    end

    test "2fa enabled in ENV but passed param 2fa_enable FALSE" do
      data = Map.put(@create_attr, "2fa_enable", false)
      assert {:ok, user} = UserAPI.create_user(data)
      assert_raise Ecto.NoResultsError, fn -> Factors.get_factor_by!(user_id: user.id) end
    end

    test "invalid 2fa_enable param" do
      data = Map.put(@create_attr, "2fa_enable", "yes")
      assert {:ok, user} = UserAPI.create_user(data)
      assert_raise Ecto.NoResultsError, fn -> Factors.get_factor_by!(user_id: user.id) end
    end

    test "invalid params for user" do
      assert {:error, _} = UserAPI.create_user(%{"email" => "test@example.com"})
      assert [] == Repo.all(Factor)
    end
  end

  describe "Template message generation" do
    test "valid template" do
      System.put_env(@env, "template <otp.code>")

      code = 1234
      assert "template 1234" == Authentication.generate_otp_message(code)

      System.put_env(@env, "Код підтвердження: <otp.code>")
    end

    test "template doesn't contains required code mask" do
      System.put_env(@env, "template without code mask")

      code = 1230
      assert "1230" == Authentication.generate_otp_message(code)

      System.put_env(@env, "Код підтвердження: <otp.code>")
    end
  end

  describe "OTP requests limit" do
    setup do
      System.put_env("OTP_SEND_TIMEOUT", "30")

      on_exit(fn ->
        System.put_env("OTP_SEND_TIMEOUT", "0")
      end)
    end

    test "timed out and reached max send attempts" do
      time = unixtime_to_naive(:os.system_time(:seconds))

      user =
        insert(
          :user,
          priv_settings: %PrivSettings{
            login_hstr: [
              build(:login_history, time: time),
              build(:login_history, time: time),
              build(:login_history, time: time)
            ]
          }
        )

      factor = insert(:authentication_factor, user_id: user.id)
      token = insert(:token, user_id: user.id)

      assert {:error, :otp_timeout} = Authentication.send_otp(user, factor, token)
    end

    test "timed out but NOT reached max send attempts" do
      time = unixtime_to_naive(:os.system_time(:seconds))

      user =
        insert(
          :user,
          priv_settings: %PrivSettings{
            login_hstr: [
              build(:login_history, time: time),
              build(:login_history, time: time)
            ]
          }
        )

      factor = insert(:authentication_factor, user_id: user.id)
      token = insert(:token, user_id: user.id)

      assert :ok = Authentication.send_otp(user, factor, token)

      db_user = UserAPI.get_user!(user.id)
      assert 3 <= length(db_user.priv_settings.login_hstr)
    end

    test "NOT timed out but reached max send attempts" do
      user =
        insert(
          :user,
          priv_settings: %PrivSettings{
            login_hstr: [
              build(:login_history),
              build(:login_history),
              build(:login_history)
            ]
          }
        )

      factor = insert(:authentication_factor, user_id: user.id)
      token = insert(:token, user_id: user.id)

      assert :ok = Authentication.send_otp(user, factor, token)

      db_user = UserAPI.get_user!(user.id)
      login_hstr = db_user.priv_settings.login_hstr
      assert 3 <= length(login_hstr)

      max_logins_period = Confex.get_env(:mithril_api, :"2fa")[:otp_send_counter_max]
      timeouted_logins = Enum.filter(login_hstr, &LoginHistory.filter_by_period(&1, max_logins_period))
      assert 1 == length(timeouted_logins)
    end

    test "NOT timed out and NOT reached max send attempts" do
      user =
        insert(
          :user,
          priv_settings: %PrivSettings{
            login_hstr: [
              build(:login_history)
            ]
          }
        )

      factor = insert(:authentication_factor, user_id: user.id)
      token = insert(:token, user_id: user.id)

      assert :ok = Authentication.send_otp(user, factor, token)

      db_user = UserAPI.get_user!(user.id)
      login_hstr = db_user.priv_settings.login_hstr
      assert 2 <= length(login_hstr)

      max_logins_period = Confex.get_env(:mithril_api, :"2fa")[:otp_send_counter_max]
      timeouted_logins = Enum.filter(login_hstr, &LoginHistory.filter_by_period(&1, max_logins_period))
      assert 1 == length(timeouted_logins)
    end

    test "reach max send attempts" do
      user =
        insert(
          :user,
          priv_settings: %PrivSettings{
            otp_error_counter: 0
          }
        )

      factor = insert(:authentication_factor, user_id: user.id)
      token = insert(:token, user_id: user.id)

      for _ <- 1..3 do
        db_user = UserAPI.get_user!(user.id)
        assert :ok = Authentication.send_otp(db_user, factor, token)
      end

      db_user = UserAPI.get_user!(user.id)
      assert {:error, :otp_timeout} = Authentication.send_otp(db_user, factor, token)

      db_user = UserAPI.get_user!(user.id)
      assert 3 <= length(db_user.priv_settings.login_hstr)
    end
  end

  defp unixtime_to_naive(time) do
    time
    |> DateTime.from_unix!()
    |> DateTime.to_naive()
  end
end
