defmodule Core.GlobalUserRoleAPI do
  @moduledoc false

  import Ecto.{Query, Changeset}, warn: false

  alias Core.GlobalUserRoleAPI.GlobalUserRole
  alias Core.Repo

  @required ~w(user_id role_id)a

  def get_global_user_role!(id), do: GlobalUserRole |> Repo.get!(id) |> preload_role()

  def create_global_user_role(attrs \\ %{}) do
    %GlobalUserRole{}
    |> user_role_changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
    |> preload_role()
  end

  def preload_role({:ok, %GlobalUserRole{} = role}), do: {:ok, preload_role(role)}
  def preload_role(%GlobalUserRole{} = role), do: Repo.preload(role, :role)
  def preload_role(err), do: err

  defp user_role_changeset(%GlobalUserRole{} = global_user_role, attrs) do
    global_user_role
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> unique_constraint(:user_roles, name: :global_user_roles_user_id_role_id_index)
    |> foreign_key_constraint(:user_id)
  end
end
