defmodule Core.ClientTypeAPI.ClientType do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "client_types" do
    field(:name, :string)
    field(:scope, :string)

    field(:seed?, :boolean, default: false, virtual: true)

    has_many(:clients, Core.Clients.Client)

    timestamps()
  end

  @cabinet_client_type "CABINET"

  def client_type(:cabinet), do: @cabinet_client_type
end
