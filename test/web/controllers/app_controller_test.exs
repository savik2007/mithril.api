defmodule Mithril.Web.AppControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.AppAPI
  alias Mithril.AppAPI.App

  @create_attrs %{scope: "some scope"}
  @update_attrs %{scope: "some updated scope"}
  @invalid_attrs %{scope: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "list all apps" do
    test "lists all entries on index", %{conn: conn} do
      insert(:app)
      insert(:app)
      insert(:app)
      conn = get(conn, app_path(conn, :index))
      assert 3 == length(json_response(conn, 200)["data"])
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

    test "invalid client_id", %{conn: conn} do
      assert [err] =
               conn
               |> get(app_path(conn, :index), %{client_id: "asd"})
               |> json_response(422)
               |> get_in(~w(error invalid))

      assert "$.client_id" == err["entry"]
    end
  end

  test "creates app and renders app when data is valid", %{conn: conn} do
    user = Mithril.Fixtures.create_user()
    client = Mithril.Fixtures.create_client()

    attrs = Map.merge(@create_attrs, %{user_id: user.id, client_id: client.id})
    conn = post(conn, app_path(conn, :create), app: attrs)
    assert %{"id" => id} = json_response(conn, 201)["data"]

    conn = get(conn, app_path(conn, :show, id))

    assert json_response(conn, 200)["data"] == %{
             "id" => id,
             "scope" => "some scope",
             "user_id" => user.id,
             "client_id" => client.id
           }
  end

  test "does not create app and renders errors when data is invalid", %{conn: conn} do
    conn = post(conn, app_path(conn, :create), app: @invalid_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates chosen app and renders app when data is valid", %{conn: conn} do
    %App{id: id} = app = insert(:app)
    conn = put(conn, app_path(conn, :update, app), app: @update_attrs)
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get(conn, app_path(conn, :show, id))

    assert json_response(conn, 200)["data"] == %{
             "id" => id,
             "scope" => "some updated scope",
             "user_id" => app.user_id,
             "client_id" => app.client_id
           }
  end

  test "does not update chosen app and renders errors when data is invalid", %{conn: conn} do
    app = insert(:app)
    conn = put(conn, app_path(conn, :update, app), app: @invalid_attrs)
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen app", %{conn: conn} do
    app = insert(:app)
    conn = delete(conn, app_path(conn, :delete, app))
    assert response(conn, 204)

    assert_error_sent(404, fn ->
      get(conn, app_path(conn, :show, app))
    end)
  end

  test "deletes apps by client_id", %{conn: conn} do
    # app 1
    %{id: id_1} = insert(:app)
    # app 2
    user = Mithril.Fixtures.create_user()
    client_1 = Mithril.Fixtures.create_client()
    attrs = Map.merge(@create_attrs, %{user_id: user.id, client_id: client_1.id})
    {:ok, _} = AppAPI.create_app(attrs)
    # app 3
    client_2 = Mithril.Fixtures.create_client()
    attrs = Map.merge(@create_attrs, %{user_id: user.id, client_id: client_2.id})
    {:ok, %{id: id_2}} = AppAPI.create_app(attrs)

    conn = delete(conn, user_app_path(conn, :delete_by_user, user.id), client_id: client_1.id)
    assert response(conn, 204)

    conn = get(conn, app_path(conn, :index))
    data = json_response(conn, 200)["data"]
    assert 2 == length(data)

    Enum.each(data, fn %{"id" => app_id} ->
      assert app_id in [id_1, id_2]
    end)
  end
end
