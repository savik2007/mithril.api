defmodule Mithril.Acceptance.ChangePasswordFlowTest do
  use Mithril.Web.ConnCase

  import Mox

  alias Mithril.OTP

  @direct Mithril.ClientAPI.access_type(:direct)

  # For Mox lib. Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "change password flow without 2fa" do
    setup %{conn: conn} do
      user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("super$ecre7"))
      client_type = insert(:client_type, scope: "user:change_password")

      client =
        insert(
          :client,
          user_id: user.id,
          redirect_uri: "http://localhost",
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password", "change_password"]},
          priv_settings: %{"access_type" => @direct}
        )

      role = insert(:role, scope: "user:change_password")
      insert(:user_role, user_id: user.id, role_id: role.id, client_id: client.id)

      %{conn: conn, user: user, client: client}
    end

    test "happy path", %{conn: conn, user: user, client: client} do
      request_body = %{
        "token" => %{
          grant_type: "change_password",
          email: user.email,
          password: "super$ecre7",
          client_id: client.id,
          scope: "user:change_password"
        }
      }

      # 1. Create password change access token, that allow to change password
      change_pwd_token =
        conn
        |> post(oauth2_token_path(conn, :create), Poison.encode!(request_body))
        |> json_response(201)
        |> Map.get("data")

      assert "user:change_password" == change_pwd_token["details"]["scope"]
      assert "change_password_token" == change_pwd_token["name"]

      # 2. Update password with change_password token
      # The request goes through gateway, which
      # converts login_response["data"]["value"] into user_id
      # and puts it in as "x-consumer-id" header
      body = %{
        "user" => %{
          "password" => "newPa$sw0rD100500"
        }
      }

      conn
      |> put_req_header("x-consumer-id", user.id)
      |> put_req_header("authorization", "Bearer #{change_pwd_token["value"]}")
      |> post("/oauth/users/actions/update_password", Poison.encode!(body))
      |> json_response(200)

      # check that password is changed
      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(request_body))
      |> json_response(401)

      # check that password is changed
      body = put_in(request_body, ~w(token password), "newPa$sw0rD100500")

      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(body))
      |> json_response(201)
    end

    test "invalid scope", %{conn: conn, user: user, client: client} do
      request_body = %{
        "token" => %{
          grant_type: "change_password",
          email: user.email,
          password: "super$ecre7",
          client_id: client.id,
          scope: "app:authorize"
        }
      }

      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(request_body))
      |> json_response(401)
    end

    test "invalid grant type", %{conn: conn, user: user, client: client} do
      request_body = %{
        "token" => %{
          grant_type: "change_passwords",
          email: user.email,
          password: "super$ecre7",
          client_id: client.id,
          scope: "user:change_password"
        }
      }

      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(request_body))
      |> json_response(422)
    end
  end

  describe "change password flow with 2fa" do
    setup %{conn: conn} do
      user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("super$ecre7"))
      client_type = insert(:client_type, scope: "user:change_password")

      client =
        insert(
          :client,
          user_id: user.id,
          redirect_uri: "http://localhost",
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password", "change_password"]},
          priv_settings: %{"access_type" => @direct}
        )

      role = insert(:role, scope: "legal_entity:read legal_entity:write")
      insert(:user_role, user_id: user.id, role_id: role.id, client_id: client.id)

      System.put_env("SMS_ENABLED", "true")

      on_exit(fn ->
        System.put_env("SMS_ENABLED", "false")
      end)

      %{conn: conn, user: user, client: client}
    end

    test "happy path", %{conn: conn, user: user, client: client} do
      expect(SMSMock, :send, 2, fn _phone_number, _body, _type -> {:ok, %{"meta" => %{"code" => 200}}} end)
      insert(:authentication_factor, user_id: user.id)

      change_password_body = %{
        "user" => %{
          "password" => "newPa$sw0rD100500"
        }
      }

      request_body = %{
        "token" => %{
          grant_type: "change_password",
          email: user.email,
          password: "super$ecre7",
          client_id: client.id,
          scope: "user:change_password"
        }
      }

      # 1. Create 2fa_access_token with change_password scope
      token_2fa =
        conn
        |> post(oauth2_token_path(conn, :create), Poison.encode!(request_body))
        |> json_response(201)
        |> Map.get("data")

      assert "2fa_access_token" == token_2fa["name"]
      refute token_2fa["scope"]
      assert "user:change_password" == token_2fa["details"]["scope_request"]

      # cannot change password with init factor token
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> put_req_header("authorization", "Bearer #{token_2fa["value"]}")
      |> post(oauth2_token_path(conn, :update_password), Poison.encode!(change_password_body))
      |> json_response(401)

      # OTP code will sent by third party. Let's get it from DB
      otp =
        OTP.list_otps()
        |> List.first()
        |> Map.get(:code)

      # 2. Verify OTP code and change 2FA access token to change password token
      # The request goes direct to Mithril, bypassing Gateway,
      # so it requires authorization header with 2FA access token
      otp_request_body = %{
        "token" => %{
          "grant_type" => "authorize_2fa_access_token",
          "otp" => otp
        }
      }

      change_pwd_token =
        conn
        |> put_req_header("authorization", "Bearer #{token_2fa["value"]}")
        |> post(oauth2_token_path(conn, :create), Poison.encode!(otp_request_body))
        |> json_response(201)
        |> Map.get("data")

      assert "change_password_token" == change_pwd_token["name"]
      assert "user:change_password" == change_pwd_token["details"]["scope"]

      # 3. Update password with change_password token
      # The request goes through gateway, which
      # converts login_response["data"]["value"] into user_id
      # and puts it in as "x-consumer-id" header

      conn
      |> put_req_header("x-consumer-id", user.id)
      |> put_req_header("authorization", "Bearer #{change_pwd_token["value"]}")
      |> post(oauth2_token_path(conn, :update_password), Poison.encode!(change_password_body))
      |> json_response(200)

      # check that password is changed
      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(request_body))
      |> json_response(401)

      # check that password is changed
      body = put_in(request_body, ~w(token password), "newPa$sw0rD100500")

      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(body))
      |> json_response(201)
    end

    test "happy path with request factor", %{conn: conn, user: user, client: client} do
      expect(SMSMock, :send, 2, fn _phone_number, _body, _type -> {:ok, %{"meta" => %{"code" => 200}}} end)
      insert(:authentication_factor, user_id: user.id, factor: nil)

      change_password_body = %{
        "user" => %{
          "password" => "newPa$sw0rD100500"
        }
      }

      # 1. Create 2fa_access_token with change_password scope

      token_request_body = %{
        "token" => %{
          grant_type: "change_password",
          email: user.email,
          password: "super$ecre7",
          client_id: client.id,
          scope: "user:change_password"
        }
      }

      resp =
        conn
        |> post(oauth2_token_path(conn, :create), Poison.encode!(token_request_body))
        |> json_response(201)

      assert "REQUEST_FACTOR" == get_in(resp, ~w(urgent next_step))
      assert "2fa_access_token" == get_in(resp, ~w(data name))
      refute get_in(resp, ~w(data scope))
      assert "user:change_password" == get_in(resp, ~w(data details scope_request))
      token_init_factor = get_in(resp, ~w(data value))

      # cannot change password with init factor token
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> put_req_header("authorization", "Bearer #{token_init_factor}")
      |> post(oauth2_token_path(conn, :update_password), Poison.encode!(change_password_body))
      |> json_response(401)

      # 2. Init factor

      init_factor_body = %{
        "type" => "SMS",
        "factor" => "+380901112233"
      }

      resp =
        conn
        |> put_req_header("x-consumer-id", user.id)
        |> put_req_header("authorization", "Bearer #{token_init_factor}")
        |> post(oauth2_token_path(conn, :init_factor), Poison.encode!(init_factor_body))
        |> json_response(201)

      assert "APPROVE_FACTOR" == get_in(resp, ~w(urgent next_step))
      assert "2fa_access_token" == get_in(resp, ~w(data name))
      refute get_in(resp, ~w(data scope))
      token_approve_factor = get_in(resp, ~w(data value))

      # cannot change password with approve factor token
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> put_req_header("authorization", "Bearer #{token_approve_factor}")
      |> post(oauth2_token_path(conn, :update_password), Poison.encode!(change_password_body))
      |> json_response(401)

      # OTP code will sent by third party. Let's get it from DB
      otp =
        OTP.list_otps()
        |> List.first()
        |> Map.get(:code)

      # 3. Approve factor with OTP code and change 2FA access token to change password token
      resp =
        conn
        |> put_req_header("authorization", "Bearer #{token_approve_factor}")
        |> post(oauth2_token_path(conn, :approve_factor), Poison.encode!(%{"otp" => otp}))
        |> json_response(201)

      assert "change_password_token" == get_in(resp, ~w(data name))
      assert "user:change_password" == get_in(resp, ~w(data details scope))
      change_pwd_token = get_in(resp, ~w(data value))

      # 4. Update password with change_password token
      # The request goes through gateway, which
      # converts login_response["data"]["value"] into user_id
      # and puts it in as "x-consumer-id" header

      conn
      |> put_req_header("x-consumer-id", user.id)
      |> put_req_header("authorization", "Bearer #{change_pwd_token}")
      |> post(oauth2_token_path(conn, :update_password), Poison.encode!(change_password_body))
      |> json_response(200)

      # check that password is changed
      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(token_request_body))
      |> json_response(401)

      # check that password is changed
      body = put_in(token_request_body, ~w(token password), "newPa$sw0rD100500")

      conn
      |> post(oauth2_token_path(conn, :create), Poison.encode!(body))
      |> json_response(201)
    end
  end
end
