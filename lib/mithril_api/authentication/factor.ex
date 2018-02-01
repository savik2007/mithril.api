defmodule Mithril.Authentication.Factor do
  @doc false

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "authentication_factors" do
    field(:type, :string)
    field(:factor, :string)
    field(:is_active, :boolean, default: true)

    belongs_to(:user, Mithril.UserAPI.User)

    timestamps()
  end
end
