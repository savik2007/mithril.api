defmodule Mithril.Repo.Migrations.AddUniqueUserTaxId do
  use Ecto.Migration

  def change do
    create(unique_index(:users, [:tax_id]))
  end
end
