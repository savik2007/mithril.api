defmodule Mithril.Web.AppControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.AppAPI.App
  alias Ecto.UUID

  @create_attrs %{scope: "some scope"}
  @update_attrs %{scope: "some updated scope"}
  @invalid_attrs %{scope: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "list all apps" do
    test "lists all entries on index", %{conn: conn} do
      client = insert(:client)
      user = insert(:user)
      insert(:app, client_id: client.id, user_id: user.id)
      insert(:app, client_id: client.id)

      resp =
        conn
        |> put_req_header("x-consumer-id", user.id)
        |> get(app_path(conn, :index))
        |> json_response(200)

      assert 1 == length(resp["data"])

      schema =
        "specs/json_schemas/apps.json"
        |> File.read!()
        |> Poison.decode!()

      assert :ok = NExJsonSchema.Validator.validate(schema, resp)
    end

    test "does not list all entries on index when limit is set", %{conn: conn} do
      user = insert(:user)
      Enum.each(1..3, fn _ -> insert(:app, user_id: user.id) end)

      resp =
        conn
        |> put_req_header("x-consumer-id", user.id)
        |> get(app_path(conn, :index), %{page_size: 2})
        |> json_response(200)

      assert 2 == length(resp["data"])
    end

    test "does not list all entries on index when starting_after is set", %{conn: conn} do
      user = insert(:user)
      insert(:app, user_id: user.id)
      insert(:app, user_id: user.id)
      insert(:app, user_id: user.id)

      resp =
        conn
        |> put_req_header("x-consumer-id", user.id)
        |> get(app_path(conn, :index), %{page_size: 2, page: 2})
        |> json_response(200)

      resp = resp["data"]
      assert 1 == length(resp)
    end

    test "list apps by client_names" do
      user = insert(:user)
      %{name: name1, id: client_id1} = insert(:client)
      %{name: name2, id: client_id2} = insert(:client)
      %{id: client_id3} = insert(:client)
      insert(:app, client_id: client_id1, user_id: user.id)
      insert(:app, client_id: client_id2, user_id: user.id)
      insert(:app, client_id: client_id3, user_id: user.id)

      prefix = "client_name-"
      client_names = "#{prefix}#{name1},#{prefix}#{name2}"
      conn = build_conn()

      resp =
        conn
        |> put_req_header("x-consumer-id", user.id)
        |> get(app_path(conn, :index), %{"client_names" => client_names})

      data = json_response(resp, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"client_id" => client_id} ->
        assert client_id in [client_id1, client_id2]
      end)
    end

    test "list apps by not exact client_names" do
      name1 = "some_clinic"
      name2 = "some_other_clinic"
      name3 = "whatever_clinic"
      user = insert(:user)
      %{id: client_id1} = insert(:client, name: name1)
      %{id: client_id2} = insert(:client, name: name2)
      %{id: client_id3} = insert(:client, name: name3)
      insert(:app, client_id: client_id1, user_id: user.id)
      insert(:app, client_id: client_id2, user_id: user.id)
      insert(:app, client_id: client_id3, user_id: user.id)

      name1 = String.slice(name1, 0, 6)
      name2 = String.slice(name2, 0, 6)
      name3 = String.slice(name3, 3, 6)
      prefix = "client_name-"
      client_names = "#{prefix}#{name1},#{prefix}#{name2},#{prefix}#{name3}"
      conn = build_conn()

      resp =
        conn
        |> put_req_header("x-consumer-id", user.id)
        |> get(app_path(conn, :index), %{"client_names" => client_names})

      data = json_response(resp, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"client_id" => client_id} ->
        assert client_id in [client_id1, client_id2]
      end)
    end

    test "list apps ignore unprefixed params" do
      name1 = "some_clinic"
      client = insert(:client, name: name1)
      insert(:app, client_id: client.id)

      prefix = ""
      client_names = "#{prefix}#{name1}"
      conn = build_conn()

      resp =
        conn
        |> put_req_header("x-consumer-id", client.user_id)
        |> get(app_path(conn, :index), %{"client_names" => client_names})
        |> json_response(200)

      data = resp["data"]
      assert 0 == length(data)
    end

    test "list apps by client_ids" do
      user = insert(:user)
      %{id: client_id1} = insert(:client)
      %{id: client_id2} = insert(:client)
      %{id: client_id3} = insert(:client)
      insert(:app, client_id: client_id1, user_id: user.id)
      insert(:app, client_id: client_id2, user_id: user.id)
      insert(:app, client_id: client_id3, user_id: user.id)

      prefix = "client-"
      client_ids = "#{prefix}#{client_id1},#{prefix}#{client_id2}"
      conn = build_conn()

      resp =
        conn
        |> put_req_header("x-consumer-id", user.id)
        |> get(app_path(conn, :index), %{"client_ids" => client_ids})

      data = json_response(resp, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"client_id" => client_id} ->
        assert client_id in [client_id1, client_id2]
      end)
    end

    test "list apps by user" do
      %{id: user_id1} = insert(:user)
      %{id: user_id2} = insert(:user)
      %{id: user_id3} = insert(:user)
      insert(:app, user_id: user_id1)
      insert(:app, user_id: user_id2)
      insert(:app, user_id: user_id3)

      prefix = "user-"
      user_ids = "#{prefix}#{user_id1},#{prefix}#{user_id2}"
      conn = build_conn()

      resp =
        conn
        |> put_req_header("x-consumer-id", user_id1)
        |> get(app_path(conn, :index), %{"user_ids" => user_ids})
        |> json_response(200)

      data = resp["data"]
      assert [%{"user_id" => ^user_id1}] = data
    end

    test "list apps by combined params" do
      %{id: user_id1} = insert(:user)
      %{id: user_id2} = insert(:user)

      %{id: client_id1, name: name1} = insert(:client)
      %{id: client_id2, name: name2} = insert(:client)
      %{id: client_id3, name: name3} = insert(:client)

      insert(:app, user_id: user_id1)
      insert(:app, user_id: user_id2)

      insert(:app, client_id: client_id1, user_id: user_id1)
      insert(:app, client_id: client_id2, user_id: user_id1)
      insert(:app, client_id: client_id3, user_id: user_id1)

      prefix = "client-"
      client_ids = "#{prefix}#{client_id1},#{prefix}#{client_id2}"

      prefix = "client_name-"
      client_names = "#{prefix}#{name1},#{prefix}#{name2},#{prefix}#{name3}"

      conn = build_conn()

      resp =
        conn
        |> put_req_header("x-consumer-id", user_id1)
        |> get(app_path(conn, :index), %{
          "client_ids" => client_ids,
          "client_names" => client_names,
          "page_size" => "1",
          "page" => "2"
        })
        |> json_response(200)

      assert 1 == length(resp["data"])

      assert %{
               "page_number" => 2,
               "page_size" => 1,
               "total_entries" => 3,
               "total_pages" => 3
             } = resp["paging"]
    end
  end

  test "creates app and renders app when data is valid", %{conn: conn} do
    user = insert(:user)
    client = insert(:client)

    attrs = Map.merge(@create_attrs, %{user_id: user.id, client_id: client.id})

    resp =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> post(app_path(conn, :create), app: attrs)
      |> json_response(201)

    assert %{"id" => id} = resp["data"]

    resp =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> get(app_path(conn, :show, id))
      |> json_response(200)

    schema =
      "specs/json_schemas/app.json"
      |> File.read!()
      |> Poison.decode!()

    assert :ok = NExJsonSchema.Validator.validate(schema, resp)
  end

  test "does not create app and renders errors when data is invalid", %{conn: conn} do
    resp =
      conn
      |> put_req_header("x-consumer-id", UUID.generate())
      |> post(app_path(conn, :create), app: @invalid_attrs)
      |> json_response(422)

    assert resp["errors"] != %{}
  end

  test "updates chosen app and renders app when data is valid", %{conn: conn} do
    user = insert(:user)
    client = insert(:client)
    %App{id: id} = app = insert(:app, client_id: client.id, user_id: user.id)

    resp =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> put(app_path(conn, :update, app), app: @update_attrs)
      |> json_response(200)

    assert %{"id" => ^id} = resp["data"]

    resp =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> get(app_path(conn, :show, id))
      |> json_response(200)

    schema =
      "specs/json_schemas/app.json"
      |> File.read!()
      |> Poison.decode!()

    assert :ok = NExJsonSchema.Validator.validate(schema, resp)
  end

  test "does not update chosen app and renders errors when data is invalid", %{conn: conn} do
    app = insert(:app)

    resp =
      conn
      |> put_req_header("x-consumer-id", app.user_id)
      |> put(app_path(conn, :update, app), app: @invalid_attrs)
      |> json_response(422)

    assert resp["errors"] != %{}
  end

  test "deletes chosen app and expire dependent tokens", %{conn: conn} do
    app = insert(:app)
    %{value: token_value} = insert(:token)
    %{value: token_value_deleted} = insert(:token, user_id: app.user_id, details: %{client_id: app.client_id})

    conn
    |> put_req_header("x-consumer-id", app.user_id)
    |> delete(app_path(conn, :delete, app))
    |> response(204)

    assert_error_sent(404, fn ->
      conn
      |> put_req_header("x-consumer-id", app.user_id)
      |> get(app_path(conn, :show, app))
    end)

    conn
    |> get(token_verify_path(conn, :verify, token_value_deleted))
    |> json_response(401)

    conn
    |> get(token_verify_path(conn, :verify, token_value))
    |> json_response(200)
  end

  test "deletes apps and expire tokens by client_id", %{conn: conn} do
    user = insert(:user)

    # app 1
    %{id: app_id_1} = insert(:app, user_id: user.id)
    # app 2
    client_1 = insert(:client)
    insert(:app, user_id: user.id, client_id: client_1.id)
    %{value: token_value_deleted} = insert(:token, user_id: user.id, details: %{client_id: client_1.id})
    # app 3
    client_2 = insert(:client)
    %{id: app_id_2} = insert(:app, user_id: user.id, client_id: client_2.id)
    %{value: token_value} = insert(:token, user_id: user.id, details: %{client_id: client_2.id})

    conn
    |> delete(user_app_path(conn, :delete_by_user, user.id), client_id: client_1.id)
    |> response(204)

    data =
      conn
      |> put_req_header("x-consumer-id", user.id)
      |> get(app_path(conn, :index))
      |> json_response(200)
      |> Map.get("data")

    assert 2 == length(data)

    Enum.each(data, fn %{"id" => app_id} ->
      assert app_id in [app_id_1, app_id_2]
    end)

    conn
    |> get(token_verify_path(conn, :verify, token_value_deleted))
    |> json_response(401)

    conn
    |> get(token_verify_path(conn, :verify, token_value))
    |> json_response(200)
  end
end
