defmodule Mithril.ConnectionControllerTest do
  use Mithril.Web.ConnCase

  alias Mithril.Connection
  @valid_attrs %{redirect_uri: "some redirect_uri", secret: "some secret"}
  @invalid_attrs %{}

  setup %{conn: conn} do
    client = insert(:client)
    consumer = insert(:client)
    {:ok, conn: conn, client: client, consumer: consumer}
  end

  describe "list" do
    test "lists all entries on index", %{conn: conn, client: client, consumer: consumer} do
      insert_pair(:connection, client: client, consumer: consumer)

      data =
        conn
        |> get(client_connection_path(conn, :index))
        |> json_response(conn, 200)
        |> Map.get("data")

      assert 2 == length(data)
    end
  end

  #
  #  test "shows chosen resource", %{conn: conn} do
  #    connection = Repo.insert!(%Connection{})
  #    conn = get(conn, client_connection_path(conn, :show, connection))
  #
  #    assert json_response(conn, 200)["data"] == %{
  #             "id" => connection.id,
  #             "redirect_uri" => connection.redirect_uri,
  #             "secret" => connection.secret,
  #             "client_id" => connection.client_id,
  #             "consumer_id" => connection.consumer_id
  #           }
  #  end
  #
  #  test "renders page not found when id is nonexistent", %{conn: conn} do
  #    assert_error_sent(404, fn ->
  #      get(conn, client_connection_path(conn, :show, "11111111-1111-1111-1111-111111111111"))
  #    end)
  #  end
  #
  #  test "creates and renders resource when data is valid", %{conn: conn} do
  #    conn = post(conn, client_connection_path(conn, :create), connection: @valid_attrs)
  #    assert json_response(conn, 201)["data"]["id"]
  #    assert Repo.get_by(Connection, @valid_attrs)
  #  end
  #
  #  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
  #    conn = post(conn, client_connection_path(conn, :create), connection: @invalid_attrs)
  #    assert json_response(conn, 422)["errors"] != %{}
  #  end
  #
  #  test "updates and renders chosen resource when data is valid", %{conn: conn} do
  #    connection = Repo.insert!(%Connection{})
  #    conn = put(conn, client_connection_path(conn, :update, connection), connection: @valid_attrs)
  #    assert json_response(conn, 200)["data"]["id"]
  #    assert Repo.get_by(Connection, @valid_attrs)
  #  end
  #
  #  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
  #    connection = Repo.insert!(%Connection{})
  #    conn = put(conn, client_connection_path(conn, :update, connection), connection: @invalid_attrs)
  #    assert json_response(conn, 422)["errors"] != %{}
  #  end
  #
  #  test "deletes chosen resource", %{conn: conn} do
  #    connection = Repo.insert!(%Connection{})
  #    conn = delete(conn, client_connection_path(conn, :delete, connection))
  #    assert response(conn, 204)
  #    refute Repo.get(Connection, connection.id)
  #  end
end
