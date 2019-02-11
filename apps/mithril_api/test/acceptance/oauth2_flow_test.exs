defmodule Mithril.Acceptance.Oauth2FlowTest do
  use Mithril.Web.ConnCase

  import Mox
  import Core.Guardian

  alias Comeonin.Bcrypt
  alias Core.OTP
  alias Core.Authorization.Tokens
  alias Core.ClientTypeAPI.ClientType
  alias Core.Authorization.GrantType

  setup :verify_on_exit!

  test "client successfully obtain an access_token API calls", %{conn: conn} do
    client_type = insert(:client_type, scope: "app:authorize legal_entity:read legal_entity:write")
    client = insert(:client, client_type: client_type)
    connection = insert(:connection, client: client, redirect_uri: "http://localhost")
    role = insert(:role, scope: "legal_entity:read legal_entity:write")
    insert(:user_role, user: client.user, role: role, client: client)

    # 1. User is presented a user-agent and logs in
    login_request_body = %{
      "token" => %{
        grant_type: "password",
        email: client.user.email,
        password: user_raw_password(),
        client_id: client.id,
        scope: "app:authorize"
      }
    }

    conn
    |> put_req_header("accept", "application/json")
    |> post(auth_token_path(conn, :create), Poison.encode!(login_request_body))
    |> json_response(201)

    # 2. After login user is presented with a list of scopes
    # The request goes through gateway, which
    # converts login_response["data"]["value"] into user_id
    # and puts it in as "x-consumer-id" header
    scope = "legal_entity:read legal_entity:write"

    approval_request_body = %{
      "app" => %{
        client_id: client.id,
        redirect_uri: connection.redirect_uri,
        scope: scope
      }
    }

    approval_response =
      conn
      |> put_req_header("x-consumer-id", client.user.id)
      |> post("/oauth/apps/authorize", Poison.encode!(approval_request_body))

    decoded_approval_response =
      approval_response
      |> Map.get(:resp_body)
      |> Poison.decode!()

    assert scope == get_in(decoded_approval_response, ["data", "details", "scope_request"])
    refute get_in(decoded_approval_response, ["data", "details", "scope"])
    code_grant = get_in(decoded_approval_response, ["data", "value"])

    redirect_uri = "http://localhost?code=#{code_grant}"

    assert [^redirect_uri] = get_resp_header(approval_response, "location")

    # 3. After authorization server responds and
    # user-agent is redirected to client server,
    # client issues an access_token request
    tokens_request_body = %{
      "token" => %{
        grant_type: "authorization_code",
        client_id: client.id,
        client_secret: connection.secret,
        code: code_grant,
        scope: scope,
        redirect_uri: connection.redirect_uri
      }
    }

    tokens_response =
      conn
      |> put_req_header("accept", "application/json")
      |> post(auth_token_path(conn, :create), Poison.encode!(tokens_request_body))
      |> Map.get(:resp_body)
      |> Poison.decode!()

    assert tokens_response["data"]["name"] == "access_token"
    assert tokens_response["data"]["value"]
    assert tokens_response["data"]["details"]["refresh_token"]
    assert scope == tokens_response["data"]["details"]["scope"]
  end

  describe "2fa flow" do
    setup %{conn: conn} do
      client_type = insert(:client_type, scope: "app:authorize legal_entity:read legal_entity:write")
      client = insert(:client, client_type: client_type)
      connection = insert(:connection, client: client, redirect_uri: "http://localhost")
      insert(:authentication_factor, user: client.user)
      role = insert(:role, scope: "legal_entity:read legal_entity:write")
      insert(:user_role, user: client.user, role: role, client: client)

      System.put_env("SMS_ENABLED", "true")
      on_exit(fn -> System.put_env("SMS_ENABLED", "false") end)

      %{conn: conn, client: client, connection: connection}
    end

    test "happy path", %{conn: conn, client: client, connection: connection} do
      expect(SMSMock, :send, fn _phone_number, _body, _type -> {:ok, %{"meta" => %{"code" => 200}}} end)

      login_request_body = %{
        "token" => %{
          grant_type: "password",
          email: client.user.email,
          password: user_raw_password(),
          client_id: client.id,
          scope: "app:authorize legal_entity:read"
        }
      }

      # 1. Create 2FA access token, that requires OTP confirmation
      resp =
        conn
        |> post(auth_token_path(conn, :create), Poison.encode!(login_request_body))
        |> json_response(201)

      assert "REQUEST_OTP" == resp["urgent"]["next_step"]
      assert "2fa_access_token" == resp["data"]["name"]
      assert "" == resp["data"]["details"]["scope"]
      assert "app:authorize legal_entity:read" == resp["data"]["details"]["scope_request"]
      otp_token_value = resp["data"]["value"]

      # OTP code will sent by third party. Let's get it from DB
      otp =
        OTP.list_otps()
        |> List.first()
        |> Map.get(:code)

      # 2. Verify OTP code and change 2FA access token to access token
      # The request goes direct to Mithril, bypassing Gateway,
      # so it requires authorization header with 2FA access token
      otp_request_body = %{
        "token" => %{
          "grant_type" => "authorize_2fa_access_token",
          "otp" => otp
        }
      }

      resp =
        conn
        |> put_req_header("authorization", "Bearer #{otp_token_value}")
        |> post(auth_token_path(conn, :create), Poison.encode!(otp_request_body))
        |> json_response(201)

      assert "REQUEST_APPS" == resp["urgent"]["next_step"]
      assert "access_token" == resp["data"]["name"]
      assert "app:authorize legal_entity:read" == resp["data"]["details"]["scope"]
      assert resp["data"]["value"]

      # 3. Create approval.
      # The request goes through Gateway, which
      # converts login_response["data"]["value"] into user_id
      # and puts it in as "x-consumer-id" header
      approval_request_body = %{
        "app" => %{
          client_id: client.id,
          redirect_uri: connection.redirect_uri,
          scope: "legal_entity:read legal_entity:write"
        }
      }

      approval_response =
        conn
        |> put_req_header("x-consumer-id", client.user.id)
        |> post("/oauth/apps/authorize", Poison.encode!(approval_request_body))

      code_grant =
        approval_response
        |> Map.get(:resp_body)
        |> Poison.decode!()
        |> get_in(["data", "value"])

      redirect_uri = "http://localhost?code=#{code_grant}"

      assert [^redirect_uri] = get_resp_header(approval_response, "location")

      # 4. After authorization server responds and
      # user-agent is redirected to client server,
      # client issues an access_token request
      tokens_request_body = %{
        "token" => %{
          grant_type: "authorization_code",
          client_id: client.id,
          client_secret: connection.secret,
          code: code_grant,
          scope: "legal_entity:read legal_entity:write",
          redirect_uri: connection.redirect_uri
        }
      }

      tokens_response =
        conn
        |> put_req_header("accept", "application/json")
        |> post(auth_token_path(conn, :create), Poison.encode!(tokens_request_body))
        |> Map.get(:resp_body)
        |> Poison.decode!()

      assert tokens_response["data"]["name"] == "access_token"
      assert tokens_response["data"]["value"]
      assert tokens_response["data"]["details"]["refresh_token"]
    end

    test "2fa access token not send", %{conn: conn} do
      otp_request_body = %{
        "token" => %{
          "grant_type" => "authorize_2fa_access_token",
          "otp" => 123
        }
      }

      conn
      |> post(auth_token_path(conn, :create), Poison.encode!(otp_request_body))
      |> json_response(401)
    end

    test "invalid OTP", %{conn: conn, client: client} do
      expect(SMSMock, :send, fn _phone_number, _body, _type -> {:ok, %{"meta" => %{"code" => 200}}} end)

      login_request_body = %{
        "token" => %{
          grant_type: "password",
          email: client.user.email,
          password: user_raw_password(),
          client_id: client.id,
          scope: "app:authorize"
        }
      }

      # 1. Create 2FA access token, that requires OTP confirmation
      otp_token_value =
        conn
        |> post(auth_token_path(conn, :create), Poison.encode!(login_request_body))
        |> json_response(201)
        |> get_in(~w(data value))

      # 2. Verify OTP code and change 2FA access token to access token
      # The request goes direct to Mithril, bypassing Gateway,
      # so it requires authorization header with 2FA access token
      otp_request_body = %{
        "token" => %{
          "grant_type" => "authorize_2fa_access_token",
          "otp" => 0
        }
      }

      assert "otp_invalid" ==
               conn
               |> put_req_header("authorization", "Bearer #{otp_token_value}")
               |> post(auth_token_path(conn, :create), Poison.encode!(otp_request_body))
               |> json_response(401)
               |> get_in(~w(error type))
    end
  end

  describe "Success login into Cabinet via EHealth Client, that do not need approval" do
    setup %{conn: conn} do
      user = insert(:user, password: Bcrypt.hashpwsalt("super$ecre7"), tax_id: "12345678")
      insert(:authentication_factor, user: user)

      client_type =
        insert(
          :client_type,
          name: ClientType.client_type(:cabinet),
          scope: "app:authorize cabinet:read cabinet:write"
        )

      client =
        insert(
          :client,
          id: "30074b6e-fbab-4dc1-9d37-88c21dab1847",
          user: user,
          client_type: client_type,
          settings: %{"allowed_grant_types" => ["password", "digital_signature"]}
        )

      connection = insert(:connection, client: client)
      insert(:app, user: user, client: client, scope: "cabinet:read cabinet:write")
      role_1 = insert(:role, scope: "cabinet:read")
      role_2 = insert(:role, scope: "cabinet:write")
      insert(:user_role, user: user, role: role_1, client: client)
      insert(:global_user_role, user: user, role: role_2)

      System.put_env("SMS_ENABLED", "true")
      on_exit(fn -> System.put_env("SMS_ENABLED", "false") end)

      %{conn: conn, user: user, client: client, connection: connection}
    end

    test "user with 2FA", %{conn: conn, user: user, client: client, connection: connection} do
      expect(SMSMock, :send, fn _phone_number, _body, _type -> {:ok, %{"meta" => %{"code" => 200}}} end)
      # 1. Create 2FA access token, that requires OTP confirmation
      token_payload = %{
        grant_type: "password",
        email: user.email,
        password: "super$ecre7",
        client_id: client.id,
        scope: "app:authorize cabinet:read cabinet:write"
      }

      resp =
        conn
        |> post(auth_token_path(conn, :create), token: token_payload)
        |> json_response(201)

      assert "REQUEST_OTP" == resp["urgent"]["next_step"]
      assert "2fa_access_token" == resp["data"]["name"]
      assert "" == resp["data"]["details"]["scope"]
      assert "app:authorize cabinet:read cabinet:write" == resp["data"]["details"]["scope_request"]
      otp_token_value = resp["data"]["value"]

      # OTP code will sent by third party. Let's get it from DB
      otp =
        OTP.list_otps()
        |> List.first()
        |> Map.get(:code)

      # 2. Verify OTP code and change 2FA access token to access token
      # The request goes direct to Mithril, bypassing Gateway,
      # so it requires authorization header with 2FA access token
      otp_request_body = %{
        grant_type: Tokens.grant_type(:"2fa_auth"),
        otp: otp
      }

      resp =
        conn
        |> put_req_header("authorization", "Bearer #{otp_token_value}")
        |> post(auth_token_path(conn, :create), token: otp_request_body)
        |> json_response(201)

      assert "REQUEST_APPS" == resp["urgent"]["next_step"]
      assert "access_token" == resp["data"]["name"]
      assert "app:authorize cabinet:read cabinet:write" == resp["data"]["details"]["scope"]
      assert resp["data"]["value"]
      refute resp["data"]["details"]["scope_request"]
      refute resp["data"]["details"]["refresh_token"]

      # 3. Create approval.
      # The request goes through Gateway, which
      # converts login_response["data"]["value"] into user_id
      # and puts it in as "x-consumer-id" header
      code_grant = post_approval(conn, user.id, client.id, connection.redirect_uri, nil)

      # 4. After authorization server responds and
      # user-agent is redirected to client server,
      # client issues an access_token request
      tokens_request_body = %{
        grant_type: "authorization_code",
        client_id: client.id,
        client_secret: connection.secret,
        code: code_grant,
        redirect_uri: connection.redirect_uri
      }

      tokens_response =
        conn
        |> put_req_header("accept", "application/json")
        |> post(auth_token_path(conn, :create), token: tokens_request_body)
        |> json_response(201)
        |> Map.get("data")

      scope = "cabinet:read cabinet:write"
      assert byte_size(scope) == byte_size(tokens_response["details"]["scope"])
      assert assert_scope_allowed(scope, tokens_response["details"]["scope"])
      assert tokens_response["name"] == "access_token"
      assert tokens_response["value"]
      assert tokens_response["details"]["refresh_token"]
    end

    test "by Digital Signature", %{conn: conn, user: user, client: client, connection: connection} do
      # 1. Login vis DS that do not need OTP confirmation and approval for EHealth client
      tax_id = "12345678"

      expect(SignatureMock, :decode_and_validate, fn signed_content, "base64", _attrs ->
        content = signed_content |> Base.decode64!() |> Poison.decode!()

        data = %{
          "content" => content,
          "signed_content" => signed_content,
          "signatures" => [
            %{
              "is_valid" => true,
              "signer" => %{
                "drfo" => tax_id
              },
              "validation_error_message" => ""
            }
          ]
        }

        {:ok, %{"data" => data}}
      end)

      expect(MPIMock, :person, fn id ->
        assert is_binary(id)
        assert byte_size(id) > 0
        {:ok, %{"data" => %{"id" => id, "tax_id" => tax_id}}}
      end)

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      resp =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(201)

      # For DS login do not need 2 factor auth, request approval next
      assert "REQUEST_APPS" == resp["urgent"]["next_step"]
      assert "access_token" == resp["data"]["name"]
      assert "app:authorize" == resp["data"]["details"]["scope"]
      assert "digital_signature" == resp["data"]["details"]["grant_type"]
      assert resp["data"]["value"]
      refute resp["data"]["details"]["refresh_token"]

      # 3. Create approval.
      # The request goes through Gateway, which
      # converts login_response["data"]["value"] into user_id
      # and puts it in as "x-consumer-id" header
      code_grant = post_approval(conn, user.id, client.id, connection.redirect_uri, nil)

      # 4. After authorization server responds and
      # user-agent is redirected to client server,
      # client issues an access_token request
      tokens_request_body = %{
        grant_type: "authorization_code",
        client_id: client.id,
        client_secret: connection.secret,
        code: code_grant,
        scope: "cabinet:read cabinet:write",
        redirect_uri: connection.redirect_uri
      }

      tokens_response =
        conn
        |> put_req_header("accept", "application/json")
        |> post(auth_token_path(conn, :create), token: tokens_request_body)
        |> json_response(201)
        |> Map.get("data")

      scope = "cabinet:read cabinet:write"
      assert byte_size(scope) == byte_size(tokens_response["details"]["scope"])
      assert tokens_response["name"] == "access_token"
      assert tokens_response["value"]
      assert tokens_response["details"]["refresh_token"]
      assert tokens_response["details"]["scope"]
    end
  end

  defp assert_scope_allowed(allowed, requested) do
    assert GrantType.requested_scope_allowed?(allowed, requested), "Scope #{requested} not in #{allowed}"
  end

  defp ds_valid_signed_content() do
    {:ok, jwt, _} = encode_and_sign(:nonce, %{nonce: 123}, token_type: "access")
    %{"jwt" => jwt} |> Poison.encode!() |> Base.encode64()
  end

  defp ds_payload(signed_content, client_id, scope \\ "cabinet:read") do
    %{
      token: %{
        grant_type: "digital_signature",
        signed_content: signed_content,
        signed_content_encoding: "base64",
        client_id: client_id,
        scope: scope
      }
    }
    |> Poison.encode!()
  end
end
