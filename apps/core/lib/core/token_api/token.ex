defmodule Core.TokenAPI.Token do
  @moduledoc false
  use Ecto.Schema

  alias Core.UserAPI.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tokens" do
    field(:details, :map)
    field(:expires_at, :integer)
    field(:name, :string)
    field(:value, :string)

    belongs_to(:user, User)

    timestamps()
  end
end
