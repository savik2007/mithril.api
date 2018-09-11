defmodule Mithril.Repo.Migrations.RemoveRedirectUriFromClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      remove(:secret)
      remove(:redirect_uri)
    end
  end
end
