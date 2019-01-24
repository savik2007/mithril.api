defmodule Mithril.UserAPITest do
  use Mithril.DataCase

  alias Comeonin.Bcrypt
  alias Ecto.Changeset
  alias Ecto.NoResultsError
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.UserAPI.User.LoginHstr
  alias Mithril.Authorization.LoginHistory
  alias Mithril.UserAPI.User.PrivSettings
  alias Scrivener.Page

  @create_attrs %{"email" => "email@example.com", "password" => "Some password1", "tax_id" => "12342345"}
  @update_attrs %{
    email: "updated@example.com",
    password: "Some updated password1",
    settings: %{},
    priv_settings: %{
      login_hstr: [
        %{
          type: LoginHistory.type(:password),
          time: NaiveDateTime.utc_now()
        },
        %{
          type: LoginHistory.type(:password),
          time: NaiveDateTime.utc_now()
        }
      ],
      otp_error_counter: 5,
      invalid: "field"
    }
  }
  @invalid_attrs %{email: nil, password: nil, settings: nil}

  test "list_users/1 returns all users without search params" do
    # System User already inserted in DB by means of migration
    system_user_id = "4261eacf-8008-4e62-899f-de1e2f7065f0"
    %{id: id} = insert(:user)

    assert %Page{
             entries: [%{id: ^system_user_id}, %{id: ^id}],
             page_number: 1,
             page_size: 50,
             total_pages: 1,
             total_entries: 2
           } = UserAPI.list_users(%{})
  end

  test "list_users/1 returns all users with valid search params" do
    %{id: id} = user = insert(:user)

    assert %Page{
             entries: [%{id: ^id}],
             page_number: 1,
             page_size: 50,
             total_pages: 1,
             total_entries: 1
           } = UserAPI.list_users(%{"email" => user.email})
  end

  test "list_users/1 returns empty list with invalid search params" do
    user = insert(:user)

    assert UserAPI.list_users(%{"email" => user.email <> "111"}) == %Page{
             entries: [],
             page_number: 1,
             page_size: 50,
             total_entries: 0,
             total_pages: 1
           }
  end

  test "get_user! returns the user with given id" do
    %{id: id} = insert(:user)
    assert %User{id: ^id} = UserAPI.get_user!(id)
  end

  test "create_user/1 with valid data creates a user" do
    assert {:ok, %User{} = user} = UserAPI.create_user(@create_attrs)
    assert user.email == "email@example.com"
    assert String.length(user.password) == 60
    assert user.settings == %{}

    assert user.priv_settings == %PrivSettings{login_hstr: [], otp_error_counter: 0}
  end

  test "email is case insensive" do
    assert {:ok, %User{}} = UserAPI.create_user(@create_attrs)
    attrs = %{@create_attrs | "email" => "EMAIL@example.com"}

    assert {:error, %Changeset{valid?: false, errors: [email: {"has already been taken", []}]}} =
             UserAPI.create_user(attrs)
  end

  test "create_user/1 secures user password" do
    {:ok, user} = UserAPI.create_user(@create_attrs)

    assert Bcrypt.checkpw("Some password1", user.password)
  end

  test "create_user/1 with invalid data returns error changeset" do
    assert {:error, %Changeset{}} = UserAPI.create_user(@invalid_attrs)
  end

  test "update_user/2 with valid data updates the user" do
    user = insert(:user)
    assert {:ok, user} = UserAPI.update_user(user, @update_attrs)
    assert %User{} = user
    assert user.email == "updated@example.com"
    assert String.length(user.password) == 60
    assert user.settings == %{}

    assert user.priv_settings == %PrivSettings{login_hstr: [], otp_error_counter: 0}
  end

  test "update_user_priv_settings/2 with valid data updates the user.priv_settings" do
    user = insert(:user)
    assert {:ok, user} = UserAPI.update_user_priv_settings(user, @update_attrs.priv_settings)
    assert %User{} = user
    assert length(user.priv_settings.login_hstr) == 2
    assert user.priv_settings.otp_error_counter == 5
  end

  test "update_user/2 with invalid data returns error changeset" do
    user = insert(:user)
    assert {:error, %Changeset{}} = UserAPI.update_user(user, %{email: nil})
    assert user.email == UserAPI.get_user!(user.id).email
  end

  test "unblock/1 and refresh error counters" do
    user =
      insert(
        :user,
        priv_settings: %{
          login_hstr: [
            %LoginHstr{type: LoginHistory.type(:password), time: NaiveDateTime.utc_now()},
            %LoginHstr{type: LoginHistory.type(:password), time: NaiveDateTime.utc_now()}
          ],
          otp_error_counter: 3
        }
      )

    assert %{
             priv_settings: %{
               login_hstr: [%LoginHstr{}, %LoginHstr{}],
               otp_error_counter: 3
             }
           } = UserAPI.get_user!(user.id)

    assert {:ok, %User{}} = UserAPI.unblock_user(user)
    db_user = UserAPI.get_user!(user.id)
    assert %{login_hstr: [], otp_error_counter: 0} = db_user.priv_settings
    refute db_user.is_blocked
  end

  test "delete_user/1 deletes the user" do
    user = insert(:user)
    assert {:ok, %User{}} = UserAPI.delete_user(user)
    assert_raise NoResultsError, fn -> UserAPI.get_user!(user.id) end
  end
end
