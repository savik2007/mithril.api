defmodule Core.RoleAPITest do
  use Core.DataCase

  alias Core.RoleAPI
  alias Core.RoleAPI.Role
  alias Scrivener.Page

  @create_attrs %{name: "some name", scope: "some scope"}
  @update_attrs %{name: "some updated name", scope: "some updated scope"}
  @invalid_attrs %{name: nil, scope: nil}

  test "list_roles/1 returns all roles" do
    cleanup_fixture_roles()
    role = insert(:role)
    assert %Page{entries: roles} = RoleAPI.list_roles()
    assert List.first(roles) == role
  end

  test "get_role! returns the role with given id" do
    role = insert(:role)
    assert RoleAPI.get_role!(role.id) == role
  end

  test "create_role/1 with valid data creates a role" do
    assert {:ok, %Role{} = role} = RoleAPI.create_role(@create_attrs)
    assert role.name == "some name"
    assert role.scope == "some scope"
  end

  test "create_role/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = RoleAPI.create_role(@invalid_attrs)
  end

  test "update_role/2 with valid data updates the role" do
    role = insert(:role)
    assert {:ok, role} = RoleAPI.update_role(role, @update_attrs)
    assert %Role{} = role
    assert role.name == "some updated name"
    assert role.scope == "some updated scope"
  end

  test "update_role/2 with invalid data returns error changeset" do
    role = insert(:role)
    assert {:error, %Ecto.Changeset{}} = RoleAPI.update_role(role, @invalid_attrs)
    assert role == RoleAPI.get_role!(role.id)
  end

  test "delete_role/1 deletes the role" do
    role = insert(:role)
    assert {:ok, %Role{}} = RoleAPI.delete_role(role)
    assert_raise Ecto.NoResultsError, fn -> RoleAPI.get_role!(role.id) end
  end

  test "change_role/1 returns a role changeset" do
    role = insert(:role)
    assert %Ecto.Changeset{} = RoleAPI.change_role(role)
  end
end
