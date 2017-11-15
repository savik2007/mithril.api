defmodule Mithril.OAuth.Token2FAControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.TokenAPI.Token
  alias Mithril.Authorization.GrantType.Password, as: PasswordGrantType

  setup %{conn: conn} do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    client_type = Mithril.Fixtures.create_client_type(%{scope: allowed_scope})
    client = Mithril.Fixtures.create_client(
      %{
        settings: %{
          "allowed_grant_types" => ["password"]
        },
        client_type_id: client_type.id
      }
    )
    user = Mithril.Fixtures.create_user(%{password: "somepa$$word"})

    {:ok, token} = PasswordGrantType.authorize(
      %{
        "email" => user.email,
        "password" => "somepa$$word",
        "client_id" => client.id,
        "scope" => "legal_entity:read",
      }
    )
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token.value}")

    {:ok, conn: conn, token: token, otp: "123", user: user, client: client}
  end

  test "successfully issues new access_token using 2fa_access_token",
       %{conn: conn, otp: otp, client: client, user: user} do

    request_payload = %{
      "token": %{
        "grant_type": "authorize_2fa_access_token",
        "otp": otp
      }
    }
    conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    token = json_response(conn, 201)["data"]

    assert token["name"] == "access_token"
    assert token["value"]
    assert token["expires_at"]
    assert token["user_id"] == user.id
    assert token["details"]["client_id"] == client.id
    assert token["details"]["grant_type"] == "password"
    assert token["details"]["redirect_uri"] == client.redirect_uri
    assert token["details"]["scope"] == "legal_entity:read"
  end

  test "invalid token", %{conn: conn, otp: otp} do
    request_payload = %{
      "token": %{
        "grant_type": "authorize_2fa_access_token",
        "otp": otp
      }
    }
    conn = conn
           |> put_req_header("authorization", "Bearer a")
           |> post("/oauth/tokens", Poison.encode!(request_payload))
    result = json_response(conn, 401)["error"]
    assert "Invalid token" == result["message"]
  end

  test "authorization header not set", %{conn: conn, otp: otp} do
    request_payload = %{
      "token": %{
        "grant_type": "authorize_2fa_access_token",
        "otp": otp
      }
    }
    conn = conn
           |> delete_req_header("authorization")
           |> post("/oauth/tokens", Poison.encode!(request_payload))
    result = json_response(conn, 401)["error"]
    assert "Authorization header required." == result["message"]
  end

  test "expire old password tokens", %{conn: conn} do
    allowed_scope = "app:authorize"
    client_type = Mithril.Fixtures.create_client_type(%{scope: allowed_scope})
    client = Mithril.Fixtures.create_client(
      %{
        settings: %{
          "allowed_grant_types" => ["password"]
        },
        client_type_id: client_type.id
      }
    )
    user = Mithril.Fixtures.create_user(%{password: "secret_password"})

    request_payload = %{
      "token": %{
        "grant_type": "password",
        "email": user.email,
        "password": "secret_password",
        "client_id": client.id,
        "scope": "app:authorize"
      }
    }

    conn1 = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    %{
      "data" => %{
        "id" => token1_id,
        "expires_at" => expires_at
      }
    } = json_response(conn1, 201)
    conn2 = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    assert json_response(conn2, 201)

    now = DateTime.to_unix(DateTime.utc_now)
    assert expires_at > now

    %{expires_at: expires_at} = Repo.get!(Token, token1_id)
    assert expires_at <= now
  end
end
