defmodule Core.Repo.Migrations.AddPasswordsHistory do
  use Ecto.Migration

  def change do
    create table(:password_hstr) do
      add(:user_id, :uuid, null: false)
      add(:password, :string, null: false)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create(index(:password_hstr, [:user_id]))
  end
end
