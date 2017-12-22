defmodule Mithril.Web.UserRoleControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.UserAPI.User
  alias Mithril.UserRoleAPI
  import Mithril.Fixtures

  setup %{conn: conn} do
    {:ok, user} = Mithril.UserAPI.create_user(%{email: "some email", password: "Some password1", settings: %{}})

    {:ok, conn: put_req_header(conn, "accept", "application/json"), user_id: user.id}
  end

  describe "list user_roles" do
    test "all entries on index", %{user_id: user_id, conn: conn} do
      insert(:user_role, user_id: user_id)
      insert(:user_role, user_id: user_id)
      insert(:user_role, user_id: user_id)
      conn = get conn, user_role_path(conn, :index, %User{id: user_id})
      assert 3 == length(json_response(conn, 200)["data"])
    end

    test "search by user_ids", %{conn: conn} do
      %{id: id1} = insert(:user)
      %{id: id2} = insert(:user)
      %{id: id3} = insert(:user)

      insert(:user_role, user_id: id1)
      insert(:user_role, user_id: id1)
      insert(:user_role, user_id: id2)
      insert(:user_role, user_id: id3)

      # all user_roles
      conn = get conn, user_roles_path(conn, :index)
      assert 4 == length(json_response(conn, 200)["data"])

      # filter by user_ids and client_id
      conn = get conn, user_roles_path(conn, :index), user_ids: "#{id1},#{id2}"
      data = json_response(conn, 200)["data"]
      assert 3 == length(data)
      Enum.each(data, fn %{"user_id" => user_id} ->
        assert user_id in [id1, id2]
      end)
    end

    test "search by user_ids and client_id", %{conn: conn} do
      %{id: id1} = insert(:user)
      %{id: id2} = insert(:user)
      %{id: client_id1} = insert(:client)
      %{id: client_id2} = insert(:client)

      insert(:user_role, user_id: id1, client_id: client_id1)
      insert(:user_role, user_id: id1, client_id: client_id2)
      insert(:user_role, user_id: id2, client_id: client_id1)
      insert(:user_role, user_id: id2, client_id: client_id2)

      # all user_roles
      conn = get conn, user_roles_path(conn, :index)
      assert 4 == length(json_response(conn, 200)["data"])

      # filter by user_ids and client_id
      conn = get conn, user_roles_path(conn, :index), [user_ids: "#{id1},#{id2}", client_id: client_id1]
      data = json_response(conn, 200)["data"]
      assert 2 == length(data)
      Enum.each(data, fn %{"user_id" => user_id, "client_id" => client_id} ->
        assert user_id in [id1, id2]
        assert client_id in [client_id1, client_id2]
      end)
    end
  end

  test "creates user_role and renders user_role when data is valid", %{user_id: user_id, conn: conn} do
    create_attrs = user_role_attrs()
    conn = post conn, user_role_path(conn, :create, %User{id: user_id}), user_role: create_attrs
    assert %{"id" => id} = json_response(conn, 201)["data"]

    conn = get conn, user_role_path(conn, :show, user_id, id)
    assert json_response(conn, 200)["data"] == %{
      "id" => id,
      "client_id" => create_attrs.client_id,
      "role_id" => create_attrs.role_id,
      "user_id" => create_attrs.user_id,
    }
  end

  test "create user_role twice with same user_id, client_id", %{user_id: user_id, conn: conn} do
    create_attrs = user_role_attrs()
    %{client_id: client_id, role_id: role_id, user_id: attr_user_id} = create_attrs
    conn1 = post conn, user_role_path(conn, :create, %User{id: user_id}), user_role: create_attrs
    assert %{
      "id" => _,
      "client_id" => ^client_id,
      "role_id" => ^role_id,
      "user_id" => ^attr_user_id,
    } = json_response(conn1, 201)["data"]

    conn2 = post conn, user_role_path(conn, :create, %User{id: user_id}), user_role: create_attrs
    assert %{
      "error" => %{
        "invalid" => [
          %{"rules" => [%{"description" => "has already been taken"}]}
        ]
      }
    } = json_response(conn2, 422)
  end

  test "does not create user_role and renders errors when data is invalid", %{user_id: user_id, conn: conn} do
    invalid_attrs = %{client_id: nil, role_id: nil}
    conn = post conn, user_role_path(conn, :create, %User{id: user_id}), user_role: invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen user_role", %{conn: conn} do
    create_attrs = user_role_attrs()
    {:ok, user_role} = UserRoleAPI.create_user_role(create_attrs)
    conn = delete conn, user_role_path(conn, :delete, user_role.id)
    assert response(conn, 204)
    assert_error_sent 404, fn ->
      get conn, user_role_path(conn, :show, user_role.user_id, user_role.id)
    end
  end

  test "deletes user_roles by user_id", %{user_id: user_id, conn: conn} do
    insert(:user_role, user_id: user_id)
    insert(:user_role, user_id: user_id)
    {:ok, user} = Mithril.UserAPI.create_user(%{email: "email@example.com", password: "Some password1", settings: %{}})
    insert(:user_role, user_id: user.id)

    conn = delete conn, user_role_path(conn, :delete_by_user, user_id)
    assert response(conn, 204)

    conn = get conn, user_role_path(conn, :index, %User{id: user_id})
    assert [] == json_response(conn, 200)["data"]

    conn = get conn, user_role_path(conn, :index, %User{id: user.id})
    assert 1 == length(json_response(conn, 200)["data"])
  end

  test "delete user_role by role_id", %{user_id: user_id, conn: conn} do
    user_role = insert(:user_role, user_id: user_id)
    conn = delete conn, "/admin/users/roles/#{user_role.id}"
    assert response(conn, 204)

    assert_raise Ecto.NoResultsError, fn ->
      get conn, user_role_path(conn, :show, user_id, user_role.id)
    end
  end

  test "deletes user_roles by user_id and client_id", %{user_id: user_id, conn: conn} do
    cleanup_fixture_roles()
    %{id: role_id_admin} = create_role(%{name: "ADMIN", user_id: user_id})
    %{id: role_id_doctor} = create_role(%{name: "DOCTOR", user_id: user_id})
    create_user_role(%{role_id: role_id_admin, user_id: user_id})
    create_user_role(%{role_id: role_id_admin, user_id: user_id})
    %{id: user_role_id} = create_user_role(%{role_id: role_id_doctor, user_id: user_id})

    conn = delete conn, user_role_path(conn, :delete_by_user, user_id), [role_name: "ADMIN"]
    assert response(conn, 204)

    conn = get conn, user_role_path(conn, :index, %User{id: user_id})
    assert [user_role] = json_response(conn, 200)["data"]
    assert user_role_id == user_role["id"]
  end
end
