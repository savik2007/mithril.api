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

      expect(SMSMock, :send, fn "+380670001122", _body, _type -> {:ok, %{"meta" => %{"code" => 200}}} end)

      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
      |> post(otp_path(conn, :send_otp), %{type: "SMS", factor: "+380670001122"})
      |> json_response(200)
    end

    test "OTP rate limit", %{conn: conn, jwt: jwt} do
      System.put_env("OTP_SEND_TIMEOUT", "5")
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
