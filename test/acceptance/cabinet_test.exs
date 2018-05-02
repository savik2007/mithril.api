defmodule Mithril.Acceptance.CabinetTest do
  use Mithril.Web.ConnCase

  @direct Mithril.ClientAPI.access_type(:direct)
  @password "Somepa$$word1"

  describe "create approval for MIS client that doesn't have User.user_roles with MIS client_id" do
    setup %{conn: conn} do
      user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt(@password))

      role_mis = insert(:role, name: "MIS USER", scope: "legal_entity:read legal_entity:write")
      role_cabinet = insert(:role, name: "CABINET", scope: "cabinet:read")

      client_type_mis = insert(:client_type, scope: "app:authorize cabinet:read legal_entity:read")
      client_type_cabinet = insert(:client_type, scope: "cabinet:read")

      client_cabinet =
        insert(
          :client,
          redirect_uri: "http://localhost",
          user_id: user.id,
          client_type_id: client_type_cabinet.id,
          settings: %{"allowed_grant_types" => ["password"]},
          priv_settings: %{"access_type" => @direct}
        )

      client_mis =
        insert(
          :client,
          redirect_uri: "http://localhost",
          user_id: user.id,
          client_type_id: client_type_mis.id,
          settings: %{"allowed_grant_types" => ["password"]},
          priv_settings: %{"access_type" => @direct}
        )

      insert(:user_role, user_id: user.id, role_id: role_mis.id, client_id: client_cabinet.id)
      insert(:global_user_role, user_id: user.id, role_id: role_cabinet.id)

      %{conn: conn, user: user, client_mis: client_mis}
    end

    test "success", %{conn: conn, user: user, client_mis: client_mis} do
      request_payload = %{
        token: %{
          grant_type: "password",
          email: user.email,
          password: @password,
          client_id: client_mis.id,
          scope: "app:authorize"
        }
      }

      conn
      |> post("/oauth/tokens", Poison.encode!(request_payload))
      |> json_response(201)

      post_approval(conn, user.id, client_mis.id, client_mis.redirect_uri, "cabinet:read")
    end
  end
end
