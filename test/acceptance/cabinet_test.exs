defmodule Mithril.Acceptance.CabinetTest do
  use Mithril.Web.ConnCase

  describe "create approval for MIS client that doesn't have User.user_roles with MIS client_id" do
    setup %{conn: conn} do
      user = insert(:user)

      role_mis = insert(:role, name: "MIS USER", scope: "legal_entity:read legal_entity:write")
      role_cabinet = insert(:role, name: "CABINET", scope: "cabinet:read")

      client_type_mis = insert(:client_type, scope: "app:authorize cabinet:read legal_entity:read")
      client_type_cabinet = insert(:client_type, scope: "cabinet:read")

      client_cabinet = insert(:client, user: user, client_type: client_type_cabinet)
      client_mis = insert(:client, user: user, client_type: client_type_mis)
      connection_mis = insert(:connection, client: client_mis)

      insert(:user_role, user: user, role: role_mis, client: client_cabinet)
      insert(:global_user_role, user: user, role: role_cabinet)

      %{conn: conn, user: user, client_mis: client_mis, connection_mis: connection_mis}
    end

    test "success", %{conn: conn, user: user, client_mis: client_mis, connection_mis: connection_mis} do
      request_payload = %{
        token: %{
          grant_type: "password",
          email: user.email,
          password: user_raw_password(),
          client_id: client_mis.id,
          scope: "app:authorize"
        }
      }

      conn
      |> post(auth_token_path(conn, :create), Poison.encode!(request_payload))
      |> json_response(201)

      post_approval(conn, user.id, client_mis.id, connection_mis.redirect_uri, "cabinet:read")
    end
  end
end
