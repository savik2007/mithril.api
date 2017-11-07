defmodule Mithril.Repo.Migrations.AddUniqueIndexes do
  use Ecto.Migration

  def change do
    create unique_index(:client_types, [:name])
    create unique_index(:roles, [:name])
  end
end
