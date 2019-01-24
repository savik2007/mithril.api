defmodule Mithril.ClientTypeAPI do
  @moduledoc """
  The boundary for the ClientTypeAPI system.
  """
  import Mithril.Search

  import Ecto.{Query, Changeset}, warn: false
  alias Mithril.Repo

  alias Mithril.Clients.ClientTypeSearch
  alias Mithril.ClientTypeAPI.ClientType

  @doc """
  Returns the list of client_types.

  ## Examples

      iex> list_client_types()
      [%ClientType{}, ...]

  """
  def list_client_types(params \\ %{}) do
    %ClientTypeSearch{}
    |> client_type_changeset(params)
    |> search(params, ClientType)
  end

  @doc """
  Gets a single client_type.

  Raises `Ecto.NoResultsError` if the Client type does not exist.

  ## Examples

      iex> get_client_type!(123)
      %ClientType{}

      iex> get_client_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_client_type!(id), do: Repo.get!(ClientType, id)

  def get_client_type_by(attrs), do: Repo.get_by(ClientType, attrs)

  @doc """
  Creates a client_type.

  ## Examples

      iex> create_client_type(%{field: value})
      {:ok, %ClientType{}}

      iex> create_client_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_client_type(attrs \\ %{}) do
    %ClientType{}
    |> client_type_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a client_type.

  ## Examples

      iex> update_client_type(client_type, %{field: new_value})
      {:ok, %ClientType{}}

      iex> update_client_type(client_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_client_type(%ClientType{} = client_type, attrs) do
    client_type
    |> client_type_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ClientType.

  ## Examples

      iex> delete_client_type(client_type)
      {:ok, %ClientType{}}

      iex> delete_client_type(client_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_client_type(%ClientType{} = client_type) do
    Repo.delete(client_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking client_type changes.

  ## Examples

      iex> change_client_type(client_type)
      %Ecto.Changeset{source: %ClientType{}}

  """
  def change_client_type(%ClientType{} = client_type) do
    client_type_changeset(client_type, %{})
  end

  defp client_type_changeset(%ClientType{} = client_type, attrs) do
    client_type
    |> cast(attrs, [:name, :scope])
    |> validate_required([:name, :scope])
    |> unique_constraint(:name)
  end

  defp client_type_changeset(%ClientTypeSearch{} = client_type, attrs) do
    fields = ~W(
      name
      scope
    )

    client_type
    |> cast(attrs, fields)
    |> put_search_change()
  end

  defp put_search_change(%Ecto.Changeset{valid?: true, changes: %{scope: scopes}} = changeset) do
    put_change(changeset, :scope, {String.split(scopes, ","), :intersect})
  end

  defp put_search_change(changeset), do: changeset
end
