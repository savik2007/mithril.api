defmodule Mithril.Web.AuthenticationFactorControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.Authentication
  alias Mithril.Authentication.Factor

  describe "list user auth factor" do
    setup %{conn: conn} do
      user = insert(:user)
      insert(:authentication_factor, user_id: user.id)
      insert(:authentication_factor, user_id: user.id, type: "EMAIL")
      insert(:authentication_factor, user_id: user.id, type: "PHONE")
      {:ok, conn: conn, user: user}
    end

    test "success", %{conn: conn, user: user} do
      conn = get(conn, user_authentication_factor_path(conn, :index, user))
      data = json_response(conn, 200)["data"]
      assert 3 = length(data)
    end

    test "filter by type", %{conn: conn, user: user} do
      conn = get(conn, user_authentication_factor_path(conn, :index, user), %{"type" => Authentication.type(:sms)})
      assert [%{"factor" => factor}] = json_response(conn, 200)["data"]
      assert String.match?(factor, ~r/\+\d{5}\*{5}\d{2}/), "factor `#{factor}` not masked"
    end
  end

  describe "get factor by id" do
    setup %{conn: conn} do
      user = insert(:user)
      factor = insert(:authentication_factor, user_id: user.id, factor: "+380881002030")
      {:ok, conn: conn, user: user, factor: factor}
    end

    test "success", %{conn: conn, factor: factor, user: user} do
      conn = get(conn, user_authentication_factor_path(conn, :show, user.id, factor.id))
      data = json_response(conn, 200)["data"]
      assert "+38088*****30" == data["factor"]
      assert factor.id == data["id"]
    end
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

      conn = post(conn, user_authentication_factor_path(conn, :create, user), create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, user_authentication_factor_path(conn, :show, user.id, id))
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

    test "reset factor", %{conn: conn, user: user, factor: factor} do
      conn = get(conn, user_authentication_factor_path(conn, :show, user.id, factor.id))
      factor_value = json_response(conn, 200)["data"]["factor"]
      assert String.match?(factor_value, ~r/\+\d{5}\*{5}\d{2}/), "factor `#{factor_value}` not masked"

      conn = patch(conn, user_authentication_factor_path(conn, :reset, user, factor.id))
      data = json_response(conn, 200)["data"]

      assert user.id == data["user_id"]
      refute data["factor"]
      assert data["is_active"]

      conn = get(conn, user_authentication_factor_path(conn, :show, user.id, factor.id))
      data = json_response(conn, 200)["data"]

      assert user.id == data["user_id"]
      refute data["factor"]
      assert data["is_active"]
    end

    test "disable", %{conn: conn, user: user, factor: factor} do
      conn = patch(conn, user_authentication_factor_path(conn, :disable, user, factor.id))
      assert %{"id" => id, "is_active" => false} = json_response(conn, 200)["data"]

      conn = get(conn, user_authentication_factor_path(conn, :show, user.id, id))
      data = json_response(conn, 200)["data"]
      assert user.id == data["user_id"]
      refute data["is_active"]
    end

    test "already disabled", %{conn: conn, user: user, factor: factor} do
      conn = patch(conn, user_authentication_factor_path(conn, :disable, user, factor.id))
      assert json_response(conn, 200)

      conn = patch(conn, user_authentication_factor_path(conn, :disable, user, factor.id))
      json_response(conn, 409)
    end

    test "enable", %{conn: conn, user: user, factor: factor} do
      conn = patch(conn, user_authentication_factor_path(conn, :disable, user, factor.id))
      assert json_response(conn, 200)

      conn = patch(conn, user_authentication_factor_path(conn, :enable, user, factor.id))
      assert %{"is_active" => true} = json_response(conn, 200)["data"]

      conn = get(conn, user_authentication_factor_path(conn, :show, user.id, factor.id))
      data = json_response(conn, 200)["data"]
      assert user.id == data["user_id"]
      assert data["is_active"]
    end

    test "already enabled", %{conn: conn, user: user, factor: factor} do
      conn = patch(conn, user_authentication_factor_path(conn, :enable, user, factor.id))
      assert json_response(conn, 409)
    end

    test "reset", %{conn: conn, user: user, factor: factor} do
      conn = patch(conn, user_authentication_factor_path(conn, :reset, user, factor.id))
      assert json_response(conn, 200)
      assert [factor] = Repo.all(Factor)
      assert user.id == factor.user_id
      assert factor.is_active
      assert nil == factor.factor
    end
  end
end
