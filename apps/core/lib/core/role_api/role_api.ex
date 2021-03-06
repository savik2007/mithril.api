defmodule Core.RoleAPI do
  @moduledoc """
  The boundary for the RoleAPI system.
  """
  import Core.Search
  import Ecto.{Query, Changeset}, warn: false
  alias Core.Repo

  alias Core.RoleAPI.Role
  alias Core.RoleAPI.RoleSearch

  @doc """
  Returns the list of roles.

  ## Examples

      iex> list_roles()
      [%Role{}, ...]

  """
  def list_roles(params \\ %{}) do
    %RoleSearch{}
    |> role_changeset(params)
    |> search(params, Role)
  end

  @doc """
  Gets a single role.

  Raises `Ecto.NoResultsError` if the Role does not exist.

  ## Examples

      iex> get_role!(123)
      %Role{}

      iex> get_role!(456)
      ** (Ecto.NoResultsError)

  """
  def get_role!(id), do: Repo.get!(Role, id)

  @doc """
  Creates a role.

  ## Examples

      iex> create_role(%{field: value})
      {:ok, %Role{}}

      iex> create_role(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> role_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role.

  ## Examples

      iex> update_role(role, %{field: new_value})
      {:ok, %Role{}}

      iex> update_role(role, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_role(%Role{} = role, attrs) do
    role
    |> role_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Role.

  ## Examples

      iex> delete_role(role)
      {:ok, %Role{}}

      iex> delete_role(role)
      {:error, %Ecto.Changeset{}}

  """
  def delete_role(%Role{} = role) do
    Repo.delete(role)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking role changes.

  ## Examples

      iex> change_role(role)
      %Ecto.Changeset{source: %Role{}}

  """
  def change_role(%Role{} = role) do
    role_changeset(role, %{})
  end

  defp role_changeset(%Role{} = role, attrs) do
    role
    |> cast(attrs, [:name, :scope])
    |> validate_required([:name, :scope])
    |> unique_constraint(:name)
  end

  defp role_changeset(%RoleSearch{} = role, attrs) do
    role
    |> cast(attrs, [:name, :scope])
    |> put_search_change()
  end

  defp put_search_change(%Ecto.Changeset{valid?: true, changes: %{scope: scopes}} = changeset) do
    put_change(changeset, :scope, {String.split(scopes, ","), :intersect})
  end

  defp put_search_change(changeset), do: changeset
end
