defmodule Core.UserAPI.PasswordHistory do
  @moduledoc false

  use Ecto.Schema

  schema "password_hstr" do
    field(:password, :string)
    belongs_to(:user, Core.UserAPI.User, type: Ecto.UUID)
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
