defmodule Mithril.Repo.Migrations.AddUpdateTokensUsersIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    execute("
    CREATE INDEX CONCURRENTLY IF NOT EXISTS tokens_user_id_expires_at_index ON tokens (user_id, expires_at);
    ")
    execute("
    CREATE INDEX CONCURRENTLY IF NOT EXISTS users_password_set_at_id_index ON users (password_set_at, id);
    ")
  end

  def down do
    execute("
    DROP INDEX CONCURRENTLY IF EXISTS tokens_user_id_expires_at_index;
    ")
    execute("
    DROP INDEX CONCURRENTLY IF EXISTS users_password_set_at_id_index;
    ")
  end
end
