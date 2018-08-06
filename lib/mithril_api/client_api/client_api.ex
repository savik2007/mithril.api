defmodule Mithril.ClientAPI do
  @moduledoc false
  import Mithril.Search

  import Ecto.{Query, Changeset}, warn: false

  alias Mithril.ClientAPI.Client
  alias Mithril.ClientAPI.ClientSearch
  alias Mithril.Repo

  @access_type_direct "DIRECT"
  @access_type_broker "BROKER"

  @fields_required ~w(
    name
    user_id
    redirect_uri
    settings
    priv_settings
    client_type_id
  )a

  @fields_optional ~w(
    is_blocked
    block_reason
  )a

  def access_type(:direct), do: @access_type_direct
  def access_type(:broker), do: @access_type_broker

  def list_clients(params) do
    %ClientSearch{}
    |> client_changeset(params)
    |> search(params, Client)
  end

  def get_client!(id), do: Repo.get!(Client, id)
  def get_client(id), do: Repo.get(Client, id)

  def get_client_with_type(id),
    do:
      id
      |> query_client_with_type()
      |> Repo.one()

  def get_client_with_type!(id),
    do:
      id
      |> query_client_with_type()
      |> Repo.one!()

  defp query_client_with_type(id) do
    from(
      c in Client,
      left_join: ct in assoc(c, :client_type),
      on: ct.id == c.client_type_id,
      where: c.id == ^id,
      preload: [
        client_type: ct
      ]
    )
  end

  def get_client_by(attrs), do: Repo.get_by(Client, attrs)

  def edit_client(id, attrs \\ %{}) do
    case Repo.get(Client, id) do
      nil -> create_client(id, attrs)
      %Client{} = client -> update_client(client, attrs)
    end
  end

  def create_client do
    %Client{}
    |> client_changeset(%{})
    |> create_client()
  end

  def create_client(id, attrs) do
    %Client{id: id}
    |> client_changeset(attrs)
    |> create_client()
  end

  def create_client(%Ecto.Changeset{} = changeset) do
    Repo.insert(changeset)
  end

  def create_client(attrs) when is_map(attrs) do
    %Client{}
    |> client_changeset(attrs)
    |> create_client()
  end

  def update_client(%Client{} = client, attrs) do
    client
    |> client_changeset(attrs)
    |> Repo.update()
  end

  def delete_client(%Client{} = client) do
    Repo.delete(client)
  end

  def change_client(%Client{} = client) do
    client_changeset(client, %{})
  end

  def refresh_secret(%Client{} = client) do
    client
    |> change(%{secret: SecureRandom.urlsafe_base64()})
    |> Repo.update()
  end

  defp client_changeset(%ClientSearch{} = client, attrs) do
    cast(client, attrs, ClientSearch.__schema__(:fields))
  end

  defp client_changeset(%Client{} = client, attrs) do
    client
    |> cast(attrs, @fields_required ++ @fields_optional)
    |> put_secret()
    |> validate_required(@fields_required)
    |> validate_format(:redirect_uri, ~r{^https?://.+})
    |> validate_priv_settings()
    |> unique_constraint(:name)
    |> assoc_constraint(:user)
    |> assoc_constraint(:client_type)
  end

  defp validate_priv_settings(changeset) do
    validate_change(changeset, :priv_settings, fn :priv_settings, priv_settings ->
      case Map.get(priv_settings, "access_type") do
        nil -> [priv_settings: "access_type required."]
        @access_type_direct -> []
        @access_type_broker -> []
        _ -> [priv_settings: "access_type is invalid."]
      end
    end)
  end

  defp put_secret(changeset) do
    case fetch_field(changeset, :secret) do
      {:data, nil} ->
        put_change(changeset, :secret, SecureRandom.urlsafe_base64())

      _ ->
        changeset
    end
  end
end
