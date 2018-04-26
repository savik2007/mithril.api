defmodule Mithril.Acceptance.CabinetTest do
  use Mithril.Web.ConnCase

  @direct Mithril.ClientAPI.access_type(:direct)

  describe "Register user via EHealth clinet and login via MIS client" do
    setup %{conn: conn} do
      client_type_mis = insert(:client_type, scope: "legal_entity:read legal_entity:write legal_entity:mis_verify")
      client_type_cabinet = insert(:client_type, scope: "cabinet:read")
      role_cabinet = insert(:role, scope: "cabinet:read")

      client_cabinet =
        insert(
          :client,
          redirect_uri: "http://localhost",
          client_type_id: client_type_cabinet.id,
          settings: %{"allowed_grant_types" => ["password"]},
          priv_settings: %{"access_type" => @direct}
        )

      client_mis =
        insert(
          :client,
          redirect_uri: "http://localhost",
          client_type_id: client_type_mis.id,
          settings: %{"allowed_grant_types" => ["password"]},
          priv_settings: %{"access_type" => @direct}
        )

      %{conn: conn}
    end

    test "success" do

    end
  end
end
