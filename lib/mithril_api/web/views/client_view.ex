defmodule Mithril.Web.ClientView do
  use Mithril.Web, :view

  def render("index.json", %{clients: clients}) do
    render_many(clients, __MODULE__, "client.json")
  end

  def render("show.json", %{client: client}) do
    render_one(client, __MODULE__, "client.json")
  end

  def render("client.json", %{client: client}) do
    Map.take(client, ~w(id name secret is_blocked block_reason redirect_uri settings priv_settings)a)
  end

  def render("details.json", %{client: client, client_type_name: client_type_name}) do
    client
    |> Map.take(~w(id name redirect_uri settings is_blocked block_reason)a)
    |> Map.put(:client_type_name, client_type_name)
  end
end
