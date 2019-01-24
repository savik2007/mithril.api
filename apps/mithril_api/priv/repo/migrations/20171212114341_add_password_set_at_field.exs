defmodule Mithril.Repo.Migrations.AddPasswordSetAtField do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:password_set_at, :naive_datetime, null: false, default: fragment("now()"))
    end
  end
end
