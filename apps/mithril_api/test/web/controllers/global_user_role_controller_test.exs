defmodule Mithril.Web.GlobalUserRoleControllerTest do
  use Mithril.Web.ConnCase

  alias Core.UserAPI.User

  setup %{conn: conn} do
    user = insert(:user)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), user_id: user.id}
  end

  describe "create global user role" do
    test "creates global_user_role and renders global_user_role when data is valid", %{user_id: user_id, conn: conn} do
      %{id: role_id} = insert(:role)
      create_attrs = %{role_id: role_id}

      assert %{"id" => id, "scope" => _} =
               conn
               |> post(user_global_role_path(conn, :create, %User{id: user_id}), global_user_role: create_attrs)
               |> json_response(201)
               |> Map.get("data")

      global_role =
        conn
        |> get(user_global_role_path(conn, :show, user_id, id))
        |> json_response(200)
        |> Map.get("data")

      assert id == global_role["id"]
      assert role_id == global_role["role_id"]
      assert user_id == global_role["user_id"]
    end

    test "create global_user_role twice with same user_id, client_id", %{user_id: user_id, conn: conn} do
      %{id: role_id} = insert(:role)
      create_attrs = %{role_id: role_id}

      conn
      |> post(user_global_role_path(conn, :create, %User{id: user_id}), global_user_role: create_attrs)
      |> json_response(201)

      conn
      |> post(user_global_role_path(conn, :create, %User{id: user_id}), global_user_role: create_attrs)
      |> json_response(201)
    end

    test "does not create global_user_role and renders errors when data is invalid", %{user_id: user_id, conn: conn} do
      invalid_attrs = %{role_id: nil}
      conn = post(conn, user_global_role_path(conn, :create, %User{id: user_id}), global_user_role: invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
