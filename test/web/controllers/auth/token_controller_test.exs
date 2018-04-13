defmodule Mithril.OAuth.TokenControllerTest do
  use Mithril.Web.ConnCase

  import Mox
  import Mithril.Guardian

  alias Ecto.UUID
  alias Mithril.TokenAPI.Token
  alias Mithril.ClientTypeAPI.ClientType

  setup :verify_on_exit!

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "user is blocked", %{conn: conn} do
    password = "Somepa$$word1"
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt(password), is_blocked: true)
    client_type = insert(:client_type, scope: "app:authorize")

    client =
      insert(
        :client,
        user_id: user.id,
        client_type_id: client_type.id,
        settings: %{"allowed_grant_types" => ["password"]}
      )

    request_payload = %{
      token: %{
        grant_type: "password",
        email: user.email,
        password: password,
        client_id: client.id,
        scope: "app:authorize"
      }
    }

    conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    assert %{"message" => "User blocked.", "type" => "user_blocked"} == json_response(conn, 401)["error"]
  end

  test "login user after request with invalid password", %{conn: conn} do
    password = "Somepa$$word1"
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt(password))
    insert(:authentication_factor, user_id: user.id)
    client_type = insert(:client_type, scope: "app:authorize")

    client =
      insert(
        :client,
        user_id: user.id,
        client_type_id: client_type.id,
        settings: %{"allowed_grant_types" => ["password"]}
      )

    request_payload = %{
      token: %{
        grant_type: "password",
        email: user.email,
        password: "invalid_password",
        client_id: client.id,
        scope: "app:authorize"
      }
    }

    assert %{"message" => "Identity, password combination is wrong.", "type" => "access_denied"} ==
             conn
             |> post("/oauth/tokens", Poison.encode!(request_payload))
             |> json_response(401)
             |> Map.get("error")

    data = request_payload |> put_in(~w(token password)a, password) |> Poison.encode!()

    conn
    |> post("/oauth/tokens", data)
    |> json_response(201)
  end

  describe "login user via client CABINET" do
    setup %{conn: conn} do
      client_type = insert(:client_type, name: ClientType.client_type(:cabinet), scope: "app:authorize")
      user = insert(:user, tax_id: "", password: Comeonin.Bcrypt.hashpwsalt("Somepa$$word1"))
      insert(:authentication_factor, user_id: user.id, factor: "+380771114466")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password"]}
        )

      payload = %{
        token: %{
          grant_type: "password",
          email: user.email,
          password: "Somepa$$word1",
          client_id: client.id,
          scope: "app:authorize"
        }
      }

      %{conn: conn, payload: payload}
    end

    test "user tax_id is empty", %{conn: conn, payload: payload} do
      assert "User is not registered" ==
               conn
               |> post("/oauth/tokens", payload)
               |> json_response(403)
               |> get_in(~w(error message))
    end

    test "password has been expired", %{conn: conn, payload: payload} do
      default_expiration = Confex.get_env(:mithril_api, :password)[:expiration]
      System.put_env("PASSWORD_EXPIRATION_DAYS", "0")

      assert "User is not registered" ==
               conn
               |> post("/oauth/tokens", payload)
               |> json_response(403)
               |> get_in(~w(error message))

      on_exit(fn ->
        System.put_env("PASSWORD_EXPIRATION_DAYS", to_string(default_expiration))
      end)
    end
  end

  describe "login via client CABINET with empty factor for 2FA" do
    setup %{conn: conn} do
      client_type = insert(:client_type, name: ClientType.client_type(:cabinet), scope: "app:authorize")
      user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Somepa$$word1"))

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password"]}
        )

      payload = %{
        token: %{
          grant_type: "password",
          email: user.email,
          password: "Somepa$$word1",
          client_id: client.id,
          scope: "app:authorize"
        }
      }

      %{conn: conn, user: user, payload: payload}
    end

    test "send user to REQUEST_FACTOR when 2FA factor is nil", %{conn: conn, user: user, payload: payload} do
      insert(:authentication_factor, user_id: user.id, factor: nil)

      assert "REQUEST_FACTOR" ==
               conn
               |> post("/oauth/tokens", payload)
               |> json_response(201)
               |> get_in(~w(urgent next_step))
    end

    test "send user to REQUEST_FACTORS when 2FA factor is empty string", %{conn: conn, user: user, payload: payload} do
      insert(:authentication_factor, user_id: user.id, factor: "")

      assert "REQUEST_FACTOR" ==
               conn
               |> post("/oauth/tokens", payload)
               |> json_response(201)
               |> get_in(~w(urgent next_step))
    end

    test "send user to login via DS when 2FA not exist", %{conn: conn, payload: payload} do
      assert "REQUEST_LOGIN_VIA_DS" ==
               conn
               |> post("/oauth/tokens", payload)
               |> json_response(403)
               |> get_in(~w(error message))
    end
  end

  test "successfully issues new 2FA access_token using password. Next step: send OTP", %{conn: conn} do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    password = "secret_password"
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt(password))
    client_type = insert(:client_type, name: ClientType.client_type(:cabinet), scope: allowed_scope)

    client =
      insert(
        :client,
        user_id: user.id,
        client_type_id: client_type.id,
        settings: %{"allowed_grant_types" => ["password"]}
      )

    insert(:authentication_factor, user_id: user.id)

    request_payload = %{
      token: %{
        grant_type: "password",
        email: user.email,
        password: password,
        client_id: client.id,
        scope: "app:authorize"
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
  end

  test "successfully issues new access_token using code_grant", %{conn: conn} do
    client = insert(:client)
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Secret_password1"))

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read legal_entity:write"
    })

    code_grant = create_code_grant_token(client, user, "legal_entity:read")

    request_payload = %{
      token: %{
        "grant_type" => "authorization_code",
        "client_id" => client.id,
        "client_secret" => client.secret,
        "redirect_uri" => client.redirect_uri,
        "code" => code_grant.value
      }
    }

    conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))

    token = json_response(conn, 201)["data"]

    assert token["name"] == "access_token"
    assert token["value"]
    assert token["expires_at"]
    assert token["user_id"] == user.id
    assert token["details"]["client_id"] == client.id
    assert token["details"]["grant_type"] == "authorization_code"
    assert token["details"]["redirect_uri"] == client.redirect_uri
    assert token["details"]["scope"] == "legal_entity:read"
  end

  test "incorrectly crafted body is still treated nicely", %{conn: conn} do
    assert_error_sent(400, fn ->
      post(conn, "/oauth/tokens", Poison.encode!(%{"scope" => "legal_entity:read"}))
    end)
  end

  test "errors are rendered as json", %{conn: conn} do
    request = %{
      "token" => %{
        "scope" => "legal_entity:read"
      }
    }

    conn = post(conn, "/oauth/tokens", Poison.encode!(request))

    result = json_response(conn, 422)["error"]
    assert result["message"] == "Request must include grant_type."
  end

  test "expire old password tokens", %{conn: conn} do
    allowed_scope = "app:authorize"
    client_type = insert(:client_type, scope: allowed_scope)

    client =
      insert(
        :client,
        settings: %{"allowed_grant_types" => ["password"]},
        client_type_id: client_type.id
      )

    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Secret_password1"))

    request_payload = %{
      token: %{
        grant_type: "password",
        email: user.email,
        password: "Secret_password1",
        client_id: client.id,
        scope: "app:authorize"
      }
    }

    conn1 = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    %{"data" => %{"id" => token1_id, "expires_at" => expires_at}} = json_response(conn1, 201)
    conn2 = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    assert json_response(conn2, 201)

    now = DateTime.to_unix(DateTime.utc_now())
    assert expires_at > now

    %{expires_at: expires_at} = Repo.get!(Token, token1_id)
    assert expires_at <= now
  end

  test "password has been expired", %{conn: conn} do
    default_expiration = Confex.get_env(:mithril_api, :password)[:expiration]
    System.put_env("PASSWORD_EXPIRATION_DAYS", "0")

    allowed_scope = "app:authorize"
    client_type = insert(:client_type, scope: allowed_scope)

    client =
      insert(
        :client,
        settings: %{"allowed_grant_types" => ["password"]},
        client_type_id: client_type.id
      )

    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Secret_password1"))

    request_payload = %{
      token: %{
        grant_type: "password",
        email: user.email,
        password: "Secret_password1",
        client_id: client.id,
        scope: "app:authorize"
      }
    }

    conn = post(conn, "/oauth/tokens", Poison.encode!(request_payload))
    res = json_response(conn, 401)
    message = "The password expired for user: #{user.id}"

    on_exit(fn ->
      System.put_env("PASSWORD_EXPIRATION_DAYS", to_string(default_expiration))
    end)

    assert %{"message" => ^message, "type" => "password_expired"} = res["error"]
  end

  describe "change password token flow" do
    setup %{conn: conn} do
      allowed_scope = "user:change_password"
      user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Secret_password1"))
      client_type = insert(:client_type, scope: allowed_scope)

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["change_password", "password"]}
        )

      %{conn: conn, client: client, user: user}
    end

    test "get change_password token when password has been expired", %{conn: conn, client: client, user: user} do
      default_expiration = Confex.get_env(:mithril_api, :password)[:expiration]
      System.put_env("PASSWORD_EXPIRATION_DAYS", "0")

      request_payload = %{
        "token" => %{
          "grant_type" => "change_password",
          "email" => user.email,
          "password" => "Secret_password1",
          "client_id" => client.id,
          "scope" => "user:change_password"
        }
      }

      resp =
        conn
        |> post(oauth2_token_path(conn, :create), Poison.encode!(request_payload))
        |> json_response(201)

      on_exit(fn ->
        System.put_env("PASSWORD_EXPIRATION_DAYS", to_string(default_expiration))
      end)

      assert resp["data"]["details"]["client_id"] == client.id
      assert resp["data"]["details"]["grant_type"] == "change_password"
      assert resp["data"]["details"]["redirect_uri"] == client.redirect_uri
      assert resp["data"]["user_id"] == user.id
      assert resp["data"]["name"] == "change_password_token"
    end

    test "get change_password token when password has not been expired", %{conn: conn, client: client, user: user} do
      default_expiration = Confex.get_env(:mithril_api, :password)[:expiration]
      default_2fa = Confex.get_env(:mithril_api, :"2fa")[:user_2fa_enabled?]

      System.put_env("PASSWORD_EXPIRATION_DAYS", "180")
      System.put_env("USER_2FA_ENABLED", "false")

      request_payload = %{
        "token" => %{
          "grant_type" => "change_password",
          "email" => user.email,
          "password" => "Secret_password1",
          "client_id" => client.id,
          "scope" => "user:change_password"
        }
      }

      resp =
        conn
        |> post(oauth2_token_path(conn, :create), Poison.encode!(request_payload))
        |> json_response(201)

      on_exit(fn ->
        System.put_env("PASSWORD_EXPIRATION_DAYS", to_string(default_expiration))
        System.put_env("USER_2FA_ENABLED", to_string(default_2fa))
      end)

      assert resp["data"]["details"]["client_id"] == client.id
      assert resp["data"]["details"]["grant_type"] == "change_password"
      assert resp["data"]["details"]["redirect_uri"] == client.redirect_uri
      assert resp["data"]["details"]["scope"] == "user:change_password"
      assert resp["data"]["user_id"] == user.id
      assert resp["data"]["name"] == "change_password_token"
    end
  end

  defmodule SignatureExpect do
    defmacro __using__(_) do
      quote do
        expect(SignatureMock, :decode_and_validate, fn signed_content, "base64", _attrs ->
          content = signed_content |> Base.decode64!() |> Poison.decode!()

          data = %{
            "signer" => %{
              "drfo" => "12345678"
            },
            "signed_content" => signed_content,
            "is_valid" => true,
            "content" => content
          }

          {:ok, %{"data" => data}}
        end)
      end
    end
  end

  describe "digital signature flow" do
    test "successfully issues new access_token", %{conn: conn} do
      tax_id = "12345678"
      use SignatureExpect

      expect(MPIMock, :person, fn id ->
        assert is_binary(id)
        assert byte_size(id) > 0
        {:ok, %{"data" => %{"id" => id, "tax_id" => tax_id}}}
      end)

      user = insert(:user, tax_id: tax_id)
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password", "digital_signature"]}
        )

      Mithril.AppAPI.create_app(%{
        user_id: user.id,
        client_id: client.id,
        scope: "cabinet:read cabinet:write"
      })

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      token =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(201)
        |> Map.get("data")

      assert token["name"] == "access_token"
      assert token["value"]
      assert token["expires_at"]
      assert token["user_id"] == user.id
      assert token["details"]["client_id"] == client.id
      assert token["details"]["grant_type"] == "digital_signature"
      assert token["details"]["redirect_uri"] == client.redirect_uri
      assert token["details"]["scope"] == "cabinet:read"
    end

    test "DS tax_id does not contain drfo", %{conn: conn} do
      expect(SignatureMock, :decode_and_validate, fn signed_content, "base64", _attrs ->
        content = signed_content |> Base.decode64!() |> Poison.decode!()

        data = %{
          "signer" => %{"edrpou" => "12345678"},
          "signed_content" => signed_content,
          "is_valid" => true,
          "content" => content
        }

        {:ok, %{"data" => data}}
      end)

      payload = ds_valid_signed_content() |> ds_payload(UUID.generate())

      msg =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(422)
        |> get_in(~w(error message))

      assert "Digital signature signer does not contain drfo." == msg
    end

    test "invalid JWT format", %{conn: conn} do
      use SignatureExpect

      payload =
        %{"jwt" => "invalid jwt"}
        |> Poison.encode!()
        |> Base.encode64()
        |> ds_payload(UUID.generate())

      "JWT is invalid." =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(401)
        |> get_in(~w(error message))
    end

    test "JWT not in signed content", %{conn: conn} do
      use SignatureExpect
      signed_content = %{"no" => "jwt"} |> Poison.encode!() |> Base.encode64()

      payload = signed_content |> ds_payload(UUID.generate())

      "Signed content does not contain field jwt." =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(401)
        |> get_in(~w(error message))
    end

    test "JWT expired", %{conn: conn} do
      use SignatureExpect

      jwt =
        "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJtaXRocmlsLWxvZ2luIiwiZXhwIjoxNTIyMzEzODgxLCJpYXQiOjE1Mj" <>
          "IzMTM4MjEsImlzcyI6IkVIZWFsdGgiLCJqdGkiOiI1YzRlMjg5ZS0wNjQyLTQ0YzYtYmU0Yy1iOWZjM2EyZDllZGYiLCJuYmYiOjE" <>
          "1MjIzMTM4MjAsIm5vbmNlIjoxMjMsInN1YiI6MTIzLCJ0eXAiOiJhY2Nlc3MifQ.g853d2Tl3J0aAeEfJyxQ1O1V4b442qSdXb9em" <>
          "TGvhZIooT5c8JN5rdRh0x3L-Mk58Z_vcjtZcAHc9Vsn-MFLbg"

      payload = %{"jwt" => jwt} |> Poison.encode!() |> Base.encode64() |> ds_payload(UUID.generate())

      "JWT is invalid." =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(401)
        |> get_in(~w(error message))
    end

    test "JWT invalid claim", %{conn: conn} do
      use SignatureExpect

      {:ok, jwt, _} = encode_and_sign(:email, %{email: "email@example.com"}, token_type: "access")

      payload = %{"jwt" => jwt} |> Poison.encode!() |> Base.encode64() |> ds_payload(UUID.generate())

      "JWT is invalid." =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(401)
        |> get_in(~w(error message))
    end

    test "user by tax_id not found", %{conn: conn} do
      use SignatureExpect

      user = insert(:user, tax_id: "00001111")
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password", "digital_signature"]}
        )

      payload = ds_valid_signed_content() |> ds_payload(client.id())

      msg =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(401)
        |> get_in(~w(error message))

      assert "Person with tax id from digital signature not found." == msg
    end

    test "MPI person not found", %{conn: conn} do
      tax_id = "12345678"
      use SignatureExpect
      expect(MPIMock, :person, fn _id -> {:error, %{"meta" => %{"code" => 404}}} end)

      user = insert(:user, tax_id: tax_id)
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password", "digital_signature"]}
        )

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      msg =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(401)
        |> get_in(~w(error message))

      assert "Person not found." == msg
    end

    test "MPI person inactive", %{conn: conn} do
      tax_id = "12345678"
      use SignatureExpect

      expect(MPIMock, :person, fn id ->
        {:ok, %{"data" => %{"id" => id, "tax_id" => tax_id, "status" => "INACTIVE"}}}
      end)

      user = insert(:user, tax_id: tax_id)
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password", "digital_signature"]}
        )

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      msg =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(401)
        |> get_in(~w(error message))

      assert "Person not found." == msg
    end

    test "MPI person tax_id not match with digital signature drfo", %{conn: conn} do
      use SignatureExpect
      expect(MPIMock, :person, fn id -> {:ok, %{"data" => %{"id" => id, "tax_id" => "00001111"}}} end)

      user = insert(:user, tax_id: "12345678")
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password", "digital_signature"]}
        )

      Mithril.AppAPI.create_app(%{
        user_id: user.id,
        client_id: client.id,
        scope: "cabinet:read cabinet:write"
      })

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      msg =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(403)
        |> get_in(~w(error message))

      assert "Tax id not matched with MPI person." == msg
    end

    test "invalid params", %{conn: conn} do
      conn
      |> post("/oauth/tokens", %{token: %{invalid: "params"}})
      |> json_response(422)
    end

    test "invalid scopes", %{conn: conn} do
      use SignatureExpect

      user = insert(:user, tax_id: "12345678")
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["digital_signature"]}
        )

      payload = ds_valid_signed_content() |> ds_payload(client.id, "cabinet:delete")

      msg =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(401)
        |> get_in(~w(error message))

      assert "Allowed scopes for the token are cabinet:read, cabinet:write." == msg
    end

    test "DS cannot decode signed content", %{conn: conn} do
      expect(SignatureMock, :decode_and_validate, fn _signed_content, "base64", _attrs ->
        {:error, %{"data" => %{"is_valid" => false}, "meta" => %{"code" => 422, "type" => "list"}}}
      end)

      user = insert(:user, tax_id: "12345678")
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["digital_signature"]}
        )

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      err =
        conn
        |> post("/oauth/tokens", payload)
        |> json_response(422)
        |> Map.get("error")

      assert %{"is_valid" => false} == err
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

  describe "generate nonce" do
    test "success", %{conn: conn} do
      %{id: id} = insert(:client)

      nonce =
        conn
        |> put_req_header("client-id", id)
        |> get(oauth2_token_path(conn, :nonce))
        |> json_response(200)
        |> get_in(~w(data token))

      aud = get_aud(:login)
      assert {:ok, %{"nonce" => _, "aud" => ^aud}} = decode_and_verify(nonce)
    end

    test "client_id header not set", %{conn: conn} do
      assert "Client header not set" =
               conn
               |> get(oauth2_token_path(conn, :nonce))
               |> json_response(401)
               |> get_in(~w(error message))
    end
  end
end
