defmodule Mithril.Authentication.CRUDTest do
  use Mithril.DataCase, async: true

  alias Mithril.Authentication
  alias Mithril.Authentication.Factors
  alias Ecto.Changeset

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
      %{user: user, factor: factor}
    end

    test "success", %{user: user, factor: factor} do
      phone = "+380909998877"
      assert {:ok, %Factors{factor: ^phone}} = Authentication.update_factor(factor, %{"factor" => phone})
    end
  end
end
