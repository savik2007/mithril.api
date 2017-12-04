defmodule Mithril.OAuth.Token2FAControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.OTP
  alias Mithril.TokenAPI.Token
  alias Mithril.Authorization.GrantType.Password, as: PasswordGrantType

  @password "somepa$$word"

  setup %{conn: conn} do
    allowed_scope = "app:authorize legal_entity:read"
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt(@password))
    client_type = insert(:client_type, scope: allowed_scope)
    client = insert(:client,
      user_id: user.id,
      client_type_id: client_type.id,
      settings: %{"allowed_grant_types" => ["password"]}
    )
    conn = put_req_header(conn, "accept", "application/json")

    {:ok, conn: conn, user: user, client: client}
  end

  test "authorize - authorize_2fa_access_token when factor not set", %{conn: conn, user: user, client: client} do
    insert(:authentication_factor, user_id: user.id, factor: nil)
    token = authorize(user.email, client.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token.value}")
    request_payload = %{
      "token": %{
        "grant_type": "authorize_2fa_access_token",
        "otp": 1234
      }
    }
    conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    json_response(conn, 409)
  end

  describe "authorize" do
    setup %{conn: conn, user: user, client: client} do
      insert(:authentication_factor, user_id: user.id)
      token = authorize(user.email, client.id)
      conn = put_req_header(conn, "authorization", "Bearer #{token.value}")

      {:ok, conn: conn, token: token, otp: get_last_otp().code, user: user, client: client}
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
      resp = json_response(conn, 201)

      assert Map.has_key?(resp, "urgent")
      assert Map.has_key?(resp["urgent"], "next_step")
      assert "REQUEST_APPS" = resp["urgent"]["next_step"]

      token = resp["data"]

      assert token["name"] == "access_token"
      assert token["value"]
      assert token["expires_at"]
      assert token["user_id"] == user.id
      assert token["details"]["client_id"] == client.id
      assert token["details"]["grant_type"] == "password"
      assert token["details"]["redirect_uri"] == client.redirect_uri
      assert token["details"]["scope"] == "app:authorize"
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
      assert "token_invalid" == result["type"]
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

  describe "set factor (init factor)" do

    setup %{conn: conn, user: user, client: client} do
      insert(:authentication_factor, user_id: user.id)
      token = authorize(user.email, client.id)
      conn1 = put_req_header(conn, "authorization", "Bearer #{token.value}")

      request_payload = %{
        "token": %{
          "grant_type": "authorize_2fa_access_token",
          "otp": get_last_otp().code
        }
      }
      conn2 = post(conn1, "/oauth/tokens", Poison.encode!(request_payload))
      token = json_response(conn2, 201)["data"]["value"]

      conn = put_req_header(conn, "authorization", "Bearer #{token}")
      {:ok, conn: conn, token: token, user: user, client: client}
    end

    test "success create token for changing factor", %{conn: conn, user: user} do
      conn1 = post conn, oauth2_token_path(conn, :init_factor), %{type: "SMS", factor: "+380881002030"}
      token = json_response(conn1, 201)["data"]

      assert token["name"] == "2fa_access_token"
      assert token["value"]
      assert token["expires_at"]
      assert token["user_id"] == user.id
      refute Map.has_key?(token, "details")

      # token expired
      conn2 = post conn, oauth2_token_path(conn, :init_factor), %{type: "SMS", factor: "+380881002030"}
      assert "Token expired" = json_response(conn2, 401)["error"]["message"]
    end

    test "invalid type", %{conn: conn} do
      conn = post conn, oauth2_token_path(conn, :init_factor), %{type: 123, factor: "+380881002030"}
      assert err = hd(json_response(conn, 422)["error"]["invalid"])
      assert "$.type" == err["entry"]
    end

    test "invalid factor", %{conn: conn} do
      conn = post conn, oauth2_token_path(conn, :init_factor), %{type: "SMS", factor: "Skywalker"}
      assert err = hd(json_response(conn, 422)["error"]["invalid"])
      assert "$.factor" == err["entry"]
    end

    test "invalid token type: requires access token", %{conn: conn, user: user} do
      token = insert(:token, user_id: user.id, name: "2fa_access_token")
      conn = put_req_header(conn, "authorization", "Bearer #{token.value}")

      conn = post conn, oauth2_token_path(conn, :init_factor), %{type: "SMS", factor: "+380881002030"}
      assert "token_invalid_type" == json_response(conn, 401)["error"]["type"]
    end
  end

  describe "change factor (init factor)" do
    setup %{conn: conn, user: user} do
      insert(:authentication_factor, user_id: user.id, factor: nil)
      token = insert(:token, user_id: user.id, name: "2fa_access_token")
      conn = put_req_header(conn, "authorization", "Bearer #{token.value}")

      %{conn: conn, user: user}
    end

    test "success create token for first init factor", %{conn: conn, user: user} do
      conn = post conn, oauth2_token_path(conn, :init_factor), %{type: "SMS", factor: "+380885002030"}
      token = json_response(conn, 201)["data"]

      assert token["name"] == "2fa_access_token"
      assert token["user_id"] == user.id
      refute Map.has_key?(token, "details")
    end

    test "invalid token type: requires 2fa access token", %{conn: conn, user: user} do
      token = insert(:token, user_id: user.id, name: "access_token")
      conn = put_req_header(conn, "authorization", "Bearer #{token.value}")

      conn = post conn, oauth2_token_path(conn, :init_factor), %{type: "SMS", factor: "+380881002030"}
      assert "token_invalid_type" == json_response(conn, 401)["error"]["type"]
    end
  end

  describe "approve factor" do
    setup %{conn: conn, user: user, client: client} do
      insert(:authentication_factor, user_id: user.id, factor: nil)
      token = authorize(user.email, client.id)

      conn1 = put_req_header(conn, "authorization", "Bearer #{token.value}")
      conn2 = post conn1, oauth2_token_path(conn1, :init_factor), %{type: "SMS", factor: "+380885002030"}
      token = json_response(conn2, 201)["data"]

      conn = put_req_header(conn, "authorization", "Bearer #{token["value"]}")

      %{conn: conn, user: user, otp: get_last_otp().code}
    end

    test "success", %{conn: conn, user: user, otp: otp} do
      conn = post conn, oauth2_token_path(conn, :approve_factor), %{otp: otp}
      token = json_response(conn, 201)["data"]

      assert "access_token" == token["name"]
      assert user.id == token["user_id"]
      assert "password" == token["details"]["grant_type"]
      assert "app:authorize" == token["details"]["scope"]
      refute Map.has_key?(token["details"], "request_authentication_factor")
      refute Map.has_key?(token["details"], "request_authentication_factor_type")
    end

    test "invalid OTP", %{conn: conn} do
      conn = post conn, oauth2_token_path(conn, :approve_factor), %{otp: 100200}
      json_response(conn, 401)
      assert %{"type" => "otp_invalid"} = json_response(conn, 401)["error"]
    end

    test "OTP expired", %{conn: conn, otp: otp} do
      [code: otp]
      |> OTP.get_otp_by!()
      |> OTP.update_otp(%{code_expired_at: "2010-11-27T12:40:13"})

      conn = post conn, oauth2_token_path(conn, :approve_factor), %{otp: 100200}
      json_response(conn, 401)
      assert %{"type" => "otp_expired"} = json_response(conn, 401)["error"]
    end
  end

  describe "refresh" do
    setup %{conn: conn, user: user, client: client} do
      insert(:authentication_factor, user_id: user.id)
      # details.scope should be empty, but for case, that we flush scope on creating 2fa token you can see it
      details = %{
        scope: "app:authorize",
        scope_request: "app:authorize",
        client_id: client.id,
        grant_type: "password",
        redirect_uri: "http://localhost",
      }
      token = insert(:token, user_id: user.id, name: "2fa_access_token", details: details)
      conn = put_req_header(conn, "authorization", "Bearer #{token.value}")

      {:ok, conn: conn, token: token, user: user, client: client}
    end

    test "successfully refresh 2fa_access_token", %{conn: conn, client: client, user: user} do
      request_payload = %{
        "token": %{
          "grant_type": "refresh_2fa_access_token",
        }
      }
      conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
      resp = json_response(conn, 201)

      assert Map.has_key?(resp, "urgent")
      assert Map.has_key?(resp["urgent"], "next_step")
      assert "REQUEST_OTP" = resp["urgent"]["next_step"]

      token = resp["data"]

      assert token["name"] == "2fa_access_token"
      assert token["value"]
      assert token["expires_at"]
      assert token["user_id"] == user.id
      assert token["details"]["client_id"] == client.id
      assert token["details"]["grant_type"] == "password"
      assert token["details"]["redirect_uri"] == client.redirect_uri
      assert token["details"]["scope"] == ""
      assert token["details"]["scope_request"] == "app:authorize"
    end

    test "invalid token type", %{conn: conn, user: user} do
      token = insert(:token, user_id: user.id, name: "access_token")
      conn = put_req_header(conn, "authorization", "Bearer #{token.value}")
      request_payload = %{
        "token": %{
          "grant_type": "refresh_2fa_access_token",
        }
      }
      conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
      assert "Invalid token type" == json_response(conn, 401)["error"]["message"]
    end
  end

  test "refresh - refresh_2fa_access_token when factor not set", %{conn: conn, user: user, client: client} do
    insert(:authentication_factor, user_id: user.id, factor: nil)
    token = authorize(user.email, client.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token.value}")
    request_payload = %{
      "token": %{
        "grant_type": "refresh_2fa_access_token",
      }
    }
    conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    json_response(conn, 409)
  end

  describe "SMS not send" do
    defmodule Microservices do
      use MicroservicesHelper

      Plug.Router.post "/sms/send" do
        Plug.Conn.send_resp(conn, 500, Poison.encode!(%{"error" => "smth wrng"}))
      end
    end

    setup %{conn: conn, user: user, client: client} do
      insert(:authentication_factor, user_id: user.id)
      details = %{
        scope: "app:authorize",
        client_id: client.id,
        grant_type: "password",
        redirect_uri: "http://localhost",
      }
      token = insert(:token, user_id: user.id, name: "2fa_access_token", details: details)
      conn = put_req_header(conn, "authorization", "Bearer #{token.value}")

      {:ok, port, ref} = start_microservices(Microservices)
      System.put_env("OTP_ENDPOINT", "http://localhost:#{port}")
      System.put_env("SMS_ENABLED", "true")
      on_exit fn ->
        System.delete_env("OTP_ENDPOINT")
        System.put_env("SMS_ENABLED", "false")
        stop_microservices(ref)
      end

      {:ok, conn: conn, user: user, client: client}
    end

    test "refresh 2FA factor", %{conn: conn} do
      request_payload = %{
        "token": %{
          "grant_type": "refresh_2fa_access_token",
        }
      }
      conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
      json_response(conn, 503)
    end

    test "login via password", %{conn: conn, user: user, client: client} do
      request_payload = %{
        "token": %{
          "grant_type": "password",
          "email": user.email,
          "password": @password,
          "client_id": client.id,
          "scope": "app:authorize"
        }
      }

      conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
      json_response(conn, 503)
    end
  end

  defp authorize(email, client_id, password \\ @password) do
    {:ok, %{token: token}} = PasswordGrantType.authorize(%{
      "email" => email,
      "password" => password,
      "client_id" => client_id,
      "scope" => "app:authorize",
    })
    token
  end

  defp get_last_otp do
    List.first(OTP.list_otps)
  end
end
