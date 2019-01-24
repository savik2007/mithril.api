defmodule Mithril.RoleAPI.Role do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "roles" do
    field(:name, :string)
    field(:scope, :string)

    field(:seed?, :boolean, default: false, virtual: true)

    timestamps()
  end
end
