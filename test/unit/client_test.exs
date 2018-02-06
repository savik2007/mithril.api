defmodule Mithril.RoleAPI.ClientTest do
  @doc false

  use Mithril.Web.ConnCase

  alias Mithril.ClientAPI
  alias Mithril.ClientAPI.Client

  test "Create client with access_type" do
    %{id: user_id} = insert(:user)
    %{id: client_type_id} = insert(:client_type)

    assert {:ok, client} =
             ClientAPI.create_client(%{
               name: "MSP",
               user_id: user_id,
               redirect_uri: "http://example.com",
               settings: %{},
               client_type_id: client_type_id
             })

    assert %Client{priv_settings: %{"access_type" => "BROKER"}} = client
  end
end
