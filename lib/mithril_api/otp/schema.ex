defmodule Mithril.OTP.Schema do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "otp" do
    field(:key, :string)
    field(:code, :integer)
    field(:code_expired_at, :utc_datetime)
    field(:status, :string)
    field(:active, :boolean)
    field(:attempts_count, :integer, default: 0)
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
