defmodule Mithril.Web.TokenControllerTest do
  use Mithril.Web.ConnCase

  alias Ecto.UUID
  alias Mithril.TokenAPI.Token

  @broker Mithril.ClientAPI.access_type(:broker)
  @direct Mithril.ClientAPI.access_type(:direct)

  @create_attrs %{details: %{}, expires_at: 42, name: "some name", value: "some value"}
  @update_attrs %{details: %{}, expires_at: 43, name: "some updated name", value: "some updated value"}
  @invalid_attrs %{details: nil, expires_at: nil, name: nil, value: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    insert(:token, name: "1")
    insert(:token, name: "2")
    insert(:token, name: "3")
    conn = get(conn, token_path(conn, :index))
    assert 3 == length(json_response(conn, 200)["data"])
  end

  test "lists with filter by client_id", %{conn: conn} do
    client_1 = UUID.generate()
    client_2 = UUID.generate()

    insert(:token, name: "1", details: %{"client_id" => client_1})
    insert(:token, name: "2", details: %{"client_id" => client_1})
    insert(:token, name: "3", details: %{"client_id" => client_2})

    conn = get(conn, token_path(conn, :index), %{"client_id" => client_1})
    assert 2 == length(json_response(conn, 200)["data"])
  end

  test "does not list all entries on index when limit is set", %{conn: conn} do
    insert(:token, name: "1")
    insert(:token, name: "2")
    insert(:token, name: "3")
    conn = get(conn, token_path(conn, :index), %{page_size: 2})
    assert 2 == length(json_response(conn, 200)["data"])
  end

  test "does not list all entries on index when page_size and page are set", %{conn: conn} do
    insert(:token, name: "1")
    insert(:token, name: "2")
    token = insert(:token, name: "3")
    conn = get(conn, token_path(conn, :index), %{page_size: 2, page: 2})
    resp = json_response(conn, 200)["data"]
    assert 1 == length(resp)
    assert token.id == Map.get(hd(resp), "id")
  end

  test "search by name by like works", %{conn: conn} do
    insert(:token, name: "refresh_token")
    insert(:token, name: "access_token")
    insert(:token, name: "something_different")

    conn = get(conn, token_path(conn, :index), %{name: "token"})
    assert 2 == length(json_response(conn, 200)["data"])
  end

  test "search by value by like works", %{conn: conn} do
    insert(:token, name: "access_token", value: "111")
    insert(:token, name: "access_token", value: "123")
    insert(:token, name: "access_token", value: "234")
    conn = get(conn, token_path(conn, :index), %{value: "23"})
    assert 2 == length(json_response(conn, 200)["data"])
  end

  test "search by user_id works", %{conn: conn} do
    token = insert(:token, name: "1")
    insert(:token, name: "2")
    insert(:token, name: "3")
    conn = get(conn, token_path(conn, :index), %{user_id: token.user_id})
    assert 1 == length(json_response(conn, 200)["data"])
  end

  describe "create token" do
    test "creates token and renders token when data is valid", %{conn: conn} do
      user = insert(:user)
      conn = post(conn, token_path(conn, :create), token: Map.put_new(@create_attrs, :user_id, user.id))
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, token_path(conn, :show, id))

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "details" => %{},
               "expires_at" => 42,
               "name" => "some name",
               "value" => "some value",
               "user_id" => user.id
             }
    end

    test "does not create token and renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, token_path(conn, :create), token: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "create access token" do
    test "creates token and renders token when data is valid", %{conn: conn} do
      user = insert(:user)
      allowed_scope = "cabinet:read"
      client_type = insert(:client_type, scope: allowed_scope)

      %{id: client_id} =
        insert(
          :client,
          settings: %{"allowed_grant_types" => ["password"]},
          client_type_id: client_type.id
        )

      payload = %{
        client_id: client_id,
        scope: allowed_scope
      }

      assert %{"id" => id} =
               conn
               |> post(user_token_path(conn, :create_access_token, user.id), token: payload)
               |> json_response(201)
               |> Map.get("data")

      token =
        conn
        |> get(token_path(conn, :show, id))
        |> json_response(200)
        |> Map.get("data")

      assert id == token["id"]
      assert %{"client_id" => ^client_id, "grant_type" => "password", "scope" => ^allowed_scope} = token["details"]
      assert "access_token" == token["name"]
    end

    test "invalid client scope", %{conn: conn} do
      user = insert(:user)
      allowed_scope = "cabinet:read"
      client_type = insert(:client_type, scope: allowed_scope)

      %{id: client_id} =
        insert(
          :client,
          settings: %{"allowed_grant_types" => ["password"]},
          client_type_id: client_type.id
        )

      payload = %{
        client_id: client_id,
        scope: "cabinet:write"
      }

      assert msg =
               conn
               |> post(user_token_path(conn, :create_access_token, user.id), token: payload)
               |> json_response(401)
               |> get_in(~w(error message))

      assert "Allowed scopes for the token are cabinet:read." == msg
    end

    test "user not found", %{conn: conn} do
      assert_error_sent(404, fn ->
        post(conn, user_token_path(conn, :create_access_token, Ecto.UUID.generate()), token: %{})
      end)
    end
  end

  test "updates chosen token and renders token when data is valid", %{conn: conn} do
    %Token{id: id} = token = insert(:token)
    conn = put(conn, token_path(conn, :update, token), token: @update_attrs)
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get(conn, token_path(conn, :show, id))

    assert json_response(conn, 200)["data"] == %{
             "id" => id,
             "details" => %{},
             "expires_at" => 43,
             "name" => "some updated name",
             "value" => "some updated value",
             "user_id" => token.user_id
           }
  end

  test "does not update chosen token and renders errors when data is invalid", %{conn: conn} do
    token = insert(:token)
    conn = put(conn, token_path(conn, :update, token), token: @invalid_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  describe "delete token" do
    test "by id", %{conn: conn} do
      token = insert(:token)
      conn = delete(conn, token_path(conn, :delete, token))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, token_path(conn, :show, token))
      end)
    end

    test "by user and client_id", %{conn: conn} do
      %{id: id_1} = insert(:token)
      user = insert(:user)
      client_id = UUID.generate()
      insert(:token, name: "first", value: "a", details: %{"client_id" => client_id}, user_id: user.id)
      insert(:token, name: "second", value: "b", details: %{"client_id" => client_id}, user_id: user.id)

      %{id: id_2} =
        insert(:token, name: "third", value: "c", details: %{"client_id" => UUID.generate()}, user_id: user.id)

      conn = delete(conn, user_token_path(conn, :delete_by_user, user.id), client_id: client_id)
      assert response(conn, 204)

      conn = get(conn, token_path(conn, :index))
      data = json_response(conn, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"id" => token_id} ->
        assert token_id in [id_1, id_2]
      end)
    end

    test "by user_ids", %{conn: conn} do
      %{user_id: user_id_1} = insert(:token)
      %{user_id: user_id_2} = insert(:token)
      %{id: id_1} = insert(:token)
      %{id: id_2} = insert(:token)

      conn = delete(conn, token_path(conn, :delete_by_user_ids), user_ids: "#{user_id_1},#{user_id_2}")
      assert response(conn, 204)

      conn = get(conn, token_path(conn, :index))
      data = json_response(conn, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"id" => token_id} ->
        assert token_id in [id_1, id_2]
      end)
    end
  end

  test "render additional info about user", %{conn: conn} do
    client = insert(:client)
    user = insert(:user)

    {:ok, role} = Mithril.RoleAPI.create_role(%{name: "Some role", scope: "legal_entity:read"})

    {:ok, _} =
      Mithril.UserRoleAPI.create_user_role(%{
        client_id: client.id,
        user_id: user.id,
        role_id: role.id
      })

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read,legal_entity:write"
    })

    token = create_access_token(client, user)

    conn = get(conn, token_user_path(conn, :user, token.value))

    response = json_response(conn, 200)["data"]

    assert response["id"] == user.id
    assert response["email"] == user.email
    assert response["settings"] == %{}
    assert hd(response["urgent"]["roles"])["name"] == "Some role"
    assert hd(response["urgent"]["roles"])["scope"] == "legal_entity:read"
    assert response["urgent"]["token"]["expires_at"] == token.expires_at
  end

  test "verify token using token value", %{conn: conn} do
    client = insert(:client)
    user = insert(:user)

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read,legal_entity:write"
    })

    token = create_code_grant_token(client, user)

    conn = get(conn, token_verify_path(conn, :verify, token.value))

    token = json_response(conn, 200)["data"]

    assert token["name"] == "authorization_code"
    assert token["value"]
    assert token["expires_at"]
    assert token["user_id"] == user.id
    assert token["details"]["client_id"] == client.id
    assert token["details"]["grant_type"] == "password"
    assert token["details"]["redirect_uri"] == client.redirect_uri
    assert token["details"]["scope_request"] == "app:authorize"
  end

  test "verify blocked client", %{conn: conn} do
    client = insert(:client, is_blocked: true)

    token =
      insert(
        :token,
        details: %{
          scope: "app:authorize",
          client_id: client.id,
          grant_type: "password",
          redirect_uri: "http://localhost"
        }
      )

    conn = get(conn, token_verify_path(conn, :verify, token.value))

    resp = json_response(conn, 401)
    assert %{"error" => %{"message" => "Authentication failed."}} = resp
  end

  test "verify blocked user", %{conn: conn} do
    user = insert(:user, is_blocked: true)
    token = insert(:token, user_id: user.id)

    conn = get(conn, token_verify_path(conn, :verify, token.value))

    resp = json_response(conn, 401)
    assert %{"error" => %{"message" => "Authentication failed."}} = resp
  end

  test "returns error during token verification", %{conn: conn} do
    token = insert(:token, expires_at: 1000)

    conn = get(conn, token_verify_path(conn, :verify, token.value))

    error = json_response(conn, 401)["error"]

    assert %{"message" => "Token expired or client approval was revoked."} = error
  end

  describe "verify token using token value via broker client" do
    setup %{conn: conn} do
      client_type = insert(:client_type, scope: "b c d")

      client =
        insert(
          :client,
          client_type_id: client_type.id,
          priv_settings: %{
            "access_type" => @broker
          }
        )

      broker_client_type = insert(:client_type, scope: "a b c")

      broker =
        insert(
          :client,
          client_type_id: broker_client_type.id,
          priv_settings: %{
            "access_type" => @direct,
            "broker_scope" => "b c"
          }
        )

      user = insert(:user)
      role = insert(:role, scope: "a b c")
      insert(:user_role, user_id: user.id, role_id: role.id, client_id: client.id)

      token =
        insert(
          :token,
          user_id: user.id,
          details: %{
            scope: "b",
            client_id: client.id
          }
        )

      %{conn: conn, client: client, broker: broker, token: token.value, user: user}
    end

    test "API-KEY Header required", %{conn: conn, token: token} do
      conn = get(conn, token_verify_path(conn, :verify, token))
      assert "API-KEY header required." == json_response(conn, 422)["error"]["message"]
    end

    test "invalid API-KEY Header", %{conn: conn, token: token} do
      conn = put_req_header(conn, "api-key", "invalid_api_key")
      conn = get(conn, token_verify_path(conn, :verify, token))
      assert "API-KEY header is invalid." == json_response(conn, 422)["error"]["message"]
    end

    test "not broker API-KEY Header", %{conn: conn, client: client, token: token} do
      conn = put_req_header(conn, "api-key", client.secret)
      conn = get(conn, token_verify_path(conn, :verify, token))
      assert "Incorrect broker settings." == json_response(conn, 422)["error"]["message"]
    end

    test "valid request with broker scope", %{conn: conn, client: client, broker: broker, user: user} do
      token =
        insert(
          :token,
          user_id: user.id,
          value: "code",
          details: %{
            scope: "c",
            client_id: client.id
          }
        )

      conn = put_req_header(conn, "api-key", broker.secret)
      conn = get(conn, token_verify_path(conn, :verify, token.value))

      result = json_response(conn, 200)["data"]

      assert result["details"]["broker_scope"] == "b c"
    end
  end
end
