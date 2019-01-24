defmodule Mithril.Repo.Migrations.OtpAddKeyCitext do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext")

    alter table(:otp) do
      modify(:key, :citext)
    end

    execute("UPDATE otp SET key=lower(key)")
  end
end
