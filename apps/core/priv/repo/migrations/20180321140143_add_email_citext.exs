defmodule Core.Repo.Migrations.AddEmailCitext do
  @moduledoc false

  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext")

    alter table(:users) do
      modify(:email, :citext)
    end

    execute("UPDATE users SET email=lower(email)")
  end
end
