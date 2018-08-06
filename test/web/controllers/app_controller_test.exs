defmodule Mithril.Web.AppControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.AppAPI.App

  @create_attrs %{scope: "some scope"}
  @update_attrs %{scope: "some updated scope"}
  @invalid_attrs %{scope: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "list all apps" do
    test "lists all entries on index", %{conn: conn} do
      client = insert(:client)
      insert(:app, client_id: client.id)
      insert(:app, client_id: client.id)
      insert(:app, client_id: client.id)
      resp = conn |> get(app_path(conn, :index)) |> json_response(200)
      assert 3 == length(resp["data"])

      schema =
        "specs/json_schemas/apps.json"
        |> File.read!()
        |> Poison.decode!()

      assert :ok = NExJsonSchema.Validator.validate(schema, resp)
    end

    test "does not list all entries on index when limit is set", %{conn: conn} do
      insert(:app)
      insert(:app)
      insert(:app)
      conn = get(conn, app_path(conn, :index), %{page_size: 2})
      assert 2 == length(json_response(conn, 200)["data"])
    end

    test "does not list all entries on index when starting_after is set", %{conn: conn} do
      insert(:app)
      insert(:app)
      app = insert(:app)
      conn = get(conn, app_path(conn, :index), %{page_size: 2, page: 2})
      resp = json_response(conn, 200)["data"]
      assert 1 == length(resp)
      assert app.id == Map.get(hd(resp), "id")
    end

    test "list apps by client_names" do
      %{name: name1, id: client_id1} = insert(:client)
      %{name: name2, id: client_id2} = insert(:client)
      %{id: client_id3} = insert(:client)
      insert(:app, client_id: client_id1)
      insert(:app, client_id: client_id2)
      insert(:app, client_id: client_id3)

      prefix = "client_name-"
      client_names = "#{prefix}#{name1},#{prefix}#{name2}"
      conn = build_conn()
      resp = get(conn, app_path(conn, :index), %{"client_names" => client_names})
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
      %{id: client_id1} = insert(:client, name: name1)
      %{id: client_id2} = insert(:client, name: name2)
      %{id: client_id3} = insert(:client, name: name3)
      insert(:app, client_id: client_id1)
      insert(:app, client_id: client_id2)
      insert(:app, client_id: client_id3)

      name1 = String.slice(name1, 0, 6)
      name2 = String.slice(name2, 0, 6)
      name3 = String.slice(name3, 3, 6)
      prefix = "client_name-"
      client_names = "#{prefix}#{name1},#{prefix}#{name2},#{prefix}#{name3}"
      conn = build_conn()
      resp = get(conn, app_path(conn, :index), %{"client_names" => client_names})
      data = json_response(resp, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"client_id" => client_id} ->
        assert client_id in [client_id1, client_id2]
      end)
    end

    test "list apps by client_ids" do
      %{id: client_id1} = insert(:client)
      %{id: client_id2} = insert(:client)
      %{id: client_id3} = insert(:client)
      insert(:app, client_id: client_id1)
      insert(:app, client_id: client_id2)
      insert(:app, client_id: client_id3)

      prefix = "client-"
      client_ids = "#{prefix}#{client_id1},#{prefix}#{client_id2}"
      conn = build_conn()
      resp = get(conn, app_path(conn, :index), %{"client_ids" => client_ids})
      data = json_response(resp, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"client_id" => client_id} ->
        assert client_id in [client_id1, client_id2]
      end)
    end

    test "list apps by user_ids" do
      %{id: user_id1} = insert(:user)
      %{id: user_id2} = insert(:user)
      %{id: user_id3} = insert(:user)
      insert(:app, user_id: user_id1)
      insert(:app, user_id: user_id2)
      insert(:app, user_id: user_id3)

      prefix = "user-"
      user_ids = "#{prefix}#{user_id1},#{prefix}#{user_id2}"
      conn = build_conn()
      resp = get(conn, app_path(conn, :index), %{"user_ids" => user_ids})
      data = json_response(resp, 200)["data"]
      assert 2 == length(data)

      Enum.each(data, fn %{"user_id" => user_id} ->
        assert user_id in [user_id1, user_id2]
      end)
    end

    test "list apps by combined params" do
      %{id: user_id1} = insert(:user)
      %{id: user_id2} = insert(:user)
      %{id: client_id1} = insert(:client)
      %{id: client_id2} = insert(:client)
      %{id: client_id3, name: name} = insert(:client)

      insert(:app, user_id: user_id1)
      insert(:app, user_id: user_id2)
      insert(:app, client_id: client_id1)
      insert(:app, client_id: client_id2)
      insert(:app, client_id: client_id3)

      prefix = "user-"
      user_ids = "#{prefix}#{user_id1},#{prefix}#{user_id2}"

      prefix = "client-"
      client_ids = "#{prefix}#{client_id1},#{prefix}#{client_id2}"

      prefix = "client_name-"
      client_names = "#{prefix}#{name}"

      conn = build_conn()

      resp =
        conn
        |> get(app_path(conn, :index), %{
          "user_ids" => user_ids,
          "client_ids" => client_ids,
          "client_names" => client_names,
          "page_size" => "3",
          "page" => "2"
        })
        |> json_response(200)

      assert 2 == length(resp["data"])

      assert %{
               "page_number" => 2,
               "page_size" => 3,
               "total_entries" => 5,
               "total_pages" => 2
             } = resp["paging"]
    end
  end

  test "creates app and renders app when data is valid", %{conn: conn} do
    user = insert(:user)
    client = insert(:client)

    attrs = Map.merge(@create_attrs, %{user_id: user.id, client_id: client.id})
    conn = post(conn, app_path(conn, :create), app: attrs)
    assert %{"id" => id} = json_response(conn, 201)["data"]

    resp = conn |> get(app_path(conn, :show, id)) |> json_response(200)

    schema =
      "specs/json_schemas/app.json"
      |> File.read!()
      |> Poison.decode!()

    assert :ok = NExJsonSchema.Validator.validate(schema, resp)
  end

  test "does not create app and renders errors when data is invalid", %{conn: conn} do
    conn = post(conn, app_path(conn, :create), app: @invalid_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates chosen app and renders app when data is valid", %{conn: conn} do
    client = insert(:client)
    %App{id: id} = app = insert(:app, client_id: client.id)
    conn = put(conn, app_path(conn, :update, app), app: @update_attrs)
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    resp = conn |> get(app_path(conn, :show, id)) |> json_response(200)

    schema =
      "specs/json_schemas/app.json"
      |> File.read!()
      |> Poison.decode!()

    assert :ok = NExJsonSchema.Validator.validate(schema, resp)
  end

  test "does not update chosen app and renders errors when data is invalid", %{conn: conn} do
    app = insert(:app)
    conn = put(conn, app_path(conn, :update, app), app: @invalid_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen app and expire dependent tokens", %{conn: conn} do
    app = insert(:app)
    %{value: token_value} = insert(:token)
    %{value: token_value_deleted} = insert(:token, user_id: app.user_id, details: %{client_id: app.client_id})

    conn
    |> delete(app_path(conn, :delete, app))
    |> response(204)

    assert_error_sent(404, fn ->
      get(conn, app_path(conn, :show, app))
    end)

    conn
    |> get(token_verify_path(conn, :verify, token_value_deleted))
    |> json_response(401)

    conn
    |> get(token_verify_path(conn, :verify, token_value))
    |> json_response(200)
  end

  test "deletes apps and expire tokens by client_id", %{conn: conn} do
    # app 1
    %{id: app_id_1} = insert(:app)
    # app 2
    user = insert(:user)
    client_1 = insert(:client)
    insert(:app, user_id: user.id, client_id: client_1.id)
    %{value: token_value_deleted} = insert(:token, user_id: user.id, details: %{client_id: client_1.id})
    # app 3
    client_2 = insert(:client)
    %{id: app_id_2} = insert(:app, user_id: user.id, client_id: client_2.id)
    %{value: token_value} = insert(:token, user_id: user.id, details: %{client_id: client_2.id})

    conn = delete(conn, user_app_path(conn, :delete_by_user, user.id), client_id: client_1.id)
    assert response(conn, 204)

    data =
      conn
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
