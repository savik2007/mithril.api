defmodule Mithril.Web.RegistrationControllerTest do
  use Mithril.Web.ConnCase

  import Mox
  import Joken

  @jwt_secret Confex.fetch_env!(:mithril_api, Mithril.Registration.API)[:jwt_secret]

  describe "send verification email" do
    setup %{conn: conn} do
      insert(:user, tax_id: "")

      expect(EmailMock, :send, fn "success-new-user@example.com", jwt ->
        %{claims: claims, error: err} =
          jwt
          |> token()
          |> with_signer(hs256(@jwt_secret))
          |> verify()

        refute err
        assert Map.has_key?(claims, "email")
        assert "success-new-user@example.com" == claims["email"]

        {:ok, %{"meta" => %{"code" => 200}}}
      end)

      expect(EmailMock, :send, fn _email, _jwt ->
        {:error, %{"meta" => %{"code" => 500}}}
      end)

      %{conn: conn}
    end

    test "invalid email", %{conn: conn} do
      assert "$.email" ==
               conn
               |> post(registration_path(conn, :send_email_verification), %{email: "invalid"})
               |> json_response(422)
               |> get_in(~w(error invalid))
               |> hd()
               |> Map.get("entry")
    end

    test "user with passed email already exists", %{conn: conn} do
      email = "test@example.com"
      insert(:user, email: email, tax_id: "23451234")

      assert "User with this email already exists" ==
               conn
               |> post(registration_path(conn, :send_email_verification), %{email: email})
               |> json_response(409)
               |> get_in(~w(error message))
    end

    test "user with passed email already exists but tax_id is empty", %{conn: conn} do
      email = "success-new-user@example.com"
      insert(:user, email: email, tax_id: "")

      conn
      |> post(registration_path(conn, :send_email_verification), %{email: email})
      |> json_response(200)
    end

    test "success", %{conn: conn} do
      email = "success-new-user@example.com"

      conn
      |> post(registration_path(conn, :send_email_verification), %{email: email})
      |> json_response(200)
    end
  end
end
