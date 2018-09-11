defmodule Mithril.Repo.Migrations.SetConnectionsSecretNotNull do
  use Ecto.Migration

  def change do
    alter table(:connections) do
      modify(:secret, :string, null: false)
      modify(:redirect_uri, :string, null: false)
    end
  end
end
