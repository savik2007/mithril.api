defmodule Mithril.UserAPITest do
  use Mithril.DataCase

  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Scrivener.Page

  @create_attrs %{email: "some email", password: "some password", settings: %{}}
  @update_attrs %{
    email: "some updated email",
    password: "some updated password",
    settings: %{},
    priv_settings: %{
      login_error_counter: 2,
      otp_error_counter: 5,
      invalid: "field"
    }
  }
  @invalid_attrs %{email: nil, password: nil, settings: nil}

  def fixture(:user, attrs \\ @create_attrs) do
    {:ok, user} = UserAPI.create_user(attrs)
    user
  end

  test "list_users/1 returns all users without search params" do
    user = fixture(:user)
    assert UserAPI.list_users(%{}) == %Page{
             entries: [user],
             page_number: 1,
             page_size: 50,
             total_pages: 1,
             total_entries: 1
           }
  end

  test "list_users/1 returns all users with valid search params" do
    user = fixture(:user)
    assert UserAPI.list_users(%{"email" => user.email}) == %Page{
             entries: [user],
             page_number: 1,
             page_size: 50,
             total_pages: 1,
             total_entries: 1
           }
  end

  test "list_users/1 returns empty list with invalid search params" do
    user = fixture(:user)
    assert UserAPI.list_users(%{"email" => user.email <> "111"}) == %Page{
             entries: [],
             page_number: 1,
             page_size: 50,
             total_entries: 0,
             total_pages: 1,
           }
  end

  test "get_user! returns the user with given id" do
    user = fixture(:user)
    assert UserAPI.get_user!(user.id) == user
  end

  test "create_user/1 with valid data creates a user" do
    assert {:ok, %User{} = user} = UserAPI.create_user(@create_attrs)
    assert user.email == "some email"
    assert String.length(user.password) == 60
    assert user.settings == %{}
    assert user.priv_settings == %Mithril.UserAPI.User.PrivSettings{
             login_error_counter: 0,
             otp_error_counter: 0
           }
  end

  test "create_user/1 secures user password" do
    {:ok, user} = UserAPI.create_user(@create_attrs)

    assert Comeonin.Bcrypt.checkpw("some password", user.password)
  end

  test "create_user/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = UserAPI.create_user(@invalid_attrs)
  end

  test "update_user/2 with valid data updates the user" do
    user = fixture(:user)
    assert {:ok, user} = UserAPI.update_user(user, @update_attrs)
    assert %User{} = user
    assert user.email == "some updated email"
    assert String.length(user.password) == 60
    assert user.settings == %{}
    assert user.priv_settings == %Mithril.UserAPI.User.PrivSettings{
             login_error_counter: 0,
             otp_error_counter: 0
           }
  end

  test "update_user_priv_settings/2 with valid data updates the user.priv_settings" do
    user = fixture(:user)
    assert {:ok, user} = UserAPI.update_user_priv_settings(user, @update_attrs.priv_settings)
    assert %User{} = user
    assert user.priv_settings == %Mithril.UserAPI.User.PrivSettings{
             login_error_counter: 2,
             otp_error_counter: 5
           }
  end

  test "update_user/2 with invalid data returns error changeset" do
    user = fixture(:user)
    assert {:error, %Ecto.Changeset{}} = UserAPI.update_user(user, @invalid_attrs)
    assert user == UserAPI.get_user!(user.id)
  end

  test "delete_user/1 deletes the user" do
    user = fixture(:user)
    assert {:ok, %User{}} = UserAPI.delete_user(user)
    assert_raise Ecto.NoResultsError, fn -> UserAPI.get_user!(user.id) end
  end

  test "change_user/1 returns a user changeset" do
    user = fixture(:user)
    assert %Ecto.Changeset{} = UserAPI.change_user(user)
  end
end
