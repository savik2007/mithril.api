defmodule Mithril.OAuth.NonceControllerTest do
  use Mithril.Web.ConnCase

  import Mithril.Guardian

  describe "generate nonce" do
    test "success", %{conn: conn} do
      %{id: id} = insert(:client)

      nonce =
        conn
        |> put_req_header("client-id", id)
        |> get(oauth2_nonce_path(conn, :nonce))
        |> json_response(200)
        |> get_in(~w(data token))

      aud = get_aud(:login)
      assert {:ok, %{"nonce" => _, "aud" => ^aud}} = decode_and_verify(nonce)
    end

    test "client_id header not set", %{conn: conn} do
      assert "Client header not set" =
               conn
               |> get(oauth2_nonce_path(conn, :nonce))
               |> json_response(401)
               |> get_in(~w(error message))
    end
  end
end
