defmodule Core.Repo.Migrations.AddTokenNameExpiresAtIndex do
  @moduledoc false

  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(index(:tokens, [:name, :user_id, :expires_at], concurrently: true))
  end
end
