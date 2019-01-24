defmodule Mithril.Repo.Migrations.CreateOTP do
  use Ecto.Migration

  def change do
    create table(:otp, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:key, :string, null: false)
      add(:code, :integer, null: false)
      add(:code_expired_at, :utc_datetime, null: false)
      add(:status, :string, null: false)
      add(:active, :boolean, default: true)
      add(:attempts_count, :integer, default: 0)
      timestamps(updated_at: false, type: :utc_datetime)
    end
  end
end
