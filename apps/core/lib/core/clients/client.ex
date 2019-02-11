defmodule Core.Clients.Client do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Core.Clients.Connection
  alias Core.ClientTypeAPI.ClientType
  alias Core.UserAPI.User

  @fields_required ~w(
    name
    user_id
    settings
    priv_settings
    client_type_id
  )a

  @fields_optional ~w(
    is_blocked
    block_reason
  )a

  @access_type_direct "DIRECT"
  @access_type_broker "BROKER"

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "clients" do
    field(:name, :string)
    field(:priv_settings, :map, default: %{"access_type" => "BROKER"})
    field(:settings, :map, default: %{})
    field(:is_blocked, :boolean, default: false)
    field(:block_reason, :string)
    field(:seed?, :boolean, default: false, virtual: true)
    field(:redirect_uri, :string)

    belongs_to(:client_type, ClientType)
    belongs_to(:user, User)

    has_many(:connections, Connection)

    timestamps()
  end

  def changeset(%__MODULE__{} = client, attrs) do
    client
    |> cast(attrs, @fields_required ++ @fields_optional)
    |> validate_required(@fields_required)
    |> validate_priv_settings()
    |> unique_constraint(:name)
    |> assoc_constraint(:user)
    |> assoc_constraint(:client_type)
  end

  defp validate_priv_settings(changeset) do
    validate_change(changeset, :priv_settings, fn :priv_settings, priv_settings ->
      case Map.get(priv_settings, "access_type") do
        nil -> [priv_settings: "access_type required."]
        @access_type_direct -> []
        @access_type_broker -> []
        _ -> [priv_settings: "access_type is invalid."]
      end
    end)
  end

  def access_type(:direct), do: @access_type_direct
  def access_type(:broker), do: @access_type_broker
end
