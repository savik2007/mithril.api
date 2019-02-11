defmodule Core.Repo.Migrations.CreateAuthenticationFactors do
  use Ecto.Migration

  def change do
    create table(:authentication_factors, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string, null: false)
      add(:factor, :string)
      add(:is_active, :boolean, default: true)

      add(:user_id, references(:users, on_delete: :delete_all, type: :uuid))

      timestamps()
    end

    create(unique_index(:authentication_factors, [:user_id, :type]))
  end
end
