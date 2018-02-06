defmodule Mithril.Web.OTPControllerTest do
  use Mithril.Web.ConnCase

  alias Ecto.UUID

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

  defp generate_code(prefix) do
    prefix <> "===" <> UUID.generate()
  end
end
