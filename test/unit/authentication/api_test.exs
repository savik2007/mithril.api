defmodule Mithril.Authentication.APITest do
  use Mithril.DataCase, async: false

  alias Mithril.OTP.SMS
  alias Ecto.Changeset
  alias Mithril.UserAPI
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor

  @env "OTP_SMS_TEMPLATE"

  describe "create" do
    setup do
      %{user: insert(:user)}
    end

    test "success", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
        "factor" => "+380901002030"
      }
      assert {:ok, %Factor{}} = Authentication.create_factor(data)
    end

    test "success without factor", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
      }
      assert {:ok, %Factor{}} = Authentication.create_factor(data)
    end

    test "cannot create factor with value", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
        "factor" => "+380881002030"
      }
      assert  {:ok, %Factor{factor: nil}} = Authentication.create_factor(data)
    end

    test "invalid type", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => "INVALID",
      }
      assert {:error, %Changeset{valid?: false, errors: [type: _]}} = Authentication.create_factor(data)
    end

    test "factor already exists", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
        "factor" => "+380901002030"
      }
      assert {:ok, %Factor{}} = Authentication.create_factor(data)
      assert {:error, %Changeset{valid?: false, errors: [user_id: _]}} = Authentication.create_factor(data)
    end

    test "user does not exists" do
      data = %{
        "user_id" => Ecto.UUID.generate(),
        "type" => Authentication.type(:sms),
        "factor" => "+380901002030"
      }
      assert {:error, %Changeset{valid?: false, errors: [user: _]}} = Authentication.create_factor(data)
    end
  end

  describe "authentication factor created when user created" do
    test "success" do
      assert {:ok, user} = UserAPI.create_user(%{"email" => "test@example.com", "password" => "p@S$w0rD"})
      assert %{login_error_counter: 0, otp_error_counter: 0} = user.priv_settings
      assert %Factor{} = Authentication.get_factor_by!(user_id: user.id)
    end

    test "2fa not enabled in ENV" do
      System.put_env("USER_2FA_ENABLED", "false")

      assert {:ok, user} = UserAPI.create_user(%{"email" => "test@example.com", "password" => "p@S$w0rD"})
      assert_raise Ecto.NoResultsError, fn -> Authentication.get_factor_by!(user_id: user.id) end

      System.put_env("USER_2FA_ENABLED", "true")
    end

    test "2fa not enabled in ENV but passed param 2fa_enable" do
      System.put_env("USER_2FA_ENABLED", "false")

      data = %{"email" => "test@example.com", "password" => "p@S$w0rD", "2fa_enable" => true}
      assert {:ok, user} = UserAPI.create_user(data)
      assert %Factor{} = Authentication.get_factor_by!(user_id: user.id)
      System.put_env("USER_2FA_ENABLED", "true")
    end

    test "2fa enabled in ENV but passed param 2fa_enable FALSE" do
      data = %{"email" => "test@example.com", "password" => "p@S$w0rD", "2fa_enable" => false}
      assert {:ok, user} = UserAPI.create_user(data)
      assert_raise Ecto.NoResultsError, fn -> Authentication.get_factor_by!(user_id: user.id) end
    end

    test "invalid 2fa_enable param" do
      data = %{"email" => "test@example.com", "password" => "p@S$w0rD", "2fa_enable" => "yes"}
      assert {:ok, user} = UserAPI.create_user(data)
      assert_raise Ecto.NoResultsError, fn -> Authentication.get_factor_by!(user_id: user.id) end
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
      assert "template 1234" == Authentication.generate_message(code)

      System.put_env(@env, "Код підтвердження: <otp.code>")
    end

    test "template doesn't contains required code mask" do
      System.put_env(@env, "template without code mask")

      code = 1230
      assert "1230" == Authentication.generate_message(code)

      System.put_env(@env, "Код підтвердження: <otp.code>")
    end
  end
end
