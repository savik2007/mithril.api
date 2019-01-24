defmodule Mithril.OAuth.NonceControllerTest do
  use Mithril.Web.ConnCase

  import Mithril.Guardian

  alias Ecto.UUID

  describe "generate nonce" do
    test "success", %{conn: conn} do
      %{id: id} = insert(:client)

      nonce =
        conn
        |> post(oauth2_nonce_path(conn, :nonce, client_id: id))
        |> json_response(200)
        |> get_in(~w(data token))

      aud = get_aud(:login)
      assert {:ok, %{"nonce" => _, "aud" => ^aud}} = decode_and_verify(nonce)
    end

    test "client not found", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        post(conn, oauth2_nonce_path(conn, :nonce, client_id: UUID.generate()))
      end
    end

    test "client_id not set", %{conn: conn} do
      assert [err] =
               conn
               |> post(oauth2_nonce_path(conn, :nonce))
               |> json_response(422)
               |> get_in(~w(error invalid))

      assert "$.client_id" == err["entry"]
    end
  end
end
