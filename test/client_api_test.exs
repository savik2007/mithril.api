defmodule Mithril.ClientAPITest do
  use Mithril.DataCase

  alias Mithril.ClientAPI
  alias Mithril.ClientAPI.Client
  alias Scrivener.Page

  @broker ClientAPI.access_type(:broker)
  @direct ClientAPI.access_type(:direct)

  @update_attrs %{
    name: "some updated name",
    priv_settings: %{"access_type" => @broker},
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

  test "list_clients/1 returns all clients" do
    client = insert(:client)
    assert %Page{entries: [^client]} = ClientAPI.list_clients(%{})
  end

  test "get_client! returns the client with given id" do
    client = insert(:client)
    assert ClientAPI.get_client!(client.id) == client
  end

  test "create_client/1 with valid data creates a client" do
    attrs = :client |> build() |> Map.from_struct()
    assert {:ok, %Client{} = client} = ClientAPI.create_client(attrs)
    assert client.name == "some client"
    assert client.priv_settings == %{"access_type" => @direct}
    assert client.redirect_uri == "http://localhost"
    assert client.secret
    assert client.settings == %{}
  end

  test "create_client/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = ClientAPI.create_client(@invalid_attrs)
  end

  test "create_client/1 with no client_type_id provided returns error changeset" do
    {:error, %Ecto.Changeset{} = changeset} = ClientAPI.create_client(@invalid_attrs)

    assert Keyword.fetch!(changeset.errors, :client_type_id) == {"can't be blank", [validation: :required]}
  end

  test "update_client/2 with valid data updates the client" do
    client = insert(:client)
    assert {:ok, client} = ClientAPI.update_client(client, @update_attrs)
    assert %Client{} = client
    assert client.name == "some updated name"
    assert client.priv_settings == %{"access_type" => @broker}
    assert client.redirect_uri == "https://localhost"
    assert client.settings == %{}
  end

  test "update_client/2 with invalid data returns error changeset" do
    client = insert(:client)
    assert {:error, %Ecto.Changeset{}} = ClientAPI.update_client(client, @invalid_attrs)
    assert client == ClientAPI.get_client!(client.id)
  end

  test "delete_client/1 deletes the client" do
    client = insert(:client)
    assert {:ok, %Client{}} = ClientAPI.delete_client(client)
    assert_raise Ecto.NoResultsError, fn -> ClientAPI.get_client!(client.id) end
  end

  test "change_client/1 returns a client changeset" do
    client = insert(:client)
    assert %Ecto.Changeset{} = ClientAPI.change_client(client)
  end

  test "updating non-existent client results in creating a new client (idempotency)" do
    user = insert(:user)
    client_type = insert(:client_type)
    client_id = Ecto.UUID.generate()

    {:ok, client} =
      ClientAPI.edit_client(client_id, %{
        name: "some updated name",
        user_id: user.id,
        client_type_id: client_type.id,
        priv_settings: %{"access_type" => @broker},
        redirect_uri: "https://localhost",
        settings: %{}
      })

    assert client_id == client.id

    initial_secret = client.secret

    {:ok, client} =
      ClientAPI.edit_client(client_id, %{
        secret: "attempt to update secret"
      })

    # secret did not change
    assert initial_secret == client.secret
  end
end
