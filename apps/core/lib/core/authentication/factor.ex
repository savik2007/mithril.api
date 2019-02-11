defmodule Core.Authentication.Factor do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "authentication_factors" do
    field(:type, :string)
    field(:factor, :string)
    field(:is_active, :boolean, default: true)
    field(:otp, :integer, virtual: true)
    field(:email, :string, virtual: true)

    belongs_to(:user, Core.UserAPI.User)

    timestamps()
  end
end
