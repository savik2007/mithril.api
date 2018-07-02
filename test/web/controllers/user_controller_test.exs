defmodule Mithril.Web.UserControllerTest do
  use Mithril.Web.ConnCase

  import Ecto.Query
  alias Ecto.UUID
  alias Mithril.TokenAPI
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.Authentication
  alias Mithril.UserAPI.PasswordHistory
  alias Mithril.Repo
  alias Mithril.Authentication.Factor

  @create_attrs %{
    email: "email@example.com",
    password: "Somepassword1",
    settings: %{},
    "2fa_enable": true,
    tax_id: "12341234",
    person_id: UUID.generate()
  }
  @update_attrs %{email: "update@example.com", password: "Some updated password1", settings: %{}}
  @invalid_attrs %{email: nil, password: nil, settings: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "search users" do
    test "lists all entries on index", %{conn: conn} do
      insert(:user, email: "1", password: "Password1234", settings: %{})
      insert(:user, email: "2", password: "Password2234", settings: %{})
      insert(:user, email: "3", password: "Password3234", settings: %{})

      conn = get(conn, user_path(conn, :index))

      # System User already inserted in DB by means of migration
      [users_count] = Repo.all(from(u in User, select: count(u.id)))

      assert users_count == length(json_response(conn, 200)["data"])
    end

    test "does not list all entries on index when limit is set", %{conn: conn} do
      insert(:user, email: "1", password: "Password1234", settings: %{})
      insert(:user, email: "2", password: "Password2234", settings: %{})
      insert(:user, email: "3", password: "Password3234", settings: %{})
      conn = get(conn, user_path(conn, :index), %{page_size: 2})
      assert 2 == length(json_response(conn, 200)["data"])
    end

    test "does not list all entries on index when starting_after is set", %{conn: conn} do
      # System User already inserted in DB by means of migration
      insert(:user, email: "1", password: "Password1234", settings: %{})
      insert(:user, email: "2", password: "Password2234", settings: %{})
      insert(:user, email: "3", password: "Password3234", settings: %{})
      insert(:user, email: "4", password: "Password4234", settings: %{})

      conn = get(conn, user_path(conn, :index), %{page_size: 2, page: 3})
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
    end

    test "finds user by valid email", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: @create_attrs)

      resp =
        conn
        |> get(user_path(conn, :index, %{email: @create_attrs.email}))
        |> json_response(200)
        |> Map.get("data")

      assert 1 == length(resp)
      assert resp |> hd() |> Map.has_key?("tax_id")
    end

    test "finds users by id", %{conn: conn} do
      user = insert(:user, %{email: "1", password: "Password1234", settings: %{}})
      conn = get(conn, user_path(conn, :index, %{id: user.id}))
      assert length(json_response(conn, 200)["data"]) == 1
    end

    test "finds users by tax_id", %{conn: conn} do
      insert(:user, %{email: "1", password: "Password1234", tax_id: "3002001020"})
      %{id: id} = insert(:user, %{email: "2", password: "Password1234", tax_id: "3002001030"})

      assert [%{"id" => ^id}] =
               conn
               |> get(user_path(conn, :index, %{tax_id: "3002001030"}))
               |> json_response(200)
               |> Map.get("data")
    end

    test "finds users by ids and is_blocked", %{conn: conn} do
      %{id: id1} = insert(:user, email: "1", password: "Password1234", settings: %{}, is_blocked: true)
      %{id: id2} = insert(:user, email: "2", password: "Password2234", settings: %{}, is_blocked: true)
      %{id: id3} = insert(:user, email: "3", password: "Password3234", settings: %{})
      insert(:user, %{email: "4", password: "Password4234", settings: %{}})

      conn = get(conn, user_path(conn, :index, %{ids: Enum.join([id1, id2, id3], ","), is_blocked: true}))
      data = json_response(conn, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"id" => id} ->
        assert id in [id1, id2]
      end)
    end

    test "finds nothing by invalid email", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: @create_attrs)
      conn = get(conn, user_path(conn, :index, %{email: @create_attrs.email <> "111"}))
      assert Enum.empty?(json_response(conn, 200)["data"])
    end
  end

  describe "create user" do
    test "creates user and renders user when data is valid", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, user_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "email" => "email@example.com",
               "person_id" => _,
               "settings" => %{}
             } = json_response(conn, 200)["data"]

      # duplicated email
      assert [err] =
               conn
               |> post(user_path(conn, :create), user: Map.put(@create_attrs, :tax_id, "99990000"))
               |> json_response(422)
               |> get_in(~w(error invalid))

      assert "$.email" == err["entry"]
    end

    test "password is too short", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: Map.put(@create_attrs, :password, "Short1"))
      res = json_response(conn, 422)

      assert [
               %{
                 "entry" => "$.password",
                 "entry_type" => "json_data_property",
                 "rules" => [
                   %{
                     "description" => "should be at least 12 character(s)",
                     "params" => %{"min" => 12},
                     "rule" => "length"
                   }
                 ]
               }
             ] = res["error"]["invalid"]
    end

    test "password has no uppercase", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: Map.put(@create_attrs, :password, "password1234"))
      res = json_response(conn, 422)

      assert [
               %{
                 "entry" => "$.password",
                 "entry_type" => "json_data_property",
                 "rules" => [
                   %{
                     "description" => "Password does not meet complexity requirements",
                     "params" => ["~r/^(?=.*[a-zа-яёїієґ])(?=.*[A-ZА-ЯЁЇIЄҐ])(?=.*\\d)/"],
                     "rule" => "format"
                   }
                 ]
               }
             ] = res["error"]["invalid"]
    end

    test "password has no lowercase", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: Map.put(@create_attrs, :password, "PASSWORD1234"))
      res = json_response(conn, 422)

      assert [
               %{
                 "entry" => "$.password",
                 "entry_type" => "json_data_property",
                 "rules" => [
                   %{
                     "description" => "Password does not meet complexity requirements",
                     "params" => ["~r/^(?=.*[a-zа-яёїієґ])(?=.*[A-ZА-ЯЁЇIЄҐ])(?=.*\\d)/"],
                     "rule" => "format"
                   }
                 ]
               }
             ] = res["error"]["invalid"]
    end

    test "password has no numbers", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: Map.put(@create_attrs, :password, "Passwordpassword"))
      res = json_response(conn, 422)

      assert [
               %{
                 "entry" => "$.password",
                 "entry_type" => "json_data_property",
                 "rules" => [
                   %{
                     "description" => "Password does not meet complexity requirements",
                     "params" => ["~r/^(?=.*[a-zа-яёїієґ])(?=.*[A-ZА-ЯЁЇIЄҐ])(?=.*\\d)/"],
                     "rule" => "format"
                   }
                 ]
               }
             ] = res["error"]["invalid"]
    end

    test "create user with factor", %{conn: conn} do
      key = Authentication.generate_otp_key("email@example.com", "+380631112233")
      insert(:otp, key: key, code: 1234)
      attrs = Map.merge(@create_attrs, %{factor: "+380631112233", otp: 1234})

      assert %{"id" => id} =
               conn
               |> post(user_path(conn, :create), user: attrs)
               |> json_response(201)
               |> Map.get("data")

      resp =
        conn
        |> get(user_path(conn, :show, id))
        |> json_response(200)
        |> Map.get("data")

      assert %{
               "id" => ^id,
               "email" => "email@example.com",
               "settings" => %{}
             } = resp

      assert [factor] =
               conn
               |> get(user_authentication_factor_path(conn, :index, id))
               |> json_response(200)
               |> Map.get("data")

      assert "+38063*****33" == factor["factor"]
    end

    test "create user with factor but without otp", %{conn: conn} do
      attrs = Map.merge(@create_attrs, %{factor: "+380631112233"})

      assert conn
             |> post(user_path(conn, :create), user: attrs)
             |> json_response(201)
    end

    test "create user with factor but invalid OTP", %{conn: conn} do
      key = Authentication.generate_otp_key("email@example.com", "+380631112233")
      insert(:otp, key: key, code: 1234)

      attrs = Map.merge(@create_attrs, %{factor: "+380631112233", otp: 1235})

      assert conn
             |> post(user_path(conn, :create), user: attrs)
             |> json_response(201)
    end

    test "create user with factor but OTP was not created", %{conn: conn} do
      attrs = Map.merge(@create_attrs, %{factor: "+380631112233", otp: 1234})

      assert conn
             |> post(user_path(conn, :create), user: attrs)
             |> json_response(201)
    end

    test "does not create user and renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup %{conn: conn} do
      %{conn: conn, user: insert(:user, email: "email@example.com")}
    end

    test "updates chosen user and renders user when data is valid", %{conn: conn, user: user} do
      %User{id: id, password_set_at: password_set_at} = user
      conn = put(conn, user_path(conn, :update, user), user: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, user_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "email" => "update@example.com",
               "settings" => %{}
             } = json_response(conn, 200)["data"]

      user = UserAPI.get_user!(id)
      refute password_set_at == user.password_set_at
    end

    test "update user with factor when factor don't exist and otp valid", %{conn: conn, user: user} do
      key = Authentication.generate_otp_key("email@example.com", "+380551112233")
      insert(:otp, key: key, code: 2233)

      person_id = UUID.generate()

      update = %{
        "2fa_enable": true,
        factor: "+380551112233",
        tax_id: "12341234",
        otp: 2233,
        person_id: person_id
      }

      assert %{"id" => id, "person_id" => ^person_id} =
               conn
               |> put(user_path(conn, :update, user), user: update)
               |> json_response(200)
               |> Map.get("data")

      assert id

      assert [factor] =
               conn
               |> get(user_authentication_factor_path(conn, :index, id))
               |> json_response(200)
               |> Map.get("data")

      assert "+38055*****33" == factor["factor"]
    end

    test "update user with factor when factor doesn't exist and otp invalid", %{conn: conn, user: user} do
      key = Authentication.generate_otp_key("email@example.com", "+380551112233")
      insert(:otp, key: key, code: 2233)

      update = %{
        "2fa_enable": true,
        factor: "+380551112233",
        tax_id: "12341234",
        otp: 1234,
        person_id: UUID.generate()
      }

      assert conn
             |> put(user_path(conn, :update, user), user: update)
             |> json_response(200)
    end

    test "update user with factor when factor exist and otp valid", %{conn: conn, user: user} do
      insert(:authentication_factor, user_id: user.id)
      key = Authentication.generate_otp_key("email@example.com", "+380551112233")
      insert(:otp, key: key, code: 1234)

      update = %{
        "2fa_enable": true,
        factor: "+380551112233",
        tax_id: "12341234",
        otp: 1234,
        person_id: UUID.generate()
      }

      id =
        conn
        |> put(user_path(conn, :update, user), user: update)
        |> json_response(200)
        |> get_in(~w(data id))

      assert id

      assert [factor] =
               conn
               |> get(user_authentication_factor_path(conn, :index, id))
               |> json_response(200)
               |> Map.get("data")

      assert "+38055*****33" == factor["factor"]
    end

    test "update user with factor when factor exist and otp invalid", %{conn: conn, user: user} do
      insert(:authentication_factor, user_id: user.id)

      update = %{
        "2fa_enable": true,
        factor: "+380551112233",
        tax_id: "12341234",
        otp: 9999,
        person_id: UUID.generate()
      }

      assert conn
             |> put(user_path(conn, :update, user), user: update)
             |> json_response(200)
    end

    test "does not update chosen user and renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, user_path(conn, :update, user), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "deletes chosen user", %{conn: conn, user: user} do
      conn
      |> delete(user_path(conn, :delete, user))
      |> response(204)

      assert_error_sent(404, fn ->
        get(conn, user_path(conn, :show, user))
      end)
    end
  end

  describe "create and update user without 2fa attr when USER_2FA_ENABLED config value is true (turned on)" do
    setup %{conn: conn} do
      current_value = System.get_env("USER_2FA_ENABLED") || "false"
      System.put_env("USER_2FA_ENABLED", "true")

      on_exit(fn ->
        System.put_env("USER_2FA_ENABLED", current_value)
      end)

      {:ok, %{conn: conn}}
    end

    test "successful creation", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: Map.delete(@create_attrs, :"2fa_enable"))
      assert %{"id" => id} = json_response(conn, 201)["data"]
      # both User and Factor are created
      refute is_nil(Repo.get(User, id))
      refute is_nil(Repo.get_by(Factor, user_id: id))
    end

    test "successful updating user without factor", %{conn: conn} do
      %User{id: id} = insert(:user, email: "email@example.com")
      conn = put(conn, user_path(conn, :update, id), user: @update_attrs)

      # User is updated
      assert %{
               "id" => ^id,
               "email" => "update@example.com",
               "settings" => %{}
             } = json_response(conn, 200)["data"]

      # Factor is not created
      assert is_nil(Repo.get_by(Factor, user_id: id))
    end

    test "successful updating user (only) with factor", %{conn: conn} do
      %User{id: id} = insert(:user, email: "email@example.com")
      insert(:authentication_factor, user_id: id)
      conn = put(conn, user_path(conn, :update, id), user: @update_attrs)

      # User is updated
      assert %{
               "id" => ^id,
               "email" => "update@example.com",
               "settings" => %{}
             } = json_response(conn, 200)["data"]

      # Factor is not updated
      assert [factor] =
               conn
               |> get(user_authentication_factor_path(conn, :index, id))
               |> json_response(200)
               |> Map.get("data")

      assert "+38090*****33" == factor["factor"]
    end
  end

  describe "create and update user without 2fa attr when USER_2FA_ENABLED config value is false (turned off)" do
    setup %{conn: conn} do
      current_value = System.get_env("USER_2FA_ENABLED") || "false"
      System.put_env("USER_2FA_ENABLED", "false")

      on_exit(fn ->
        System.put_env("USER_2FA_ENABLED", current_value)
      end)

      {:ok, %{conn: conn}}
    end

    test "successful creation", %{conn: conn} do
      conn = post(conn, user_path(conn, :create), user: Map.delete(@create_attrs, :"2fa_enable"))
      assert %{"id" => id} = json_response(conn, 201)["data"]
      # User is created
      refute is_nil(Repo.get(User, id))
      # Factor is not created
      assert is_nil(Repo.get_by(Factor, user_id: id))
    end

    test "successful updating user without factor", %{conn: conn} do
      %User{id: id} = insert(:user, email: "email@example.com")
      conn = put(conn, user_path(conn, :update, id), user: @update_attrs)

      # User is updated
      assert %{
               "id" => ^id,
               "email" => "update@example.com",
               "settings" => %{}
             } = json_response(conn, 200)["data"]

      # Factor is not created
      assert is_nil(Repo.get_by(Factor, user_id: id))
    end

    test "successful updating user (only) with factor", %{conn: conn} do
      %User{id: id} = insert(:user, email: "email@example.com")
      insert(:authentication_factor, user_id: id)
      conn = put(conn, user_path(conn, :update, id), user: @update_attrs)

      # User is updated
      assert %{
               "id" => ^id,
               "email" => "update@example.com",
               "settings" => %{}
             } = json_response(conn, 200)["data"]

      # Factor is not updated
      assert [factor] =
               conn
               |> get(user_authentication_factor_path(conn, :index, id))
               |> json_response(200)
               |> Map.get("data")

      assert "+38090*****33" == factor["factor"]
    end
  end

  describe "block/unblock user" do
    test "block user. All user tokens deactivated", %{conn: conn} do
      user = insert(:user)
      token1 = insert(:token, user_id: user.id, details: %{"client_id" => UUID.generate()})
      token2 = insert(:token, user_id: user.id, details: %{"client_id" => UUID.generate()})

      refute TokenAPI.expired?(token1)
      refute TokenAPI.expired?(token2)

      params = %{user: %{"block_reason" => "fraud"}}
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/block", params)

      assert data = json_response(conn, 200)["data"]
      assert "fraud" = data["block_reason"]
      assert data["is_blocked"]

      assert token1.id |> TokenAPI.get_token!() |> TokenAPI.expired?()
      assert token2.id |> TokenAPI.get_token!() |> TokenAPI.expired?()
    end

    test "user already blocked", %{conn: conn} do
      user = insert(:user, is_blocked: true)
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/block")
      assert json_response(conn, 409)
    end

    test "invalid user params will be ignored", %{conn: conn} do
      user = insert(:user)
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/block", ~S({"user" : [{}] }))
      json_response(conn, 200)
    end

    test "unblock user", %{conn: conn} do
      user = insert(:user, is_blocked: true)
      params = %{user: %{"block_reason" => "good boy"}}
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/unblock", params)

      assert data = json_response(conn, 200)["data"]
      assert "good boy" = data["block_reason"]
      refute data["is_blocked"]
    end

    test "user already unblocked", %{conn: conn} do
      user = insert(:user)
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/unblock")
      assert json_response(conn, 409)
    end
  end

  describe "change password" do
    test "works with when current password is valid", %{conn: conn} do
      user = insert(:user, email: "1", password: Comeonin.Bcrypt.hashpwsalt("Hello1231234"), settings: %{})

      update_params = %{user: %{"password" => "World1231234", "current_password" => "Hello1231234"}}
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/change_password", update_params)
      assert json_response(conn, 200)

      updated_user = UserAPI.get_user(user.id)
      assert Comeonin.Bcrypt.checkpw("World1231234", updated_user.password)
      refute user.password_set_at == updated_user.password_set_at
    end

    test "returns validation error when current password is invalid", %{conn: conn} do
      user = insert(:user, email: "1", password: "Hello1231234", settings: %{})

      update_params = %{user: %{"password" => "World1231234", current_password: "invalid"}}
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/change_password", update_params)

      assert [%{"entry" => "$.current_password", "rules" => [%{"rule" => "password"}]}] =
               json_response(conn, 422)["error"]["invalid"]
    end

    test "returns validation error when current password is not present", %{conn: conn} do
      user = insert(:user, email: "1", password: "Hello1231234", settings: %{})

      update_params = %{user: %{"password" => "World1231234"}}
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/change_password", update_params)

      assert [%{"entry" => "$.current_password", "rules" => [%{"rule" => "required"}]}] =
               json_response(conn, 422)["error"]["invalid"]
    end

    test "returns validation error when new password is not present", %{conn: conn} do
      user = insert(:user, email: "1", password: "Hello1231234", settings: %{})

      update_params = %{user: %{current_password: "Hello1231234"}}
      conn = patch(conn, user_path(conn, :update, user) <> "/actions/change_password", update_params)

      assert [%{"entry" => "$.password", "rules" => [%{"rule" => "required"}]}] =
               json_response(conn, 422)["error"]["invalid"]
    end

    test "validation error when password has already been used", %{conn: conn} do
      user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("SecurePassword1"))

      update_params = %{user: %{"password" => "Password1234", current_password: "SecurePassword1"}}
      conn1 = patch(conn, user_path(conn, :update, user) <> "/actions/change_password", update_params)
      assert json_response(conn1, 200)

      update_params = %{user: %{"password" => "Password2234", current_password: "Password1234"}}
      conn2 = patch(conn, user_path(conn, :update, user) <> "/actions/change_password", update_params)
      assert json_response(conn2, 200)

      update_params = %{user: %{"password" => "Password3234", current_password: "Password2234"}}
      conn3 = patch(conn, user_path(conn, :update, user) <> "/actions/change_password", update_params)
      assert json_response(conn3, 200)

      update_params = %{user: %{"password" => "Password1234", current_password: "Password3234"}}
      conn4 = patch(conn, user_path(conn, :update, user) <> "/actions/change_password", update_params)
      res = json_response(conn4, 422)

      assert [
               %{
                 "entry" => "$.password",
                 "entry_type" => "json_data_property",
                 "rules" => [
                   %{
                     "description" => "This password has been used recently. Try another one",
                     "params" => [],
                     "rule" => "password_used"
                   }
                 ]
               }
             ] = res["error"]["invalid"]

      history =
        PasswordHistory
        |> where([ph], ph.user_id == ^user.id)
        |> order_by([ph], asc: ph.id)
        |> Repo.all()

      assert 3 == length(history)
      assert Comeonin.Bcrypt.checkpw("Password1234", hd(history).password)
    end
  end
end
