defmodule Mithril.Web.ConnectionController do
  use Mithril.Web, :controller

  alias Mithril.ClientAPI
  alias Mithril.ClientAPI.Connection
  alias Scrivener.Page

  action_fallback(Mithril.Web.FallbackController)

  def index(conn, %{"client_id" => client_id} = params) do
    params = Map.put(params, "client_id", client_id)

    with %Page{} = paging <- ClientAPI.list_connections(params) do
      render(conn, "index.json", connections: paging.entries, paging: paging)
    end
  end

  def upsert(conn, %{"client_id" => client_id} = attrs) do
    consumer_id = Map.get(attrs, "consumer_id", nil)
    with {:ok, %Connection{} = connection, code} <- ClientAPI.upsert_connection(client_id, consumer_id, attrs) do
      conn
      |> put_status(code)
      |> put_resp_header("location", client_connection_path(conn, :show, client_id, connection))
      |> render("show.json", connection: connection)
    end
  end

  def update(conn, %{"client_id" => client_id, "id" => id} = attrs) do
    connection = ClientAPI.get_connection_by!(%{id: id, client_id: client_id})

    with {:ok, %Connection{}} <- ClientAPI.update_connection(connection, attrs) do
      render(conn, "show.json", connection: connection)
    end
  end

  def refresh_secret(conn, %{"client_id" => client_id, "id" => id}) do
    connection = ClientAPI.get_connection_by!(%{client_id: client_id, id: id})

    with {:ok, %Connection{} = connection} <- ClientAPI.refresh_connection_secret(connection) do
      render(conn, "connection_with_secret.json", connection: connection)
    end
  end

  def show(conn, %{"client_id" => client_id, "id" => id}) do
    connection = ClientAPI.get_connection_by!(%{id: id, client_id: client_id})
    render(conn, "connection.json", connection: connection)
  end

  def delete(conn, %{"client_id" => client_id, "id" => id}) do
    connection = ClientAPI.get_connection_by!(%{id: id, client_id: client_id})

    with {:ok, %Connection{}} <- ClientAPI.delete_connection(connection) do
      send_resp(conn, :no_content, "")
    end
  end
end
