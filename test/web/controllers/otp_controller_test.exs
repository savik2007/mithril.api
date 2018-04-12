defmodule Mithril.Web.OTPControllerTest do
  use Mithril.Web.ConnCase

  import Mox
  import Mithril.Guardian

  alias Ecto.UUID

  setup :verify_on_exit!

  setup %{conn: conn} do
    token = UUID.generate()
    insert(:otp, code: 1234, key: generate_code(token))
    insert(:otp, code: 2345, status: "CANCELED")
    insert(:otp, code: 3456, active: false)

    {:ok, conn: put_req_header(conn, "accept", "application/json"), token: token}
  end

  describe "list otps" do
    test "search by token", %{conn: conn, token: token} do
      conn = get(conn, otp_path(conn, :index), %{key: token})
      data = json_response(conn, 200)["data"]
      assert 1 == length(data)
      assert 1234 == hd(data)["code"]
    end

    test "search by status", %{conn: conn} do
      conn = get(conn, otp_path(conn, :index), %{status: "CANCELED"})
      data = json_response(conn, 200)["data"]
      assert 1 == length(data)
      assert 2345 == hd(data)["code"]
    end

    test "search by active", %{conn: conn} do
      conn = get(conn, otp_path(conn, :index), %{active: false})
      data = json_response(conn, 200)["data"]
      assert 1 == length(data)
      assert 3456 == hd(data)["code"]
    end
  end

  describe "send OTP" do
    setup %{conn: conn} do
      System.put_env("SMS_ENABLED", "true")
      on_exit(fn -> System.put_env("SMS_ENABLED", "false") end)
      {:ok, jwt, _} = encode_and_sign(:email, %{email: "email@example.com"}, token_type: "access")

      %{conn: conn, jwt: jwt}
    end

    test "success", %{conn: conn, jwt: jwt} do
      key = "email@example.com===+380670001122"
      insert(:otp, key: key, inserted_at: DateTime.from_naive!(~N[2017-01-02 13:26:08], "Etc/UTC"))
      insert(:otp, key: key)
      insert(:otp, key: key)

      expect(SMSMock, :send, 2, fn "+380670001122", _body, _type -> {:ok, %{"meta" => %{"code" => 200}}} end)

      # response contain urgent data with jwt token
      assert conn
             |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
             |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "+380670001122"})
             |> json_response(200)
             |> get_in(~w(urgent code))

      # response DOES NOT contain urgent data with jwt token for disabled config
      System.put_env("SENSITIVE_DATA_IN_RESPONSE_ENABLED", "false")

      refute conn
             |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
             |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "+380670001122"})
             |> json_response(200)
             |> get_in(~w(urgent code))

      on_exit(fn ->
        System.put_env("SENSITIVE_DATA_IN_RESPONSE_ENABLED", "true")
      end)
    end

    test "invalid otp value", %{conn: conn, jwt: jwt} do
      assert [err] =
               conn
               |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
               |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "invalid"})
               |> json_response(422)
               |> get_in(~w(error invalid))

      assert "$.factor" == err["entry"]
    end

    test "OTP rate limit", %{conn: conn, jwt: jwt} do
      System.put_env("OTP_SEND_TIMEOUT", "3")
      on_exit(fn -> System.put_env("SMS_ENABLED", "0") end)

      key = "email@example.com===+380670001122"
      insert(:otp, key: key)
      insert(:otp, key: key)
      insert(:otp, key: key)

      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
      |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "+380670001122"})
      |> json_response(429)
    end

    test "JWT not set", %{conn: conn} do
      conn
      |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "+380670001122"})
      |> json_response(401)
    end

    test "invalid JWT", %{conn: conn} do
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer invalid")
      |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "+380670001122"})
      |> json_response(401)
    end

    test "JWT expired", %{conn: conn} do
      jwt =
        "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJtaXRocmlsLWxvZ2luIiwiZXhwIjoxNTIyMzEzODgxLCJpYXQiOjE1Mj" <>
          "IzMTM4MjEsImlzcyI6IkVIZWFsdGgiLCJqdGkiOiI1YzRlMjg5ZS0wNjQyLTQ0YzYtYmU0Yy1iOWZjM2EyZDllZGYiLCJuYmYiOjE" <>
          "1MjIzMTM4MjAsIm5vbmNlIjoxMjMsInN1YiI6MTIzLCJ0eXAiOiJhY2Nlc3MifQ.g853d2Tl3J0aAeEfJyxQ1O1V4b442qSdXb9em" <>
          "TGvhZIooT5c8JN5rdRh0x3L-Mk58Z_vcjtZcAHc9Vsn-MFLbg"

      conn
      |> Plug.Conn.put_req_header("authorization", jwt)
      |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "+380670001122"})
      |> json_response(401)
    end

    test "invalid JWT aud", %{conn: conn} do
      {:ok, jwt, _} = encode_and_sign(:nonce, %{nonce: 123}, token_type: "access")

      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
      |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "+380670001122"})
      |> json_response(401)
    end

    test "invalid type", %{conn: conn, jwt: jwt} do
      assert [err] =
               conn
               |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
               |> post(otp_path(conn, :send_otp), %{type: "invalid", factor: "+380670001122"})
               |> json_response(422)
               |> get_in(~w(error invalid))

      assert "$.type" == err["entry"]
    end

    test "invalid params", %{conn: conn, jwt: jwt} do
      assert [err1, err2] =
               conn
               |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
               |> post(otp_path(conn, :send_otp), %{types: "SMS", factors: "+380670001122"})
               |> json_response(422)
               |> get_in(~w(error invalid))

      assert "$.type" == err2["entry"]
      assert "$.factor" == err1["entry"]
    end
  end

  defp generate_code(prefix) do
    prefix <> "===" <> UUID.generate()
  end
end
