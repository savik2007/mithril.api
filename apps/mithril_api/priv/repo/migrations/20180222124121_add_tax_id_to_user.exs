defmodule Mithril.Repo.Migrations.AddTaxIdToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:tax_id, :string, null: false, default: "")
    end
  end
end
