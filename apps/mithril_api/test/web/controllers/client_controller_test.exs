defmodule Mithril.Web.ClientControllerTest do
  use Mithril.Web.ConnCase

  alias Ecto.UUID
  alias Core.Clients.Client
  alias Core.TokenAPI

  @broker Client.access_type(:broker)

  @update_attrs %{
    name: "some updated name",
    priv_settings: %{
      "access_type" => @broker
    },
    settings: %{}
  }

  @invalid_attrs %{
    name: nil,
    priv_settings: nil,
    settings: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "list clients" do
    test "search by name by like works", %{conn: conn} do
      insert(:client, name: "john")
      insert(:client, name: "simon")
      insert(:client, name: "monica")
      conn = get(conn, client_path(conn, :index), %{name: "mon"})
      assert 2 == length(json_response(conn, 200)["data"])
    end

    test "search by id", %{conn: conn} do
      client = insert(:client)
      insert(:client)
      insert(:client)

      data =
        conn
        |> get(client_path(conn, :index), %{id: client.id})
        |> json_response(200)
        |> Map.get("data")

      assert 1 == length(data)
      assert client.id == hd(data)["id"]
    end

    test "search by name by like is skipped when other params are invalid", %{conn: conn} do
      insert(:client, name: "john")
      insert(:client, name: "simon")
      insert(:client, name: "monica")
      conn = get(conn, client_path(conn, :index), %{user_id: "111", name: "mon"})
      resp = json_response(conn, 422)
      assert Map.has_key?(resp, "error")
      error = resp["error"]
      assert Map.has_key?(error, "invalid")
      invalid = error["invalid"]
      assert 1 == length(invalid)
      invalid = Enum.at(invalid, 0)
      assert "$.user_id" == invalid["entry"]
    end

    test "lists all entries on index", %{conn: conn} do
      insert(:client)
      insert(:client)
      insert(:client)
      conn = get(conn, client_path(conn, :index))
      assert 3 == length(json_response(conn, 200)["data"])
    end

    test "does not list all entries on index when limit is set", %{conn: conn} do
      insert(:client)
      insert(:client)
      insert(:client)
      conn = get(conn, client_path(conn, :index), %{page_size: 2})
      assert 2 == length(json_response(conn, 200)["data"])
    end

    test "does not list all entries on index when starting_after is set", %{conn: conn} do
      insert(:client)
      insert(:client)
      client = insert(:client)
      conn = get(conn, client_path(conn, :index), %{page_size: 2, page: 2})
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
      assert client.id == Map.get(hd(resp), "id")
    end

    test "search clients by name", %{conn: conn} do
      name = "search_name"
      insert(:client)
      insert(:client, name: name)

      conn = get(conn, client_path(conn, :index, name: name))
      resp = json_response(conn, 200)

      assert Map.has_key?(resp, "paging")
      assert 1 == length(resp["data"])
      refute resp["paging"]["has_more"]
    end
  end

  describe "get client by id" do
    test "show client details", %{conn: conn} do
      client_type = insert(:client_type, name: "independent client")
      client = :client |> insert(client_type: client_type) |> with_connection()

      conn = get(conn, client_details_path(conn, :details, client.id))

      assert %{
               "id" => client.id,
               "name" => client.name,
               "settings" => client.settings,
               "user_id" => client.user_id,
               "client_type_id" => client.client_type_id,
               "client_type_name" => "independent client",
               "is_blocked" => false,
               "block_reason" => nil,
               "inserted_at" => NaiveDateTime.to_iso8601(client.inserted_at),
               "updated_at" => NaiveDateTime.to_iso8601(client.updated_at)
             } == json_response(conn, 200)["data"]
    end

    test "show client", %{conn: conn} do
      client_type = insert(:client_type, name: "independent client 2")
      client = :client |> insert(client_type: client_type) |> with_connection()

      conn = get(conn, client_path(conn, :show, client.id))

      assert %{
               "id" => client.id,
               "name" => client.name,
               "settings" => client.settings,
               "priv_settings" => client.priv_settings,
               "user_id" => client.user_id,
               "client_type_id" => client.client_type_id,
               "client_type_name" => "independent client 2",
               "is_blocked" => false,
               "block_reason" => nil,
               "inserted_at" => NaiveDateTime.to_iso8601(client.inserted_at),
               "updated_at" => NaiveDateTime.to_iso8601(client.updated_at)
             } == json_response(conn, 200)["data"]
    end
  end

  describe "create client" do
    test "creates client and renders client when data is valid", %{conn: conn} do
      client_type = insert(:client_type, name: "independent client 2")
      user = insert(:user)

      attrs = %{
        name: "Test MIS",
        user_id: user.id,
        settings: "",
        client_type_id: client_type.id
      }

      client =
        conn
        |> post(client_path(conn, :create), client: attrs)
        |> json_response(201)
        |> assert_client_fields()

      data =
        conn
        |> get(client_path(conn, :show, client["id"]))
        |> json_response(200)
        |> assert_client_fields()

      assert data["name"] == client["name"]
    end

    test "does not create client and renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, client_path(conn, :create), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "put new client with id", %{conn: conn} do
      %Client{client_type_id: client_type_id, user_id: user_id} = insert(:client)

      update_attrs =
        Map.merge(@update_attrs, %{
          client_type_id: client_type_id,
          user_id: user_id
        })

      id = UUID.generate()
      conn = put(conn, client_path(conn, :update, %Client{id: id}), client: update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, client_path(conn, :show, id))
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end
  end

  describe "update client" do
    test "updates chosen client and renders client when data is valid", %{conn: conn} do
      %Client{id: id} = client = insert(:client)
      conn = put(conn, client_path(conn, :update, client), client: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, client_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some updated name",
               "priv_settings" => %{
                 "access_type" => @broker
               },
               "is_blocked" => false,
               "block_reason" => nil,
               "settings" => %{}
             } = json_response(conn, 200)["data"]
    end

    test "does not update chosen client and renders errors when data is invalid", %{conn: conn} do
      client = insert(:client)
      conn = put(conn, client_path(conn, :update, client), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "deactivate client tokens", %{conn: conn} do
      client = insert(:client)
      client2 = insert(:client)
      access_token = create_access_token(client, client.user)
      refresh_token = create_refresh_token(client, client.user)
      access_token2 = create_access_token(client2, client2.user)
      refresh_token2 = create_refresh_token(client2, client2.user)

      conn
      |> patch(client_actions_path(conn, :deactivate_tokens, client))
      |> json_response(200)

      assert access_token.id |> TokenAPI.get_token!() |> TokenAPI.expired?()
      assert refresh_token.id |> TokenAPI.get_token!() |> TokenAPI.expired?()

      refute access_token2.id |> TokenAPI.get_token!() |> TokenAPI.expired?()
      refute refresh_token2.id |> TokenAPI.get_token!() |> TokenAPI.expired?()
    end
  end

  test "deletes chosen client", %{conn: conn} do
    client = insert(:client)
    conn = delete(conn, client_path(conn, :delete, client))
    assert response(conn, 204)

    assert_error_sent(404, fn ->
      get(conn, client_path(conn, :show, client))
    end)
  end

  defp assert_client_fields(%{"data" => client}), do: assert_client_fields(client)

  defp assert_client_fields(client) do
    fields = ~w(
      id
      name
      settings
      priv_settings
      is_blocked
      block_reason
      user_id
      client_type_id
      inserted_at
      updated_at
    )

    Enum.each(fields, fn field ->
      err_msg = "Response for client doesn't contains field `#{field}}`"
      assert Map.has_key?(client, field), err_msg
    end)

    client
  end
end
