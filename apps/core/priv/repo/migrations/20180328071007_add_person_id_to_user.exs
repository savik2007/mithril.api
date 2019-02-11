defmodule Core.Repo.Migrations.AddPersonIdToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:person_id, :string, null: false, default: "")
    end
  end
end
