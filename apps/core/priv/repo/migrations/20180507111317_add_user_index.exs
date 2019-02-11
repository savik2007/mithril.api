defmodule Core.Repo.Migrations.AddUserIndex do
  @moduledoc false

  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(index(:users, [:password_set_at], concurrently: true))
  end
end
