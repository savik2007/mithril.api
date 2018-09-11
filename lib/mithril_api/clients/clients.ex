defmodule Mithril.Clients do
  @moduledoc false

  import Mithril.Search
  import Ecto.{Query, Changeset}, warn: false

  alias Ecto.UUID
  alias Mithril.Clients.Client
  alias Mithril.Clients.ClientSearch
  alias Mithril.Clients.Connection
  alias Mithril.Clients.ConnectionSearch
  alias Mithril.Repo

  def list_clients(params) do
    %ClientSearch{}
    |> ClientSearch.changeset(params)
    |> search(params, Client)
  end

  def get_client!(id), do: Repo.get!(Client, id)
  def get_client(id), do: Repo.get(Client, id)

  def get_client_with(id, preload \\ []) when is_list(preload) do
    Client
    |> where([c], c.id == ^id)
    |> join_with(preload)
    |> Repo.one()
  end

  def get_client_with!(id, preload \\ []) when is_list(preload) do
    Client
    |> where([c], c.id == ^id)
    |> join_with(preload)
    |> Repo.one!()
  end

  defp join_with(query, []), do: query

  defp join_with(query, [entity | tail]) do
    query
    |> join_with(entity)
    |> join_with(tail)
  end

  defp join_with(query, entity) when entity in [:connections, :client_type] do
    query
    |> join(:left, [c, ...], j in assoc(c, ^entity))
    |> preload([..., j], [{^entity, j}])
  end

  def get_client_by(attrs), do: Repo.get_by(Client, attrs)

  def upsert_client(id, attrs \\ %{}) do
    case Repo.get(Client, id) do
      nil -> create_client(id, attrs)
      %Client{} = client -> update_client(client, attrs)
    end
  end

  def create_client(id, attrs) do
    %Client{id: id}
    |> Client.changeset(attrs)
    |> create_client()
  end

  def create_client(%Ecto.Changeset{} = changeset) do
    Repo.insert(changeset)
  end

  def create_client(attrs) when is_map(attrs) do
    %Client{}
    |> Client.changeset(attrs)
    |> create_client()
  end

  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
  end

  def delete_client(%Client{} = client) do
    Repo.delete(client)
  end

  # connections

  def list_connections(params) do
    %ConnectionSearch{}
    |> ConnectionSearch.changeset(params)
    |> search(params, Connection)
  end

  def get_connection!(id), do: Repo.get!(Connection, id)

  def get_connection_by(attrs), do: Repo.get_by(Connection, attrs)
  def get_connection_by!(attrs), do: Repo.get_by!(Connection, attrs)

  def get_connection_with_client_by(attrs) do
    Connection
    |> where([c], ^attrs)
    |> join(:inner, [c], cl in assoc(c, :client))
    |> preload([_, cl], client: cl)
    |> Repo.one()
  end

  def upsert_connection(client_id, consumer_id, attrs) do
    with {:ok, _} <- UUID.cast(client_id),
         {:ok, _} <- UUID.cast(consumer_id),
         %Client{} = client <- get_client(client_id) do
      case get_connection_by(%{consumer_id: consumer_id, client_id: client.id}) do
        nil -> attrs |> create_connection() |> Tuple.append(:created)
        %Connection{} = connection -> connection |> update_connection(attrs) |> Tuple.append(:ok)
      end
    else
      _ -> {:error, :not_found}
    end
  end

  def create_connection(attrs) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end

  def update_connection(%Connection{} = connection, attrs) do
    connection
    |> Connection.changeset(attrs)
    |> Repo.update()
  end

  def refresh_connection_secret(%Connection{} = connection) do
    connection
    |> change(%{secret: SecureRandom.urlsafe_base64()})
    |> Repo.update()
  end

  def delete_connection(%Connection{} = connection) do
    Repo.delete(connection)
  end
end
