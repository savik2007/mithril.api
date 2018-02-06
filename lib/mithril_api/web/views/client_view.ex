defmodule Mithril.Web.ClientView do
  use Mithril.Web, :view

  @fields ~w(
    id
    name
    secret
    redirect_uri
    settings
    priv_settings
    is_blocked
    block_reason
    user_id
    client_type_id
    inserted_at
    updated_at
  )a

  def render("index.json", %{clients: clients}) do
    render_many(clients, __MODULE__, "client.json")
  end

  def render("show.json", %{client: client}) do
    render_one(client, __MODULE__, "client.json")
  end

  def render("client.json", %{client: client, client_type_name: client_type_name}) do
    client
    |> Map.take(@fields)
    |> Map.put(:client_type_name, client_type_name)
  end

  def render("client.json", %{client: client}) do
    Map.take(client, @fields)
  end

  def render("details.json", %{client: client, client_type_name: client_type_name}) do
    client
    |> Map.take(Enum.reject(@fields, fn x -> x in ~w(secret priv_settings)a end))
    |> Map.put(:client_type_name, client_type_name)
  end
end
