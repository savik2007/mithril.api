defmodule Mithril.Web.ConnectionView do
  use Mithril.Web, :view

  @fields ~w(id redirect_uri client_id consumer_id)a

  def render("index.json", %{connections: connections}) do
    render_many(connections, __MODULE__, "connection.json")
  end

  def render("show.json", %{connection: connection}) do
    render_one(connection, __MODULE__, "connection.json")
  end

  def render("connection.json", %{connection: connection}) do
    Map.take(connection, @fields)
  end

  def render("connection_with_secret.json", %{connection: connection}) do
    Map.take(connection, @fields ++ [:secret])
  end
end
