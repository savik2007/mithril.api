defmodule Mithril.Web.UserControllerTest do
  use Mithril.Web.ConnCase

  alias Ecto.UUID
  alias Mithril.TokenAPI
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User

  @create_attrs %{email: "some email", password: "some password", settings: %{}, "2fa_enable": true}
  @update_attrs %{email: "some updated email", password: "some updated password", settings: %{}}
  @invalid_attrs %{email: nil, password: nil, settings: nil}

  def fixture(:user, create_attrs \\ @create_attrs) do
    {:ok, user} = UserAPI.create_user(create_attrs)
    user
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    fixture(:user, %{email: "1", password: "1", settings: %{}})
    fixture(:user, %{email: "2", password: "2", settings: %{}})
    fixture(:user, %{email: "3", password: "3", settings: %{}})
    conn = get conn, user_path(conn, :index)
    assert 3 == length(json_response(conn, 200)["data"])
  end

  test "does not list all entries on index when limit is set", %{conn: conn} do
    fixture(:user, %{email: "1", password: "1", settings: %{}})
    fixture(:user, %{email: "2", password: "2", settings: %{}})
    fixture(:user, %{email: "3", password: "3", settings: %{}})
    conn = get conn, user_path(conn, :index), %{page_size: 2}
    assert 2 == length(json_response(conn, 200)["data"])
  end

  test "does not list all entries on index when starting_after is set", %{conn: conn} do
    fixture(:user, %{email: "1", password: "1", settings: %{}})
    fixture(:user, %{email: "2", password: "2", settings: %{}})
    user = fixture(:user, %{email: "3", password: "3", settings: %{}})
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
    user = fixture(:user, %{email: "1", password: "1", settings: %{}})
    conn = get conn, user_path(conn, :index, %{id: user.id})
    assert length(json_response(conn, 200)["data"]) == 1
  end

  test "finds users by ids and is_blocked", %{conn: conn} do
    %{id: id1} = fixture(:user, %{email: "1", password: "1", settings: %{}, is_blocked: true})
    %{id: id2} = fixture(:user, %{email: "2", password: "2", settings: %{}, is_blocked: true})
    %{id: id3} = fixture(:user, %{email: "3", password: "3", settings: %{}})
    fixture(:user, %{email: "4", password: "4", settings: %{}})

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
    assert length(json_response(conn, 200)["data"]) == 0
  end

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

  test "does not create user and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates chosen user and renders user when data is valid", %{conn: conn} do
    %User{id: id} = user = fixture(:user)
    conn = put conn, user_path(conn, :update, user), user: @update_attrs
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get conn, user_path(conn, :show, id)
    assert %{
      "id" => ^id,
      "email" => "some updated email",
      "settings" => %{},
    } = json_response(conn, 200)["data"]
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

    test "unblock user", %{conn: conn} do
      user = insert(:user, is_blocked: true)
      conn = patch conn, user_path(conn, :update, user) <> "/actions/unblock"

      assert data = json_response(conn, 200)["data"]
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
      user = fixture(:user, %{email: "1", password: "hello", settings: %{}})

      update_params = %{user: %{"password" => "world", current_password: "hello"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/change_password", update_params
      assert json_response(conn, 200)

      assert Comeonin.Bcrypt.checkpw("world", UserAPI.get_user(user.id).password)
    end

    test "returns validation error when current password is invalid", %{conn: conn} do
      user = fixture(:user, %{email: "1", password: "hello", settings: %{}})

      update_params = %{user: %{"password" => "world", current_password: "invalid"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/change_password", update_params
      assert [%{"entry" => "$.current_password", "rules" => [%{"rule" => "password"}]}]
        = json_response(conn, 422)["error"]["invalid"]
    end

    test "returns validation error when current password is not present", %{conn: conn} do
      user = fixture(:user, %{email: "1", password: "hello", settings: %{}})

      update_params = %{user: %{"password" => "world"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/change_password", update_params
      assert [%{"entry" => "$.current_password", "rules" => [%{"rule" => "required"}]}]
        = json_response(conn, 422)["error"]["invalid"]
    end

    test "returns validation error when new password is not present", %{conn: conn} do
      user = fixture(:user, %{email: "1", password: "hello", settings: %{}})

      update_params = %{user: %{current_password: "hello"}}
      conn = patch conn, user_path(conn, :update, user) <> "/actions/change_password", update_params
      assert [%{"entry" => "$.password", "rules" => [%{"rule" => "required"}]}]
        = json_response(conn, 422)["error"]["invalid"]
    end
  end
end
