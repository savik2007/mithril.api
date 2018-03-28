defmodule Mithril.UserRoleAPI do
  @moduledoc """
  The boundary for the UserRoleAPI system.
  """
  use Mithril.Search

  import Ecto.{Query, Changeset}, warn: false

  alias Mithril.Repo
  alias Mithril.RoleAPI.Role
  alias Mithril.UserRoleAPI.UserRole
  alias Mithril.UserRoleAPI.UserRoleSearch

  def list_user_roles(params \\ %{}) do
    search_user_roles(user_role_changeset(%UserRoleSearch{}, params))
  end

  defp search_user_roles(%Ecto.Changeset{valid?: false} = changeset), do: {:error, changeset}

  defp search_user_roles(%Ecto.Changeset{valid?: true} = changeset) do
    UserRole
    |> query_where(changeset.changes)
    |> join(:left, [ur], r in assoc(ur, :role))
    |> join(:left, [ur, r], c in assoc(ur, :client))
    |> preload([ur, r, c], role: r, client: c)
    |> Repo.all()
  end

  def query_where(entity, changes) do
    params = Enum.filter(changes, fn {_key, value} -> !is_tuple(value) end)
    q = where(entity, ^params)

    Enum.reduce(changes, q, fn {_key, val}, query ->
      case val do
        # ToDo: hardcoded db_field :user_id. It's not good
        {value, :in} ->
          where(query, [r], field(r, :user_id) in ^value)

        _ ->
          query
      end
    end)
  end

  # get_by
  def get_user_role!(id), do: Repo.get!(UserRole, id)

  def create_user_role(attrs \\ %{}) do
    %UserRole{}
    |> user_role_changeset(attrs)
    |> Repo.insert()
    |> preload_role()
  end

  def preload_role({:ok, %UserRole{} = role}), do: {:ok, Repo.preload(role, :role)}
  def preload_role(err), do: err

  def delete_user_role(%UserRole{} = user_role) do
    Repo.delete(user_role)
  end

  def delete_user_roles_by_params(%{"user_id" => user_id, "role_name" => role_name}) do
    query =
      from(
        u in UserRole,
        inner_join: r in Role,
        on: [id: u.role_id],
        where: u.user_id == ^user_id,
        where: r.name == ^role_name
      )

    Repo.delete_all(query)
  end

  def delete_user_roles_by_params(params) do
    %UserRoleSearch{}
    |> user_role_changeset(params)
    |> case do
      %Ecto.Changeset{valid?: true, changes: changes} ->
        changes = Map.to_list(changes)
        UserRole |> where([ur], ^changes) |> Repo.delete_all()

      changeset ->
        changeset
    end
  end

  defp user_role_changeset(%UserRole{} = user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :client_id])
    |> validate_required([:user_id, :role_id, :client_id])
    |> unique_constraint(:user_roles, name: :user_roles_user_id_role_id_client_id_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:client_id)
  end

  defp user_role_changeset(%UserRoleSearch{} = user_role, attrs) do
    cast(user_role, attrs, UserRoleSearch.__schema__(:fields))
  end

  def convert_comma_params_to_where_in_clause(changes, param_name, db_field) do
    changes
    |> Map.put(db_field, {String.split(changes[param_name], ","), :in})
    |> Map.delete(param_name)
  end
end
