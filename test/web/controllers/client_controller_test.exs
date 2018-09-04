defmodule Mithril.Web.ClientControllerTest do
  use Mithril.Web.ConnCase

  alias Ecto.UUID
  alias Mithril.ClientAPI
  alias Mithril.ClientAPI.Client

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

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "search by name by like works", %{conn: conn} do
    insert(:client, name: "john")
    insert(:client, name: "simon")
    insert(:client, name: "monica")
    conn = get(conn, client_path(conn, :index), %{name: "mon"})
    assert 2 == length(json_response(conn, 200)["data"])
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

  test "show client details", %{conn: conn} do
    client_type = insert(:client_type, name: "independent client")
    client = insert(:client, client_type_id: client_type.id)

    conn = get(conn, client_details_path(conn, :details, client.id))

    assert %{
             "id" => client.id,
             "name" => client.name,
             "settings" => client.settings,
             "redirect_uri" => client.redirect_uri,
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
    client = insert(:client, client_type_id: client_type.id)

    conn = get(conn, client_path(conn, :show, client.id))

    assert %{
             "id" => client.id,
             "name" => client.name,
             "secret" => client.secret,
             "settings" => client.settings,
             "priv_settings" => client.priv_settings,
             "redirect_uri" => client.redirect_uri,
             "user_id" => client.user_id,
             "client_type_id" => client.client_type_id,
             "client_type_name" => "independent client 2",
             "is_blocked" => false,
             "block_reason" => nil,
             "inserted_at" => NaiveDateTime.to_iso8601(client.inserted_at),
             "updated_at" => NaiveDateTime.to_iso8601(client.updated_at)
           } == json_response(conn, 200)["data"]
  end

  test "creates client and renders client when data is valid", %{conn: conn} do
    attrs = :client |> build() |> Map.from_struct()
    conn = post(conn, client_path(conn, :create), client: attrs)
    assert %{"id" => id} = json_response(conn, 201)["data"]

    name = attrs.name
    conn = get(conn, client_path(conn, :show, id))

    assert %{
             "id" => ^id,
             "name" => ^name,
             "secret" => _secret,
             "settings" => %{},
             "redirect_uri" => "http://localhost"
           } = json_response(conn, 200)["data"]
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

  test "updates chosen client and renders client when data is valid", %{conn: conn} do
    %Client{id: id, secret: secret} = client = insert(:client)
    conn = put(conn, client_path(conn, :update, client), client: @update_attrs)
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get(conn, client_path(conn, :show, id))

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
             "settings" => %{}
           } = json_response(conn, 200)["data"]
  end

  test "does not update chosen client and renders errors when data is invalid", %{conn: conn} do
    client = insert(:client)
    conn = put(conn, client_path(conn, :update, client), client: @invalid_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen client", %{conn: conn} do
    client = insert(:client)
    conn = delete(conn, client_path(conn, :delete, client))
    assert response(conn, 204)

    assert_error_sent(404, fn ->
      get(conn, client_path(conn, :show, client))
    end)
  end

  # connections

  describe "list connections" do
    setup %{conn: conn} do
      client = insert(:client)
      consumer = insert(:client)
      {:ok, conn: conn, client: client, consumer: consumer}
    end

    test "all entries on index", %{conn: conn, client: client, consumer: consumer} do
      insert_pair(:connection, client: client, consumer: consumer)

      data =
        conn
        |> get(client_connection_path(conn, :index, client))
        |> json_response(200)
        |> Map.get("data")

      assert 2 == length(data)
    end
  end

  describe "get connection by id" do
    setup %{conn: conn} do
      client = insert(:client)
      consumer = insert(:client)
      {:ok, conn: conn, client: client, consumer: consumer}
    end

    test "success", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)

      conn
      |> get(client_connection_path(conn, :show, client, connection))
      |> json_response(200)
      |> assert_connection_fields()
    end

    test "invalid connection id", %{conn: conn, client: client, consumer: consumer} do
      assert_error_sent(404, fn ->
        get(conn, client_connection_path(conn, :show, client, consumer))
      end)
    end

    test "invalid client id", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)

      assert_error_sent(404, fn ->
        get(conn, client_connection_path(conn, :show, consumer, connection))
      end)
    end
  end

  describe "upsert connection" do
    setup %{conn: conn} do
      client = insert(:client)
      consumer = insert(:client)
      {:ok, conn: conn, client: client, consumer: consumer}
    end

    test "success create", %{conn: conn, client: client, consumer: consumer} do
      attrs = %{redirect_uri: "http://localhost", client_id: client.id, consumer_id: consumer.id}

      connection =
        conn
        |> put(client_connection_path(conn, :upsert, client), attrs)
        |> json_response(201)
        |> assert_connection_fields()

      connection_show =
        conn
        |> get(client_connection_path(conn, :show, client, connection["id"]))
        |> json_response(200)
        |> assert_connection_fields()

      assert connection == connection_show
    end

    test "success update", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)
      attrs = %{consumer_id: consumer.id, client_id: client.id, secret: "new secret"}

      conn
      |> put(client_connection_path(conn, :upsert, client), attrs)
      |> json_response(200)
      |> assert_connection_fields()

      %{secret: new_secret} = ClientAPI.get_connection!(connection.id)
      assert connection.secret == new_secret
    end

    test "refresh secret", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)

      data =
        conn
        |> patch(client_connection_path(conn, :refresh_secret, client, connection))
        |> json_response(200)
        |> Map.get("data")

      assert Map.has_key?(data, "secret")
      %{secret: new_secret} = ClientAPI.get_connection!(connection.id)
      assert new_secret == data["secret"]
      refute connection.secret == new_secret
    end

    test "invalid redirect uri", %{conn: conn, client: client, consumer: consumer} do
      attrs = %{redirect_uri: "invalid url", consumer_id: consumer.id}

      errors =
        conn
        |> put(client_connection_path(conn, :upsert, client), attrs)
        |> json_response(422)
        |> get_in(~w(error invalid))

      assert "$.redirect_uri" == hd(errors)["entry"]
    end

    test "invalid client_id", %{conn: conn, consumer: consumer} do
      attrs = %{redirect_uri: "http://localhost", consumer_id: consumer.id}

      conn
      |> put(client_connection_path(conn, :upsert, "invalid"), attrs)
      |> json_response(404)
    end

    test "invalid consumer_id", %{conn: conn, client: client} do
      attrs = %{redirect_uri: "http://localhost", consumer_id: "invalid"}

      conn
      |> put(client_connection_path(conn, :upsert, client), attrs)
      |> json_response(404)
    end
  end

  describe "update connection" do
    setup %{conn: conn} do
      client = insert(:client)
      consumer = insert(:client)
      {:ok, conn: conn, client: client, consumer: consumer}
    end

    test "success update", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)
      redirect_uri = "http://example.com"
      attrs = %{secret: "new secret", redirect_uri: redirect_uri}

      conn
      |> patch(client_connection_path(conn, :update, client, connection), attrs)
      |> json_response(200)
      |> assert_connection_fields()

      connection_from_db = ClientAPI.get_connection!(connection.id)
      assert connection.secret == connection_from_db.secret
      assert redirect_uri == connection_from_db.redirect_uri
    end

    test "invalid params", %{conn: conn, client: client, consumer: consumer} do
      connection = insert(:connection, client: client, consumer: consumer)
      attrs = %{redirect_uri: "invalid url", consumer_id: consumer.id}

      errors =
        conn
        |> patch(client_connection_path(conn, :update, client, connection), attrs)
        |> json_response(422)
        |> get_in(~w(error invalid))

      assert "$.redirect_uri" == hd(errors)["entry"]
    end
  end

  describe "delete connections" do
    test "success", %{conn: conn} do
      connection = insert(:connection)

      conn
      |> delete(client_connection_path(conn, :delete, connection.client_id, connection))
      |> response(204)

      assert_error_sent(404, fn ->
        get(conn, client_connection_path(conn, :show, connection.client_id, UUID.generate()))
      end)
    end

    test "not found", %{conn: conn} do
      connection = insert(:connection)

      assert_error_sent(404, fn ->
        delete(conn, client_connection_path(conn, :delete, connection.client_id, UUID.generate()))
      end)
    end
  end

  defp assert_connection_fields(%{"data" => connection}), do: assert_connection_fields(connection)

  defp assert_connection_fields(connection) do
    refute Map.has_key?(connection, "secret")
    fields = ~w(id redirect_uri client_id consumer_id)

    Enum.each(fields, fn field ->
      err_msg = "Response doesn't contains field `#{field}}`"
      assert Map.has_key?(connection, field), err_msg
    end)

    connection
  end
end
