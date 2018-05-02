defmodule Mithril.Repo.Migrations.CreateGlobalUserRoles do
  use Ecto.Migration

  def change do
    create table(:global_user_roles, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:users, on_delete: :delete_all, type: :uuid))
      add(:role_id, references(:roles, on_delete: :delete_all, type: :uuid))

      timestamps()
    end

    create(unique_index(:global_user_roles, [:user_id, :role_id]))
  end
end
