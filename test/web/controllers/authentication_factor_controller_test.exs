defmodule Mithril.Web.AuthenticationFactorControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.Authentication
  alias Mithril.Authentication.Factor

  describe "list user auth factor" do

  end

  describe "create user auth factor" do
    setup %{conn: conn} do
      user = insert(:user)
      {:ok, conn: conn, user: user}
    end

    test "success", %{conn: conn, user: user} do
      create_attrs = %{
        "user_id" => user.id,
        "type" => Authentication.type(:sms)
      }
      conn = post conn, user_authentication_factor_path(conn, :create, user), create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, user_authentication_factor_path(conn, :show, user.id, id)
      data = json_response(conn, 200)["data"]
      assert user.id == data["user_id"]
      assert Authentication.type(:sms) == data["type"]
      assert nil == data["factor"]
     end
  end

  describe "update user auth factor" do
    setup %{conn: conn} do
      user = insert(:user)
      factor = insert(:authentication_factor, user_id: user.id)
      {:ok, conn: conn, user: user, factor: factor}
    end

    test "disable", %{conn: conn, user: user, factor: factor} do
      conn = patch conn, user_authentication_factor_path(conn, :disable, user, factor.id)
      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = get conn, user_authentication_factor_path(conn, :show, user.id, id)
      data = json_response(conn, 200)["data"]
      assert user.id == data["user_id"]
      refute data["is_active"]
    end

    test "already disabled", %{conn: conn, user: user, factor: factor} do
      conn = patch conn, user_authentication_factor_path(conn, :disable, user, factor.id)
      assert json_response(conn, 200)

      conn = patch conn, user_authentication_factor_path(conn, :disable, user, factor.id)
      json_response(conn, 409)
    end

    test "enable", %{conn: conn, user: user, factor: factor} do
      conn = patch conn, user_authentication_factor_path(conn, :disable, user, factor.id)
      assert json_response(conn, 200)

      conn = patch conn, user_authentication_factor_path(conn, :enable, user, factor.id)
      assert %{"is_active" => true} = json_response(conn, 200)["data"]

      conn = get conn, user_authentication_factor_path(conn, :show, user.id, factor.id)
      data = json_response(conn, 200)["data"]
      assert user.id == data["user_id"]
      assert data["is_active"]
    end

    test "already enabled", %{conn: conn, user: user, factor: factor} do
      conn = patch conn, user_authentication_factor_path(conn, :enable, user, factor.id)
      assert json_response(conn, 409)
    end

    test "reset", %{conn: conn, user: user, factor: factor} do
      conn = patch conn, user_authentication_factor_path(conn, :reset, user, factor.id)
      assert json_response(conn, 200)
      assert [factor] = Repo.all(Factor)
      assert user.id == factor.user_id
      assert factor.is_active
      assert nil == factor.factor
    end
  end
end
