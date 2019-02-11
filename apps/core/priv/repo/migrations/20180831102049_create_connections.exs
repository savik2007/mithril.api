defmodule Core.Repo.Migrations.CreateConnections do
  use Ecto.Migration

  def change do
    create table(:connections, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:secret, :string)
      add(:redirect_uri, :string)
      add(:client_id, references(:clients, on_delete: :delete_all, type: :uuid), null: false)
      add(:consumer_id, references(:clients, on_delete: :delete_all, type: :uuid), null: false)

      timestamps()
    end

    create(unique_index(:connections, [:secret]))
    create(unique_index(:connections, [:client_id, :consumer_id]))
  end
end
