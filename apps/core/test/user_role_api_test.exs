defmodule Core.UserRoleAPITest do
  use Core.DataCase

  alias Core.UserRoleAPI
  alias Core.UserRoleAPI.UserRole

  test "list_user_roles/1 returns all user_roles" do
    user_role =
      :user_role
      |> insert()
      |> Repo.preload(:client)
      |> Repo.preload(:role)

    assert {:ok, list} = UserRoleAPI.list_user_roles(%{"user_id" => user_role.user_id})
    assert 1 == length(list)
    assert user_role.id == hd(list).id
  end

  test "get_user_role! returns the user_role with given id" do
    user_role = insert(:user_role)
    db_user_role = UserRoleAPI.get_user_role!(user_role.id)
    assert db_user_role.id == user_role.id
    assert db_user_role.client_id == user_role.client_id
    assert db_user_role.role_id == user_role.role_id
  end

  describe "create_user_role" do
    setup do
      role = insert(:role)
      client = insert(:client)

      attrs = %{
        user_id: client.user.id,
        role_id: role.id,
        client_id: client.id
      }

      {:ok, attrs: attrs}
    end

    test "create_user_role/1 with valid data creates a user_role", %{attrs: attrs} do
      assert {:ok, %UserRole{} = user_role} = UserRoleAPI.create_user_role(attrs)
      assert user_role.client_id == attrs.client_id
      assert user_role.role_id == attrs.role_id
      assert user_role.user_id == attrs.user_id
    end

    test "create_user_role/1 with duplicate data returns error changeset", %{attrs: attrs} do
      assert {:ok, %UserRole{}} = UserRoleAPI.create_user_role(attrs)
      assert {:error, %Ecto.Changeset{}} = UserRoleAPI.create_user_role(attrs)
    end
  end

  test "create_user_role/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = UserRoleAPI.create_user_role(%{client_id: nil, role_id: nil, user_id: nil})
  end

  test "delete_user_role/1 deletes the user_role" do
    user_role = insert(:user_role)
    assert {:ok, %UserRole{}} = UserRoleAPI.delete_user_role(user_role)
    assert_raise Ecto.NoResultsError, fn -> UserRoleAPI.get_user_role!(user_role.id) end
  end
end
