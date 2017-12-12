defmodule Mithril.Web.ClientControllerTest do
  use Mithril.Web.ConnCase

  alias Ecto.UUID
  alias Mithril.ClientAPI
  alias Mithril.ClientAPI.Client
  alias Mithril.Repo

  @broker ClientAPI.access_type(:broker)

  @update_attrs %{
    name: "some updated name",
    priv_settings: %{
      "access_type" => @broker
    },
    redirect_uri: "https://localhost",
    secret: "some updated secret",
    settings: %{}
  }

  @invalid_attrs %{
    name: nil,
    priv_settings: nil,
    redirect_uri: nil,
    settings: nil
  }

  def fixture(:client, name \\ "some_name", client_type_params \\ %{}) do
    %{id: client_type_id} = Mithril.Fixtures.create_client_type(client_type_params)
    {:ok, client} =
      name
      |> Mithril.Fixtures.client_create_attrs(client_type_id)
      |> ClientAPI.create_client()
    client
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "search by name by like works", %{conn: conn} do
    fixture(:client, "john")
    fixture(:client, "simon")
    fixture(:client, "monica")
    conn = get conn, client_path(conn, :index), %{name: "mon"}
    assert 2 == length(json_response(conn, 200)["data"])
  end

  test "search by name by like is skipped when other params are invalid", %{conn: conn} do
    fixture(:client, "john")
    fixture(:client, "simon")
    fixture(:client, "monica")
    conn = get conn, client_path(conn, :index), %{user_id: "111", name: "mon"}
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
    fixture(:client)
    fixture(:client)
    fixture(:client)
    conn = get conn, client_path(conn, :index)
    assert 3 == length(json_response(conn, 200)["data"])
  end

  test "does not list all entries on index when limit is set", %{conn: conn} do
    fixture(:client)
    fixture(:client)
    fixture(:client)
    conn = get conn, client_path(conn, :index), %{page_size: 2}
    assert 2 == length(json_response(conn, 200)["data"])
  end

  test "does not list all entries on index when starting_after is set", %{conn: conn} do
    fixture(:client)
    fixture(:client)
    client = fixture(:client)
    conn = get conn, client_path(conn, :index), %{page_size: 2, page: 2}
    resp = json_response(conn, 200)["data"]
    assert 1 == length(resp)
    assert client.id == Map.get(hd(resp), "id")
  end

  test "search clients by name", %{conn: conn} do
    name = "search_name"
    fixture(:client)
    {:ok, _} = name
               |> Mithril.Fixtures.client_create_attrs()
               |> ClientAPI.create_client()

    conn = get conn, client_path(conn, :index, [name: name])
    resp = json_response(conn, 200)

    assert Map.has_key?(resp, "paging")
    assert 1 == length(resp["data"])
    refute resp["paging"]["has_more"]
  end

  test "show client details", %{conn: conn} do
    client = fixture(:client, "some name", %{name: "some_kind_of_client"})

    conn = get conn, client_details_path(conn, :details, client.id)
    assert %{
             "id" => client.id,
             "name" => client.name,
             "settings" => client.settings,
             "redirect_uri" => client.redirect_uri,
             "user_id" => client.user_id,
             "client_type_id" => client.client_type_id,
             "client_type_name" => "some_kind_of_client",
             "is_blocked" => false,
             "block_reason" => nil,
             "inserted_at" => NaiveDateTime.to_iso8601(client.inserted_at),
             "updated_at" => NaiveDateTime.to_iso8601(client.updated_at),
           } == json_response(conn, 200)["data"]
  end

  test "show client", %{conn: conn} do
    client = fixture(:client, "some name", %{name: "some_kind_of_client"})
    conn = get conn, client_path(conn, :show, client.id)
    assert %{
             "id" => client.id,
             "name" => client.name,
             "secret" => client.secret,
             "settings" => client.settings,
             "priv_settings" => client.priv_settings,
             "redirect_uri" => client.redirect_uri,
             "user_id" => client.user_id,
             "client_type_id" => client.client_type_id,
             "client_type_name" => "some_kind_of_client",
             "is_blocked" => false,
             "block_reason" => nil,
             "inserted_at" => NaiveDateTime.to_iso8601(client.inserted_at),
             "updated_at" => NaiveDateTime.to_iso8601(client.updated_at),
           } == json_response(conn, 200)["data"]
  end

  test "creates client and renders client when data is valid", %{conn: conn} do
    attrs = Mithril.Fixtures.client_create_attrs()
    conn = post conn, client_path(conn, :create), client: attrs
    assert %{"id" => id} = json_response(conn, 201)["data"]

    name = attrs.name
    conn = get conn, client_path(conn, :show, id)
    assert %{
             "id" => ^id,
             "name" => ^name,
             "secret" => _secret,
             "settings" => %{},
             "redirect_uri" => "http://localhost"
           } = json_response(conn, 200)["data"]
  end

  test "does not create client and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, client_path(conn, :create), client: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "put new client with id", %{conn: conn} do
    %Client{client_type_id: client_type_id, user_id: user_id} = fixture(:client)

    update_attrs = Map.merge(
      @update_attrs,
      %{
        client_type_id: client_type_id,
        user_id: user_id
      }
    )

    id = UUID.generate()
    conn = put conn, client_path(conn, :update, %Client{id: id}), client: update_attrs
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get conn, client_path(conn, :show, id)
    assert %{"id" => ^id} = json_response(conn, 200)["data"]
  end

  test "updates chosen client and renders client when data is valid", %{conn: conn} do
    %Client{id: id, secret: secret} = client = fixture(:client)
    conn = put conn, client_path(conn, :update, client), client: @update_attrs
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get conn, client_path(conn, :show, id)
    assert %{
             "id" => ^id,
             "name" => "some updated name",
             "redirect_uri" => "https://localhost",
             "secret" => ^secret,
             "priv_settings" => %{
               "access_type" => @broker
             },
             "is_blocked" => false,
             "block_reason" => nil,
             "settings" => %{},
           } = json_response(conn, 200)["data"]
  end

  test "does not update chosen client and renders errors when data is invalid", %{conn: conn} do
    client = fixture(:client)
    conn = put conn, client_path(conn, :update, client), client: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen client", %{conn: conn} do
    client = fixture(:client)
    conn = delete conn, client_path(conn, :delete, client)
    assert response(conn, 204)
    assert_error_sent 404, fn ->
      get conn, client_path(conn, :show, client)
    end
  end

  test "refresh client secret", %{conn: conn} do
    %{id: id, secret: old_secret} = fixture(:client)
    conn = patch conn, client_refresh_secret_path(conn, :refresh_secret, id)
    resp = json_response(conn, 200)

    %{secret: new_secret} = Repo.one(Client)
    assert %{"secret" => ^new_secret} = resp["data"]
    assert old_secret != new_secret
  end
end
