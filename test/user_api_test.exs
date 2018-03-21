defmodule Mithril.UserAPITest do
  use Mithril.DataCase

  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.UserAPI.User.LoginHstr
  alias Mithril.Authorization.LoginHistory
  alias Scrivener.Page

  @create_attrs %{email: "email@example.com", password: "Some password1", settings: %{}}
  @update_attrs %{
    email: "some updated email",
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

  def fixture(:user, attrs \\ @create_attrs) do
    {:ok, user} = UserAPI.create_user(attrs)
    user
  end

  test "list_users/1 returns all users without search params" do
    # System User already inserted in DB by means of migration
    system_user = UserAPI.get_user!("4261eacf-8008-4e62-899f-de1e2f7065f0")
    user = fixture(:user)

    assert UserAPI.list_users(%{}) == %Page{
             entries: [system_user, user],
             page_number: 1,
             page_size: 50,
             total_pages: 1,
             total_entries: 2
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
             total_pages: 1
           }
  end

  test "get_user! returns the user with given id" do
    user = fixture(:user)
    assert UserAPI.get_user!(user.id) == user
  end

  test "create_user/1 with valid data creates a user" do
    assert {:ok, %User{} = user} = UserAPI.create_user(@create_attrs)
    assert user.email == "email@example.com"
    assert String.length(user.password) == 60
    assert user.settings == %{}

    assert user.priv_settings == %Mithril.UserAPI.User.PrivSettings{
             login_hstr: [],
             otp_error_counter: 0
           }
  end

  test "email is case insensive" do
    assert {:ok, %User{}} = UserAPI.create_user(@create_attrs)
    attrs = %{@create_attrs | email: "EMAIL@example.com"}

    assert {:error, %Ecto.Changeset{valid?: false, errors: [email: {"has already been taken", []}]}} =
             UserAPI.create_user(attrs)
  end

  test "create_user/1 secures user password" do
    {:ok, user} = UserAPI.create_user(@create_attrs)

    assert Comeonin.Bcrypt.checkpw("Some password1", user.password)
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
             login_hstr: [],
             otp_error_counter: 0
           }
  end

  test "update_user_priv_settings/2 with valid data updates the user.priv_settings" do
    user = fixture(:user)
    assert {:ok, user} = UserAPI.update_user_priv_settings(user, @update_attrs.priv_settings)
    assert %User{} = user
    assert length(user.priv_settings.login_hstr) == 2
    assert user.priv_settings.otp_error_counter == 5
  end

  test "update_user/2 with invalid data returns error changeset" do
    user = fixture(:user)
    assert {:error, %Ecto.Changeset{}} = UserAPI.update_user(user, @invalid_attrs)
    assert user == UserAPI.get_user!(user.id)
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
    user = fixture(:user)
    assert {:ok, %User{}} = UserAPI.delete_user(user)
    assert_raise Ecto.NoResultsError, fn -> UserAPI.get_user!(user.id) end
  end
end
