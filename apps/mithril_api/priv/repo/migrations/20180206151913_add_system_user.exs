defmodule Mithril.Repo.Migrations.AddSystemUser do
  use Ecto.Migration

  def change do
    execute(
      "INSERT INTO users(id, email, password, settings, priv_settings, inserted_at, updated_at, is_blocked, block_reason, password_set_at) " <>
        "VALUES ('4261eacf-8008-4e62-899f-de1e2f7065f0', 'bot@ehealth-ukraine.org', '$2b$12$iwFmDKCvTLiwLywAWx1ppOdSQHLi8u0hQ7o8u5WmNUVS/nIwAFDFG', " <>
        "'{}', '{}', current_timestamp, current_timestamp, false, null, current_timestamp);"
    )
  end
end
