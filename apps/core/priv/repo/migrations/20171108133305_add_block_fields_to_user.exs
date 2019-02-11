defmodule Core.Repo.Migrations.AddBlockFieldsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:is_blocked, :boolean, null: false, default: false)
      add(:block_reason, :string)
    end
  end
end
