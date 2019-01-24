defmodule Mithril.Repo.Migrations.AddTokensExpIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    execute("
    CREATE INDEX CONCURRENTLY IF NOT EXISTS tokens_expires_at_name_index ON tokens (expires_at, name);
    ")
  end

  def down do
    execute("
    DROP INDEX CONCURRENTLY IF EXISTS tokens_expires_at_name_index;
    ")
  end
end
