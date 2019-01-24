defmodule Mithril.OAuth.AppControllerTest do
  use Mithril.Web.ConnCase
  alias Mithril.AppAPI
  alias Mithril.Clients.Client
  alias Mithril.UserRoleAPI

  @direct Client.access_type(:direct)
  @trusted_client_id "30074b6e-fbab-4dc1-9d37-88c21dab1847"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "successfully approves new client request & issues a code grant", %{conn: conn} do
    client_type = insert(:client_type, scope: "legal_entity:read legal_entity:write")
    client = insert(:client, client_type: client_type)
    connection = insert(:connection, redirect_uri: "http://some_host.com:3000/", client: client)

    user = insert(:user)
    user_role = insert(:role, scope: "legal_entity:read legal_entity:write")
    UserRoleAPI.create_user_role(%{user_id: user.id, role_id: user_role.id, client_id: client.id})
    redirect_uri = "#{connection.redirect_uri}path?param=1"

    request = %{
      app: %{
        client_id: client.id,
        redirect_uri: redirect_uri,
        scope: "legal_entity:read legal_entity:write"
      }
    }

    # This request is expected to be made by our own front-end.
    # Gateway must have /oauth/apps/authorize route & related ACL/auth/proxy enabled
    conn =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> post("/oauth/apps/authorize", Poison.encode!(request))

    result = json_response(conn, 201)["data"]

    assert result["value"]
    assert result["user_id"]
    assert result["name"] == "authorization_code"
    assert result["expires_at"]
    assert result["details"]["scope_request"] == "legal_entity:read legal_entity:write"
    assert result["details"]["redirect_uri"]
    assert result["details"]["client_id"]
    assert result["details"]["grant_type"] == "password"

    [header] = Plug.Conn.get_resp_header(conn, "location")

    assert "http://some_host.com:3000/path?code=#{result["value"]}&param=1" == header

    app = AppAPI.get_app_by(user_id: user.id, client_id: client.id)

    assert app.user_id == user.id
    assert app.client_id == client.id
    assert app.scope == "legal_entity:read legal_entity:write"
  end

  test "successfully updates existing approval with more scopes", %{conn: conn} do
    client_type = insert(:client_type, scope: "legal_entity:read legal_entity:write")
    client = insert(:client, client_type: client_type)
    connection = insert(:connection, redirect_uri: "http://some_host.com:3000/", client: client)
    user = insert(:user)
    user_role = insert(:role, scope: "legal_entity:read legal_entity:write")

    UserRoleAPI.create_user_role(%{user_id: user.id, role_id: user_role.id, client_id: client.id})

    AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read"
    })

    request = %{
      app: %{
        client_id: client.id,
        redirect_uri: connection.redirect_uri,
        scope: "legal_entity:write"
      }
    }

    conn =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> post("/oauth/apps/authorize", Poison.encode!(request))

    result = json_response(conn, 201)["data"]

    assert result["name"] == "authorization_code"
    assert result["details"]["scope_request"] == "legal_entity:write"

    app = AppAPI.get_app_by(user_id: user.id, client_id: client.id)

    assert app.user_id == user.id
    assert app.client_id == client.id
    assert app.scope == "legal_entity:write legal_entity:read"
  end

  test "client is blocked", %{conn: conn} do
    user = insert(:user)
    client = insert(:client, is_blocked: true)
    connection = insert(:connection, redirect_uri: "http://some_host.com:3000/", client: client)

    request = %{
      app: %{
        client_id: client.id,
        redirect_uri: connection.redirect_uri,
        scope: "legal_entity:write"
      }
    }

    resp =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> post("/oauth/apps/authorize", Poison.encode!(request))
      |> json_response(401)

    assert %{"error" => %{"message" => "Client is blocked."}} = resp
  end

  test "incorrectly crafted body is still treated nicely", %{conn: conn} do
    assert_error_sent(400, fn ->
      conn
      |> put_req_header("x-consumer-id", Ecto.UUID.generate())
      |> post("/oauth/apps/authorize", Poison.encode!(%{"scope" => "legal_entity:read"}))
    end)
  end

  test "errors are rendered as json", %{conn: conn} do
    request = %{"scope" => "legal_entity:read"}

    errors =
      conn
      |> put_req_header("x-consumer-id", "F003D59D-3E7A-40E0-8207-7EC05C3303FF")
      |> post(oauth2_app_path(conn, :authorize), app: request)
      |> json_response(422)
      |> get_in(~w(error invalid))

    assert 2 == length(errors)
  end

  test "render error for empty scope with user tihout roles", %{conn: conn} do
    user = insert(:user)
    client = insert(:client, id: @trusted_client_id)
    connection = insert(:connection, redirect_uri: "http://some_host.com:3000/", client: client)

    request = %{
      client_id: client.id,
      redirect_uri: connection.redirect_uri
    }

    assert "Requested scope is empty. Scope not passed or user has no roles or global roles." =
             conn
             |> put_req_header("x-consumer-id", user.id)
             |> post(oauth2_app_path(conn, :authorize), app: request)
             |> json_response(422)
             |> get_in(~w(error message))
  end

  test "returns error when redirect uri is not whitelisted", %{conn: conn} do
    client = :client |> insert(priv_settings: %{"access_type" => @direct}) |> with_connection()
    user = insert(:user)
    user_role = insert(:role, scope: "legal_entity:read legal_entity:write")
    Mithril.UserRoleAPI.create_user_role(%{user_id: user.id, role_id: user_role.id, client_id: client.id})
    redirect_uri = "http://some_other_host.com:3000/path?param=1"

    request = %{
      app: %{
        client_id: client.id,
        redirect_uri: redirect_uri,
        scope: "legal_entity:read legal_entity:write"
      }
    }

    # This request is expected to be made by our own front-end.
    # Gateway must have /oauth/apps/authorize route & related ACL/auth/proxy enabled
    conn =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> post("/oauth/apps/authorize", Poison.encode!(request))

    result = json_response(conn, 401)["error"]

    message = "The redirection URI provided does not match a pre-registered value."
    assert %{"message" => ^message} = result
  end

  test "validates list of available user scopes", %{conn: conn} do
    client_type = insert(:client_type, scope: "b c d")
    client = insert(:client, client_type: client_type)
    connection = insert(:connection, redirect_uri: "http://some_host.com:3000/", client: client)
    user = insert(:user)
    user_role = insert(:role, scope: "a b c")
    Mithril.UserRoleAPI.create_user_role(%{user_id: user.id, role_id: user_role.id, client_id: client.id})

    request = %{
      app: %{
        client_id: client.id,
        redirect_uri: connection.redirect_uri,
        scope: "b c d"
      }
    }

    conn =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> post("/oauth/apps/authorize", Poison.encode!(request))

    result = json_response(conn, 422)["error"]

    message = "User requested scope that is not allowed by role based access policies."
    assert %{"message" => ^message} = result
  end

  test "validates list of available client scopes", %{conn: conn} do
    client_type = insert(:client_type, scope: "a c d")
    client = insert(:client, client_type: client_type)
    connection = insert(:connection, redirect_uri: "http://some_host.com:3000/", client: client)
    user = insert(:user)
    user_role = insert(:role, scope: "b c d")
    Mithril.UserRoleAPI.create_user_role(%{user_id: user.id, role_id: user_role.id, client_id: client.id})

    request = %{
      app: %{
        client_id: client.id,
        redirect_uri: connection.redirect_uri,
        scope: "b c d"
      }
    }

    conn =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> post("/oauth/apps/authorize", Poison.encode!(request))

    result = json_response(conn, 422)["error"]

    message = "Scope is not allowed by client type."
    assert %{"message" => ^message} = result
  end
end
