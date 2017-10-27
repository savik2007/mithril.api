defmodule Mithril.Repo.Migrations.AddBlockFieldsToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add :is_blocked, :boolean, null: false, default: false
      add :block_reason, :string
    end
  end
end
