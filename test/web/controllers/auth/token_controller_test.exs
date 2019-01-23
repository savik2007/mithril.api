defmodule Mithril.OAuth.TokenControllerTest do
  use Mithril.Web.ConnCase

  import Mox
  import Mithril.Guardian

  alias Comeonin.Bcrypt
  alias Ecto.UUID
  alias Mithril.AppAPI
  alias Mithril.TokenAPI.Token
  alias Mithril.ClientTypeAPI.ClientType

  setup :verify_on_exit!

  @password user_raw_password()
  @cabinet ClientType.client_type(:cabinet)

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "user is blocked", %{conn: conn} do
    user = insert(:user, is_blocked: true)
    client = :client |> insert(user: user) |> with_connection()
    payload = token_payload(client)

    resp =
      conn
      |> post(auth_token_path(conn, :create), Poison.encode!(payload))
      |> json_response(401)

    assert %{"message" => "User blocked.", "type" => "user_blocked"} == resp["error"]
  end

  test "login user after request with invalid password", %{conn: conn} do
    client = :client |> insert() |> with_connection()

    request_payload = token_payload(client, "invalid_password")

    assert %{"message" => "Identity, password combination is wrong.", "type" => "access_denied"} ==
             conn
             |> post(auth_token_path(conn, :create), Poison.encode!(request_payload))
             |> json_response(401)
             |> Map.get("error")

    data = request_payload |> put_in(~w(token password)a, user_raw_password()) |> Poison.encode!()

    conn
    |> post(auth_token_path(conn, :create), data)
    |> json_response(201)
  end

  test "invalid grant_type for public login endpoint", %{conn: conn} do
    client = :client |> insert() |> with_connection()
    payload = token_payload(client)

    assert "Grant type not allowed." ==
             conn
             |> post(oauth2_token_path(conn, :create), payload)
             |> json_response(401)
             |> get_in(~w(error message))
  end

  describe "login user via client CABINET" do
    setup %{conn: conn} do
      user = :user |> insert(tax_id: "") |> with_authentication_factor()
      client_type = insert(:client_type, name: @cabinet)

      client =
        :client
        |> insert(user: user, client_type: client_type)
        |> with_connection()

      %{conn: conn, payload: token_payload(client)}
    end

    test "user tax_id is empty", %{conn: conn, payload: payload} do
      assert "User is not registered" ==
               conn
               |> post(auth_token_path(conn, :create), payload)
               |> json_response(403)
               |> get_in(~w(error message))
    end

    test "password has been expired", %{conn: conn, payload: payload} do
      default_expiration = Confex.get_env(:mithril_api, :password)[:expiration]
      System.put_env("PASSWORD_EXPIRATION_DAYS", "0")

      assert "User is not registered" ==
               conn
               |> post(auth_token_path(conn, :create), payload)
               |> json_response(403)
               |> get_in(~w(error message))

      on_exit(fn ->
        System.put_env("PASSWORD_EXPIRATION_DAYS", to_string(default_expiration))
      end)
    end
  end

  describe "login via client CABINET with empty factor for 2FA when USER_2FA_ENABLED conf value is true" do
    setup %{conn: conn} do
      client_type = insert(:client_type, name: @cabinet)
      client = :client |> insert(client_type: client_type) |> with_connection()

      current_value = System.get_env("USER_2FA_ENABLED") || "false"
      System.put_env("USER_2FA_ENABLED", "true")

      on_exit(fn ->
        System.put_env("USER_2FA_ENABLED", current_value)
      end)

      %{conn: conn, user: client.user, payload: token_payload(client)}
    end

    test "send user to REQUEST_FACTOR when 2FA factor is nil", %{conn: conn, user: user, payload: payload} do
      insert(:authentication_factor, user: user, factor: nil)

      assert "REQUEST_FACTOR" ==
               conn
               |> post(auth_token_path(conn, :create), payload)
               |> json_response(201)
               |> get_in(~w(urgent next_step))
    end

    test "send user to REQUEST_FACTORS when 2FA factor is empty string", %{conn: conn, user: user, payload: payload} do
      insert(:authentication_factor, user: user, factor: "")

      assert "REQUEST_FACTOR" ==
               conn
               |> post(auth_token_path(conn, :create), payload)
               |> json_response(201)
               |> get_in(~w(urgent next_step))
    end

    test "send user to REQUEST_APPS when 2FA not exist", %{conn: conn, payload: payload} do
      assert "REQUEST_APPS" ==
               conn
               |> post(auth_token_path(conn, :create), payload)
               |> json_response(201)
               |> get_in(~w(urgent next_step))
    end
  end

  describe "login via client CABINET with empty factor for 2FA when USER_2FA_ENABLED conf value is false" do
    setup %{conn: conn} do
      client_type = insert(:client_type, name: @cabinet)
      client = :client |> insert(client_type: client_type) |> with_connection()

      current_value = System.get_env("USER_2FA_ENABLED") || "false"
      System.put_env("USER_2FA_ENABLED", "false")
      on_exit(fn -> System.put_env("USER_2FA_ENABLED", current_value) end)

      %{conn: conn, user: client.user, payload: token_payload(client)}
    end

    test "send user to REQUEST_FACTOR when 2FA factor is nil", %{conn: conn, user: user, payload: payload} do
      insert(:authentication_factor, user: user, factor: nil)

      assert "REQUEST_FACTOR" ==
               conn
               |> post(auth_token_path(conn, :create), payload)
               |> json_response(201)
               |> get_in(~w(urgent next_step))
    end

    test "send user to REQUEST_FACTOR when 2FA factor is empty string", %{conn: conn, user: user, payload: payload} do
      insert(:authentication_factor, user: user, factor: "")

      assert "REQUEST_FACTOR" ==
               conn
               |> post(auth_token_path(conn, :create), payload)
               |> json_response(201)
               |> get_in(~w(urgent next_step))
    end

    test "do not send user to login via DS when 2FA not exist", %{conn: conn, payload: payload} do
      assert "REQUEST_APPS" ==
               conn
               |> post(auth_token_path(conn, :create), payload)
               |> json_response(201)
               |> get_in(~w(urgent next_step))
    end
  end

  test "successfully issues new 2FA access_token using password. Next step: send OTP", %{conn: conn} do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    client_type = insert(:client_type, name: @cabinet, scope: allowed_scope)
    client = :client |> insert(client_type: client_type) |> with_connection()

    insert(:authentication_factor, user: client.user)

    request_payload = token_payload(client)

    resp =
      conn
      |> post(auth_token_path(conn, :create), Poison.encode!(request_payload))
      |> json_response(201)

    assert Map.has_key?(resp, "urgent")
    assert Map.has_key?(resp["urgent"], "next_step")
    assert "REQUEST_OTP" = resp["urgent"]["next_step"]

    token = resp["data"]
    assert token["name"] == "2fa_access_token"
    assert token["value"]
    assert token["expires_at"]
    assert token["user_id"] == client.user.id
    assert token["details"]["client_id"] == client.id
    assert token["details"]["grant_type"] == "password"
    assert token["details"]["scope"] == ""
  end

  test "successfully issues new access_token using code_grant", %{conn: conn} do
    client = insert(:client)
    connection = insert(:connection, client: client)

    assert {:ok, _} =
             AppAPI.create_app(%{
               user_id: client.user.id,
               client_id: client.id,
               scope: "legal_entity:read legal_entity:write"
             })

    code_grant = create_code_grant_token(connection, client.user, "legal_entity:read")

    request_payload = %{
      token: %{
        "grant_type" => "authorization_code",
        "client_id" => client.id,
        "client_secret" => connection.secret,
        "redirect_uri" => connection.redirect_uri,
        "code" => code_grant.value
      }
    }

    token =
      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(request_payload))
      |> json_response(201)
      |> Map.get("data")

    assert token["name"] == "access_token"
    assert token["value"]
    assert token["expires_at"]
    assert token["user_id"] == client.user.id
    assert token["details"]["client_id"] == client.id
    assert token["details"]["grant_type"] == "authorization_code"
    assert token["details"]["redirect_uri"] == connection.redirect_uri
    assert token["details"]["scope"] == "legal_entity:read"
  end

  test "incorrectly crafted body is still treated nicely", %{conn: conn} do
    assert_error_sent(400, fn ->
      post(conn, auth_token_path(conn, :create), Poison.encode!(%{"scope" => "legal_entity:read"}))
    end)
  end

  test "errors are rendered as json", %{conn: conn} do
    request = %{
      "token" => %{
        "scope" => "legal_entity:read"
      }
    }

    conn = post(conn, auth_token_path(conn, :create), Poison.encode!(request))

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
        client_type: client_type
      )

    user = insert(:user, password: Bcrypt.hashpwsalt("Secret_password1"))

    request_payload = %{
      token: %{
        grant_type: "password",
        email: user.email,
        password: "Secret_password1",
        client_id: client.id,
        scope: "app:authorize"
      }
    }

    conn1 = post(conn, auth_token_path(conn, :create), Poison.encode!(request_payload))
    %{"data" => %{"id" => token1_id, "expires_at" => expires_at}} = json_response(conn1, 201)
    conn2 = post(conn, auth_token_path(conn, :create), Poison.encode!(request_payload))
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
        client_type: client_type
      )

    user = insert(:user, password: Bcrypt.hashpwsalt("Secret_password1"))

    request_payload = %{
      token: %{
        grant_type: "password",
        email: user.email,
        password: "Secret_password1",
        client_id: client.id,
        scope: "app:authorize"
      }
    }

    conn = post(conn, auth_token_path(conn, :create), Poison.encode!(request_payload))
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
      user = insert(:user, password: Bcrypt.hashpwsalt("Secret_password1"))
      client_type = insert(:client_type, scope: allowed_scope)

      client =
        :client
        |> insert(
          user: user,
          client_type: client_type,
          settings: %{"allowed_grant_types" => ["change_password", "password"]}
        )
        |> with_connection()

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
        |> post(auth_token_path(conn, :create), Poison.encode!(request_payload))
        |> json_response(201)

      on_exit(fn ->
        System.put_env("PASSWORD_EXPIRATION_DAYS", to_string(default_expiration))
      end)

      assert resp["data"]["details"]["client_id"] == client.id
      assert resp["data"]["details"]["grant_type"] == "change_password"
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
        |> post(auth_token_path(conn, :create), Poison.encode!(request_payload))
        |> json_response(201)

      on_exit(fn ->
        System.put_env("PASSWORD_EXPIRATION_DAYS", to_string(default_expiration))
        System.put_env("USER_2FA_ENABLED", to_string(default_2fa))
      end)

      assert resp["data"]["details"]["client_id"] == client.id
      assert resp["data"]["details"]["grant_type"] == "change_password"
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
            "content" => content,
            "signed_content" => signed_content,
            "signatures" => [
              %{
                "is_valid" => true,
                "signer" => %{
                  "drfo" => "12345678"
                },
                "validation_error_message" => ""
              }
            ]
          }

          {:ok, %{"data" => data}}
        end)
      end
    end
  end

  describe "Digital Signature flow. Negative cases" do
    test "DS expired", %{conn: conn} do
      expect(SignatureMock, :decode_and_validate, fn signed_content, "base64", _attrs ->
        data = %{
          "signed_content" => signed_content,
          "signatures" => [
            %{
              "is_valid" => false,
              "validation_error_message" => "DS expired."
            }
          ]
        }

        {:ok, %{"data" => data}}
      end)

      payload = ds_valid_signed_content() |> ds_payload(UUID.generate())

      msg =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(422)
        |> get_in(~w(error message))

      assert "DS expired." == msg
    end

    test "DS tax_id does not contain drfo", %{conn: conn} do
      expect(SignatureMock, :decode_and_validate, fn signed_content, "base64", _attrs ->
        content = signed_content |> Base.decode64!() |> Poison.decode!()

        data = %{
          "content" => content,
          "signed_content" => signed_content,
          "signatures" => [
            %{
              "is_valid" => true,
              "signer" => %{
                "edrpou" => "12345678"
              },
              "validation_error_message" => ""
            }
          ]
        }

        {:ok, %{"data" => data}}
      end)

      payload = ds_valid_signed_content() |> ds_payload(UUID.generate())

      msg =
        conn
        |> post(auth_token_path(conn, :create), payload)
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
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(401)
        |> get_in(~w(error message))
    end

    test "JWT not in signed content", %{conn: conn} do
      use SignatureExpect
      signed_content = %{"no" => "jwt"} |> Poison.encode!() |> Base.encode64()

      payload = signed_content |> ds_payload(UUID.generate())

      "Signed content does not contain field jwt." =
        conn
        |> post(auth_token_path(conn, :create), payload)
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
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(401)
        |> get_in(~w(error message))
    end

    test "JWT invalid claim", %{conn: conn} do
      use SignatureExpect

      {:ok, jwt, _} = encode_and_sign(:email, %{email: "email@example.com"}, token_type: "access")

      payload = %{"jwt" => jwt} |> Poison.encode!() |> Base.encode64() |> ds_payload(UUID.generate())

      "JWT is invalid." =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(401)
        |> get_in(~w(error message))
    end

    test "user by tax_id not found", %{conn: conn} do
      use SignatureExpect

      user = insert(:user, tax_id: "00001111")
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        :client
        |> insert(
          user: user,
          client_type: client_type,
          settings: %{"allowed_grant_types" => ["password", "digital_signature"]}
        )
        |> with_connection()

      payload = ds_valid_signed_content() |> ds_payload(client.id())

      msg =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(401)
        |> get_in(~w(error message))

      assert "Person with tax id from digital signature not found." == msg
    end

    test "invalid params", %{conn: conn} do
      conn
      |> post(auth_token_path(conn, :create), %{token: %{invalid: "params"}})
      |> json_response(422)
    end
  end

  describe "Digital Signature flow" do
    setup %{conn: conn} do
      tax_id = "12345678"
      user = insert(:user, tax_id: tax_id)
      client_type = insert(:client_type, scope: "cabinet:read cabinet:write")

      client =
        :client
        |> insert(
          user: user,
          client_type: client_type,
          settings: %{"allowed_grant_types" => ["password", "digital_signature"]}
        )
        |> with_connection()

      %{conn: conn, client: client, user: user}
    end

    test "successfully issues new access_token", %{conn: conn, client: client, user: user} do
      use SignatureExpect

      expect(MPIMock, :person, fn id ->
        assert is_binary(id)
        assert byte_size(id) > 0
        {:ok, %{"data" => %{"id" => id, "tax_id" => user.tax_id}}}
      end)

      AppAPI.create_app(%{
        user: user,
        client_id: client.id,
        scope: "cabinet:read cabinet:write"
      })

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      token =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(201)
        |> Map.get("data")

      assert token["name"] == "access_token"
      assert token["value"]
      assert token["expires_at"]
      assert token["user_id"] == user.id
      assert token["details"]["client_id"] == client.id
      assert token["details"]["grant_type"] == "digital_signature"
      assert token["details"]["scope"] == "app:authorize"
    end

    test "MPI person not found", %{conn: conn, client: client} do
      use SignatureExpect
      expect(MPIMock, :person, fn _id -> {:error, %{"meta" => %{"code" => 404}}} end)

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      msg =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(401)
        |> get_in(~w(error message))

      assert "Person not found." == msg
    end

    test "MPI person inactive", %{conn: conn, client: client, user: user} do
      use SignatureExpect

      expect(MPIMock, :person, fn id ->
        {:ok, %{"data" => %{"id" => id, "tax_id" => user.tax_id, "status" => "INACTIVE"}}}
      end)

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      msg =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(401)
        |> get_in(~w(error message))

      assert "Person not found." == msg
    end

    test "MPI person tax_id not match with digital signature drfo", %{conn: conn, client: client, user: user} do
      use SignatureExpect
      expect(MPIMock, :person, fn id -> {:ok, %{"data" => %{"id" => id, "tax_id" => "00001111"}}} end)

      AppAPI.create_app(%{
        user: user,
        client_id: client.id,
        scope: "cabinet:read cabinet:write"
      })

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      msg =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(403)
        |> get_in(~w(error message))

      assert "Tax id not matched with MPI person." == msg
    end

    test "invalid scopes", %{conn: conn, client: client} do
      use SignatureExpect

      payload = ds_valid_signed_content() |> ds_payload(client.id, "cabinet:delete")

      msg =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(422)
        |> get_in(~w(error message))

      assert "Scope is not allowed by client type." == msg
    end

    test "DS cannot decode signed content", %{conn: conn, client: client} do
      expect(SignatureMock, :decode_and_validate, fn _signed_content, "base64", _attrs ->
        err_resp = %{
          "error" => %{
            "invalid" => [
              %{
                "entry" => "$.signed_content",
                "entry_type" => "json_data_property",
                "rules" => [
                  %{
                    "description" => "Not a base64 string",
                    "params" => [],
                    "rule" => "invalid"
                  }
                ]
              }
            ],
            "message" =>
              "Validation failed. You can find validators description at our API Manifest:" <>
                " http://docs.apimanifest.apiary.io/#introduction/interacting-with-api/errors.",
            "type" => "validation_failed"
          },
          "meta" => %{
            "code" => 422,
            "request_id" => "2kmaguf9ec791885t40008s2",
            "type" => "object",
            "url" => "http://www.example.com/digital_signatures"
          }
        }

        {:error, err_resp}
      end)

      payload = ds_valid_signed_content() |> ds_payload(client.id)

      resp =
        conn
        |> post(auth_token_path(conn, :create), payload)
        |> json_response(422)

      %{"error" => %{"invalid" => [%{"rules" => [%{"description" => err_desc}]}]}} = resp
      assert "Not a base64 string" == err_desc
    end
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

  defp token_payload(client, password \\ @password) do
    %{
      token: %{
        grant_type: "password",
        email: client.user.email,
        password: password,
        client_id: client.id,
        scope: client.client_type.scope
      }
    }
  end
end
