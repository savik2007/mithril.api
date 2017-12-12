defmodule Mithril.Web.UserControllerTest do
  use Mithril.Web.ConnCase

  alias Ecto.UUID
  alias Mithril.TokenAPI
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User

  @create_attrs %{email: "some email", password: "Somepassword1", settings: %{}, "2fa_enable": true}
  @update_attrs %{email: "some updated email", password: "Some updated password1", settings: %{}}
  @invalid_attrs %{email: nil, password: nil, settings: nil}

  def fixture(:user, create_attrs \\ @create_attrs) do
    {:ok, user} = UserAPI.create_user(create_attrs)
    user
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    fixture(:user, %{email: "1", password: "Password1", settings: %{}})
    fixture(:user, %{email: "2", password: "Password2", settings: %{}})
    fixture(:user, %{email: "3", password: "Password3", settings: %{}})
    conn = get conn, user_path(conn, :index)
    assert 3 == length(json_response(conn, 200)["data"])
  end

  test "does not list all entries on index when limit is set", %{conn: conn} do
    fixture(:user, %{email: "1", password: "Password1", settings: %{}})
    fixture(:user, %{email: "2", password: "Password2", settings: %{}})
    fixture(:user, %{email: "3", password: "Password3", settings: %{}})
    conn = get conn, user_path(conn, :index), %{page_size: 2}
    assert 2 == length(json_response(conn, 200)["data"])
  end

  test "does not list all entries on index when starting_after is set", %{conn: conn} do
    fixture(:user, %{email: "1", password: "Password1", settings: %{}})
    fixture(:user, %{email: "2", password: "Password2", settings: %{}})
    user = fixture(:user, %{email: "3", password: "Password3", settings: %{}})
    conn = get conn, user_path(conn, :index), %{page_size: 2, page: 2}
    resp = json_response(conn, 200)["data"]
    assert 1 == length(resp)
    assert user.id == Map.get(hd(resp), "id")
  end

  test "finds user by valid email", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @create_attrs
    conn = get conn, user_path(conn, :index, %{email: @create_attrs.email})
    assert length(json_response(conn, 200)["data"]) == 1
  end

  test "finds users by id", %{conn: conn} do
    user = fixture(:user, %{email: "1", password: "Password1", settings: %{}})
    conn = get conn, user_path(conn, :index, %{id: user.id})
    assert length(json_response(conn, 200)["data"]) == 1
  end

  test "finds users by ids and is_blocked", %{conn: conn} do
    %{id: id1} = fixture(:user, %{email: "1", password: "Password1", settings: %{}, is_blocked: true})
    %{id: id2} = fixture(:user, %{email: "2", password: "Password2", settings: %{}, is_blocked: true})
    %{id: id3} = fixture(:user, %{email: "3", password: "Password3", settings: %{}})
    fixture(:user, %{email: "4", password: "Password4", settings: %{}})

    conn = get conn, user_path(conn, :index, %{ids: Enum.join([id1, id2, id3], ","), is_blocked: true})
    data = json_response(conn, 200)["data"]
    assert 2 == length(data)
    Enum.each(data, fn %{"id" => id} ->
      assert id in [id1, id2]
    end)
  end

  test "finds nothing by invalid email", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @create_attrs
    conn = get conn, user_path(conn, :index, %{email: @create_attrs.email <> "111"})
    assert Enum.empty?(json_response(conn, 200)["data"])
  end

  describe "create user" do
    test "creates user and renders user when data is valid", %{conn: conn} do
      conn = post conn, user_path(conn, :create), user: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, user_path(conn, :show, id)
      assert %{
               "id" => ^id,
               "email" => "some email",
               "settings" => %{},
             } = json_response(conn, 200)["data"]
    end

    test "password is too short", %{conn: conn} do
      conn = post conn, user_path(conn, :create), user: Map.put(@create_attrs, :password, "Short1")
      res = json_response(conn, 422)
      assert [
        %{
          "entry" => "$.password",
          "entry_type" => "json_data_property",
          "rules" => [
            %{
              "description" => "should be at least 8 character(s)",
              "params" => %{"min" => 8},
              "rule" => "length"
            }
          ]
        }
      ] = res["error"]["invalid"]
    end

    test "password has no uppercase", %{conn: conn} do
      conn = post conn, user_path(conn, :create), user: Map.put(@create_attrs, :password, "password1")
      res = json_response(conn, 422)
      assert [
        %{
          "entry" => "$.password",
          "entry_type" => "json_data_property",
          "rules" => [
            %{
              "description" => "password should contain both upper and lowercase letters, numbers",
              "params" => ["~r/^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)/"],
              "rule" => "format"
            }
          ]
        }
      ] = res["error"]["invalid"]
    end

    test "password has no lowercase", %{conn: conn} do
      conn = post conn, user_path(conn, :create), user: Map.put(@create_attrs, :password, "PASSWORD1")
      res = json_response(conn, 422)
      assert [
        %{
          "entry" => "$.password",
          "entry_type" => "json_data_property",
          "rules" => [
            %{
              "description" => "password should contain both upper and lowercase letters, numbers",
              "params" => ["~r/^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)/"],
              "rule" => "format"
            }
          ]
        }
      ] = res["error"]["invalid"]
    end

    test "password has no numbers", %{conn: conn} do
      conn = post conn, user_path(conn, :create), user: Map.put(@create_attrs, :password, "Password")
      res = json_response(conn, 422)
      assert [
        %{
          "entry" => "$.password",
          "entry_type" => "json_data_property",
          "rules" => [
            %{
              "description" => "password should contain both upper and lowercase letters, numbers",
              "params" => ["~r/^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)/"],
              "rule" => "format"
            }
          ]
        }
      ] = res["error"]["invalid"]
    end

    test "does not create user and renders errors when data is invalid", %{conn: conn} do
      conn = post conn, user_path(conn, :create), user: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  test "updates chosen user and renders user when data is valid", %{conn: conn} do
    %User{id: id, password_set_at: password_set_at} = user = fixture(:user)
    conn = put conn, user_path(conn, :update, user), user: @update_attrs
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get conn, user_path(conn, :show, id)
    assert %{
      "id" => ^id,
      "email" => "some updated email",
      "settings" => %{},
    } = json_response(conn, 200)["data"]
    user = Repo.one(User)
    refute password_set_at == user.password_set_at
  end

  test "does not update chosen user and renders errors when data is invalid", %{conn: conn} do
    user = fixture(:user)
    conn = put conn, user_path(conn, :update, user), user: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen user", %{conn: conn} do
    user = fixture(:user)
    conn = delete conn, user_path(conn, :delete, user)
    assert response(conn, 204)
    assert_error_sent 404, fn ->
      get conn, user_path(conn, :show, user)
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
      conn = patch conn, user_path(conn, :update, user) <> "/actions/block", params

      assert data = json_response(conn, 200)["data"]
      assert "fraud" = data["block_reason"]
      assert data["is_blocked"]

      assert token1.id |> TokenAPI.get_token!() |> TokenAPI.expired?()
      assert token2.id |> TokenAPI.get_token!() |> TokenAPI.expired?()
    end

    test "user already blocked", %{conn: conn} do
      user = insert(:user, is_blocked: true)
      conn = patch conn, user_path(conn, :update, user) <> "/actions/block"
      assert json_response(conn, 409)
    end

    test "invalid user params will be ignored", %{conn: conn} do
      user = insert(:user)
      conn = patch conn, user_path(conn, :update, user) <> "/actions/block", ~S({"user" : [{}] })
      json_response(conn, 200)
    end

    test "unblock user", %{conn: conn} do
      user = insert(:user, is_blocked: true)
      params = %{user: %{"block_reason" => "good boy"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/unblock", params

      assert data = json_response(conn, 200)["data"]
      assert "good boy" = data["block_reason"]
      refute data["is_blocked"]
    end

    test "user already unblocked", %{conn: conn} do
      user = insert(:user)
      conn = patch conn, user_path(conn, :update, user) <> "/actions/unblock"
      assert json_response(conn, 409)
    end
  end

  describe "change password" do
    test "works with when current password is valid", %{conn: conn} do
      user = fixture(:user, %{email: "1", password: "Hello123", settings: %{}})

      update_params = %{user: %{"password" => "World123", current_password: "Hello123"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/change_password", update_params
      assert json_response(conn, 200)

      updated_user = UserAPI.get_user(user.id)
      assert Comeonin.Bcrypt.checkpw("World123", updated_user.password)
      refute user.password_set_at == updated_user.password_set_at
    end

    test "returns validation error when current password is invalid", %{conn: conn} do
      user = fixture(:user, %{email: "1", password: "Hello123", settings: %{}})

      update_params = %{user: %{"password" => "World123", current_password: "invalid"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/change_password", update_params
      assert [%{"entry" => "$.current_password", "rules" => [%{"rule" => "password"}]}]
        = json_response(conn, 422)["error"]["invalid"]
    end

    test "returns validation error when current password is not present", %{conn: conn} do
      user = fixture(:user, %{email: "1", password: "Hello123", settings: %{}})

      update_params = %{user: %{"password" => "World123"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/change_password", update_params
      assert [%{"entry" => "$.current_password", "rules" => [%{"rule" => "required"}]}]
        = json_response(conn, 422)["error"]["invalid"]
    end

    test "returns validation error when new password is not present", %{conn: conn} do
      user = fixture(:user, %{email: "1", password: "Hello123", settings: %{}})

      update_params = %{user: %{current_password: "Hello123"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/change_password", update_params
      assert [%{"entry" => "$.password", "rules" => [%{"rule" => "required"}]}]
        = json_response(conn, 422)["error"]["invalid"]
    end
  end
end
