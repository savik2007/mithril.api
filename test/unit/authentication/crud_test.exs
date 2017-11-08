defmodule Mithril.Authentication.CRUDTest do
  use Mithril.DataCase, async: true

  alias Ecto.Changeset
  alias Mithril.UserAPI
  alias Mithril.Authentication
  alias Mithril.Authentication.Factors

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
      assert {:ok, %Factors{}} = Authentication.create_factor(data)
    end

    test "success without factor", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
      }
      assert {:ok, %Factors{}} = Authentication.create_factor(data)
    end

    test "invalid factor value", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
        "factor" => "invalid"
      }
      assert {:error, %Changeset{valid?: false, errors: [factor: _]}} = Authentication.create_factor(data)
    end

    test "invalid type and factor", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => "INVALID",
        "factor" => "invalid"
      }
      assert {:error, %Changeset{valid?: false, errors: [type: _]}} = Authentication.create_factor(data)
    end

    test "factor already exists", %{user: user} do
      data = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms),
        "factor" => "+380901002030"
      }
      assert {:ok, %Factors{}} = Authentication.create_factor(data)
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

  describe "update" do
    setup do
      user = insert(:user)
      factor = insert(:authentication_factor, user_id: user.id)
      %{factor: factor}
    end

    test "success", %{factor: factor} do
      phone = "+380909998877"
      assert {:ok, %Factors{factor: ^phone}} = Authentication.update_factor(factor, %{"factor" => phone})
    end
  end

  describe "authentication factor created when user created" do
    test "success" do
      assert {:ok, user} = UserAPI.create_user(%{"email" => "test@example.com", "password" => "p@S$w0rD"})
      assert %Factors{} = Authentication.get_authentication_factor_by!(user_id: user.id)
    end

    test "2fa not enabled" do
      System.put_env("USER_2FA_ENABLED", "false")

      assert {:ok, user} = UserAPI.create_user(%{"email" => "test@example.com", "password" => "p@S$w0rD"})
      assert_raise Ecto.NoResultsError, fn -> Authentication.get_authentication_factor_by!(user_id: user.id) end

      System.put_env("USER_2FA_ENABLED", "true")
    end

    test "invalid params for user" do
      assert {:error, _} = UserAPI.create_user(%{"email" => "test@example.com"})
      assert [] == Repo.all(Factors)
    end
  end
end
