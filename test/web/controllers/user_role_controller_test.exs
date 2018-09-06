defmodule Mithril.Web.UserRoleControllerTest do
  use Mithril.Web.ConnCase

  setup %{conn: conn} do
    user = insert(:user)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), user: user}
  end

  describe "list user_roles" do
    test "all entries on index", %{conn: conn, user: user} do
      insert(:user_role, user: user)
      insert(:user_role, user: user)
      insert(:user_role, user: user)
      conn = get(conn, user_role_path(conn, :index, user))
      assert 3 == length(json_response(conn, 200)["data"])
    end

    test "search by user_ids", %{conn: conn} do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      insert(:user_role, user: user1)
      insert(:user_role, user: user1)
      insert(:user_role, user: user2)
      insert(:user_role, user: user3)

      # all user_roles
      conn = get(conn, user_roles_path(conn, :index))
      assert 4 == length(json_response(conn, 200)["data"])

      # filter by user_ids and client_id
      conn = get(conn, user_roles_path(conn, :index), user_ids: "#{user1.id},#{user2.id}")
      data = json_response(conn, 200)["data"]
      assert 3 == length(data)

      Enum.each(data, fn %{"user_id" => user_id} ->
        assert user_id in [user1.id, user2.id]
      end)
    end

    test "search by user_ids and client_id", %{conn: conn} do
      %{id: id1} = user1 = insert(:user)
      %{id: id2} = user2 = insert(:user)
      %{id: client_id1} = client1 = insert(:client)
      %{id: client_id2} = client2 = insert(:client)

      insert(:user_role, user: user1, client: client1)
      insert(:user_role, user: user1, client: client2)
      insert(:user_role, user: user2, client: client1)
      insert(:user_role, user: user2, client: client2)

      # all user_roles
      conn = get(conn, user_roles_path(conn, :index))
      assert 4 == length(json_response(conn, 200)["data"])

      # filter by user_ids and client_id
      conn = get(conn, user_roles_path(conn, :index), user_ids: "#{id1},#{id2}", client_id: client_id1)
      data = json_response(conn, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"user_id" => user_id, "client_id" => client_id} ->
        assert user_id in [id1, id2]
        assert client_id in [client_id1, client_id2]
      end)
    end

    test "search by invalid client_id", %{conn: conn} do
      assert [err] =
               conn
               |> get(user_roles_path(conn, :index), client_id: "asd")
               |> json_response(422)
               |> get_in(~w(error invalid))

      assert "$.client_id" == err["entry"]
    end
  end

  test "creates user_role and renders user_role when data is valid", %{user: user, conn: conn} do
    client = insert(:client)
    role = insert(:role)

    create_attrs = %{
      client_id: client.id,
      role_id: role.id,
      user_id: user.id
    }

    assert %{"id" => id, "scope" => _} =
             conn
             |> post(user_role_path(conn, :create, user), user_role: create_attrs)
             |> json_response(201)
             |> Map.get("data")

    resp =
      conn
      |> get(user_role_path(conn, :show, user, id))
      |> json_response(200)
      |> Map.get("data")

    assert %{
             "id" => id,
             "client_id" => create_attrs.client_id,
             "role_id" => create_attrs.role_id,
             "user_id" => create_attrs.user_id
           } == resp
  end

  test "create user_role twice with same user_id, client_id", %{conn: conn, user: user} do
    client = insert(:client)
    role = insert(:role)

    create_attrs = %{
      client_id: client.id,
      role_id: role.id,
      user_id: user.id
    }

    data =
      conn
      |> post(user_role_path(conn, :create, user), user_role: create_attrs)
      |> json_response(201)
      |> Map.get("data")

    assert %{
             "id" => _,
             "client_id" => _,
             "role_id" => _,
             "user_id" => _,
             "scope" => _
           } = data

    assert user.id == data["user_id"]
    assert role.id == data["role_id"]
    assert client.id == data["client_id"]

    resp =
      conn
      |> post(user_role_path(conn, :create, user), user_role: create_attrs)
      |> json_response(422)

    assert %{
             "error" => %{
               "invalid" => [
                 %{"rules" => [%{"description" => "has already been taken"}]}
               ]
             }
           } = resp
  end

  test "does not create user_role and renders errors when data is invalid", %{user: user, conn: conn} do
    invalid_attrs = %{client_id: nil, role_id: nil}

    refute %{} ==
             conn
             |> post(user_role_path(conn, :create, user), user_role: invalid_attrs)
             |> json_response(422)
             |> Map.get("errors")
  end

  test "deletes chosen user_role", %{conn: conn} do
    user_role = insert(:user_role)
    conn = delete(conn, user_role_path(conn, :delete, user_role.id))
    assert response(conn, 204)

    assert_error_sent(404, fn ->
      get(conn, user_role_path(conn, :show, user_role.user_id, user_role.id))
    end)
  end

  test "deletes user_roles by user_id", %{user: user, conn: conn} do
    insert(:user_role, user: user)
    insert(:user_role, user: user)

    user2 = insert(:user)
    insert(:user_role, user: user2)

    conn = delete(conn, user_role_path(conn, :delete_by_user, user))
    assert response(conn, 204)

    conn = get(conn, user_role_path(conn, :index, user))
    assert [] == json_response(conn, 200)["data"]

    conn = get(conn, user_role_path(conn, :index, user2))
    assert 1 == length(json_response(conn, 200)["data"])
  end

  test "delete user_role by role_id", %{user: user, conn: conn} do
    user_role = insert(:user_role, user: user)
    conn = delete(conn, "/admin/users/roles/#{user_role.id}")
    assert response(conn, 204)

    assert_raise Ecto.NoResultsError, fn ->
      get(conn, user_role_path(conn, :show, user.id, user_role.id))
    end
  end

  test "deletes user_roles by user_id and client_id", %{user: user, conn: conn} do
    cleanup_fixture_roles()
    role_admin = insert(:role, name: "ADMIN")
    role_doctor = insert(:role, name: "DOCTOR")
    insert(:user_role, role: role_admin, user: user)
    insert(:user_role, role: role_admin, user: user)
    %{id: user_role_id} = insert(:user_role, role: role_doctor, user: user)

    conn = delete(conn, user_role_path(conn, :delete_by_user, user.id), role_name: "ADMIN")
    assert response(conn, 204)

    conn = get(conn, user_role_path(conn, :index, user))
    assert [user_role] = json_response(conn, 200)["data"]
    assert user_role_id == user_role["id"]
  end
end
